import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import {
  chmodSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const runtimeRoot = path.resolve(__dirname, '..')
const artifactsRoot = path.join(runtimeRoot, 'artifacts')
const manifestTomlPath = path.join(runtimeRoot, 'manifest.toml')
const distRoot = path.join(runtimeRoot, 'dist')

function readTomlFile(filePath) {
  const stdout = execFileSync(
    'python3',
    [
      '-c',
      [
        'import json',
        'import pathlib',
        'import sys',
        'try:',
        '    import tomllib',
        'except ModuleNotFoundError:',
        '    import tomli as tomllib',
        'path = pathlib.Path(sys.argv[1])',
        'with path.open("rb") as handle:',
        '    data = tomllib.load(handle)',
        'print(json.dumps(data))',
      ].join('\n'),
      filePath,
    ],
    { encoding: 'utf8' },
  )

  return JSON.parse(stdout)
}

function parseArgs(argv) {
  const values = {
    version: String(process.env.PYBERCHEF_RUNTIME_VERSION ?? '0.1.0-local').trim(),
  }

  for (let index = 2; index < argv.length; index += 1) {
    const value = argv[index]

    if (value === '--version') {
      values.version = String(argv[index + 1] ?? '').trim()
      index += 1
      continue
    }

    throw new Error(`Unknown argument: ${value}`)
  }

  if (!values.version) {
    throw new Error('Runtime package version cannot be empty.')
  }

  if (!/^[0-9A-Za-z._-]+$/.test(values.version)) {
    throw new Error(
      'Runtime package version may only contain letters, numbers, dots, underscores, and dashes.',
    )
  }

  return values
}

function assertPathExists(targetPath, label) {
  if (!existsSync(targetPath)) {
    throw new Error(`Missing required ${label} at ${targetPath}. Build the runtime first.`)
  }
}

function copyTree(sourcePath, destinationPath) {
  cpSync(sourcePath, destinationPath, {
    recursive: true,
    dereference: false,
  })
}

function pruneTransientEntries(rootPath) {
  for (const entry of readdirSync(rootPath, { withFileTypes: true })) {
    const absolutePath = path.join(rootPath, entry.name)

    if (entry.isDirectory() && entry.name === '__pycache__') {
      rmSync(absolutePath, { recursive: true, force: true })
      continue
    }

    if (entry.isDirectory()) {
      pruneTransientEntries(absolutePath)
      continue
    }

    if (entry.isFile() && (entry.name.endsWith('.pyc') || entry.name.endsWith('.pyo'))) {
      unlinkSync(absolutePath)
    }
  }
}

function normalizePermissions(rootPath) {
  for (const entry of readdirSync(rootPath, { withFileTypes: true })) {
    const absolutePath = path.join(rootPath, entry.name)

    if (entry.isDirectory()) {
      chmodSync(absolutePath, 0o755)
      normalizePermissions(absolutePath)
      continue
    }

    if (entry.isFile()) {
      chmodSync(absolutePath, 0o644)
    }
  }
}

function sha256ForFile(filePath) {
  return createHash('sha256').update(readFileSync(filePath)).digest('hex')
}

function collectFiles(rootPath, currentPath = rootPath) {
  const files = []

  for (const entry of readdirSync(currentPath, { withFileTypes: true })) {
    const absolutePath = path.join(currentPath, entry.name)

    if (entry.isDirectory()) {
      files.push(...collectFiles(rootPath, absolutePath))
      continue
    }

    if (!entry.isFile()) {
      continue
    }

    const relativePath = path.relative(rootPath, absolutePath).replaceAll(path.sep, '/')
    const stats = statSync(absolutePath)
    files.push({
      path: relativePath,
      size: stats.size,
      sha256: sha256ForFile(absolutePath),
    })
  }

  files.sort((left, right) => left.path.localeCompare(right.path))
  return files
}

const { version } = parseArgs(process.argv)
const archiveStem = `pyberchef-runtime-v${version}`
const stagedRoot = path.join(distRoot, `${archiveStem}.staging`)
const archivePath = path.join(distRoot, `${archiveStem}.tar.gz`)
const standaloneManifestPath = path.join(distRoot, `${archiveStem}.manifest.json`)
const standaloneChecksumsPath = path.join(distRoot, `${archiveStem}.SHA256SUMS`)

const manifest = readTomlFile(manifestTomlPath)
const pythonPackages = Array.isArray(manifest.python_packages) ? manifest.python_packages : []

const browserRoot = path.join(artifactsRoot, 'browser')
const nodeRoot = path.join(artifactsRoot, 'node')

assertPathExists(browserRoot, 'browser runtime directory')
assertPathExists(path.join(browserRoot, 'python.js'), 'browser runtime script')
assertPathExists(path.join(browserRoot, 'python.wasm'), 'browser runtime wasm')
assertPathExists(path.join(browserRoot, 'python.data'), 'browser runtime data file')
assertPathExists(nodeRoot, 'node runtime directory')
assertPathExists(path.join(nodeRoot, 'python.js'), 'node runtime script')
assertPathExists(path.join(nodeRoot, 'python.wasm'), 'node runtime wasm')
assertPathExists(path.join(nodeRoot, 'Lib'), 'node stdlib directory')

rmSync(stagedRoot, { recursive: true, force: true })
mkdirSync(path.join(stagedRoot, 'packages'), { recursive: true })

copyTree(browserRoot, path.join(stagedRoot, 'browser'))
copyTree(nodeRoot, path.join(stagedRoot, 'node'))

const normalizedPackages = pythonPackages.map((pkg, index) => {
  const name = pkg?.name
  const stageDir = pkg?.stage_dir

  if (typeof name !== 'string' || name.length === 0) {
    throw new Error(`runtime/cpython-wasm/manifest.toml package #${index} is missing name.`)
  }

  if (typeof stageDir !== 'string' || stageDir.length === 0) {
    throw new Error(`runtime/cpython-wasm/manifest.toml package #${index} is missing stage_dir.`)
  }

  const sourcePath = path.join(artifactsRoot, stageDir)
  const destinationPath = path.join(stagedRoot, 'packages', stageDir)
  assertPathExists(sourcePath, `${name} staged package directory`)
  copyTree(sourcePath, destinationPath)

  return {
    name,
    stage_dir: stageDir,
    path: `packages/${stageDir}`,
  }
})

pruneTransientEntries(stagedRoot)
normalizePermissions(stagedRoot)

const payloadFiles = collectFiles(stagedRoot)
const manifestJson = {
  version,
  archive_name: path.basename(archivePath),
  runtime_api_version: manifest.runtime_api_version ?? 1,
  cpython_version: manifest.cpython_version ?? null,
  generated_at: new Date().toISOString(),
  layout: {
    browser: 'browser',
    node: 'node',
    packages: 'packages',
  },
  python_packages: normalizedPackages,
  files: payloadFiles,
}

const manifestText = `${JSON.stringify(manifestJson, null, 2)}\n`
writeFileSync(path.join(stagedRoot, 'manifest.json'), manifestText)
writeFileSync(standaloneManifestPath, manifestText)

const checksumFiles = collectFiles(stagedRoot)
const checksumText = `${checksumFiles
  .map((entry) => `${entry.sha256}  ${entry.path}`)
  .join('\n')}\n`

writeFileSync(path.join(stagedRoot, 'SHA256SUMS'), checksumText)
writeFileSync(standaloneChecksumsPath, checksumText)

mkdirSync(distRoot, { recursive: true })
execFileSync('tar', ['-czf', archivePath, '-C', stagedRoot, '.'])
rmSync(stagedRoot, { recursive: true, force: true })

console.log(`Packaged runtime ${version}`)
console.log(`Archive: ${archivePath}`)
console.log(`Manifest: ${standaloneManifestPath}`)
console.log(`Checksums: ${standaloneChecksumsPath}`)
