#!/usr/bin/env python3
from pathlib import Path
import shutil


REPO_ROOT = Path(__file__).resolve().parents[2]
BENCHMARKS_DIR = REPO_ROOT / "Foray" / "benchmarks"


def main():
    removed = []

    for benchmark_dir in sorted(p for p in BENCHMARKS_DIR.iterdir() if p.is_dir()):
        for file_path in benchmark_dir.glob("*_candidates.t.sol"):
            file_path.unlink(missing_ok=True)
            removed.append(file_path)
        for file_path in benchmark_dir.glob("*_query.t.sol"):
            file_path.unlink(missing_ok=True)
            removed.append(file_path)
        for file_path in benchmark_dir.glob("_eurus_verify.t.sol"):
            file_path.unlink(missing_ok=True)
            removed.append(file_path)

        for dir_path in sorted(benchmark_dir.glob("result*")):
            if dir_path.is_dir():
                shutil.rmtree(dir_path)
                removed.append(dir_path)
        cache_dir = benchmark_dir / ".cache"
        if cache_dir.is_dir():
            shutil.rmtree(cache_dir)
            removed.append(cache_dir)

    for path in removed:
        print(path.relative_to(REPO_ROOT))

    print(f"removed {len(removed)} generated benchmark paths")


if __name__ == "__main__":
    main()
