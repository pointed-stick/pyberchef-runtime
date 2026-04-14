# Adding Python Libraries

This guide explains how to add a new third-party Python library to the
PyberChef CPython/WASM runtime.

Use this repo for runtime dependency work. The app repo only consumes packaged
runtime releases.

## Short Version

1. Keep the runtime dependency list intentionally small.
2. Add the package to `runtime/cpython-wasm/manifest.toml`.
3. Fetch its source.
4. Stage it into the runtime package layout.
5. Verify both browser and Node still work.
6. Repackage the runtime and rerun smoke checks.

## Before Adding Anything

Pause here first:

- Do we really need this package?
- Is it pure Python or does it build native extensions?
- Does it depend on C libraries like `libffi`, `zlib`, or `jpeg`?
- Does it work in both browser and Node, or only one target?

The runtime is part of the shipped product surface, so size, build complexity,
and maintenance cost matter.

## Where Dependencies Live

Pinned runtime packages live in:

- `runtime/cpython-wasm/manifest.toml`

Each package entry currently looks like:

```toml
[[python_packages]]
name = "Pillow"
source_url = "https://files.pythonhosted.org/packages/source/p/pillow/pillow-11.3.0.tar.gz"
stage_dir = "pillow"
```

Field meanings:

- `name`: display name for the package
- `source_url`: pinned source archive fetched into `runtime/cpython-wasm/vendor/`
- `stage_dir`: directory name staged into `runtime/cpython-wasm/artifacts/` and packaged under `packages/`

## Basic Flow

### 1. Add the Package to the Manifest

Add a new `[[python_packages]]` entry to:

- `runtime/cpython-wasm/manifest.toml`

### 2. Fetch Sources

From the `pyberchef-runtime` repo root:

```bash
npm run runtime:fetch
```

That fetches pinned source archives and expands them into:

- `runtime/cpython-wasm/vendor/<stage_dir>`

### 3. Decide How the Package Gets Staged

#### Pure Python Package

For pure Python packages, the usual job is:

- copy only the importable package tree into `runtime/cpython-wasm/artifacts/<stage_dir>`
- keep staged output minimal
- make sure it imports cleanly in both runtime targets

Useful starting points:

- `runtime/cpython-wasm/scripts/common.sh`
- `runtime/cpython-wasm/scripts/build-pure-python-package-template.sh`

The normal pattern is:

1. Copy the template to `build-<stage-dir>.sh`.
2. Set the vendor stage dir.
3. Set the artifact stage dir.
4. List the import roots to copy.
5. Wire the new script into `build-browser-packages.sh`.

#### Package With Native Extensions

If the package compiles extensions, you usually need:

- the browser target build metadata from `runtime:build-browser`
- the host Python from `runtime:build-host`
- explicit support libraries
- a staging step that copies only runtime outputs, not the whole build tree

Examples:

- `runtime/cpython-wasm/scripts/build-pillow.sh`
- `runtime/cpython-wasm/scripts/build-pycryptodome.sh`

## Support Libraries

Right now:

- `pycryptodome` needs `libffi`
- `Pillow` needs `zlib` and `jpeg`

Those build inputs are handled by:

- `runtime/cpython-wasm/scripts/build-libffi.sh`
- `runtime/cpython-wasm/scripts/build-browser-zlib.sh`
- `runtime/cpython-wasm/scripts/build-browser-jpeg.sh`

If a new package needs another C library, add that dependency explicitly and
script it deliberately.

## Suggested Verification Flow

From the `pyberchef-runtime` repo root:

```bash
npm run runtime:fetch
npm run runtime:fetch-browser-support
npm run runtime:build-host
npm run runtime:build-browser
npm run runtime:build-browser-packages
npm run runtime:build-node
npm run runtime:package -- --version 0.1.0-local
```

Then verify from the app repo:

```bash
cd ../pyberchef
PYBERCHEF_RUNTIME_ROOT=../pyberchef-runtime/runtime/cpython-wasm \
  docker compose run --rm dev bash -lc "npm --prefix ./frontend ci && npm run check"
```

If you want to verify the packaged archive form before publishing a release, use
the packaged tarball temporarily:

```bash
cd ../pyberchef
PYBERCHEF_RUNTIME_ARCHIVE_PATH=../pyberchef-runtime/runtime/cpython-wasm/dist/pyberchef-runtime-v0.1.0-local.tar.gz \
  npm run runtime:install -- --force
docker compose run --rm dev bash -lc "npm --prefix ./frontend ci && npm run check"
```

## Practical Notes

- Keep staged package output small. Do not copy whole source trees into staged artifacts.
- Be explicit about browser vs Node support when a package only works in one target.
- Prefer scripted, repeatable steps over manual edits in build directories.
- Repackage and rerun smoke checks any time the runtime surface changes.

## Quick Checklist

Before calling a new runtime dependency done, check:

- source pin added to `manifest.toml`
- fetch step works from clean state
- support libraries are explicit
- staged package dir is minimal
- browser runtime still builds
- Node runtime still works
- packaged runtime still installs in `pyberchef`
