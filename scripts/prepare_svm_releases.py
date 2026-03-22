#!/usr/bin/env python3
import json
import sys
import urllib.request
from pathlib import Path


URL = "https://binaries.soliditylang.org/linux-amd64/list.json"


def main() -> int:
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("Foray/.cache/svm/linux-amd64/list.json")
    out_path.parent.mkdir(parents=True, exist_ok=True)

    request = urllib.request.Request(
        URL,
        headers={
            "User-Agent": "contract-workflow/foray-local-foundry-setup"
        },
    )
    with urllib.request.urlopen(request) as response:
        data = json.load(response)

    builds = data.get("builds", [])
    by_version = {}
    for build in builds:
        version = build.get("version")
        current = by_version.get(version)
        if current is None:
            by_version[version] = build
            continue

        current_is_prerelease = bool(current.get("prerelease"))
        build_is_prerelease = bool(build.get("prerelease"))
        if current_is_prerelease and not build_is_prerelease:
            by_version[version] = build

    deduped = list(by_version.values())

    data["builds"] = deduped
    out_path.write_text(json.dumps(data, indent=2) + "\n")

    print(f"Wrote deduped solc release list to {out_path}")
    print(f"Original builds: {len(builds)}")
    print(f"Deduped builds: {len(deduped)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
