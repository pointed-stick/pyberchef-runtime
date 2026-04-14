#!/usr/bin/env bash
set -euo pipefail

"$(dirname "${BASH_SOURCE[0]}")/fetch-cpython.sh"
"$(dirname "${BASH_SOURCE[0]}")/fetch-libffi.sh"
"$(dirname "${BASH_SOURCE[0]}")/fetch-python-package-sources.sh"
"$(dirname "${BASH_SOURCE[0]}")/fetch-browser-support.sh"

echo "Fetched PyberChef runtime sources."
