import os
from os import path
from subprocess import Popen, run, DEVNULL

import subprocess
from typing import List, Dict, Tuple

from dataclasses import dataclass

import re

import requests
import json

from .storage.read import StorageDescriber, StorageLayout, TypeDescriber, get_var
from .storage.utils import int2address

from .config import init_config
from .foundry_bins import forge_skip_args, resolve_foundry_bin

from .utils import *

DEFAULT_ACCOUNT = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
DEFAULT_PK = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
ATTACK_ACCOUNT = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
ATTACK_PK = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
DEFAULT_HOST = "http://127.0.0.1"
DEFAULT_PORT = "8545"


def init_anvil(timestamp: int):
    cmd = [
        resolve_foundry_bin("anvil"),
        "--timestamp",
        str(timestamp),
        "--base-fee",
        "0",
        "--gas-price",
        "0",
        "--code-size-limit",
        str(10**8),
        "--gas-limit",
        str(10**8),
    ]
    import time
    proc = Popen(cmd, stdout=DEVNULL)
    time.sleep(2)  # Wait for anvil to start
    return proc


def create_snapshot() -> str:
    payload = {
        "id": 1337,
        "jsonrpc": "2.0",
        "method": "evm_snapshot",
        "params": [],
    }
    url = f"{DEFAULT_HOST}:{DEFAULT_PORT}"
    headers = {"Content-Type": "application/json"}
    response = requests.post(url, data=json.dumps(payload), headers=headers)
    if response.status_code == 200:
        # snapshot id.
        return response.json()["result"]
    else:
        raise RuntimeError(f"Create snapshot failed! Error: {response.status_code} - {response.text}")


def recover_snapshot(idx: str):
    payload = {
        "id": 1337,
        "jsonrpc": "2.0",
        "method": "evm_revert",
        "params": [idx],
    }
    url = f"{DEFAULT_HOST}:{DEFAULT_PORT}"
    headers = {"Content-Type": "application/json"}
    response = requests.post(url, data=json.dumps(payload), headers=headers)
    if response.status_code == 200:
        if response.json()["result"]:
            return
    else:
        raise RuntimeError(f"Revert to snapshot: {idx} failed! Error: {response.status_code} - {response.text}")


def set_nomining():
    # Run setup
    cmd = [
        resolve_foundry_bin("cast"),
        "rpc",
        "evm_setAutomine",
        "false",
        "--rpc-url",
        f"{DEFAULT_HOST}:{DEFAULT_PORT}",
    ]
    try:
        out = run(cmd, text=True, capture_output=True)
    except Exception as err:
        print(f"Set nomining failed!")
        raise err


@dataclass
class CastStorageInfo:
    type: str
    slot: str
    offset: str
    bytes: str
    value: str
    hex_value: str
    contract: str


def parse_cast_storage_info(lines: List[str]) -> Dict[str, CastStorageInfo]:
    # Update to anvil 0.2.0
    # |Name|Type|Slot|Offset|Bytes|Value|Hex Value|Contract|
    results = {}
    storage_regex = re.compile(r"\|[\w\s\|]+\|")
    for l in lines:
        if not storage_regex.match(l):
            continue
        record = l.split("|")
        record = [r.strip() for r in record if r]
        if record[0] == "Name":
            continue
        results[record[0]] = CastStorageInfo(*record[1:])
    return results


def _load_storage_layout(cache_path: str, source_key: str, contract_name: str) -> StorageLayout:
    with open(path.join(cache_path, "solidity-files-cache.json"), "r") as f:
        sol_file_cache = json.load(f)["files"]

    if source_key not in sol_file_cache:
        raise ValueError(f"Unknown compiled source: {source_key}")

    artifact_info = sol_file_cache[source_key]["artifacts"][contract_name]
    compiled_file = list(artifact_info.values())[0]
    if isinstance(compiled_file, dict) and "path" not in compiled_file and "default" in compiled_file:
        compiled_file = compiled_file["default"]

    source_output = path.join(".cache", compiled_file["path"])
    with open(source_output, "r") as f:
        compile_output = json.load(f)

    contract_layout = compile_output["storageLayout"]
    label_defs = [StorageDescriber(storage_describer) for storage_describer in contract_layout["storage"]]
    type_def_mapping = {
        type_name: TypeDescriber(type_name, contract_layout["types"])
        for type_name in contract_layout["types"]
    }
    return (label_defs, type_def_mapping)


