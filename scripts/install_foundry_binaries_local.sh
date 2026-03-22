#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
foundryup_script="${repo_root}/Foray/foundry-nightly-20b3da1f22e9f62f6e3406a5d582ad4aa509122c/foundryup/foundryup"
local_foundry_dir="${repo_root}/Foray/.local/foundry"
version="${1:-nightly}"

if [[ ! -f "${foundryup_script}" ]]; then
  echo "foundryup script not found: ${foundryup_script}" >&2
  exit 1
fi

mkdir -p "${local_foundry_dir}/bin" "${local_foundry_dir}/share/man/man1"

tmp_foundryup="$(mktemp)"
trap 'rm -f "${tmp_foundryup}"' EXIT
tr -d '\r' < "${foundryup_script}" > "${tmp_foundryup}"
chmod +x "${tmp_foundryup}"

FOUNDRY_DIR="${local_foundry_dir}" bash "${tmp_foundryup}" --version "${version}"

echo
echo "Installed workspace-local foundry into:"
echo "  ${local_foundry_dir}"
echo
echo "If direnv is enabled, run:"
echo "  direnv allow ${repo_root}"
echo "Then verify with:"
echo "  direnv exec ${repo_root} forge --version"
echo "  direnv exec ${repo_root} anvil --version"
