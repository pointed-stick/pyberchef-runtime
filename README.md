# PyberChef Runtime

This local workspace owns the runtime build, staging, packaging, and release side of PyberChef.

For now, the app repo still owns `runtime/pyberchef_ctx.py`, but the CPython/WASM build and release assets live here under `runtime/cpython-wasm/`.

Runtime-specific docs live under `docs/`.

## Quick Start

Package the currently staged runtime into a release archive:

```bash
docker compose run --rm dev bash -lc 'node ./runtime/cpython-wasm/scripts/package-runtime.mjs --version 0.1.0'
```

That writes the archive, manifest, and checksums into:

- `runtime/cpython-wasm/dist/`

For `0.1.0`, the manual release assets are:

- `pyberchef-runtime-v0.1.0.tar.gz`
- `pyberchef-runtime-v0.1.0.manifest.json`
- `pyberchef-runtime-v0.1.0.SHA256SUMS`

The corresponding Git tag should be `v0.1.0`.

If you need to rebuild the runtime from source first:

```bash
docker compose run --rm cpython-wasm ./runtime/cpython-wasm/scripts/fetch-all.sh
docker compose run --rm cpython-wasm ./runtime/cpython-wasm/scripts/build-browser.sh
docker compose run --rm cpython-wasm ./runtime/cpython-wasm/scripts/build-browser-packages.sh
docker compose run --rm cpython-wasm ./runtime/cpython-wasm/scripts/build-node.sh
```

The `pyberchef` app repo can consume a packaged archive from this sibling folder
through its `runtime.lock.json`, or temporarily through
`PYBERCHEF_RUNTIME_ARCHIVE_PATH` / `PYBERCHEF_RUNTIME_ROOT` during local
cross-repo development.