def _read_contract_address(storage_layout: StorageLayout, deployed_test_addr: str, var_name: str) -> str:
    value = get_var(deployed_test_addr, var_name, [], storage_layout)
    if not isinstance(value, str) or not value.startswith("0x") or len(value) != 42:
        raise ValueError(f"Failed to decode address variable `{var_name}` from deployed test contract")
    return value


def deploy_contract(bmk_dir: str):
    project_name = resolve_project_name(bmk_dir)
    cache_path, _ = prepare_subfolder(bmk_dir)
    config = init_config(bmk_dir)

    ctrt_path = path.join(bmk_dir, f"{project_name}_candidates.t.sol")

    # Deploy
    cmd = [
        resolve_foundry_bin("forge"),
        "create",
        *forge_skip_args(),
        "--contracts",
        bmk_dir,
        "--rpc-url",
        f"{DEFAULT_HOST}:{DEFAULT_PORT}",
        "--private-key",
        DEFAULT_PK,
        "--broadcast",
        "--via-ir",
        "--cache-path",
        cache_path,
        "--extra-output",
        "storageLayout",
        "metadata",
        "--root",
        os.getcwd(),
        f"{ctrt_path}:{project_name}Test",
    ]
    try:
        out = run(cmd, text=True, capture_output=True)
    except Exception as err:
        print(f"Deploy contract:{project_name} failed!")
        raise err
    lines = out.stdout.splitlines(keepends=False)
    address = None
    print("=== Deploy Command Output ===")
    print("STDOUT:")
    print(out.stdout)
    print("STDERR:")
    print(out.stderr)
    print("=== End Output ===")
    for l in lines:
        if l.startswith("Deployed to: "):
            address = l[13:] if l.startswith("Deployed to: ") else l
            address = address.strip()
    if address is None:
        raise ValueError("Unknown address for deployment.")

    # Run setup
    cmd = [
        resolve_foundry_bin("cast"),
        "send",
        "--rpc-url",
        f"{DEFAULT_HOST}:{DEFAULT_PORT}",
        "--private-key",
        DEFAULT_PK,
        "--gas-limit",
        str(10**8),
        address,
        "setUp()",
    ]
    try:
        out = run(cmd, text=True, capture_output=True)
        print("=== setUp() Output ===")
        print("STDOUT:", out.stdout)
        print("STDERR:", out.stderr)
        print("Return code:", out.returncode)
        print("=== End setUp() ===")
    except Exception as err:
        print(f"Setup contract:{project_name} failed!")
        raise err
    
    # Run snapshot
    snapshot_id = create_snapshot()

    # Get contract addresses from the deployed test contract storage layout.
    ctrt_name2addr: Dict[str, str] = {}
    print("=== Retrieving contract addresses ===")
    test_contract_name = f"{project_name}Test"
    source_key = path.join(bmk_dir, f"{project_name}_candidates.t.sol")
    storage_layout = _load_storage_layout(cache_path, source_key, test_contract_name)

    ctrt_name2addr["owner"] = _read_contract_address(storage_layout, address, "owner")
    print(f"  owner: {ctrt_name2addr['owner']}")
    ctrt_name2addr["attacker"] = _read_contract_address(storage_layout, address, "attacker")
    print(f"  attacker: {ctrt_name2addr['attacker']}")

    for ctrt_name, _ in config.ctrt_name2cls:
        if ctrt_name == "attacker":
            continue
        addr_var_name = f"{ctrt_name}Addr"
        ctrt_name2addr[ctrt_name] = _read_contract_address(storage_layout, address, addr_var_name)
        print(f"  {ctrt_name}: {ctrt_name2addr[ctrt_name]}")

    ctrt_name2addr["dead"] = "0x000000000000000000000000000000000000dEaD"
    print("=== End retrieval ===")
    return snapshot_id, ctrt_name2addr


