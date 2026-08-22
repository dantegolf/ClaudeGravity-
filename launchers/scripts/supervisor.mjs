#!/usr/bin/env node

import { spawn, spawnSync } from 'node:child_process';
import {
  appendFileSync,
  existsSync,
  mkdirSync,
  renameSync,
  statSync,
  unlinkSync,
} from 'node:fs';
import http from 'node:http';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { applyClaudeDesktopConfig, restoreClaudeDesktopConfig } from './configure-claude-desktop.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const runtimeDir = process.env.CLAUDEGRAVITY_RUNTIME_DIR || join(root, 'runtime');
const proxyRoot = process.env.CLAUDEGRAVITY_PROXY_ROOT || join(runtimeDir, 'node_modules', 'antigravity-claude-proxy');
const accCli = process.env.CLAUDEGRAVITY_ACC_CLI || join(proxyRoot, 'bin', 'cli.js');
const proxyServer = process.env.CLAUDEGRAVITY_PROXY_SERVER || join(proxyRoot, 'src', 'index.js');
const relayCli = process.env.CLAUDEGRAVITY_RELAY_CLI || join(runtimeDir, 'node_modules', '@jacobbd', 'relay-ai', 'dist', 'cli.js');
const patchScript = join(here, 'patch-antigravity-proxy.mjs');
const configureRelayScript = join(here, 'configure-relay.mjs');
const nodeBin = process.env.CLAUDEGRAVITY_NODE || process.execPath;
const relayHome = process.env.RELAY_AI_HOME || join(homedir(), '.relay-ai');
const internalPort = Number(process.env.CLAUDEGRAVITY_ANTIGRAVITY_PORT || 18080);
const gatewayPort = Number(process.env.CLAUDEGRAVITY_GATEWAY_PORT || 17645);
const controlPort = Number(process.env.CLAUDEGRAVITY_CONTROL_PORT || 17646);
const internalBaseUrl = `http://127.0.0.1:${internalPort}`;
const gatewayBaseUrl = `http://127.0.0.1:${gatewayPort}`;
const controlBaseUrl = `http://127.0.0.1:${controlPort}`;
const uiUrl = `${internalBaseUrl}/`;
const stateDir = process.env.CLAUDEGRAVITY_STATE_DIR || join(homedir(), '.claudegravity');
const logPath = join(stateDir, 'claudegravity.log');
const oldLogPath = `${logPath}.1`;
const mirrorLogs = process.env.CLAUDEGRAVITY_FOREGROUND_LOGS === '1';
const MAX_LOG_BYTES = 5 * 1024 * 1024;
const MAX_LOG_HISTORY = 1200;
const startedAt = new Date().toISOString();

let proxyChild = null;
let relayChild = null;
let controlServer = null;
let shuttingDown = false;
let restarting = false;
let desktopConfigured = false;
let proxyReady = false;
let gatewayReady = false;
const logHistory = [];
const logClients = new Set();

mkdirSync(stateDir, { recursive: true });
try {
  if (existsSync(logPath) && statSync(logPath).size > MAX_LOG_BYTES) {
    try { unlinkSync(oldLogPath); } catch { /* ignore */ }
    renameSync(logPath, oldLogPath);
  }
} catch { /* logging must never prevent startup */ }

function fail(message) {
  throw new Error(message);
}

function checkPort(value, name) {
  if (!Number.isInteger(value) || value <= 0 || value > 65535) {
    fail(`${name} must be a valid TCP port.`);
  }
}

