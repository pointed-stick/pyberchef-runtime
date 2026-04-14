#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

"$(dirname "${BASH_SOURCE[0]}")/build-browser-zlib.sh"
"$(dirname "${BASH_SOURCE[0]}")/build-browser-jpeg.sh"
"$(dirname "${BASH_SOURCE[0]}")/build-pycryptodome.sh"
"$(dirname "${BASH_SOURCE[0]}")/build-pillow.sh"

echo "Built PyberChef browser package stages into $ARTIFACTS_DIR"
