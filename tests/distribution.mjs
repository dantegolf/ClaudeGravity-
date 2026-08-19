#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const builtRoot = process.argv[2] ? resolve(process.argv[2]) : null;
const read = (path) => readFile(join(root, path), 'utf8');

const manifest = JSON.parse(await read('distribution/manifest.json'));
const exactVersion = /^\d+\.\d+\.\d+$/;
for (const engine of Object.values(manifest.engines)) {
  if (!exactVersion.test(engine.version)) throw new Error(`Engine version must be exact: ${engine.package}@${engine.version}`);
  if (engine.license !== 'MIT') throw new Error(`Unexpected engine license metadata for ${engine.package}`);
}
if (manifest.engines.antigravityProxy.version !== '2.7.7') throw new Error('Unexpected proxy pin');
if (manifest.engines.relayAi.version !== '0.9.5') throw new Error('Unexpected Relay pin');

for (const path of ['install-windows.ps1', 'install-macos.sh', 'install-linux.sh']) {
  const source = await read(path);
  for (const forbidden of ['olegsuper338-lgtm', '@latest', 'npm install -g']) {
    if (source.includes(forbidden)) throw new Error(`${path} still contains legacy dependency: ${forbidden}`);
  }
  if (!source.includes('dantegolf/ClaudeGravity-/releases/latest/download')) {
    throw new Error(`${path} does not use the ClaudeGravity release source`);
  }
}

for (const path of ['distribution/runtime/ClaudeGravity.sh', 'distribution/runtime/ClaudeGravity.ps1']) {
  const source = await read(path);
  if (source.includes('npm install')) throw new Error(`${path} must never update runtime packages`);
  if (!source.includes('node_modules')) throw new Error(`${path} does not use the bundled runtime`);
  if (!source.includes('patch-antigravity-proxy.mjs')) throw new Error(`${path} does not verify the bundled proxy`);
}

const builder = await read('distribution/build-runtime.mjs');
if (!builder.includes("'--omit=optional'")) throw new Error('Runtime build must omit architecture-specific optional dependencies');
if (!builder.includes('ClaudeGravity selective Smart DNS v1')) throw new Error('Runtime build does not verify Smart DNS');

if (builtRoot) {
  const proxyPackage = JSON.parse(await readFile(join(builtRoot, 'runtime/node_modules/antigravity-claude-proxy/package.json'), 'utf8'));
  const relayPackage = JSON.parse(await readFile(join(builtRoot, 'runtime/node_modules/@jacobbd/relay-ai/package.json'), 'utf8'));
  if (proxyPackage.version !== manifest.engines.antigravityProxy.version) throw new Error('Built proxy version differs from manifest');
  if (relayPackage.version !== manifest.engines.relayAi.version) throw new Error('Built Relay version differs from manifest');
  const helpers = await readFile(join(builtRoot, 'runtime/node_modules/antigravity-claude-proxy/src/utils/helpers.js'), 'utf8');
  if (!helpers.includes('ClaudeGravity selective Smart DNS v1')) throw new Error('Built runtime is missing Smart DNS patch');
  for (const required of ['ClaudeGravity.sh', 'ClaudeGravity.ps1', 'manifest.json', 'THIRD_PARTY_NOTICES.md']) {
    await readFile(join(builtRoot, required));
  }
}

console.log('ClaudeGravity distribution checks passed.');
