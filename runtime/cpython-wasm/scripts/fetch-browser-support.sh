#!/usr/bin/env bash
set -euo pipefail

"$(dirname "${BASH_SOURCE[0]}")/fetch-zlib.sh"
"$(dirname "${BASH_SOURCE[0]}")/fetch-jpeg.sh"

echo "Fetched browser support library sources."
