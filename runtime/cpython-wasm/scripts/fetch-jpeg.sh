#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

JPEG_VERSION="${JPEG_VERSION:-9f}"
ARCHIVE_URL="https://www.ijg.org/files/jpegsrc.v${JPEG_VERSION}.tar.gz"
ARCHIVE_PATH="$VENDOR_DIR/jpegsrc.v${JPEG_VERSION}.tar.gz"
SRC_DIR="$VENDOR_DIR/jpeg"

curl -fL "$ARCHIVE_URL" -o "$ARCHIVE_PATH"

rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$SRC_DIR" --strip-components=1
rm -f "$ARCHIVE_PATH"

echo "Fetched jpeg v${JPEG_VERSION} into $SRC_DIR"
