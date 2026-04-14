#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

LIBFFI_DIR="$VENDOR_DIR/libffi"
LIBFFI_BUILD_DIR="$BUILD_DIR/libffi"
INSTALL_DIR="$BUILD_DIR/libffi-install"

if [[ ! -d "$LIBFFI_DIR/.git" ]]; then
  echo "libffi source is missing. Run runtime/cpython-wasm/scripts/fetch-libffi.sh first." >&2
  exit 1
fi

activate_emsdk

export CFLAGS="${CFLAGS:+$CFLAGS }-fPIC"
export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }-fPIC"

if [[ ! -x "$LIBFFI_DIR/configure" ]]; then
  cd "$LIBFFI_DIR"
  ./autogen.sh
fi

rm -rf "$LIBFFI_BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$LIBFFI_BUILD_DIR" "$INSTALL_DIR"

cd "$LIBFFI_BUILD_DIR"
emconfigure "$LIBFFI_DIR/configure" \
  --host=wasm32-unknown-emscripten \
  --build="$(bash "$LIBFFI_DIR/config.guess")" \
  --disable-shared \
  --enable-static \
  --with-pic \
  --disable-docs \
  --prefix="$INSTALL_DIR"

emmake make -j"$(nproc)"
emmake make install

echo "libffi wasm install is ready at $INSTALL_DIR"
