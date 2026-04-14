#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

PACKAGE_DIR="$VENDOR_DIR/pillow"
OUT_DIR="$ARTIFACTS_DIR/pillow"

if [[ ! -d "$PACKAGE_DIR" ]]; then
  echo "Pillow source is missing. Run runtime/cpython-wasm/scripts/fetch-all.sh first." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

cat > "$OUT_DIR/STAGE-PLAN.txt" <<EOF
PyberChef Pillow staging plan

Source: $PACKAGE_DIR

Goal:
- build/stage Pillow for the CPython WASM runtime
- keep the package explicitly listed in manifest.toml
- avoid hidden host-only installs
EOF

echo "Wrote Pillow stage plan to $OUT_DIR/STAGE-PLAN.txt"
