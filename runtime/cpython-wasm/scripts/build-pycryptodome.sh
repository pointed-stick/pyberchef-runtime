#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

BROWSER_TARGET="$(manifest_value emscripten_target_browser)"
HOST_BUILD_DIR="$CPYTHON_DIR/builddir/build"
TARGET_BUILD_DIR="$CPYTHON_DIR/builddir/$BROWSER_TARGET"
SYSCONFIGDATA_PATH="$TARGET_BUILD_DIR/build/lib.emscripten-wasm32-3.12/_sysconfigdata__emscripten_wasm32-emscripten.py"
PACKAGE_DIR="$VENDOR_DIR/pycryptodome"
WORK_DIR="$BUILD_DIR/pycryptodome-src-work"
STAGE_DIR="$ARTIFACTS_DIR/pycryptodome"
HOST_TOOLS_DIR="$BUILD_DIR/host-tools"
TARGET_PYTHONPATH="$HOST_TOOLS_DIR:$TARGET_BUILD_DIR/build/lib.emscripten-wasm32-3.12:$CPYTHON_DIR/Lib"

require_cpython
activate_emsdk

if [[ ! -f "$HOST_BUILD_DIR/python.exe" && ! -f "$HOST_BUILD_DIR/python" ]]; then
  echo "Host build-python is missing. Run runtime/cpython-wasm/scripts/build-host-python.sh first." >&2
  exit 1
fi

if [[ ! -f "$SYSCONFIGDATA_PATH" ]]; then
  echo "Target browser build metadata is missing. Run runtime/cpython-wasm/scripts/build-browser.sh first." >&2
  exit 1
fi

if [[ ! -f "$PACKAGE_DIR/setup.py" ]]; then
  echo "PyCryptodome source is missing. Run runtime/cpython-wasm/scripts/fetch-all.sh first." >&2
  exit 1
fi

rm -rf "$WORK_DIR" "$STAGE_DIR"
mkdir -p "$WORK_DIR" "$STAGE_DIR"
cp -R "$PACKAGE_DIR"/. "$WORK_DIR"

if [[ ! -d "$HOST_TOOLS_DIR/setuptools" ]]; then
  mkdir -p "$HOST_TOOLS_DIR"
  python3 -m pip install \
    --disable-pip-version-check \
    --target "$HOST_TOOLS_DIR" \
    setuptools
fi

export _PYTHON_PROJECT_BASE="$TARGET_BUILD_DIR"
export _PYTHON_HOST_PLATFORM="emscripten-wasm32"
export _PYTHON_SYSCONFIGDATA_NAME="_sysconfigdata__emscripten_wasm32-emscripten"
export PYTHONNOUSERSITE=1
export PYCRYPTODOME_SYS_BITS=32
export PYCRYPTODOME_WORK_DIR="$WORK_DIR"
export PYCRYPTODOME_SYSCONFIGDATA_PATH="$SYSCONFIGDATA_PATH"

PY_CORE_LDFLAGS="$(python3 - <<'PY'
import os
from pathlib import Path

namespace = {}
source = Path(os.environ["PYCRYPTODOME_SYSCONFIGDATA_PATH"]).read_text()
exec(source, namespace)
print(namespace["build_time_vars"].get("PY_CORE_LDFLAGS", ""))
PY
)"

EMCC="${EMCC:-/emsdk/upstream/emscripten/emcc}"
EMAR="${EMAR:-/emsdk/upstream/emscripten/emar}"
SIDE_MODULE_LDSHARED="$EMCC -shared -sSIDE_MODULE=1 ${PY_CORE_LDFLAGS}"
HOST_PYTHON="$HOST_BUILD_DIR/python"
if [[ ! -f "$HOST_PYTHON" || ! -x "$HOST_PYTHON" ]]; then
  HOST_PYTHON="$HOST_BUILD_DIR/python.exe"
fi

export CC="$EMCC"
export AR="$EMAR"
export BLDSHARED="$SIDE_MODULE_LDSHARED"
export LDSHARED="$SIDE_MODULE_LDSHARED"
export LDCXXSHARED="$SIDE_MODULE_LDSHARED"

python3 - <<'PY'
import os
from pathlib import Path

compiler_opt = Path(os.environ["PYCRYPTODOME_WORK_DIR"]) / "compiler_opt.py"
text = compiler_opt.read_text()
needle = '    system_bits = 8 * struct.calcsize("P")\n'
replacement = (
    '    target_bits = os.environ.get("PYCRYPTODOME_SYS_BITS")\n'
    '    if target_bits is not None:\n'
    '        system_bits = int(target_bits)\n'
    '    else:\n'
    '        system_bits = 8 * struct.calcsize("P")\n'
)
if needle not in text:
    raise SystemExit("Expected compiler_opt.py layout changed")
compiler_opt.write_text(text.replace(needle, replacement))
PY

cd "$WORK_DIR"
PYTHONPATH="$TARGET_PYTHONPATH" "$HOST_PYTHON" setup.py build \
  --build-base "$BUILD_DIR/pycryptodome" \
  --build-lib "$STAGE_DIR"

echo "PyCryptodome browser stage copied to $STAGE_DIR"
