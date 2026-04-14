#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cpython

HOST_BUILD_DIR="$CPYTHON_DIR/builddir/build"

cd "$CPYTHON_DIR"
./Tools/wasm/wasm_build.py build

if [[ ! -e "$HOST_BUILD_DIR/python" && -x "$HOST_BUILD_DIR/python.exe" ]]; then
  ln -s python.exe "$HOST_BUILD_DIR/python"
fi

echo "Built host Python in $HOST_BUILD_DIR"

