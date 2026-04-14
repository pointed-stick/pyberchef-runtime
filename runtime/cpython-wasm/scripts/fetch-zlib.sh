#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"
ARCHIVE_URL="https://zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz"
ARCHIVE_PATH="$VENDOR_DIR/zlib-${ZLIB_VERSION}.tar.gz"
SRC_DIR="$VENDOR_DIR/zlib"

curl -fL "$ARCHIVE_URL" -o "$ARCHIVE_PATH"

rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$SRC_DIR" --strip-components=1
rm -f "$ARCHIVE_PATH"

echo "Fetched zlib ${ZLIB_VERSION} into $SRC_DIR"
