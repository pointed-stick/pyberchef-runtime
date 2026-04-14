#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUNTIME_DIR="$ROOT_DIR/runtime/cpython-wasm"
VENDOR_DIR="$RUNTIME_DIR/vendor"
ARTIFACTS_DIR="$RUNTIME_DIR/artifacts"
BUILD_DIR="$RUNTIME_DIR/build"
PATCHES_DIR="$RUNTIME_DIR/patches"
MANIFEST_PATH="$RUNTIME_DIR/manifest.toml"
CPYTHON_DIR="$VENDOR_DIR/cpython"
EMSDK_ENV="${EMSDK_ENV:-/emsdk/emsdk_env.sh}"
EM_CONFIG_FILE="${EM_CONFIG_FILE:-/emsdk/.emscripten}"

mkdir -p "$VENDOR_DIR" "$ARTIFACTS_DIR" "$BUILD_DIR"

manifest_value() {
  local key="$1"
  python3 - "$MANIFEST_PATH" "$key" <<'PY'
import pathlib
import sys
try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - build image compatibility
    import tomli as tomllib

manifest_path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
with manifest_path.open("rb") as handle:
    data = tomllib.load(handle)
value = data[key]
print(value)
PY
}

require_cpython() {
  if [[ ! -x "$CPYTHON_DIR/Tools/wasm/wasm_build.py" ]]; then
    echo "CPython source is missing. Run runtime/cpython-wasm/scripts/fetch-all.sh first." >&2
    exit 1
  fi

  apply_runtime_source_patches
}

activate_emsdk() {
  if [[ -f "$EMSDK_ENV" ]]; then
    # shellcheck disable=SC1090
    source "$EMSDK_ENV" >/dev/null
    export EM_CONFIG="${EM_CONFIG:-$EM_CONFIG_FILE}"
    return
  fi

  echo "Emscripten SDK activation script not found at $EMSDK_ENV" >&2
  exit 1
}

apply_tree_patch() {
  local tree_path="$1"
  local patch_path="$2"

  if git -C "$tree_path" apply --check --whitespace=nowarn "$patch_path" >/dev/null 2>&1; then
    git -C "$tree_path" apply --whitespace=nowarn "$patch_path"
    return
  fi

  if git -C "$tree_path" apply --reverse --check --whitespace=nowarn "$patch_path" >/dev/null 2>&1; then
    return
  fi

  echo "Patch does not apply cleanly: $patch_path" >&2
  exit 1
}

apply_runtime_source_patches() {
  local cpython_patch="$PATCHES_DIR/cpython/0001-emscripten-signal-init.patch"

  if [[ -f "$cpython_patch" ]]; then
    apply_tree_patch "$CPYTHON_DIR" "$cpython_patch"
  fi
}

stage_pure_python_package() {
  local vendor_stage_dir="$1"
  local artifact_stage_dir="$2"
  shift 2

  if [[ $# -eq 0 ]]; then
    echo "stage_pure_python_package requires at least one import root path." >&2
    exit 1
  fi

  local package_dir="$VENDOR_DIR/$vendor_stage_dir"
  local out_dir="$ARTIFACTS_DIR/$artifact_stage_dir"

  if [[ ! -d "$package_dir" ]]; then
    echo "Package source is missing at $package_dir. Run runtime/cpython-wasm/scripts/fetch-all.sh first." >&2
    exit 1
  fi

  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  python3 - "$package_dir" "$out_dir" "$@" <<'PY'
from pathlib import Path
import shutil
import sys

source_root = Path(sys.argv[1])
output_root = Path(sys.argv[2])
relative_paths = sys.argv[3:]

if not relative_paths:
    raise SystemExit("Expected at least one import root path.")

for relative_path in relative_paths:
    source = source_root / relative_path
    target = output_root / relative_path

    if not source.exists():
        raise SystemExit(f"Missing import root in package source: {source}")

    if source.is_dir():
        shutil.copytree(
            source,
            target,
            dirs_exist_ok=True,
            ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "*.pyo", "*.dist-info"),
        )
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
PY

  echo "Pure Python package staged from $package_dir to $out_dir"
}
