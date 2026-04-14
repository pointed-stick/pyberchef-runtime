#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

python3 - "$MANIFEST_PATH" "$VENDOR_DIR" <<'PY'
import pathlib
import shutil
import subprocess
import sys
import tarfile
import urllib.request
try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - build image compatibility
    import tomli as tomllib

manifest_path = pathlib.Path(sys.argv[1])
vendor_dir = pathlib.Path(sys.argv[2])

with manifest_path.open("rb") as handle:
    manifest = tomllib.load(handle)

for package in manifest.get("python_packages", []):
    name = package["name"]
    url = package["source_url"]
    stage_dir = package["stage_dir"]
    archive_name = url.rsplit("/", 1)[-1]
    archive_path = vendor_dir / archive_name
    target_dir = vendor_dir / stage_dir

    if target_dir.exists():
        print(f"{name} already fetched at {target_dir}")
        continue

    print(f"Fetching {name} from {url}")
    urllib.request.urlretrieve(url, archive_path)

    extract_root = vendor_dir / f"{stage_dir}-src"
    if extract_root.exists():
        shutil.rmtree(extract_root)
    extract_root.mkdir(parents=True, exist_ok=True)

    with tarfile.open(archive_path, "r:gz") as archive:
        archive.extractall(extract_root)

    children = [child for child in extract_root.iterdir()]
    if len(children) != 1 or not children[0].is_dir():
        raise SystemExit(f"Unexpected source layout for {name}")

    children[0].rename(target_dir)
    shutil.rmtree(extract_root)
    archive_path.unlink(missing_ok=True)
    print(f"Fetched {name} into {target_dir}")
PY
