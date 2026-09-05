import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import http from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const home = await mkdtemp(join(tmpdir(), 'claudegravity-models-'));
const script = fileURLToPath(new URL('../launchers/scripts/configure-relay.mjs', import.meta.url));
const variants = ['high', 'low', 'medium', 'tiered'].map(variant => ({
  id: `gemini-3.8-flash-${variant}`, description: `Gemini 3.8 Flash (${variant})`,
  apiUrl: 'https://untrusted.example', upstreamModelId: 'wrong-id'
}));
let responseBody = JSON.stringify({ data: [...variants, variants[0]] });
let status = 200;
let requests = 0;
const server = http.createServer((req, res) => {
  requests++;
  assert.equal(req.url, '/v1/models');
  assert.equal(req.headers['x-api-key'], 'antigravity');
  if (responseBody === null) return; // exercise the absolute discovery deadline
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(responseBody);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const baseUrl = `http://127.0.0.1:${server.address().port}`;
const read = async name => JSON.parse(await readFile(join(home, name), 'utf8'));
const provider = async () => (await read('providers.json')).providers.find(p => p.id === 'custom-antigravity');
async function configure(refresh = false) {
  const child = spawn(process.execPath, [script, home, baseUrl, ...(refresh ? ['--refresh-models'] : [])], {
    env: { ...process.env, HTTPS_PROXY: 'http://127.0.0.1:1', HTTP_PROXY: 'http://127.0.0.1:1' },
    stdio: ['ignore', 'pipe', 'pipe']
  });
  let output = '';
  child.stdout.on('data', chunk => { output += chunk; });
  child.stderr.on('data', chunk => { output += chunk; });
  const timeout = setTimeout(() => child.kill(), 15000);
  try { assert.equal(await new Promise(resolve => child.on('exit', resolve)), 0, output); }
  finally { clearTimeout(timeout); }
  return output;
}

try {
  const otherProvider = { id: 'keep-me', modelsCache: { models: [{ id: 'custom' }] } };
  const preferences = { theme: 'dark', claudeGravityFavoritesVersion: 2,
    favoriteModels: [{ providerId: 'keep-me', modelId: 'custom' }] };
  await writeFile(join(home, 'providers.json'), JSON.stringify({ providers: [otherProvider] }));
  await writeFile(join(home, 'config.json'), JSON.stringify(preferences));
  await writeFile(join(home, 'secrets.json'), JSON.stringify({ accounts: { 'provider:keep-me': 'test-secret' } }));
  await configure();
  assert.equal(requests, 0, 'bootstrap must not query an engine that has not started');
  assert.equal((await provider()).modelsCache.models.length, 22);

  await configure(true);
  const current = await provider();
  assert.equal(current.modelsCache.models.length, 4, 'use the live catalog and remove duplicate IDs');
  assert.equal(current.modelsCache.models[0].name, variants[0].description);
  for (const model of current.modelsCache.models) {
    assert.equal(model.apiUrl, baseUrl);
    assert.equal(model.upstreamModelId, model.id);
    assert.equal(model.modelFormat, 'anthropic');
  }
  assert.deepEqual((await read('providers.json')).providers[0], otherProvider);
  assert.deepEqual(await read('config.json'), preferences, 'preserve favorites and other preferences');
  assert.equal((await read('secrets.json')).accounts['provider:keep-me'], 'test-secret');
  await configure();
  assert.deepEqual(await provider(), current, 'next bootstrap must not reset live models to the static list');

  for (const invalid of ['{}', '{', '{"data":[]}', '{"data":[{"id":"not-a-model"}]}', 'x'.repeat(1_000_001)]) {
    responseBody = invalid;
    assert.match(await configure(true), /keeping the saved model catalog/);
    assert.deepEqual(await provider(), current, 'failed discovery must preserve the last good catalog and timestamp');
  }
  status = 503;
  responseBody = '{"error":"No accounts available"}';
  await configure(true);
  assert.deepEqual(await provider(), current);
  status = 200;
  responseBody = null;
  const started = Date.now();
  await configure(true);
  assert.ok(Date.now() - started < 14000, 'discovery must not hang startup');
  assert.deepEqual(await provider(), current);
  console.log('Live model discovery, offline fallback, metadata validation and preferences checks passed.');
} finally {
  server.closeAllConnections();
  await new Promise(resolve => server.close(resolve));
  await rm(home, { recursive: true, force: true });
}