function stripAnsi(value) {
  return String(value || '').replace(/\u001B\[[0-?]*[ -/]*[@-~]/g, '').replace(/\r/g, '').trim();
}

function inferLevel(message, fallback = 'INFO') {
  const text = String(message || '').toLowerCase();
  if (/(^|\s)(error|fatal|failed|failure|exception)(\s|:|$)/.test(text) || text.includes('❌')) return 'ERROR';
  if (/(^|\s)(warn|warning)(\s|:|$)/.test(text) || text.includes('⚠')) return 'WARN';
  if (/(success|ready|started|connected|✓|✔)/.test(text)) return 'SUCCESS';
  if (/(debug|trace)/.test(text)) return 'DEBUG';
  return fallback;
}

function recordLog(level, message, source = 'ClaudeGravity') {
  const cleaned = stripAnsi(message);
  if (!cleaned) return;
  const entry = {
    timestamp: new Date().toISOString(),
    level: level || inferLevel(cleaned),
    message: `[${source}] ${cleaned}`,
  };
  logHistory.push(entry);
  if (logHistory.length > MAX_LOG_HISTORY) logHistory.splice(0, logHistory.length - MAX_LOG_HISTORY);
  try {
    appendFileSync(logPath, `[${entry.timestamp}] [${entry.level}] ${entry.message}\n`, 'utf8');
  } catch { /* ignore log write failures */ }
  if (mirrorLogs) {
    const stream = entry.level === 'ERROR' ? process.stderr : process.stdout;
    stream.write(`${entry.message}\n`);
  }
  const payload = `data: ${JSON.stringify(entry)}\n\n`;
  for (const client of logClients) {
    try { client.write(payload); } catch { logClients.delete(client); }
  }
}

function recordCaptured(result, source) {
  for (const line of String(result.stdout || '').split(/\r?\n/)) {
    if (line.trim()) recordLog(inferLevel(line), line, source);
  }
  for (const line of String(result.stderr || '').split(/\r?\n/)) {
    if (line.trim()) recordLog(inferLevel(line, 'WARN'), line, source);
  }
}

function attachChildLogs(child, source) {
  const attach = (stream, fallback) => {
    if (!stream) return;
    let pending = '';
    stream.setEncoding('utf8');
    stream.on('data', (chunk) => {
      const lines = `${pending}${chunk}`.split(/\r?\n/);
      pending = lines.pop() || '';
      for (const line of lines) {
        if (line.trim()) recordLog(inferLevel(line, fallback), line, source);
      }
    });
    stream.on('end', () => {
      if (pending.trim()) recordLog(inferLevel(pending, fallback), pending, source);
    });
  };
  attach(child.stdout, 'INFO');
  attach(child.stderr, 'WARN');
}

function runNode(script, args = [], options = {}) {
  const result = spawnSync(nodeBin, [script, ...args], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, RELAY_AI_HOME: relayHome, ...options.env },
  });
  if (result.error) throw result.error;
  recordCaptured(result, options.source || 'setup');
  return result;
}

function httpOk(url, timeoutMs = 1500) {
  return new Promise((resolveRequest) => {
    const req = http.get(url, { timeout: timeoutMs }, (res) => {
      res.resume();
      resolveRequest(Boolean(res.statusCode && res.statusCode >= 200 && res.statusCode < 500));
    });
    req.on('timeout', () => {
      req.destroy();
      resolveRequest(false);
    });
    req.on('error', () => resolveRequest(false));
  });
}

function requestJson(url, timeoutMs = 1000) {
  return new Promise((resolveRequest) => {
    const req = http.get(url, { timeout: timeoutMs }, (res) => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try { resolveRequest(JSON.parse(body)); } catch { resolveRequest(null); }
      });
    });
    req.on('timeout', () => { req.destroy(); resolveRequest(null); });
    req.on('error', () => resolveRequest(null));
  });
}

async function waitForHttp(url, child, label, attempts = 40) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    if (child?.exitCode !== null) {
      fail(`${label} завершился до готовности (exit ${child.exitCode}).`);
    }
    if (await httpOk(url)) return;
    await new Promise((resolveWait) => setTimeout(resolveWait, 500));
  }
  fail(`${label} не ответил на ${url}.`);
}

async function terminateChild(child) {
  if (!child || child.exitCode !== null) return;
  child.kill('SIGTERM');
  const exited = await Promise.race([
    new Promise((resolveExit) => child.once('exit', () => resolveExit(true))),
    new Promise((resolveTimeout) => setTimeout(() => resolveTimeout(false), 3000)),
  ]);
  if (exited === false && child.exitCode === null) child.kill('SIGKILL');
}