class LazyStorage:
    uniswap_pair_ctrt = "UniswapV2Pair"
    uniswap_factory_ctrt = "UniswapV2Factory"
    uniswap_router_ctrt = "UniswapV2Router"
    default_erc20_tokens = [
        "USDCE",
        "USDT",
        "WETH",
        "WBNB",
        "BUSD",
    ]

    def __init__(self, bmk_dir: str, ctrt_name2addr: Dict[str, str], timestamp: str) -> None:
        self.bmk_dir = bmk_dir
        self.config = init_config(bmk_dir)
        self.project_name = self.config.project_name
        self.ctrt_name2addr: Dict[str, str] = ctrt_name2addr
        self.ctrt_name2stor_layout: Dict[str, StorageLayout] = {}
        self.timestamp = timestamp

        cache_path, _ = prepare_subfolder(bmk_dir)

        sol_file_cache: dict = {}
        with open(path.join(cache_path, "solidity-files-cache.json"), "r") as f:
            sol_file_cache = json.load(f)["files"]

        for ctrt_name, ctrt_filename in self.config.ctrt_name2cls:
            if ctrt_filename in (
                self.uniswap_pair_ctrt,
                self.uniswap_factory_ctrt,
                self.uniswap_router_ctrt,
                *self.default_erc20_tokens,
            ):
                key = f"lib/contracts/@utils/{ctrt_filename}.sol"
            else:
                key = f"benchmarks/{self.project_name}/{ctrt_filename}.sol"
            compiled_file = list(sol_file_cache[key]["artifacts"][ctrt_filename].values())[0]
            # Foundry cache format can wrap artifact under profiles like 'default'
            # Handle both: {'path': ...} and {'default': {'path': ...}}
            if isinstance(compiled_file, dict) and 'path' not in compiled_file and 'default' in compiled_file:
                compiled_file = compiled_file['default']
            print(compiled_file)
            source_output = path.join(
                ".cache",
                compiled_file['path'],
            )
            with open(source_output, "r") as f:
                compile_output = json.load(f)
                self.add_layout(ctrt_name, compile_output["storageLayout"])

        self._cache: Dict[str, str] = {}

    def add_layout(self, ctrt_name: str, contract_layout: Dict[str, dict]):
        label_defs = [StorageDescriber(storage_describer) for storage_describer in contract_layout["storage"]]
        type_def_mapping: Dict[str, TypeDescriber] = {}
        types_layout = contract_layout["types"]
        for type_name, _ in types_layout.items():
            type_def_mapping[type_name] = TypeDescriber(type_name, types_layout)
        self.ctrt_name2stor_layout[ctrt_name] = (label_defs, type_def_mapping)

    def bind_value(self, value_str: str) -> str:
        if value_str in self.ctrt_name2addr:
            return self.ctrt_name2addr[value_str]
        elif value_str.startswith("uint256"):
            # uint256(0)
            v = value_str
            v = v[8:] if v.startswith("uint256(") else v
            v = v[:-1] if v.endswith(")") else v
            h = hex(int(v))
            h = h[2:] if h.startswith("0x") else h
            v = "0x" + h.zfill(64)
            return v
        else:
            return value_str

    def parse_key(self, key: str) -> Tuple[str, str, List[str]]:
        # A.userInfo[attacker].userId
        ctrt_name, var = key.split(".", 1)

        # userInfo[attacker]; userId
        vars = var.split(".")
        temps = []
        for v in vars:
            ks = v.split("[")
            for k in ks:
                k = k.strip("]")
                temps.append(k)
        var_name = temps[0]
        keys = [self.bind_value(v) for v in temps[1:]]
        return ctrt_name, var_name, keys

    def parse_func_call(self, key: str) -> Tuple[str, str, List[str]]:
        func_name2sig = {
            "balanceOf": "balanceOf(address)(uint256)",
            "investedBalanceInUSD": "investedBalanceInUSD()(uint256)",
            "totalSupply": "totalSupply()(uint256)"
        }
        # A.balanceOf(pair)
        ctrt_name, func_call = key.split(".", 1)

        # balanceOf, pair)
        func_name, func_args = func_call.split("(")

        # pair
        func_args = func_args.strip(")")
        func_sig = func_name2sig[func_name]
        func_args = [self.bind_value(v) for v in func_args.split(",")]
        return ctrt_name, func_sig, func_args

    def get(self, key: str):
        # A.balanceOf()
        func_call_regex = re.compile(r"\w*\.\w*\(.*")

        # vm.warp(block.timestamp)
        vmwarp_regex = re.compile(r"vm\.warp\((.*)\)")
        if key in self._cache:
            return self._cache[key]
        if key == "tokenPrice":
            self._cache[key] = 0
            return 0
        
        if key == "block.timestamp":
            value = self.timestamp
            for stmt in self.config.extra_statements:
                m = vmwarp_regex.match(stmt)
                if m:
                    expr: str = m.groups()[0]
                    expr = expr.replace("block.timestamp", value)
                    value = str(eval(expr))
        elif func_call_regex.match(key):
            ctrt_name, func_sig, func_args = self.parse_func_call(key)
            if ctrt_name not in self.ctrt_name2addr:
                raise ValueError(f"Unknown contract: {ctrt_name}")
            ctrt_addr = self.ctrt_name2addr[ctrt_name]
            cmd = [
                resolve_foundry_bin("cast"),
                "call",
                "--rpc-url",
                f"{DEFAULT_HOST}:{DEFAULT_PORT}",
                ctrt_addr,
                func_sig,
                *func_args,
            ]
            output = run(cmd, capture_output=True, text=True)
            value = output.stdout.strip().removesuffix("\n")
            # To deal with the case in Anvil 0.2.0
            if " " in value:
                value = value.split(" ")[0]
        else:
            ctrt_name, var_name, keys = self.parse_key(key)
            if ctrt_name not in self.ctrt_name2addr:
                raise ValueError(f"Unknown contract: {ctrt_name}")
            ctrt_addr = self.ctrt_name2addr[ctrt_name]
            layout = self.ctrt_name2stor_layout[ctrt_name]
            value = get_var(ctrt_addr, var_name, keys, layout)
        self._cache[key] = value
        return value


