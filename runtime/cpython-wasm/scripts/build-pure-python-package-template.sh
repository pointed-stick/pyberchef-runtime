#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Copy this file to build-<stage-dir>.sh, then replace the placeholder values.
#
# Example:
#   cp runtime/cpython-wasm/scripts/build-pure-python-package-template.sh \
#     runtime/cpython-wasm/scripts/build-cbor2.sh
#   chmod +x runtime/cpython-wasm/scripts/build-cbor2.sh
#
# Then update:
# - VENDOR_STAGE_DIR
# - ARTIFACT_STAGE_DIR
# - PACKAGE_IMPORT_ROOTS
#
# Finally wire the new script into:
# - runtime/cpython-wasm/scripts/build-browser-packages.sh

VENDOR_STAGE_DIR="replace-me-stage-dir"
ARTIFACT_STAGE_DIR="replace-me-stage-dir"
PACKAGE_IMPORT_ROOTS=(
  "replace_me_package_dir"
  # "replace_me_module.py"
)

if [[ "$VENDOR_STAGE_DIR" == "replace-me-stage-dir" || "$ARTIFACT_STAGE_DIR" == "replace-me-stage-dir" ]]; then
  echo "Copy this template and replace VENDOR_STAGE_DIR / ARTIFACT_STAGE_DIR first." >&2
  exit 1
fi

if [[ "${PACKAGE_IMPORT_ROOTS[0]}" == "replace_me_package_dir" ]]; then
  echo "Copy this template and replace PACKAGE_IMPORT_ROOTS first." >&2
  exit 1
fi

stage_pure_python_package "$VENDOR_STAGE_DIR" "$ARTIFACT_STAGE_DIR" "${PACKAGE_IMPORT_ROOTS[@]}"