function launchClaudeDesktop() {
  if (process.env.CLAUDEGRAVITY_SKIP_DESKTOP_LAUNCH === '1') {
    recordLog('INFO', 'Claude Desktop launch skipped by environment.', 'desktop');
    return;
  }

  try {
    if (process.platform === 'darwin') {
      spawn('open', ['-a', 'Claude'], { detached: true, stdio: 'ignore' }).unref();
      recordLog('SUCCESS', 'Claude Desktop opened.', 'desktop');
      return;
    }
    if (process.platform === 'win32') {
      const script = [
        "$app = Get-StartApps | Where-Object { $_.Name -eq 'Claude' -or $_.Name -like 'Claude*' } | Select-Object -First 1",
        "if ($app) { Start-Process explorer.exe \"shell:AppsFolder\\$($app.AppID)\"; exit 0 }",
        "$candidates = @($env:LOCALAPPDATA + '\\AnthropicClaude\\Claude.exe', $env:LOCALAPPDATA + '\\Programs\\Claude\\Claude.exe')",
        "foreach ($candidate in $candidates) { if (Test-Path -LiteralPath $candidate) { Start-Process -FilePath $candidate; exit 0 } }",
        'exit 1',
      ].join('; ');
      const launched = spawnSync('powershell.exe', ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', script], { stdio: 'ignore' });
      if (launched.status === 0) recordLog('SUCCESS', 'Claude Desktop opened.', 'desktop');
      else recordLog('WARN', 'Claude Desktop не найден — откройте его вручную.', 'desktop');
      return;
    }
    if (process.platform === 'linux') {
      const child = spawn('claude-desktop', [], { stdio: 'ignore', detached: true });
      child.on('error', () => recordLog('WARN', 'Claude Desktop не найден — откройте его вручную.', 'desktop'));
      child.unref();
      recordLog('SUCCESS', 'Claude Desktop launch requested.', 'desktop');
    }
  } catch (error) {
    recordLog('WARN', `Не удалось открыть Claude Desktop автоматически: ${error.message}`, 'desktop');
  }
}

function openDashboard() {
  if (process.env.CLAUDEGRAVITY_SKIP_BROWSER === '1') return;
  try {
    if (process.platform === 'darwin') {
      spawn('open', [uiUrl], { detached: true, stdio: 'ignore' }).unref();
    } else if (process.platform === 'win32') {
      spawn('cmd.exe', ['/c', 'start', '', uiUrl], { detached: true, stdio: 'ignore' }).unref();
    } else {
      spawn('xdg-open', [uiUrl], { detached: true, stdio: 'ignore' }).unref();
    }
    recordLog('SUCCESS', `Dashboard opened: ${uiUrl}`, 'web');
  } catch (error) {
    recordLog('WARN', `Не удалось открыть dashboard автоматически: ${error.message}`, 'web');
  }
}

function configureEngines() {
  if (process.env.CLAUDEGRAVITY_SKIP_PATCH !== '1') {
    if (!existsSync(patchScript)) fail('Compatibility patch ClaudeGravity не найден.');
    const patched = runNode(patchScript, [proxyRoot], { source: 'patch' });
    if (patched.status !== 0) fail('Bundled Antigravity engine не прошёл compatibility check.');
  }

  const configured = runNode(configureRelayScript, [relayHome, internalBaseUrl], { source: 'relay-config' });
  if (configured.status !== 0) fail('Не удалось подготовить конфигурацию Relay AI.');

  if (process.env.CLAUDEGRAVITY_SKIP_PROVIDER_CHECK !== '1') {
    const providers = runNode(relayCli, ['providers', 'list'], { source: 'relay' });
    const output = `${providers.stdout || ''}${providers.stderr || ''}`;
    if (providers.status !== 0 || !output.includes('custom-antigravity')) {
      fail(`Relay AI не увидел провайдер Antigravity. ${stripAnsi(output)}`);
    }
  }
}

function prepareAccount() {
  if (process.env.CLAUDEGRAVITY_SKIP_ACCOUNT === '1') return;

  // Clean up the detached :8080 process used by older ClaudeGravity releases.
  runNode(accCli, ['stop'], { source: 'migration' });
  const accounts = runNode(accCli, ['accounts', 'list'], { source: 'accounts' });
  const output = `${accounts.stdout || ''}${accounts.stderr || ''}`;
  if (/[1-9][0-9]* account\(s\)/.test(output)) return;

  // Web-first startup: the bundled Antigravity WebUI owns OAuth/account setup.
  // Do not block a hidden background process on terminal input.
  recordLog('WARN', 'Google account is not linked yet. Open the Accounts tab in ClaudeGravity to add one.', 'accounts');
}

function onUnexpectedExit(source, code, signal) {
  if (source === 'Antigravity') proxyReady = false;
  if (source === 'Relay') gatewayReady = false;
  if (shuttingDown || restarting) return;
  recordLog('ERROR', `${source} engine stopped unexpectedly (code=${code}, signal=${signal || 'none'}).`, source);
  void shutdown(code || 1);
}

function startProxy() {
  if (!existsSync(proxyServer)) fail('Bundled Antigravity engine не найден. Переустановите ClaudeGravity.');
  proxyReady = false;
  proxyChild = spawn(nodeBin, [proxyServer], {
    stdio: ['ignore', 'pipe', 'pipe'],
    env: {
      ...process.env,
      PORT: String(internalPort),
      HOST: '127.0.0.1',
      ANTIGRAVITY_API_KEY: 'antigravity',
      NO_COLOR: '1',
    },
  });
  attachChildLogs(proxyChild, 'Antigravity');
  proxyChild.on('error', (error) => recordLog('ERROR', error.message, 'Antigravity'));
  proxyChild.on('exit', (code, signal) => onUnexpectedExit('Antigravity', code, signal));
}

function startRelay() {
  if (!existsSync(relayCli)) fail('Bundled Relay engine не найден. Переустановите ClaudeGravity.');
  gatewayReady = false;
  relayChild = spawn(nodeBin, [
    relayCli,
    'server',
    '--quick',
    '--listen', 'local',
    '--providers', 'custom-antigravity',
    '--no-free-only',
    '--mask-gateway-ids',
  ], {
    stdio: ['ignore', 'pipe', 'pipe'],
    env: {
      ...process.env,
      RELAY_AI_HOME: relayHome,
      ANTIGRAVITY_API_KEY: 'antigravity',
      RELAY_AI_KEY_CUSTOM_ANTIGRAVITY: 'antigravity',
      CLAUDEGRAVITY_GATEWAY_PORT: String(gatewayPort),
      NO_COLOR: '1',
    },
  });
  attachChildLogs(relayChild, 'Relay');
  relayChild.on('error', (error) => recordLog('ERROR', error.message, 'Relay'));
  relayChild.on('exit', (code, signal) => onUnexpectedExit('Relay', code, signal));
}

async function startEngines() {
  recordLog('INFO', `Starting Antigravity on ${internalBaseUrl}`, 'supervisor');
  startProxy();
  await waitForHttp(uiUrl, proxyChild, 'Antigravity engine');
  proxyReady = true;
  recordLog('SUCCESS', 'Antigravity engine ready.', 'supervisor');

  recordLog('INFO', `Starting unified gateway on ${gatewayBaseUrl}`, 'supervisor');
  startRelay();
  await waitForHttp(`${gatewayBaseUrl}/health`, relayChild, 'ClaudeGravity gateway');
  gatewayReady = true;
  recordLog('SUCCESS', 'Relay gateway ready.', 'supervisor');
}

async function restartEngines() {
  if (restarting || shuttingDown) return;
  restarting = true;
  recordLog('INFO', 'Restart requested from WebUI.', 'supervisor');
  try {
    gatewayReady = false;
    proxyReady = false;
    await terminateChild(relayChild);
    await terminateChild(proxyChild);
    relayChild = null;
    proxyChild = null;
    await startEngines();
    recordLog('SUCCESS', 'Engines restarted successfully.', 'supervisor');
  } catch (error) {
    recordLog('ERROR', `Restart failed: ${error.message}`, 'supervisor');
  } finally {
    restarting = false;
  }
}

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'content-type');
}

