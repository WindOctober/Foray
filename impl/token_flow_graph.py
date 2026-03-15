from typing import List, Set, Dict

from .financial_constraints import extract_rw_vars

from .synthesizer import AFLAction, Sketch
from .utils import *
from .utils_slither import *

VOID = "VOID"
TRACE = List["TFGEdge"]


class TFGNode:
    def __init__(self, account: str, token: str) -> None:
        self.account = account
        self.token = token
        self.name = f"{account}-{token}"
        self.income_edges: List["TFGEdge"] = []
        self.outcome_edges: List["TFGEdge"] = []

    def add_edge(self, edge: "TFGEdge"):
        if edge.start == self:
            self.outcome_edges.append(edge)
        if edge.end == self:
            self.income_edges.append(edge)

    def __eq__(self, __value: "TFGNode") -> bool:
        return self.name == __value.name

    def __hash__(self) -> int:
        return hash(self.name)


class TFGEdge:
    def __init__(self, account: str, start: "TFGNode", end: "TFGNode", label: AFLAction) -> None:
        self.account = account
        self.start = start
        self.end = end
        self.label = label
        self.name = label.func_sig
        self.start.add_edge(self)
        self.end.add_edge(self)

    def __eq__(self, __value: "TFGEdge") -> bool:
        return self.name == __value.name

    def __hash__(self) -> int:
        return hash(self.name)


class TFG:
    def __init__(self, account: str) -> None:
        self.account = account
        self.nodes: Dict[str, "TFGNode"] = {}
        self.edges: Dict[str, "TFGEdge"] = {}
        self._freeze = False

    def add_node(self, token: str) -> "TFGNode":
        if self._freeze:
            raise RuntimeError("Don't add item to a forzen graph.")
        node = TFGNode(self.account, token)
        self.nodes[node.name] = node
        return node

    def add_edge(self, start: str, end: str, f: AFLAction) -> "TFGEdge":
        if self._freeze:
            raise RuntimeError("Don't add item to a forzen graph.")
        start_n = self.get_node(start)
        end_n = self.get_node(end)
        edge = TFGEdge(self.account, start_n, end_n, f)
        self.edges[edge.name] = edge
        return edge

    def get_node(self, token: str):
        return self.nodes[f"{self.account}-{token}"]


