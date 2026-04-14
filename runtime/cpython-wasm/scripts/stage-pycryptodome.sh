#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

PACKAGE_DIR="$VENDOR_DIR/pycryptodome"
OUT_DIR="$ARTIFACTS_DIR/pycryptodome"

if [[ ! -d "$PACKAGE_DIR" ]]; then
  echo "pycryptodome source is missing. Run runtime/cpython-wasm/scripts/fetch-all.sh first." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

cat > "$OUT_DIR/STAGE-PLAN.txt" <<EOF
PyberChef pycryptodome staging plan

Source: $PACKAGE_DIR

Goal:
- build/stage pycryptodome for the CPython WASM runtime
- keep the package explicitly listed in manifest.toml
- support both browser and node runtime targets
EOF

echo "Wrote pycryptodome stage plan to $OUT_DIR/STAGE-PLAN.txt"