function sendJson(res, status, value) {
  setCors(res);
  res.statusCode = status;
  res.setHeader('content-type', 'application/json; charset=utf-8');
  res.end(`${JSON.stringify(value)}\n`);
}

function statusPayload() {
  return {
    product: 'ClaudeGravity',
    version: 1,
    ready: proxyReady && gatewayReady && desktopConfigured,
    proxyReady,
    gatewayReady,
    desktopConfigured,
    startedAt,
    uiUrl,
    publicEndpoint: `${gatewayBaseUrl}/anthropic`,
    internalEndpoint: internalBaseUrl,
    controlEndpoint: controlBaseUrl,
    logPath,
  };
}

function handleControlRequest(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    res.end();
    return;
  }

  const url = new URL(req.url || '/', controlBaseUrl);
  if (req.method === 'GET' && url.pathname === '/health') {
    sendJson(res, 200, statusPayload());
    return;
  }
  if (req.method === 'GET' && url.pathname === '/logs') {
    sendJson(res, 200, { logs: logHistory });
    return;
  }
  if (req.method === 'GET' && url.pathname === '/logs/stream') {
    res.statusCode = 200;
    res.setHeader('content-type', 'text/event-stream');
    res.setHeader('cache-control', 'no-cache');
    res.setHeader('connection', 'keep-alive');
    if (url.searchParams.get('history') === 'true') {
      for (const entry of logHistory) res.write(`data: ${JSON.stringify(entry)}\n\n`);
    }
    logClients.add(res);
    req.on('close', () => logClients.delete(res));
    return;
  }
  if (req.method === 'POST' && url.pathname === '/action/open-claude') {
    launchClaudeDesktop();
    sendJson(res, 200, { ok: true });
    return;
  }
  if (req.method === 'POST' && url.pathname === '/action/restart') {
    sendJson(res, 202, { ok: true, restarting: true });
    setTimeout(() => void restartEngines(), 25);
    return;
  }
  if (req.method === 'POST' && url.pathname === '/action/stop') {
    sendJson(res, 202, { ok: true, stopping: true });
    setTimeout(() => void shutdown(0), 75);
    return;
  }
  sendJson(res, 404, { error: 'not found' });
}