class TFGManager:
    MAX_STEP = 7

    def __init__(
        self, tokens: List[str], accounts: List[str], func_summarys: List[AFLAction], attack_goal: str
    ) -> None:
        self.sub_graphs: Dict[str, TFG] = {}
        self.tokens = tokens
        self.accounts = accounts
        self.func_summarys = func_summarys
        self.func_sigs = {f.func_sig for f in self.func_summarys}
        self.attack_goal = attack_goal
        for a in accounts:
            sub_graph = TFG(a)
            for t in tokens:
                sub_graph.add_node(t)
            self.sub_graphs[a] = sub_graph

        self.main_graph = self.sub_graphs["attacker"]
        self.start_node: TFGNode = self.main_graph.get_node(VOID)

        for f in func_summarys:
            if f.action_name in ("swap", "deposit", "withdraw"):
                a0 = f.account
                sub_graph0 = self.sub_graphs[a0]
                e0 = sub_graph0.add_edge(f.token0, f.token1, f)

                a1 = f.swap_pair
                sub_graph1 = self.sub_graphs[a1]
                e1 = sub_graph1.add_edge(f.token1, f.token0, f)
            else:
                for flow in f.token_flows:
                    a0 = flow.sender
                    sub_graph0 = self.sub_graphs[a0]
                    e0 = sub_graph0.add_edge(flow.token, VOID, f)

                    a1 = flow.receiver
                    sub_graph1 = self.sub_graphs[a1]
                    e1 = sub_graph1.add_edge(VOID, flow.token, f)

    def prune(self, trace: TRACE) -> bool:
        def trace_sig(t):
            try:
                return ' | '.join([f"{e.label.action_name}:{e.start.token}->{e.end.token}" for e in t])
            except Exception:
                return str([getattr(e, 'name', repr(e)) for e in t])

        # 1) last edge must end in VOID (flashloan completion)
        if trace[-1].end.token != VOID:
            print(f"[prune] reason=last_end_not_VOID trace={trace_sig(trace)}")
            return True

        # 2) first edge end token should match last edge start token
        if trace[0].end.token != trace[-1].start.token:
            print(f"[prune] reason=start_end_mismatch trace={trace_sig(trace)}")
            return True

        def _safe_get(obj, name):
            try:
                return getattr(obj, name)
            except (AttributeError, NotImplementedError, IndexError):
                return None

        # 3) lender must match for flashloan sequences
        if _safe_get(trace[0].label, 'lender') != _safe_get(trace[-1].label, 'lender'):
            print(f"[prune] reason=lender_mismatch trace={trace_sig(trace)} lenders=({_safe_get(trace[0].label,'lender')},{_safe_get(trace[-1].label,'lender')})")
            return True

        has_attack_goal_token = False
        for idx, e in enumerate(trace):
            action = e.label
            # check attack goal token presence
            try:
                if e.end.token == self.attack_goal and action.action_name != "borrow":
                    has_attack_goal_token = True
            except Exception:
                pass

            if idx >= 1:
                last_e = trace[idx - 1]
                last_action = last_e.label
                if action.action_name == "borrow" and last_action.action_name == "payback":
                    print(f"[prune] reason=borrow_after_payback trace={trace_sig(trace)} idx={idx}")
                    return True
                if action.action_name == "payback" and last_action.action_name == "borrow":
                    print(f"[prune] reason=payback_after_borrow trace={trace_sig(trace)} idx={idx}")
                    return True

            # Avoid swap inside flashloan when lender == swap_pair
            if action.action_name == "swap":
                for jdx, e1 in enumerate(trace[:idx]):
                    e1_action = e1.label
                    try:
                        if e1_action.action_name == "borrow":
                            if _safe_get(e1_action, 'lender') == _safe_get(action, 'swap_pair'):
                                print(f"[prune] reason=swap_inside_flashloan trace={trace_sig(trace)} idx={idx} borrow_idx={jdx}")
                                return True
                    except Exception:
                        continue

        if not has_attack_goal_token:
            print(f"[prune] reason=no_attack_goal_token trace={trace_sig(trace)}")
            return True

        return False

    def mutation(self, sketch: Sketch):
        # Heuristics
        new_sketches = []
        actions = sketch.pure_actions
        attacker_got_tokens = set()
        for i, cur_a in enumerate(actions):
            if i == 0:
                continue
            # Price manipulation
            if cur_a.action_name == "swap":
                if cur_a.account == "attacker":
                    attacker_got_tokens.add(cur_a.token1)
                read_vars, _ = extract_rw_vars(cur_a.constraints)
                # The balance of acction doesn't influence the price.
                n_read_vars = set(v for v in read_vars if not cur_a.account in v)
                for f in self.func_summarys:
                    if f.action_name == "swap":
                        if f.account == cur_a.account:
                            continue
                    if f.action_name == "borrow" or f.action_name == "payback":
                        continue
                    # Perhaps manipulate the price
                    _, write_vars = extract_rw_vars(f.constraints)
                    if write_vars.intersection(n_read_vars) != set():
                        new_sketch = [*actions]
                        new_sketch.insert(i, f)
                        new_sketches.append(Sketch(new_sketch).symbolic_copy())

            # Price manipulation
            if cur_a.action_name == "withdraw":
                last_a = actions[i-1]
                if cur_a.account == "attacker":
                    attacker_got_tokens.add(cur_a.token1)
                if last_a.action_name == "deposit" and last_a.defi == cur_a.defi:
                    read_vars, _ = extract_rw_vars(cur_a.constraints)
                    # The balance of acction doesn't influence the price.
                    n_read_vars = set(v for v in read_vars if not cur_a.account in v)
                    for f in self.func_summarys:
                        if f == cur_a or f == last_a or f.action_name == "payback":
                            continue
                        # Perhaps manipulate the price
                        if f.action_name == "borrow":
                            _, write_vars = extract_rw_vars(f.constraints)
                            if write_vars.intersection(n_read_vars) != set():
                                new_sketch = [*actions]
                                new_sketch.insert(i, f)
                                matched_payback = AFLAction("payback", f.args_in_name, f.args)
                                new_sketch.insert(i + 2, matched_payback)
                                new_sketches.append(Sketch(new_sketch).symbolic_copy())
                        else:
                            _, write_vars = extract_rw_vars(f.constraints)
                            if write_vars.intersection(n_read_vars) != set():
                                new_sketch = [*actions]
                                new_sketch.insert(i, f)
                                new_sketches.append(Sketch(new_sketch).symbolic_copy())

            if cur_a.action_name == "deposit":
                if cur_a.account == "attacker":
                    attacker_got_tokens.add(cur_a.token1)
            
            # Token distribution
            if cur_a.action_name == "payback":
                payback_token = cur_a.token0
                if payback_token in attacker_got_tokens:
                    attacker_got_tokens.remove(payback_token)
                for t in attacker_got_tokens:
                    for f in self.func_summarys:
                        if not f.action_name == "swap":
                            continue
                        if not (f.token0 == t and f.token1 == payback_token):
                            continue
                        if f.func_sig in sketch.func_sigs:
                            continue
                        new_sketch = [*actions]
                        new_sketch.insert(i, f)
                        new_sketches.append(Sketch(new_sketch).symbolic_copy())
        return new_sketches

    def gen_candidates(self):
        i = 0
        candidates: List[Sketch] = []
        while i <= self.MAX_STEP:
            # for c in candidates:
            #     print("--------")
            #     if len(c) == i - 1:
            #         print(c)
            potential_candidates: List[Sketch] = []
            if i == 0:
                old_traces = []
                new_traces: List[TRACE] = [[e] for e in self.start_node.outcome_edges]
            else:
                old_traces = new_traces
                new_traces: List[TRACE] = []
                for t in old_traces:
                    end_node = t[-1].end
                    for e in end_node.outcome_edges:
                        new_traces.append([*t, e])
            for t in new_traces:
                if self.prune(t):
                    continue
                actions = [a.label for a in t]
                sketch = Sketch(actions).symbolic_copy()
                potential_candidates.append(sketch)
            k = 0
            while k <= len(potential_candidates) - 1:
                cur_sketch = potential_candidates[k]
                if len(cur_sketch) == self.MAX_STEP:
                    # No longer need to mutate.
                    break
                new_candidates = self.mutation(cur_sketch)
                for nc in new_candidates:
                    potential_candidates.insert(k+1, nc)
                    k += 1
                k += 1
            candidates.extend(potential_candidates)

            i += 1
        return candidates


