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
const stateDir = join(temp, 'state');
const fakeProxy = join(temp, 'fake-proxy.mjs');
const fakeRelay = join(temp, 'fake-relay.mjs');
const originalMetaPath = join(desktopHome, 'configLibrary', '_meta.json');
const originalMeta = `${JSON.stringify({ appliedId: 'before', entries: [{ id: 'before', name: 'Existing config' }] }, null, 2)}\n`;
const controlUrl = 'http://127.0.0.1:17646';

function request(url, { method = 'GET' } = {}) {
  return new Promise((resolveRequest, rejectRequest) => {
    const parsed = new URL(url);
    const req = http.request({
      hostname: parsed.hostname,
      port: parsed.port,
      path: `${parsed.pathname}${parsed.search}`,
      method,
      timeout: 1000,
    }, (res) => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => resolveRequest({ status: res.statusCode, body, headers: res.headers }));
    });
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', rejectRequest);
    req.end();
  });
}

async function waitFor(url, attempts = 60) {
  for (let i = 0; i < attempts; i += 1) {
    try {
      const response = await request(url);
      if (response.status === 200) return response;
    } catch { /* retry */ }
    await new Promise((resolveWait) => setTimeout(resolveWait, 200));
  }
  throw new Error(`Timed out waiting for ${url}`);
}

async function waitForReady(attempts = 80) {
  for (let i = 0; i < attempts; i += 1) {
    try {
      const response = await request(`${controlUrl}/health`);
      if (response.status === 200) {
        const status = JSON.parse(response.body);
        if (status.ready) return status;
      }
    } catch { /* retry */ }
    await new Promise((resolveWait) => setTimeout(resolveWait, 200));
  }
  throw new Error(`ClaudeGravity control API did not become ready. Output:\n${output}`);
}

async function waitClosed(url, attempts = 40) {
  for (let i = 0; i < attempts; i += 1) {
    try {
      await request(url);
    } catch {
      return;
    }
    await new Promise((resolveWait) => setTimeout(resolveWait, 150));
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
  res.setHeader('content-type', req.url === '/' ? 'text/html' : 'application/json');
  if (req.url === '/') return res.end('<html><title>ClaudeGravity</title></html>');
  if (req.url === '/health') return res.end(JSON.stringify({ ok: true, engine: 'antigravity' }));
  if (req.url === '/account-limits') return res.end(JSON.stringify({ accounts: 1 }));
  res.statusCode = 404; res.end(JSON.stringify({ error: 'not found' }));
});
server.listen(Number(process.env.PORT), process.env.HOST, () => console.log('proxy-online-log'));
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
server.listen(port, '127.0.0.1', () => console.error('relay-online-log'));
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

const supervisorEnv = {
  ...process.env,
  RELAY_AI_HOME: relayHome,
  CLAUDEGRAVITY_STATE_DIR: stateDir,
  CLAUDEGRAVITY_CLAUDE_DESKTOP_HOME: desktopHome,
  CLAUDEGRAVITY_PROXY_SERVER: fakeProxy,
  CLAUDEGRAVITY_RELAY_CLI: fakeRelay,
  CLAUDEGRAVITY_SKIP_PATCH: '1',
  CLAUDEGRAVITY_SKIP_PROVIDER_CHECK: '1',
  CLAUDEGRAVITY_SKIP_ACCOUNT: '1',
  CLAUDEGRAVITY_SKIP_DESKTOP_LAUNCH: '1',
  CLAUDEGRAVITY_SKIP_BROWSER: '1',
};

let output = '';
const supervisor = spawn(process.execPath, [join(root, 'launchers', 'scripts', 'supervisor.mjs')], {
  cwd: root,
  env: supervisorEnv,
  stdio: ['ignore', 'pipe', 'pipe'],
});
supervisor.stdout.on('data', (chunk) => { output += chunk.toString(); });
supervisor.stderr.on('data', (chunk) => { output += chunk.toString(); });

