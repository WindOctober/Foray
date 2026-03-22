import json
import os
import subprocess
from os import path
from typing import Dict, List, Optional, Tuple

from .config import Config, init_config
from .dsl import *
from .utils import CornerCase, ATTACK_CONTRACT_CLS
from .synthesizer import Synthesizer
from .foundry_bins import forge_skip_args, resolve_foundry_bin


class BenchmarkBuilder:
    """
    Used for building test sol contract to do the test.
    """

    uniswap_pair_ctrt = "UniswapV2Pair"
    uniswap_factory_ctrt = "UniswapV2Factory"
    uniswap_router_ctrt = "UniswapV2Router"
    attack_ctrt_sv = "attackContract"
    default_erc20_tokens = [
        "USDCE",
        "USDT",
        "WETH",
        "WBNB",
        "BUSD",
    ]
    default_import_ctrts = [
        *default_erc20_tokens,
        uniswap_pair_ctrt,
        uniswap_factory_ctrt,
        uniswap_router_ctrt,
    ]

    check_cand_prefix = "check_cand"

    def __init__(self, bmk_dir: str, sketch_generation: bool = False) -> None:
        self.bmk_dir = bmk_dir
        _, result_path = prepare_subfolder(bmk_dir)
        self.config: Config = init_config(bmk_dir)
        self.name = self.config.project_name
        self.roles = self.config.roles

        # Map contract's variable name to its contract label.
        self.ctrt_name2cls = {name: cls for name, cls in self.config.ctrt_name2cls}
        self.ctrt_name2deploy = self.config.ctrt_name2deploy
        # Like pair, router, usdt, etc.
        self.ctrt_names = list(self.ctrt_name2cls.keys())
        # Like UniswapV2Router, USDCE, USDT, etc.
        self.ctrt_cls = set(self.ctrt_name2cls.values())

        self.attack_goal = self.config.attack_goal
        self.extra_deployments = self.config.extra_deployments
        self.extra_deployments_before = self.config.extra_deployments_before
        self.extra_statements = self.config.extra_statements
        self.helper_actions = self._load_flare_helper_actions()
        self.helper_action_names = list(self.helper_actions.keys())

        # Uniswap pairs.
        self.uniswap_pairs: List[str] = self.config.uniswap_pairs

        # Uniswap pairs to token_names
        self.swap_pair2tokens = self.config.swappair2tokens

        self.uniswap_2tokens = {k: v for k, v in self.swap_pair2tokens.items() if self.roles[k].is_uniswap}

        # ERC20 tokens.
        self.erc20_tokens = self.config.erc20_tokens

        # Map state_variable name to its type and initial value.
        self.init_state: Dict[str, Tuple[str, str]] = {}

        # Collect all public action names.
        self.ava_action_names = []

        # Will print token_users' initial balances.
        self.token_users = list(self.ctrt_name2cls.keys())
        self.token_users.remove("router")
        self.token_users.remove("factory")

        # Lender Pool
        self.lend_pools = self.config.lend_pools

        self._init_state()
        self._init_ava_action_names()

        if sketch_generation:
            self.synthesizer = None
        else:
            self.synthesizer = Synthesizer(self.bmk_dir, record=load_record(result_path))


    def _init_state(self):
        # Handle the initial states print by foundry.
        # Look at: QueryBlockchain.sol and query_output_example.txt for more information.
        cache_path, result_path = prepare_subfolder(self.bmk_dir)
        cache_file = path.join(result_path, "_query.cache")
        query_sol_path = path.join(self.bmk_dir, f"{self.name}_query.t.sol")
        if path.exists(cache_file):
            with open(cache_file, "r") as f:
                outputs = f.readlines()
                outputs = [l.rstrip("\n") for l in outputs]
        else:
            outputs = self._refresh_query_cache(query_sol_path, cache_file, cache_path)

        self._load_init_state_from_outputs(outputs)
        if "blockTimestamp" not in self.init_state:
            outputs = self._refresh_query_cache(query_sol_path, cache_file, cache_path)
            self.init_state.clear()
            self._load_init_state_from_outputs(outputs)

    def _refresh_query_cache(self, query_sol_path: str, cache_file: str, cache_path: str) -> List[str]:
        self.output_query(query_sol_path)
        cmd = [
            resolve_foundry_bin("forge"),
            "test",
            *forge_skip_args(),
            "-vv",
            "--contracts",
            self.bmk_dir,
            "--cache-path",
            cache_path,
            "--match-path",
            query_sol_path,
            "--extra-output",
            "storageLayout",
            "metadata",
            "--root",
            os.getcwd(),
            "--evm-version",
            "shanghai",
        ]
        print(" ".join(cmd))
        try:
            proc = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=os.getcwd(),
                check=True,
            )
        except Exception as err:
            if isinstance(err, subprocess.CalledProcessError):
                print(err.stdout)
                print(err.stderr)
            raise RuntimeError(f"Forge test failed while initializing benchmark state for {self.name}") from err
        outputs = proc.stdout + proc.stderr
        with open(cache_file, "w") as f:
            f.write(outputs)
        return outputs.split("\n")

    def _load_init_state_from_outputs(self, outputs: List[str]):
        for output in outputs:
            if output.startswith("  ----"):
                continue
            if output == "":
                continue
            if not output.startswith("  "):
                continue
            result = [s for s in output.split(" ") if s != ""]
            if len(result) != 3:
                continue
            type_str, sv_name, sv_val = result
            type_str = type_str[1:] if type_str.startswith(" ") else type_str
            sv_name = sv_name[:-1] if sv_name.endswith(":") else sv_name
            self.init_state[sv_name] = (type_str, sv_val)

    def output_query(self, output_path: str):
        query_contract_name = f"{self.name}Query"
        base_contract_name = f"{self.name}TestBase"
        import_target = f"./{self.name}.t.sol"
        if not path.exists(path.join(self.bmk_dir, f"{self.name}.t.sol")):
            candidates_path = path.join(self.bmk_dir, f"{self.name}_candidates.t.sol")
            if path.exists(candidates_path):
                import_target = f"./{self.name}_candidates.t.sol"
                base_contract_name = f"{self.name}Test"

        lines = [
            "// SPDX-License-Identifier: MIT",
            "pragma solidity ^0.8.0;",
            f'import "{import_target}";',
            f"contract {query_contract_name} is {base_contract_name}" + "{",
            "function test_query() public {",
            "queryBlockTimestamp();",
        ]

        for pair_name in self.uniswap_pairs:
            lines.append(f'queryUniswapV2Pair(address({pair_name}), "{pair_name}");')

        user_count = len(self.token_users)
        lines.extend(
            [
                f"address[] memory users = new address[]({user_count});",
                f"string[] memory userNames = new string[]({user_count});",
            ]
        )
        for idx, user in enumerate(self.token_users):
            lines.append(f"users[{idx}] = address({user});")
            lines.append(f'userNames[{idx}] = "{user}";')

        for token in self.erc20_tokens:
            lines.append(
                f'queryERC20(address({token}), "{token}", users, userNames);'
            )

        lines.extend(["}", "}"])

        with open(output_path, "w") as f:
            for line in lines:
                f.write(line)
                f.write("\n")

    def _init_ava_action_names(self):
        actions = self.gen_actions()
        for l in actions:
            m = func_name_regex.match(l)
            if m:
                func_name = m.group(1)
                self.ava_action_names.append(func_name)

    def _find_flare_tfg_path(self) -> Optional[str]:
        candidates = [
            path.join(self.bmk_dir, "flare_tfg.json"),
            path.join(self.bmk_dir, f"{self.name.lower()}_tfg.json"),
            path.join(self.bmk_dir, f"{self.name}_tfg.json"),
        ]
        return next((p for p in candidates if path.exists(p)), None)

    def _load_flare_helper_actions(self) -> Dict[str, List[str]]:
        flare_tfg_path = self._find_flare_tfg_path()
        if flare_tfg_path is None:
            return {}

        with open(flare_tfg_path, "r") as f:
            graph_data = json.load(f)

        helper_actions: Dict[str, List[str]] = {}
        for edge_data in graph_data.get("graph", {}).get("edges", {}).values():
            label = edge_data.get("label", {})
            func_sig = label.get("func_sig")
            helper = label.get("helper")
            if not func_sig or not helper:
                continue
            helper_actions[func_sig] = self._render_helper_action(func_sig, helper)
        return helper_actions

    def _render_helper_action(self, func_sig: str, helper: dict) -> List[str]:
        params = helper.get("params", [])
        used_param_names = self._collect_helper_param_names(
            helper.get("steps", []),
            [param["name"] for param in params],
        )
        rendered_params = []
        for param in params:
            param_ty = param["ty"]
            param_name = param["name"]
            if param_name in used_param_names:
                rendered_params.append(f"{param_ty} {param_name}")
            else:
                rendered_params.append(param_ty)
        signature = ", ".join(rendered_params)
        lines = [f"function {func_sig}({signature}) internal eurus" + "{"]
        for step in helper.get("steps", []):
            lines.append(self._render_helper_step(step))
        lines.append("}")
        return lines

    def _collect_helper_param_names(self, steps: List[dict], param_names: List[str]) -> set[str]:
        names = set()
        for step in steps:
            if step.get("kind") == "call":
                for arg in step.get("args", []):
                    for param_name in param_names:
                        if param_name in arg:
                            names.add(param_name)
        return names

    def _render_helper_step(self, step: dict) -> str:
        kind = step.get("kind")
        if kind == "call":
            target = step["target"]
            method = step["method"]
            args = ", ".join(step.get("args", []))
            return f"{target}.{method}({args});"
        if kind == "raw":
            return step["code"]
        raise ValueError(f"Unsupported helper action step: {step}")

    def gen_imports(self) -> List[str]:
        license = "// SPDX-License-Identifier: MIT"
        pragma = "pragma solidity ^0.8.0;"
        imports = [
            'import "forge-std/Test.sol";',
            'import "@utils/QueryBlockchain.sol";',
        ]
        for c in self.ctrt_cls:
            # if c in self.default_import_ctrts:
            #     imports.append(f'import {{{c}}} from "@utils/{c}.sol";')
            # else:
            #     imports.append(f'import "./{c}.sol";')
            if c in self.default_import_ctrts:
                imports.append(f'import {{{c}}} from "@utils/{c}.sol";')
            else:
                imports.append(f'import {{{c}}} from "./{c}.sol";')
        imports = sorted(imports)
        all = [license, pragma, *imports]
        return all

    def gen_contract_header(self, suffix: str) -> List[str]:
        return [f"contract {self.name}{suffix} is Test, BlockLoader " + "{"]

    def gen_state_varibles(self) -> List[str]:
        contract_interfaces = []
        for k, v in self.ctrt_name2cls.items():
            if v == ATTACK_CONTRACT_CLS:
                contract_interfaces.append(f"{ATTACK_CONTRACT_CLS} {self.attack_ctrt_sv};")
            else:
                contract_interfaces.append(f"{v} {k};")
        users = [
            f"address owner;",
            f"address attacker;",
            *[f"address {c}Addr;" for c in self.ctrt_names],
        ]
        states = []
        for sv_name, v in self.init_state.items():
            type_str, sv_val = v
            output_str = f"{type_str} {sv_name} = {sv_val};"
            states.append(output_str)
        all = [*contract_interfaces, *users, *states]
        return all

    def gen_setup(self) -> List[str]:
        all = [
            "function setUp() public {",
            "owner = address(this);",
        ]

        # Deploy contracts
        for ctrt_name, stmt in self.ctrt_name2deploy:
            # Default deployment
            ctrt_label = self.ctrt_name2cls[ctrt_name]
            if stmt == "":
                if ctrt_label in self.default_erc20_tokens:
                    d_stmt = f"{ctrt_name} = new {ctrt_label}();"

                elif ctrt_label == self.uniswap_pair_ctrt:
                    token0, token1 = self.uniswap_2tokens[ctrt_name]
                    d_stmt = f"{ctrt_name} = new {self.uniswap_pair_ctrt}(\
                        address({token0}), address({token1}), \
                        reserve0{ctrt_name}, reserve1{ctrt_name}, \
                        blockTimestampLast{ctrt_name}, kLast{ctrt_name}, \
                        price0CumulativeLast{ctrt_name}, price1CumulativeLast{ctrt_name});"

                elif ctrt_label == self.uniswap_factory_ctrt:
                    pairs = self.uniswap_pairs
                    if len(pairs) > 3:
                        raise ValueError("More than 3 pairs are not supported.")
                    addrs = [f"address({pairs[i]})" if i < len(pairs) else "address(0x0)" for i in range(3)]
                    params = ["address(0xdead)", *addrs]
                    d_stmt = f'{ctrt_name} = new {self.uniswap_factory_ctrt}({",".join(params)});'

                elif ctrt_label == self.uniswap_router_ctrt:
                    d_stmt = f"{ctrt_name} = new {self.uniswap_router_ctrt}(address(factory), address(0xdead));"
                elif ctrt_label == ATTACK_CONTRACT_CLS:
                    d_stmt = f"{self.attack_ctrt_sv} = new {ATTACK_CONTRACT_CLS}();"
                else:
                    raise CornerCase(f"Unsupported default deployment: {ctrt_label}")
            else:
                d_stmt = f"{ctrt_name} = {stmt};"
            all.append(d_stmt)
            addr_target = self.attack_ctrt_sv if ctrt_label == ATTACK_CONTRACT_CLS else ctrt_name
            all.append(f"{ctrt_name}Addr = address({addr_target});")

        all.append(f"attacker = address({self.attack_ctrt_sv});")
        all.extend(self.extra_deployments_before)

        all.append("// Initialize balances and mock flashloan.")

        # Deploy tokens
        for u in self.token_users:
            addr = f"address({u})"
            for t in self.erc20_tokens:
                sv_name = f"balanceOf{t}{u}"
                _, val = self.init_state.get(sv_name, ("uint256", "0"))
                if val != "0":
                    stmt = f"{t}.transfer({addr}, {sv_name});"
                    all.append(stmt)

        all.extend(self.extra_deployments)

        all.append("}")
        return all

    def gen_helper_funcs(self) -> List[str]:
        # Action modifier
        action_mod = ["modifier eurus() {", "_;", "}"]

        # Print balance.
        printer = [
            "function printBalance(string memory tips) public {",
            "emit log_string(tips);",
        ]
        for u in self.token_users:
            addr = f"address({u})"
            printer.append(f'emit log_string("{u.capitalize()} Balances: ");')
            for t in self.erc20_tokens:
                printer.append(f"queryERC20BalanceDecimals(address({t}), {addr}, {t}.decimals());")
            printer.append('emit log_string("");')
        printer.append('emit log_string("");')
        printer.append('emit log_string("");')
        printer.append("}")

        # Attack goal
        token, amount = self.attack_goal
        attack_goal_func = [
            "function attackGoal() public returns (bool) {",
            f'emit log_named_uint("StartBalance", balanceOf{token}attacker);',
            f'emit log_named_uint("FinalBalance", {token}.balanceOf(attacker));',
            f"return {token}.balanceOf(attacker) >= {amount} + balanceOf{token}attacker;",
            "}",
        ]

        return [*action_mod, *printer, *attack_goal_func]

    def gen_actions(self) -> List[str]:
        # To distinguish with testing, all actions are modified by internal.
        # Actions
        actions = []
        helper_action_names = set(self.helper_action_names)
        generated_action_names = set()

        def add_func_to_actions(func_body: str):
            func_name = func_name_regex.match(func_body[0]).group(1)
            if func_name in helper_action_names or func_name in generated_action_names:
                return
            actions.extend(func_body)
            generated_action_names.add(func_name)

        # flashloan borrow-payback
        for l in self.lend_pools:
            addr = l if l == "owner" else f"address({l})"
            for t in self.erc20_tokens:
                borrow = [
                    f"function borrow_{t}_{l}(uint256 amount) internal eurus" + "{",
                    f"vm.stopPrank();",
                    f"vm.prank({addr});",
                    f"{t}.transfer(attacker, amount);",
                    f"vm.startPrank(attacker);",
                    "}",
                ]
                payback = [
                    f"function payback_{t}_{l}(uint256 amount) internal eurus" + "{",
                    f"{t}.transfer({addr}, amount);",
                    "}",
                ]
                add_func_to_actions(borrow)
                add_func_to_actions(payback)

        # swap by uniswap
        for u, t in self.uniswap_2tokens.items():
            token0, token1 = t
            swap0 = [
                f"function swap_{u}_attacker_{token0}_{token1}(uint256 amount, uint256 amountOut) internal eurus" + "{",
                f"{token0}.transfer(address({u}), amount);",
                f"{u}.swap(0, amountOut, attacker, new bytes(0));",
                "}",
            ]
            add_func_to_actions(swap0)
            swap1 = [
                f"function swap_{u}_attacker_{token1}_{token0}(uint256 amount, uint256 amountOut) internal eurus" + "{",
                f"{token1}.transfer(address({u}), amount);",
                f"{u}.swap(amountOut, 0, attacker, new bytes(0));",
                "}",
            ]
            add_func_to_actions(swap1)

        for helper_body in self.helper_actions.values():
            actions.extend(helper_body)

        return actions

    def output(self, output_path: str):
        results = [
            *self.gen_imports(),
            *self.gen_contract_header("TestBase"),
            *self.gen_state_varibles(),
            *self.gen_setup(),
            *self.gen_helper_funcs(),
            *self.gen_actions(),
            "}",
        ]
        with open(output_path, "w") as f:
            for l in results:
                f.write(l)
                f.write("\n")

    def output_with_candidates(self, output_path: str):
        self.synthesizer = Synthesizer(self.bmk_dir, record=None)
        func_bodys: List[str] = []
        for idx, c in enumerate(self.synthesizer.candidates):
            suffix = str(idx).zfill(ZFILL_SIZE)
            func_name = self.check_cand_prefix + suffix
            func_bodys.extend(c.output(func_name, self.extra_statements))
        results = [
            *self.gen_imports(),
            *self.gen_contract_header("Test"),
            *self.gen_state_varibles(),
            *self.gen_setup(),
            *self.gen_helper_funcs(),
            *self.gen_actions(),
            *func_bodys,
            "}",
        ]
        with open(output_path, "w") as f:
            for l in results:
                f.write(l)
                f.write("\n")
        return self.synthesizer.candidates, self.synthesizer.timecost

    def output_verify(self, verifiers: List[Tuple[str, Sketch, List[List[str]]]], output_path: str):
        suffix = "Test"
        results = [
            "// SPDX-License-Identifier: MIT",
            "pragma solidity ^0.8.10;",
            f'import "./{self.name}_candidates.t.sol";',
            f"contract {self.name}Verify is {self.name}{suffix}" + "{",
        ]
        for func_name, candidate, arg_candidates in verifiers:
            if len(arg_candidates) == 0:
                continue
            for j, args in enumerate(arg_candidates):
                jdx = str(j).zfill(3)
                actual_name = f"test_verify_{func_name}_{jdx}"
                concre_sketch = candidate.concretize(args)
                results.extend(concre_sketch.output_verify(actual_name, self.extra_statements))
        results.extend(["}"])
        with open(output_path, "w") as f:
            for l in results:
                f.write(l)
                f.write("\n")

    def get_sketch_by_func_name(self, func_name: str, candidates: List[Sketch]):
        idx = int(func_name.removeprefix("check_cand"))
        return candidates[idx]
