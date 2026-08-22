#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { chmod, copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const output = resolve(process.argv[2] || join(root, 'dist', 'ClaudeGravity'));
const runtimeDir = join(output, 'runtime');
const scriptsDir = join(output, 'scripts');
const manifest = JSON.parse(await readFile(join(here, 'manifest.json'), 'utf8'));
const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm';

const run = (command, args, options = {}) => {
  execFileSync(command, args, {
    cwd: root,
    stdio: 'inherit',
    ...options
  });
};

await rm(output, { recursive: true, force: true });
await mkdir(runtimeDir, { recursive: true });
await mkdir(scriptsDir, { recursive: true });

const runtimePackage = {
  name: 'claudegravity-runtime',
  version: '0.0.0',
  private: true,
  description: 'Pinned runtime bundle for ClaudeGravity',
  dependencies: {
    [manifest.engines.antigravityProxy.package]: manifest.engines.antigravityProxy.installSpec,
    [manifest.engines.relayAi.package]: manifest.engines.relayAi.installSpec
  }
};
await writeFile(join(runtimeDir, 'package.json'), `${JSON.stringify(runtimePackage, null, 2)}\n`, 'utf8');

run(npmCommand, [
  'install',
  '--prefix', runtimeDir,
  '--omit=dev',
  '--omit=optional',
  '--no-audit',
  '--no-fund',
  '--package-lock=true'
]);

const proxyRoot = join(runtimeDir, 'node_modules', manifest.engines.antigravityProxy.package);
run(process.execPath, [join(root, 'launchers', 'scripts', 'patch-antigravity-proxy.mjs'), proxyRoot]);

const helpers = await readFile(join(proxyRoot, 'src', 'utils', 'helpers.js'), 'utf8');
if (!helpers.includes('ClaudeGravity selective Smart DNS v1')) {
  throw new Error('Bundled proxy is missing the ClaudeGravity selective Smart DNS patch.');
}
const webUi = await readFile(join(proxyRoot, 'public', 'index.html'), 'utf8');
if (!webUi.includes('ClaudeGravity WebUI v1') || !webUi.includes('<title>ClaudeGravity</title>')) {
  throw new Error('Bundled proxy is missing the ClaudeGravity WebUI patch.');
}
const webUiLogs = await readFile(join(proxyRoot, 'public', 'js', 'components', 'logs-viewer.js'), 'utf8');
if (!webUiLogs.includes('CLAUDEGRAVITY_CONTROL_URL')) {
  throw new Error('Bundled WebUI is not connected to ClaudeGravity background logs.');
}

const copies = [
  ['distribution/runtime/ClaudeGravity.sh', 'ClaudeGravity.sh'],
  ['distribution/runtime/ClaudeGravity.ps1', 'ClaudeGravity.ps1'],
  ['distribution/runtime/ClaudeGravity.cmd', 'ClaudeGravity.cmd'],
  ['distribution/runtime/Check-Limits.sh', 'Check-Limits.sh'],
  ['distribution/runtime/Check-Limits.ps1', 'Check-Limits.ps1'],
  ['distribution/runtime/Check-Limits.cmd', 'Check-Limits.cmd'],
  ['launchers/scripts/configure-relay.mjs', 'scripts/configure-relay.mjs'],
  ['launchers/scripts/configure-claude-desktop.mjs', 'scripts/configure-claude-desktop.mjs'],
  ['launchers/scripts/supervisor.mjs', 'scripts/supervisor.mjs'],
  ['launchers/scripts/patch-antigravity-proxy.mjs', 'scripts/patch-antigravity-proxy.mjs'],
  ['distribution/manifest.json', 'manifest.json'],
  ['THIRD_PARTY_NOTICES.md', 'THIRD_PARTY_NOTICES.md']
];
for (const [source, destination] of copies) {
  await copyFile(join(root, source), join(output, destination));
}

if (process.platform !== 'win32') {
  for (const name of ['ClaudeGravity.sh', 'Check-Limits.sh']) {
    await chmod(join(output, name), 0o755);
  }
}

const packageLock = JSON.parse(await readFile(join(runtimeDir, 'package-lock.json'), 'utf8'));
const buildInfo = {
  schemaVersion: 4,
  builtAt: new Date().toISOString(),
  gateway: {
    publicBaseUrl: 'http://127.0.0.1:17645/anthropic',
    antigravityInternalBaseUrl: 'http://127.0.0.1:18080',
    webUiUrl: 'http://127.0.0.1:18080/',
    controlBaseUrl: 'http://127.0.0.1:17646'
  },
  launchMode: 'background-webui',
  engines: {
    antigravityProxy: {
      packageVersion: manifest.engines.antigravityProxy.packageVersion,
      sourceRef: manifest.engines.antigravityProxy.sourceRef
    },
    relayAi: {
      packageVersion: manifest.engines.relayAi.packageVersion
    }
  },
  lockfileVersion: packageLock.lockfileVersion,
  smartDns: manifest.network
};
await writeFile(join(output, 'BUILD_INFO.json'), `${JSON.stringify(buildInfo, null, 2)}\n`, 'utf8');

console.log(`ClaudeGravity runtime bundle created at ${output}`);