try {
  const controlStatus = await waitForReady();
  if (controlStatus.product !== 'ClaudeGravity') throw new Error('Control API product marker is missing');
  if (controlStatus.uiUrl !== 'http://127.0.0.1:18080/') throw new Error('Control API does not expose the local WebUI URL');
  if (controlStatus.publicEndpoint !== 'http://127.0.0.1:17645/anthropic') throw new Error('Control API public endpoint is incorrect');

  await waitFor('http://127.0.0.1:18080/');
  const gateway = await waitFor('http://127.0.0.1:17645/health');
  if (!gateway.body.includes('relay')) throw new Error('Public health endpoint is not the Relay gateway');
  const models = await request('http://127.0.0.1:17645/anthropic/v1/models');
  if (models.status !== 200 || !models.body.includes('masked-model')) throw new Error('Anthropic model discovery is not exposed on the unified gateway');

  const activeMeta = JSON.parse(readFileSync(originalMetaPath, 'utf8'));
  if (!activeMeta.appliedId || activeMeta.appliedId === 'before') throw new Error('Claude Desktop gateway config was not activated');
  const activeConfig = JSON.parse(readFileSync(join(desktopHome, 'configLibrary', `${activeMeta.appliedId}.json`), 'utf8'));
  if (activeConfig.inferenceGatewayBaseUrl !== 'http://127.0.0.1:17645/anthropic') {
    throw new Error('Claude Desktop is not pointed at the unified public gateway');
  }

  const logsResponse = await request(`${controlUrl}/logs`);
  const logs = JSON.parse(logsResponse.body).logs;
  if (!logs.some((entry) => entry.message.includes('proxy-online-log'))) throw new Error('Proxy stdout is not captured by WebUI logs');
  if (!logs.some((entry) => entry.message.includes('relay-online-log'))) throw new Error('Relay stderr is not captured by WebUI logs');
  if (output.includes('proxy-online-log') || output.includes('relay-online-log')) {
    throw new Error(`Engine output leaked to supervisor terminal:\n${output}`);
  }

  // Starting ClaudeGravity a second time must only hand off to the existing instance.
  let secondOutput = '';
  const duplicate = spawn(process.execPath, [join(root, 'launchers', 'scripts', 'supervisor.mjs')], {
    cwd: root,
    env: supervisorEnv,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  duplicate.stdout.on('data', (chunk) => { secondOutput += chunk.toString(); });
  duplicate.stderr.on('data', (chunk) => { secondOutput += chunk.toString(); });
  const duplicateCode = await new Promise((resolveExit) => duplicate.once('exit', resolveExit));
  if (duplicateCode !== 0) throw new Error(`Duplicate supervisor did not hand off cleanly: ${secondOutput}`);
  const stillReady = JSON.parse((await request(`${controlUrl}/health`)).body);
  if (!stillReady.ready) throw new Error('Duplicate launch disrupted the running gateway');

  const stopResponse = await request(`${controlUrl}/action/stop`, { method: 'POST' });
  if (stopResponse.status !== 202) throw new Error(`WebUI stop action returned ${stopResponse.status}`);
  const exitCode = await new Promise((resolveExit) => supervisor.once('exit', resolveExit));
  if (exitCode !== 0) throw new Error(`Supervisor exited with ${exitCode}. Output:\n${output}`);

  await waitClosed('http://127.0.0.1:17646/health');
  await waitClosed('http://127.0.0.1:17645/health');
  await waitClosed('http://127.0.0.1:18080/');
  if (readFileSync(originalMetaPath, 'utf8') !== originalMeta) throw new Error('Claude Desktop config was not restored after WebUI shutdown');

  const diskLog = readFileSync(join(stateDir, 'claudegravity.log'), 'utf8');
  if (!diskLog.includes('proxy-online-log') || !diskLog.includes('relay-online-log')) throw new Error('Combined background log file is incomplete');

  console.log('Silent local WebUI gateway integration checks passed.');
} finally {
  if (supervisor.exitCode === null) supervisor.kill('SIGKILL');
  rmSync(temp, { recursive: true, force: true });
}
