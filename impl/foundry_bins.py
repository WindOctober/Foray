import os
import shutil
from os import path


def resolve_foundry_bin(name: str) -> str:
    env_dir = os.environ.get("FORAY_FOUNDRY_BIN_DIR")
    if env_dir:
        candidate = path.join(env_dir, name)
        if path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate

    repo_root = path.dirname(path.dirname(__file__))
    local_candidate = path.join(repo_root, ".local", "foundry", "bin", name)
    if path.isfile(local_candidate) and os.access(local_candidate, os.X_OK):
        return local_candidate

    system_candidate = shutil.which(name)
    if system_candidate:
        return system_candidate

    raise FileNotFoundError(
        f"Unable to locate `{name}`. Set FORAY_FOUNDRY_BIN_DIR or install workspace-local Foundry under Foray/.local/foundry/bin."
    )


def forge_skip_args() -> list[str]:
    return ["--skip", "benchmarks/**/_eurus_verify.t.sol"]