def load_tfg_manager_from_json(json_path: str) -> TFGManager:
    """Load TFGManager from a Flare_submit-exported JSON file."""
    import json

    with open(json_path, 'r') as f:
        data = json.load(f)

    tokens = data['tokens']
    accounts = data['accounts']
    func_summaries = [AFLAction.from_dict(action_data) for action_data in data['func_summaries']]

    ag = data.get('attack_goal', {})
    if isinstance(ag, dict):
        attack_goal = ag.get('profit_token', None)
    else:
        attack_goal = ag

    if attack_goal is None or attack_goal not in tokens:
        for token in tokens:
            if token != VOID:
                attack_goal = token
                break

    manager = TFGManager(tokens, accounts, func_summaries, attack_goal)

    for account, tfg_data in data['sub_graphs'].items():
        sub_graph = manager.sub_graphs[account]

        # TFGManager.__init__ constructs edges from func_summaries using Foray's
        # internal graph-building logic. When loading from JSON we must fully
        # replace that structure with the exported graph rather than layering on
        # top of it, otherwise node edge lists keep stale inferred edges.
        sub_graph.edges.clear()
        for node in sub_graph.nodes.values():
            node.outcome_edges.clear()
            node.income_edges.clear()

        for node_data in tfg_data.get('nodes', {}).values():
            token = node_data.get('token')
            if token is None:
                continue
            node_key = f"{account}-{token}"
            if node_key not in sub_graph.nodes:
                sub_graph.add_node(token)

        for edge_data in tfg_data.get('edges', {}).values():
            start_token = edge_data['start'].split('-', 1)[1]
            end_token = edge_data['end'].split('-', 1)[1]
            label = AFLAction.from_dict(edge_data['label'])

            if f"{account}-{start_token}" not in sub_graph.nodes:
                sub_graph.add_node(start_token)
            if f"{account}-{end_token}" not in sub_graph.nodes:
                sub_graph.add_node(end_token)

            sub_graph.add_edge(start_token, end_token, label)

    manager.address_to_role = data.get('address_to_role', {})

    try:
        print(f"[load_tfg_manager_from_json] tokens={manager.tokens}")
        print(f"[load_tfg_manager_from_json] accounts={manager.accounts}")
        print(f"[load_tfg_manager_from_json] attack_goal={manager.attack_goal}")
        if hasattr(manager, 'start_node') and manager.start_node is not None:
            print(f"[load_tfg_manager_from_json] start_node={manager.start_node.name} outcomes={len(manager.start_node.outcome_edges)}")
            print(f"[load_tfg_manager_from_json] start_outcome_names={[e.name for e in manager.start_node.outcome_edges]}")
    except Exception:
        pass

    try:
        main = manager.sub_graphs.get('attacker', None)
        if main is not None and (manager.start_node is None or len(manager.start_node.outcome_edges) == 0):
            for node in main.nodes.values():
                if len(node.outcome_edges) > 0:
                    manager.start_node = node
                    print(f"[load_tfg_manager_from_json] switched start_node to {node.name}")
                    break
    except Exception:
        pass

    return manager
