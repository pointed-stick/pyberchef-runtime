#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

NODE_TARGET="$(manifest_value emscripten_target_node)"
OUT_DIR="$ARTIFACTS_DIR/node"
TARGET_BUILD_DIR="$CPYTHON_DIR/builddir/$NODE_TARGET"
HOST_BUILD_DIR="$CPYTHON_DIR/builddir/build"
LIBFFI_INSTALL_DIR="$BUILD_DIR/libffi-install"
LIBFFI_PKGCONFIG_DIR="$LIBFFI_INSTALL_DIR/lib/pkgconfig"

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

mkdir -p "$ARTIFACTS_DIR"
rm -rf "$OUT_DIR"
rm -rf "$TARGET_BUILD_DIR"

cd "$CPYTHON_DIR"
python3 - <<'PY'
import runpy
import sys
from pathlib import Path

build_dir = Path("builddir/build")
globals_dict = runpy.run_path("Tools/wasm/wasm_build.py", run_name="wasm_build")

if (build_dir / "python.exe").exists():
    globals_dict["BUILD"].host.platform.pythonexe = "python.exe"

sys.argv = ["wasm_build.py", "emscripten-node-dl"]
globals_dict["main"]()
PY

cp -R "$TARGET_BUILD_DIR" "$OUT_DIR"
cp -R "$CPYTHON_DIR/Lib" "$OUT_DIR/Lib"

echo "Built self-contained node CPython WASM runtime into $OUT_DIR"