async function startControlServer() {
  controlServer = http.createServer(handleControlRequest);
  await new Promise((resolveListen, rejectListen) => {
    const onError = (error) => {
      controlServer.off('listening', onListening);
      rejectListen(error);
    };
    const onListening = () => {
      controlServer.off('error', onError);
      resolveListen();
    };
    controlServer.once('error', onError);
    controlServer.once('listening', onListening);
    controlServer.listen(controlPort, '127.0.0.1');
  });
  recordLog('SUCCESS', `Control API ready on ${controlBaseUrl}`, 'web');
}

async function closeControlServer() {
  if (!controlServer) return;
  const server = controlServer;
  controlServer = null;
  await new Promise((resolveClose) => server.close(() => resolveClose()));
}

async function shutdown(exitCode = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  gatewayReady = false;
  proxyReady = false;
  recordLog('INFO', 'Stopping ClaudeGravity...', 'supervisor');
  await terminateChild(relayChild);
  await terminateChild(proxyChild);
  relayChild = null;
  proxyChild = null;
  if (desktopConfigured) {
    try {
      restoreClaudeDesktopConfig();
      recordLog('SUCCESS', 'Claude Desktop configuration restored.', 'desktop');
    } catch (error) {
      recordLog('ERROR', `Не удалось восстановить конфигурацию Claude Desktop: ${error.message}`, 'desktop');
    }
    desktopConfigured = false;
  }
  for (const client of logClients) {
    try { client.end(); } catch { /* ignore */ }
  }
  logClients.clear();
  await closeControlServer();
  recordLog('SUCCESS', 'ClaudeGravity stopped.', 'supervisor');
  process.exit(exitCode);
}

async function handOffToExistingInstance() {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const status = await requestJson(`${controlBaseUrl}/health`, 500);
    if (status?.product === 'ClaudeGravity') {
      recordLog('INFO', 'Existing ClaudeGravity instance detected; opening its dashboard.', 'launcher');
      openDashboard();
      launchClaudeDesktop();
      return true;
    }
    await new Promise((resolveWait) => setTimeout(resolveWait, 150));
  }
  return false;
}

async function main() {
  checkPort(internalPort, 'CLAUDEGRAVITY_ANTIGRAVITY_PORT');
  checkPort(gatewayPort, 'CLAUDEGRAVITY_GATEWAY_PORT');
  checkPort(controlPort, 'CLAUDEGRAVITY_CONTROL_PORT');
  if (new Set([internalPort, gatewayPort, controlPort]).size !== 3) fail('ClaudeGravity ports must be distinct.');
  if (gatewayPort !== 17645 && process.env.CLAUDEGRAVITY_ALLOW_TEST_PORTS !== '1') {
    fail('Bundled Relay AI 0.9.5 exposes its gateway on port 17645.');
  }

  if (await handOffToExistingInstance()) return;

  try {
    await startControlServer();
  } catch (error) {
    if (error?.code === 'EADDRINUSE' && await handOffToExistingInstance()) return;
    throw error;
  }

  recordLog('INFO', 'Runtime: bundled · local WebUI · Smart DNS: selective', 'supervisor');
  restoreClaudeDesktopConfig();
  configureEngines();
  prepareAccount();
  await startEngines();

  const desktop = applyClaudeDesktopConfig(gatewayPort);
  desktopConfigured = true;
  recordLog('SUCCESS', `Claude Desktop endpoint configured: ${desktop.baseUrl}`, 'desktop');
  launchClaudeDesktop();
  openDashboard();
  recordLog('SUCCESS', `ClaudeGravity ready. Dashboard: ${uiUrl}`, 'supervisor');
}

process.on('SIGINT', () => void shutdown(0));
process.on('SIGTERM', () => void shutdown(0));
process.on('uncaughtException', async (error) => {
  recordLog('ERROR', `Uncaught exception: ${error.message}`, 'supervisor');
  await shutdown(1);
});
process.on('unhandledRejection', async (error) => {
  recordLog('ERROR', `Unhandled rejection: ${error instanceof Error ? error.message : String(error)}`, 'supervisor');
  await shutdown(1);
});

main().catch(async (error) => {
  recordLog('ERROR', error.message, 'supervisor');
  await shutdown(1);
});
