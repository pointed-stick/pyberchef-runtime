#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

LIBFFI_DIR="$VENDOR_DIR/libffi"
LIBFFI_REF="${LIBFFI_REF:-v3.5.2}"
LIBFFI_REMOTE="${LIBFFI_REMOTE:-https://github.com/libffi/libffi.git}"

mkdir -p "$VENDOR_DIR"

if [[ ! -d "$LIBFFI_DIR/.git" ]]; then
  git clone --depth 1 --branch "$LIBFFI_REF" "$LIBFFI_REMOTE" "$LIBFFI_DIR"
else
  git -C "$LIBFFI_DIR" fetch --depth 1 origin "$LIBFFI_REF"
  git -C "$LIBFFI_DIR" checkout --force FETCH_HEAD
  git -C "$LIBFFI_DIR" clean -fd
fi

echo "Pinned libffi source is ready at $LIBFFI_DIR"
