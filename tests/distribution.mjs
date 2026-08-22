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
const exactSha = /^[0-9a-f]{40}$/;
for (const engine of Object.values(manifest.engines)) {
  if (!exactVersion.test(engine.packageVersion)) throw new Error(`Engine packageVersion must be exact: ${engine.package}@${engine.packageVersion}`);
  if (engine.license !== 'MIT') throw new Error(`Unexpected engine license metadata for ${engine.package}`);
}
if (!exactSha.test(manifest.engines.antigravityProxy.sourceRef)) throw new Error('Proxy sourceRef must be a full commit SHA');
if (!manifest.engines.antigravityProxy.installSpec.endsWith(`#${manifest.engines.antigravityProxy.sourceRef}`)) {
  throw new Error('Proxy installSpec must pin sourceRef exactly');
}
if (manifest.engines.relayAi.installSpec !== manifest.engines.relayAi.packageVersion) throw new Error('Relay installSpec must be an exact package version');

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
  if (!source.includes('supervisor.mjs')) throw new Error(`${path} must delegate orchestration to the bundled supervisor`);
  if (source.includes('claude-app')) throw new Error(`${path} must not start Relay claude-app because it creates another proxy`);
  if (source.includes('127.0.0.1:8080')) throw new Error(`${path} still references the legacy public proxy port`);
}

const supervisor = await read('launchers/scripts/supervisor.mjs');
for (const required of [
  'node_modules',
  'patch-antigravity-proxy.mjs',
  '127.0.0.1',
  '18080',
  '17645',
  "'server'",
  "'--quick'",
  "'custom-antigravity'",
  "'--mask-gateway-ids'",
  'applyClaudeDesktopConfig',
  'restoreClaudeDesktopConfig',
]) {
  if (!supervisor.includes(required)) throw new Error(`Unified supervisor missing safeguard: ${required}`);
}
if (supervisor.includes("'claude-app'")) throw new Error('Unified supervisor must not use Relay claude-app');

const relayConfig = await read('launchers/scripts/configure-relay.mjs');
if (!relayConfig.includes('http://127.0.0.1:18080')) throw new Error('Relay config must default to the internal Antigravity port');
const desktopConfig = await read('launchers/scripts/configure-claude-desktop.mjs');
if (!desktopConfig.includes('inferenceGatewayBaseUrl')) throw new Error('Claude Desktop gateway configuration is missing');

const builder = await read('distribution/build-runtime.mjs');
if (!builder.includes("'--omit=optional'")) throw new Error('Runtime build must omit architecture-specific optional dependencies');
if (!builder.includes('ClaudeGravity selective Smart DNS v1')) throw new Error('Runtime build does not verify Smart DNS');
for (const required of ['scripts/supervisor.mjs', 'scripts/configure-claude-desktop.mjs']) {
  if (!builder.includes(required)) throw new Error(`Runtime build does not bundle ${required}`);
}

if (builtRoot) {
  const proxyPackage = JSON.parse(await readFile(join(builtRoot, 'runtime/node_modules/antigravity-claude-proxy/package.json'), 'utf8'));
  const relayPackage = JSON.parse(await readFile(join(builtRoot, 'runtime/node_modules/@jacobbd/relay-ai/package.json'), 'utf8'));
  if (proxyPackage.version !== manifest.engines.antigravityProxy.packageVersion) throw new Error('Built proxy package version differs from manifest');
  if (relayPackage.version !== manifest.engines.relayAi.packageVersion) throw new Error('Built Relay version differs from manifest');
  const lock = JSON.parse(await readFile(join(builtRoot, 'runtime/package-lock.json'), 'utf8'));
  const proxyLock = lock.packages?.['node_modules/antigravity-claude-proxy'];
  if (!String(proxyLock?.resolved || '').includes(manifest.engines.antigravityProxy.sourceRef)) {
    throw new Error('Built lockfile does not resolve the pinned proxy commit');
  }
  const helpers = await readFile(join(builtRoot, 'runtime/node_modules/antigravity-claude-proxy/src/utils/helpers.js'), 'utf8');
  if (!helpers.includes('ClaudeGravity selective Smart DNS v1')) throw new Error('Built runtime is missing Smart DNS patch');
  for (const required of [
    'ClaudeGravity.sh',
    'ClaudeGravity.ps1',
    'manifest.json',
    'THIRD_PARTY_NOTICES.md',
    'scripts/supervisor.mjs',
    'scripts/configure-claude-desktop.mjs',
    'scripts/configure-relay.mjs',
  ]) {
    await readFile(join(builtRoot, required));
  }
  const buildInfo = JSON.parse(await readFile(join(builtRoot, 'BUILD_INFO.json'), 'utf8'));
  if (buildInfo.gateway?.publicBaseUrl !== 'http://127.0.0.1:17645/anthropic') throw new Error('Built runtime does not declare the unified public gateway');
  if (buildInfo.gateway?.antigravityInternalBaseUrl !== 'http://127.0.0.1:18080') throw new Error('Built runtime does not declare the internal engine endpoint');
}

console.log('ClaudeGravity distribution checks passed.');
