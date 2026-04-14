#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CPYTHON_VERSION="$(manifest_value cpython_version)"
CPYTHON_DIR="$VENDOR_DIR/cpython"

if [[ -d "$CPYTHON_DIR/.git" ]]; then
  echo "CPython already fetched at $CPYTHON_DIR"
  exit 0
fi

rm -rf "$CPYTHON_DIR"
git clone --depth 1 --branch "v$CPYTHON_VERSION" https://github.com/python/cpython.git "$CPYTHON_DIR"
echo "Fetched CPython $CPYTHON_VERSION into $CPYTHON_DIR"

