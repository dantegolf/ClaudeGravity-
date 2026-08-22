#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import http from 'node:http';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const temp = mkdtempSync(join(tmpdir(), 'claudegravity-gateway-'));
const relayHome = join(temp, 'relay-home');
const desktopHome = join(temp, 'Claude-3p');
const fakeProxy = join(temp, 'fake-proxy.mjs');
const fakeRelay = join(temp, 'fake-relay.mjs');
const originalMetaPath = join(desktopHome, 'configLibrary', '_meta.json');
const originalMeta = `${JSON.stringify({ appliedId: 'before', entries: [{ id: 'before', name: 'Existing config' }] }, null, 2)}\n`;

function request(url) {
  return new Promise((resolveRequest, rejectRequest) => {
    const req = http.get(url, { timeout: 1000 }, (res) => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => resolveRequest({ status: res.statusCode, body }));
    });
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', rejectRequest);
  });
}

async function waitFor(url, attempts = 40) {
  for (let i = 0; i < attempts; i += 1) {
    try {
      const response = await request(url);
      if (response.status === 200) return response;
    } catch { /* retry */ }
    await new Promise((resolveWait) => setTimeout(resolveWait, 250));
  }
  throw new Error(`Timed out waiting for ${url}`);
}

async function waitClosed(url, attempts = 30) {
  for (let i = 0; i < attempts; i += 1) {
    try {
      await request(url);
    } catch {
      return;
    }
    await new Promise((resolveWait) => setTimeout(resolveWait, 200));
  }
  throw new Error(`Endpoint still open after supervisor shutdown: ${url}`);
}

mkdirSync(dirname(originalMetaPath), { recursive: true });
writeFileSync(originalMetaPath, originalMeta, 'utf8');

writeFileSync(fakeProxy, `
import http from 'node:http';
if (process.env.HOST !== '127.0.0.1') throw new Error('proxy must bind loopback only');
if (process.env.PORT !== '18080') throw new Error('proxy must use internal port 18080');
const server = http.createServer((req, res) => {
  res.setHeader('content-type', 'application/json');
  if (req.url === '/health') return res.end(JSON.stringify({ ok: true, engine: 'antigravity' }));
  if (req.url === '/account-limits') return res.end(JSON.stringify({ accounts: 1 }));
  res.statusCode = 404; res.end(JSON.stringify({ error: 'not found' }));
});
server.listen(Number(process.env.PORT), process.env.HOST);
const stop = () => server.close(() => process.exit(0));
process.on('SIGTERM', stop); process.on('SIGINT', stop);
`, 'utf8');

writeFileSync(fakeRelay, `
import http from 'node:http';
const args = process.argv.slice(2);
const expected = ['server', '--quick', '--listen', 'local', '--providers', 'custom-antigravity', '--no-free-only', '--mask-gateway-ids'];
for (const token of expected) if (!args.includes(token)) throw new Error('missing relay arg: ' + token);
const port = Number(process.env.CLAUDEGRAVITY_GATEWAY_PORT || 17645);
const server = http.createServer((req, res) => {
  res.setHeader('content-type', 'application/json');
  if (req.url === '/health') return res.end(JSON.stringify({ ok: true, gateway: 'relay' }));
  if (req.url === '/anthropic/v1/models') return res.end(JSON.stringify({ data: [{ id: 'masked-model' }] }));
  res.statusCode = 404; res.end(JSON.stringify({ error: 'not found' }));
});
server.listen(port, '127.0.0.1');
const stop = () => server.close(() => process.exit(0));
process.on('SIGTERM', stop); process.on('SIGINT', stop);
`, 'utf8');

const configuredRelayHome = join(temp, 'relay-config-test');
const configure = spawn(process.execPath, [
  join(root, 'launchers', 'scripts', 'configure-relay.mjs'),
  configuredRelayHome,
  'http://127.0.0.1:18080',
], { stdio: 'inherit' });
const configureCode = await new Promise((resolveExit) => configure.once('exit', resolveExit));
if (configureCode !== 0) throw new Error('configure-relay integration setup failed');
const registry = JSON.parse(readFileSync(join(configuredRelayHome, 'providers.json'), 'utf8'));
const provider = registry.providers.find((entry) => entry.id === 'custom-antigravity');
if (provider?.api?.url !== 'http://127.0.0.1:18080') throw new Error('Relay provider did not move to the internal engine port');
if (!provider.modelsCache.models.every((model) => model.apiUrl === 'http://127.0.0.1:18080')) throw new Error('Relay models still expose the legacy proxy port');

let output = '';
const supervisor = spawn(process.execPath, [join(root, 'launchers', 'scripts', 'supervisor.mjs')], {
  cwd: root,
  env: {
    ...process.env,
    RELAY_AI_HOME: relayHome,
    CLAUDEGRAVITY_CLAUDE_DESKTOP_HOME: desktopHome,
    CLAUDEGRAVITY_PROXY_SERVER: fakeProxy,
    CLAUDEGRAVITY_RELAY_CLI: fakeRelay,
    CLAUDEGRAVITY_SKIP_PATCH: '1',
    CLAUDEGRAVITY_SKIP_PROVIDER_CHECK: '1',
    CLAUDEGRAVITY_SKIP_ACCOUNT: '1',
    CLAUDEGRAVITY_SKIP_DESKTOP_LAUNCH: '1',
  },
  stdio: ['ignore', 'pipe', 'pipe'],
});
supervisor.stdout.on('data', (chunk) => { output += chunk.toString(); });
supervisor.stderr.on('data', (chunk) => { output += chunk.toString(); });

try {
  await waitFor('http://127.0.0.1:18080/health');
  const gateway = await waitFor('http://127.0.0.1:17645/health');
  if (!gateway.body.includes('relay')) throw new Error('Public health endpoint is not the Relay gateway');
  const models = await request('http://127.0.0.1:17645/anthropic/v1/models');
  if (models.status !== 200 || !models.body.includes('masked-model')) throw new Error('Anthropic model discovery is not exposed on the unified gateway');

  const activeMeta = JSON.parse(readFileSync(originalMetaPath, 'utf8'));
  if (activeMeta.appliedId === 'before') throw new Error('Claude Desktop gateway config was not activated');
  const activeConfig = JSON.parse(readFileSync(join(desktopHome, 'configLibrary', `${activeMeta.appliedId}.json`), 'utf8'));
  if (activeConfig.inferenceGatewayBaseUrl !== 'http://127.0.0.1:17645/anthropic') {
    throw new Error('Claude Desktop is not pointed at the unified public gateway');
  }

  if (!output.includes('Local endpoint: http://127.0.0.1:17645/anthropic')) {
    throw new Error(`Supervisor did not advertise the unified endpoint. Output:\n${output}`);
  }

  supervisor.kill('SIGTERM');
  const exitCode = await new Promise((resolveExit) => supervisor.once('exit', resolveExit));
  if (exitCode !== 0) throw new Error(`Supervisor exited with ${exitCode}. Output:\n${output}`);

  await waitClosed('http://127.0.0.1:17645/health');
  await waitClosed('http://127.0.0.1:18080/health');
  if (readFileSync(originalMetaPath, 'utf8') !== originalMeta) throw new Error('Claude Desktop config was not restored after shutdown');

  console.log('Unified gateway integration checks passed.');
} finally {
  if (supervisor.exitCode === null) supervisor.kill('SIGKILL');
  rmSync(temp, { recursive: true, force: true });
}
