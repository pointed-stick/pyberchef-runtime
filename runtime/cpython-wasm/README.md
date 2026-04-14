# CPython WASM

This is the PyberChef CPython WASM runtime scaffold.

It is intentionally explicit:

- the runtime is CPython
- browser and Node builds are both first-class
- shipped third-party packages are pinned and staged deliberately
- `Pillow` and `pycryptodome` are the initial bundled dependencies
- `libffi` is an explicit runtime build input so `_ctypes` works for `pycryptodome`

## Layout

- `manifest.toml`
  Pinned versions and staged dependency list.
- `Dockerfile`
  Dedicated build image for the runtime, based on the official
  `emscripten/emsdk` image with current Node tooling layered on top.
- `scripts/`
  Fetch, build, and stage commands.
- `vendor/`
  Downloaded source trees.
- `artifacts/`
  Built browser, node, and staged package outputs.
- `build/`
  Scratch build directories.

## Minimal commands

Fetch pinned sources:

```sh
npm run runtime:fetch
```

Fetch just the browser-side support libraries used by bundled packages:

```sh
npm run runtime:fetch-browser-support
```

Build browser runtime artifacts:

```sh
npm run runtime:build-browser
```

Build the wasm-targeted `libffi` install explicitly:

```sh
npm run runtime:build-libffi
```

Build the staged browser package directories for the PyberChef runtime dependencies:

```sh
npm run runtime:build-browser-packages
```

Build node runtime artifacts:

```sh
npm run runtime:build-node
```

That stages a self-contained Node runtime bundle into:

- `artifacts/node/`

Build the native host Python used for cross compilation:

```sh
npm run runtime:build-host
```

## Working Modes

Do not treat every local task as a clean release build. There are three different workflows:

### 1. App/frontend workflow

Most contributors should not build this runtime at all.

Use the pinned runtime from `pyberchef`, then work normally in the app repo.

### 2. Runtime iteration workflow

Use the cheapest rebuild that matches the change you made.

- Changed staged Python packages only:

```sh
npm run runtime:build-browser-packages
npm run runtime:package
```

- Changed browser runtime behavior:

```sh
npm run runtime:build-browser
npm run runtime:build-browser-packages
npm run runtime:package
```

- Changed Node runtime behavior:

```sh
npm run runtime:build-node
npm run runtime:package
```

- Changed shared/runtime-wide behavior and want a fresh local package:

```sh
npm run runtime:build-browser
npm run runtime:build-browser-packages
npm run runtime:build-node
npm run runtime:package
```

This workflow should reuse existing checked-out sources, host build outputs, and the persisted Emscripten cache. It is the normal maintainer loop.

### 3. Clean release workflow

Use this only when preparing a release or proving that no hidden local state is helping you.

```sh
rm -rf runtime/cpython-wasm/artifacts runtime/cpython-wasm/dist
npm run runtime:build-browser
npm run runtime:build-browser-packages
npm run runtime:build-node
docker compose run --rm dev bash -lc 'cd /workspace && node ./runtime/cpython-wasm/scripts/package-runtime.mjs --version 0.1.1-local'
```

After that, point `pyberchef/runtime.lock.json` at the resulting local tarball or upload the tarball and update the lockfile to the release asset URL.

## Why This Matters

- `build-browser` and `build-node` each rebuild a separate CPython target, so both rerun CPython's own configure/build logic.
- The Emscripten cache is now persisted, so the expensive SDK/bootstrap work should not repeat every time.
- The clean release flow is intentionally expensive; the day-to-day maintainer loop should avoid it unless we are proving a release.

## PyberChef Rules

- no alternate Python runtime path
- no hidden host-only dependency installs
- dependencies are declared in `manifest.toml`
- browser and Node are treated as sibling runtime targets
- browser support libraries such as zlib/jpeg are explicit build inputs, not hidden transitive magic

## Adding libraries

For the canonical runtime library-authoring guide, read:

- [../../docs/adding-python-libraries.md](../../docs/adding-python-libraries.md)

For simple pure-Python packages, start from:

- [scripts/build-pure-python-package-template.sh](scripts/build-pure-python-package-template.sh)
