#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
foundry_dir="${repo_root}/Foray/foundry-nightly-20b3da1f22e9f62f6e3406a5d582ad4aa509122c"
svm_releases_json="${repo_root}/Foray/.cache/svm/linux-amd64/list.json"
hardhat_console_json="${foundry_dir}/crates/evm/abi/src/HardhatConsole.json"
hardhat_console_url="https://raw.githubusercontent.com/foundry-rs/foundry/20b3da1f22e9f62f6e3406a5d582ad4aa509122c/crates/evm/abi/src/HardhatConsole.json"

if [[ ! -d "${foundry_dir}" ]]; then
  echo "foundry source directory not found: ${foundry_dir}" >&2
  exit 1
fi

python3 "${script_dir}/prepare_svm_releases.py" "${svm_releases_json}"

if [[ ! -f "${hardhat_console_json}" ]]; then
  curl -fsSL "${hardhat_console_url}" -o "${hardhat_console_json}"
fi

cd "${foundry_dir}"

rm -rf target/release/build/svm-rs-builds-*
rm -rf target/release/.fingerprint/svm-rs-builds-*
rm -f target/release/deps/libsvm_rs_builds*
SVM_RELEASES_LIST_JSON="${svm_releases_json}" cargo build --release --bin forge --bin anvil --bin cast

echo
echo "Built local foundry tools:"
echo "  ${foundry_dir}/target/release/forge"
echo "  ${foundry_dir}/target/release/anvil"
echo "  ${foundry_dir}/target/release/cast"
echo
echo "If direnv is enabled, run:"
echo "  direnv allow ${repo_root}"
echo "Then verify with:"
echo "  direnv exec ${repo_root} forge --version"
echo "  direnv exec ${repo_root} anvil --version"
