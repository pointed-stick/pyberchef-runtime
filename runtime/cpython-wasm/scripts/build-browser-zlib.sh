#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

SRC_DIR="$VENDOR_DIR/zlib"
WORK_DIR="$BUILD_DIR/zlib-browser"
INSTALL_DIR="$BUILD_DIR/zlib-browser-install"

if [[ ! -f "$SRC_DIR/configure" ]]; then
  echo "zlib source is missing. Run runtime/cpython-wasm/scripts/fetch-zlib.sh first." >&2
  exit 1
fi

activate_emsdk

rm -rf "$WORK_DIR" "$INSTALL_DIR"
cp -R "$SRC_DIR" "$WORK_DIR"
mkdir -p "$INSTALL_DIR"

export CC="${CC:-emcc}"
export AR="${AR:-emar}"
export RANLIB="${RANLIB:-emranlib}"
export CFLAGS="${CFLAGS:+$CFLAGS }-fPIC"

cd "$WORK_DIR"
CHOST=wasm32-unknown-emscripten emconfigure ./configure \
  --static \
  --prefix="$INSTALL_DIR"

emmake make -j"$(nproc)"
emmake make install

echo "Browser zlib install is ready at $INSTALL_DIR"