def verify_model_on_anvil(ctrt_name2addr: Dict[str, str], func_name: str, params: List[str]) -> bool:
    # cast call doesn't support startPrank / prank / etc. Thus, we use forge debug instead.
    owner_address = ctrt_name2addr["owner"]
    labels = []
    for k, v in ctrt_name2addr.items():
        labels.append("--labels")
        labels.append(f"{v}:{k}")
    param_types = ",".join(["uint256"] * len(params))
    func_name = f"{func_name}({param_types})"
    cmd = [
        resolve_foundry_bin("cast"),
        "call",
        "--trace",
        # cast 0.2.0 doesn't support
        # "--verbose",
        *labels,
        "--rpc-url",
        f"{DEFAULT_HOST}:{DEFAULT_PORT}",
        "--private-key",
        DEFAULT_PK,
        "--gas-limit",
        str(10**8),
        owner_address,
        func_name,
        *params,
    ]
    try:
        out = run(cmd, text=True, capture_output=True, check=True)
    except Exception as err:
        print(err)
        return False
    # This string is a special string used to indicate a successful transaction
    output = out.stdout.splitlines()[-5]
    feasible = output.endswith("0x4e487b710000000000000000000000000000000000000000000000000000000000000001")
    print(out.stdout)
    if feasible:
        print("Don't care `Transaction failed.` here. It doesn't mean the result is not feasible.")
        print("0x4e487b710000000000000000000000000000000000000000000000000000000000000001 is the special string used to indicate a successful transaction.")
    return feasible

def parse_balances(output: str):
    start = final = 0
    for m in re.finditer(r'(StartBalance|FinalBalance)\s*:\s*(\d+)', output):
        key, val = m.group(1), int(m.group(2))
        if key == 'StartBalance':
            start = val
        else:
            final = val
    return start, final


def _write_if_changed(file_path: str, content: str):
    current = None
    if path.exists(file_path):
        with open(file_path, "r") as f:
            current = f.read()
    if current == content:
        return
    with open(file_path, "w") as f:
        f.write(content)

def verify_model_on_forge_debug(bmk_dir: str, bmk_name: str, func_name: str, params: List[str]) -> bool:
    cache_path, _ = prepare_subfolder(bmk_dir)
    verify_path = path.join(bmk_dir, "_eurus_verify.t.sol")
    verify_contract_name = f"{bmk_name}EurusVerify"
    args = ",".join(params)
    verify_content = "\n".join(
        [
            "// SPDX-License-Identifier: MIT",
            "pragma solidity ^0.8.0;",
            f'import "./{bmk_name}_candidates.t.sol";',
            f"contract {verify_contract_name} is {bmk_name}Test " + "{",
            "function test_verify() public {",
            f"    {func_name}({args});",
            "}",
            "}",
            "",
        ]
    )
    _write_if_changed(verify_path, verify_content)

    cmd = [
        resolve_foundry_bin("forge"),
        "test",
        *forge_skip_args(),
        "-vv",
        "--contracts",
        bmk_dir,
        "--cache-path",
        cache_path,
        verify_path,
        "--match-contract",
        verify_contract_name,
        "--match-test",
        "test_verify",
        "--root",
        os.getcwd(),
    ]
    print(" ".join(cmd))
    try:
        out = run(cmd, text=True, capture_output=True)
    except Exception as err:
        print(err)
        return False

    combined_output = out.stdout + "\n" + out.stderr
    feasible = "Attack succeed!" in combined_output
    start, final = parse_balances(combined_output)
    profit = final - start
    return feasible, profit
