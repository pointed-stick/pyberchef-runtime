#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

BROWSER_TARGET="$(manifest_value emscripten_target_browser)"
OUT_DIR="$ARTIFACTS_DIR/browser"
TARGET_BUILD_DIR="$CPYTHON_DIR/builddir/$BROWSER_TARGET"
HOST_BUILD_DIR="$CPYTHON_DIR/builddir/build"
LIBFFI_INSTALL_DIR="$BUILD_DIR/libffi-install"
LIBFFI_PKGCONFIG_DIR="$LIBFFI_INSTALL_DIR/lib/pkgconfig"
STDLIB_SUPPLEMENT_DIR="$OUT_DIR/stdlib-supplement"
CUSTOM_STDLIB_SUPPLEMENT_DIR="$RUNTIME_DIR/stdlib-supplement-src"

require_cpython
activate_emsdk

if [[ ! -e "$HOST_BUILD_DIR/python" && ! -x "$HOST_BUILD_DIR/python.exe" ]]; then
  "$(dirname "${BASH_SOURCE[0]}")/build-host-python.sh"
fi

if [[ -d "$VENDOR_DIR/libffi/.git" && ! -f "$LIBFFI_PKGCONFIG_DIR/libffi.pc" ]]; then
  "$(dirname "${BASH_SOURCE[0]}")/build-libffi.sh"
fi

if [[ -f "$LIBFFI_PKGCONFIG_DIR/libffi.pc" ]]; then
  export EM_PKG_CONFIG_PATH="$LIBFFI_PKGCONFIG_DIR${EM_PKG_CONFIG_PATH:+:$EM_PKG_CONFIG_PATH}"
  export PKG_CONFIG_PATH="$LIBFFI_PKGCONFIG_DIR${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  export CPPFLAGS="${CPPFLAGS:+$CPPFLAGS }-I$LIBFFI_INSTALL_DIR/include"
  export LDFLAGS="${LDFLAGS:+$LDFLAGS }-L$LIBFFI_INSTALL_DIR/lib"
fi

mkdir -p "$OUT_DIR"
rm -rf "$TARGET_BUILD_DIR"
rm -rf "$STDLIB_SUPPLEMENT_DIR"

cd "$CPYTHON_DIR"
python3 - <<'PY'
import runpy
import sys
from pathlib import Path

build_dir = Path("builddir/build")
globals_dict = runpy.run_path("Tools/wasm/wasm_build.py", run_name="wasm_build")

if (build_dir / "python.exe").exists():
    globals_dict["BUILD"].host.platform.pythonexe = "python.exe"

sys.argv = ["wasm_build.py", "emscripten-browser"]
globals_dict["main"]()
PY

for file in python.html python.js python.wasm python.data python.worker.js; do
  if [[ -f "$TARGET_BUILD_DIR/$file" ]]; then
    cp "$TARGET_BUILD_DIR/$file" "$OUT_DIR/$file"
  fi
done

export PYBERCHEF_CPYTHON_LIB_DIR="$CPYTHON_DIR/Lib"
export PYBERCHEF_STDLIB_SUPPLEMENT_DIR="$STDLIB_SUPPLEMENT_DIR"
export PYBERCHEF_CUSTOM_STDLIB_SUPPLEMENT_DIR="$CUSTOM_STDLIB_SUPPLEMENT_DIR"

python3 - <<'PY'
import os
import shutil
from pathlib import Path

lib_dir = Path(os.environ["PYBERCHEF_CPYTHON_LIB_DIR"])
supplement_dir = Path(os.environ["PYBERCHEF_STDLIB_SUPPLEMENT_DIR"])
custom_dir = Path(os.environ["PYBERCHEF_CUSTOM_STDLIB_SUPPLEMENT_DIR"])
supplement_dir.mkdir(parents=True, exist_ok=True)

for relative in ["email"]:
    source = lib_dir / relative
    target = supplement_dir / relative
    if source.is_dir():
        shutil.copytree(
            source,
            target,
            dirs_exist_ok=True,
            ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
        )
    elif source.is_file():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    else:
        raise SystemExit(f"Missing stdlib supplement source: {source}")

if custom_dir.exists():
    for source in custom_dir.rglob("*"):
        if source.is_dir():
            continue
        target = supplement_dir / source.relative_to(custom_dir)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
PY

echo "Built browser CPython WASM runtime into $OUT_DIR"
