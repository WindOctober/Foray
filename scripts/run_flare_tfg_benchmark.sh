#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
foray_python="${repo_root}/Foray/.venv/bin/python"
if [[ ! -x "${foray_python}" ]]; then
  foray_python="python3"
fi

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <benchmark-name-or-dir> [tfg-output-path] [--until tfg|prepare|eurus] [eurus options...]" >&2
  exit 1
fi

benchmark_arg="$1"
if [[ -d "${benchmark_arg}" ]]; then
  benchmark_dir="$(cd "${benchmark_arg}" && pwd)"
else
  benchmark_dir="${repo_root}/Foray/benchmarks/${benchmark_arg}"
fi

if [[ ! -d "${benchmark_dir}" ]]; then
  echo "benchmark directory not found: ${benchmark_dir}" >&2
  exit 1
fi

exec "${repo_root}/Flare/scripts/run_foray_benchmark.sh" "$@"
