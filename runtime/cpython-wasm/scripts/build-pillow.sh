#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

BROWSER_TARGET="$(manifest_value emscripten_target_browser)"
HOST_BUILD_DIR="$CPYTHON_DIR/builddir/build"
TARGET_BUILD_DIR="$CPYTHON_DIR/builddir/$BROWSER_TARGET"
SYSCONFIGDATA_PATH="$TARGET_BUILD_DIR/build/lib.emscripten-wasm32-3.12/_sysconfigdata__emscripten_wasm32-emscripten.py"
PACKAGE_DIR="$VENDOR_DIR/pillow"
WORK_DIR="$BUILD_DIR/pillow-src-work"
STAGE_DIR="$ARTIFACTS_DIR/pillow"
HOST_TOOLS_DIR="$BUILD_DIR/host-tools"
TARGET_PYTHONPATH="$HOST_TOOLS_DIR:$TARGET_BUILD_DIR/build/lib.emscripten-wasm32-3.12:$CPYTHON_DIR/Lib"
ZLIB_INSTALL_DIR="$BUILD_DIR/zlib-browser-install"
JPEG_INSTALL_DIR="$BUILD_DIR/jpeg-browser-install"

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
  echo "Pillow source is missing. Run runtime/cpython-wasm/scripts/fetch-all.sh first." >&2
  exit 1
fi

if [[ ! -f "$ZLIB_INSTALL_DIR/include/zlib.h" || ! -f "$ZLIB_INSTALL_DIR/lib/libz.a" ]]; then
  echo "Browser zlib install is missing. Run runtime/cpython-wasm/scripts/build-browser-zlib.sh first." >&2
  exit 1
fi

if [[ ! -f "$JPEG_INSTALL_DIR/include/jpeglib.h" || ! -f "$JPEG_INSTALL_DIR/lib/libjpeg.a" ]]; then
  echo "Browser jpeg install is missing. Run runtime/cpython-wasm/scripts/build-browser-jpeg.sh first." >&2
  exit 1
fi

rm -rf "$WORK_DIR" "$STAGE_DIR" "$BUILD_DIR/pillow"
mkdir -p "$WORK_DIR" "$STAGE_DIR"
cp -R "$PACKAGE_DIR"/. "$WORK_DIR"

PYBERCHEF_PILLOW_PYPROJECT_PATH="$WORK_DIR/pyproject.toml" python3 - <<'PY'
from pathlib import Path
import os

pyproject_path = Path(os.environ["PYBERCHEF_PILLOW_PYPROJECT_PATH"])
text = pyproject_path.read_text()
text = text.replace('license = "MIT-CMU"', 'license = { text = "MIT-CMU" }')
text = text.replace('license-files = [ "LICENSE" ]\n', "")
pyproject_path.write_text(text)
PY

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
export PYBERCHEF_PILLOW_SYSCONFIGDATA_PATH="$SYSCONFIGDATA_PATH"
export ZLIB_ROOT="$ZLIB_INSTALL_DIR"
export JPEG_ROOT="$JPEG_INSTALL_DIR"

PY_CORE_LDFLAGS="$(python3 - <<'PY'
import os
from pathlib import Path

namespace = {}
source = Path(os.environ["PYBERCHEF_PILLOW_SYSCONFIGDATA_PATH"]).read_text()
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
export CPPFLAGS="${CPPFLAGS:+$CPPFLAGS }-I$ZLIB_INSTALL_DIR/include -I$JPEG_INSTALL_DIR/include"
export LDFLAGS="${LDFLAGS:+$LDFLAGS }-L$ZLIB_INSTALL_DIR/lib -L$JPEG_INSTALL_DIR/lib"

cd "$WORK_DIR"
PYTHONPATH="$TARGET_PYTHONPATH" "$HOST_PYTHON" setup.py \
  build_ext \
  --disable-platform-guessing \
  --disable-tiff \
  --disable-freetype \
  --disable-raqm \
  --disable-lcms \
  --disable-webp \
  --disable-jpeg2000 \
  --disable-imagequant \
  --disable-xcb \
  --disable-avif \
  build \
  --build-base "$BUILD_DIR/pillow" \
  --build-lib "$STAGE_DIR"

echo "Pillow browser stage copied to $STAGE_DIR"
