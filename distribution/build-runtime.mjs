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
    [manifest.engines.relayAi.package]: manifest.engines.relayAi.installSpec,
    [manifest.webUi.alpine.package]: manifest.webUi.alpine.packageVersion,
    [manifest.webUi.chart.package]: manifest.webUi.chart.packageVersion
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

// The upstream WebUI references Alpine.js and Chart.js from jsDelivr. A localhost
// dashboard must not depend on a third-party CDN: if that CDN is blocked or slow,
// Alpine never initializes and x-cloak can leave the interface blank/partial.
// Vendor exact browser builds into the bundled proxy and rewrite index.html to
// load them from the same loopback origin.
const publicDir = join(proxyRoot, 'public');
const vendorDir = join(publicDir, 'vendor');
await mkdir(vendorDir, { recursive: true });
const alpineVendorPath = join(vendorDir, 'alpine.min.js');
const chartVendorPath = join(vendorDir, 'chart.umd.js');
await copyFile(join(runtimeDir, 'node_modules', manifest.webUi.alpine.package, 'dist', 'cdn.min.js'), alpineVendorPath);
await copyFile(join(runtimeDir, 'node_modules', manifest.webUi.chart.package, 'dist', 'chart.umd.js'), chartVendorPath);

const webUiPath = join(publicDir, 'index.html');
let webUi = await readFile(webUiPath, 'utf8');
const webUiAssetReplacements = [
  ['https://cdn.jsdelivr.net/npm/chart.js', 'vendor/chart.umd.js'],
  ['https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js', 'vendor/alpine.min.js']
];
for (const [remoteUrl, localUrl] of webUiAssetReplacements) {
  if (webUi.includes(remoteUrl)) {
    webUi = webUi.replace(remoteUrl, localUrl);
  } else if (!webUi.includes(localUrl)) {
    throw new Error(`Bundled WebUI is missing expected frontend asset reference: ${remoteUrl}`);
  }
}
await writeFile(webUiPath, webUi, 'utf8');

// Older/stale localStorage values can reference a language that is not bundled by
// the pinned upstream UI. Its original lookup throws in that case and can abort
// Alpine rendering. Fall back to English instead of breaking the whole dashboard.
const storePath = join(publicDir, 'js', 'store.js');
let webUiStore = await readFile(storePath, 'utf8');
const unsafeTranslationLookup = "            let str = this.translations[this.lang][key] || key;";
const safeTranslationLookup = "            const dictionary = this.translations[this.lang] || this.translations.en || {};\n            let str = dictionary[key] || key;";
if (webUiStore.includes(unsafeTranslationLookup)) {
  webUiStore = webUiStore.replace(unsafeTranslationLookup, safeTranslationLookup);
  await writeFile(storePath, webUiStore, 'utf8');
} else if (!webUiStore.includes('this.translations[this.lang] || this.translations.en || {}')) {
  throw new Error('Bundled WebUI translation lookup no longer matches the expected upstream structure.');
}

const helpers = await readFile(join(proxyRoot, 'src', 'utils', 'helpers.js'), 'utf8');
if (!helpers.includes('ClaudeGravity selective Smart DNS v1')) {
  throw new Error('Bundled proxy is missing the ClaudeGravity selective Smart DNS patch.');
}
webUi = await readFile(webUiPath, 'utf8');
if (!webUi.includes('ClaudeGravity WebUI v1') || !webUi.includes('<title>ClaudeGravity</title>')) {
  throw new Error('Bundled proxy is missing the ClaudeGravity WebUI patch.');
}
if (!webUi.includes('vendor/alpine.min.js') || !webUi.includes('vendor/chart.umd.js')) {
  throw new Error('Bundled WebUI is not using local frontend assets.');
}
if (/cdn\.jsdelivr\.net\/(?:npm\/)?(?:alpinejs|chart\.js)/.test(webUi)) {
  throw new Error('Bundled WebUI still depends on a remote CDN for critical frontend assets.');
}
const alpineVendor = await readFile(alpineVendorPath);
const chartVendor = await readFile(chartVendorPath);
if (alpineVendor.length < 1000 || chartVendor.length < 1000) {
  throw new Error('Bundled WebUI vendor assets are unexpectedly empty.');
}
webUiStore = await readFile(storePath, 'utf8');
if (!webUiStore.includes('this.translations[this.lang] || this.translations.en || {}')) {
  throw new Error('Bundled WebUI is missing the safe translation fallback.');
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
  schemaVersion: 5,
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
  webUi: {
    assetMode: 'same-origin-vendored',
    alpineVersion: manifest.webUi.alpine.packageVersion,
    chartVersion: manifest.webUi.chart.packageVersion
  },
  lockfileVersion: packageLock.lockfileVersion,
  smartDns: manifest.network
};
await writeFile(join(output, 'BUILD_INFO.json'), `${JSON.stringify(buildInfo, null, 2)}\n`, 'utf8');

console.log(`ClaudeGravity runtime bundle created at ${output}`);
