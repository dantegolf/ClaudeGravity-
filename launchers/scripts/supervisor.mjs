#!/usr/bin/env node

import { spawn, spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
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
const internalBaseUrl = `http://127.0.0.1:${internalPort}`;
const gatewayBaseUrl = `http://127.0.0.1:${gatewayPort}`;

let proxyChild = null;
let relayChild = null;
let shuttingDown = false;
let desktopConfigured = false;

function fail(message) {
  throw new Error(message);
}

function checkPort(value, name) {
  if (!Number.isInteger(value) || value <= 0 || value > 65535) {
    fail(`${name} must be a valid TCP port.`);
  }
}

function runNode(script, args = [], options = {}) {
  const result = spawnSync(nodeBin, [script, ...args], {
    encoding: 'utf8',
    stdio: options.capture ? ['inherit', 'pipe', 'pipe'] : 'inherit',
    env: { ...process.env, RELAY_AI_HOME: relayHome, ...options.env },
  });
  if (result.error) throw result.error;
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

async function waitForHttp(url, child, label, attempts = 30) {
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
    new Promise((resolveExit) => child.once('exit', resolveExit)),
    new Promise((resolveTimeout) => setTimeout(() => resolveTimeout(false), 3000)),
  ]);
  if (exited === false && child.exitCode === null) child.kill('SIGKILL');
}

async function shutdown(exitCode = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  await terminateChild(relayChild);
  await terminateChild(proxyChild);
  if (desktopConfigured) {
    try {
      restoreClaudeDesktopConfig();
    } catch (error) {
      console.error(`Не удалось восстановить конфигурацию Claude Desktop: ${error.message}`);
    }
    desktopConfigured = false;
  }
  process.exitCode = exitCode;
}

function configureEngines() {
  if (process.env.CLAUDEGRAVITY_SKIP_PATCH !== '1') {
    if (!existsSync(patchScript)) fail('Compatibility patch ClaudeGravity не найден.');
    const patched = runNode(patchScript, [proxyRoot]);
    if (patched.status !== 0) fail('Bundled Antigravity engine не прошёл compatibility check.');
  }

  const configured = runNode(configureRelayScript, [relayHome, internalBaseUrl]);
  if (configured.status !== 0) fail('Не удалось подготовить конфигурацию Relay AI.');

  if (process.env.CLAUDEGRAVITY_SKIP_PROVIDER_CHECK !== '1') {
    const providers = runNode(relayCli, ['providers', 'list'], { capture: true });
    const output = `${providers.stdout || ''}${providers.stderr || ''}`;
    if (providers.status !== 0 || !output.includes('custom-antigravity')) {
      fail(`Relay AI не увидел провайдер Antigravity. ${output.trim()}`);
    }
  }
}

function prepareAccount() {
  if (process.env.CLAUDEGRAVITY_SKIP_ACCOUNT === '1') return;

  // Stop a detached proxy left by an older ClaudeGravity release. The upstream
  // CLI uses one PID file, so this also cleans the legacy :8080 instance.
  runNode(accCli, ['stop'], { capture: true });

  const accounts = runNode(accCli, ['accounts', 'list'], { capture: true });
  const output = `${accounts.stdout || ''}${accounts.stderr || ''}`;
  if (/[1-9][0-9]* account\(s\)/.test(output)) return;

  console.log('\nАккаунт Google ещё не привязан. Запускаю привязку...');
  const added = runNode(accCli, ['accounts', 'add']);
  if (added.status !== 0) fail('Не удалось привязать аккаунт Google.');
}

function startProxy() {
  if (!existsSync(proxyServer)) fail('Bundled Antigravity engine не найден. Переустановите ClaudeGravity.');
  proxyChild = spawn(nodeBin, [proxyServer], {
    stdio: 'inherit',
    env: {
      ...process.env,
      PORT: String(internalPort),
      HOST: '127.0.0.1',
      ANTIGRAVITY_API_KEY: 'antigravity',
    },
  });
  proxyChild.on('error', (error) => console.error(`Antigravity engine: ${error.message}`));
}

function startRelay() {
  if (!existsSync(relayCli)) fail('Bundled Relay engine не найден. Переустановите ClaudeGravity.');
  relayChild = spawn(nodeBin, [
    relayCli,
    'server',
    '--quick',
    '--listen', 'local',
    '--providers', 'custom-antigravity',
    '--no-free-only',
    '--mask-gateway-ids',
  ], {
    stdio: 'inherit',
    env: {
      ...process.env,
      RELAY_AI_HOME: relayHome,
      ANTIGRAVITY_API_KEY: 'antigravity',
      RELAY_AI_KEY_CUSTOM_ANTIGRAVITY: 'antigravity',
      CLAUDEGRAVITY_GATEWAY_PORT: String(gatewayPort),
    },
  });
  relayChild.on('error', (error) => console.error(`Relay engine: ${error.message}`));
}

function launchClaudeDesktop() {
  if (process.env.CLAUDEGRAVITY_SKIP_DESKTOP_LAUNCH === '1') return;

  try {
    if (process.platform === 'darwin') {
      spawn('open', ['-a', 'Claude'], { detached: true, stdio: 'ignore' }).unref();
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
      const launched = spawnSync('powershell.exe', ['-NoProfile', '-Command', script], { stdio: 'ignore' });
      if (launched.status !== 0) console.warn('Claude Desktop не найден — откройте его вручную.');
      return;
    }
    if (process.platform === 'linux') {
      const child = spawn('claude-desktop', [], { detached: true, stdio: 'ignore' });
      child.on('error', () => console.warn('Claude Desktop не найден — откройте его вручную.'));
      child.unref();
    }
  } catch {
    console.warn('Не удалось открыть Claude Desktop автоматически — откройте его вручную.');
  }
}

async function main() {
  checkPort(internalPort, 'CLAUDEGRAVITY_ANTIGRAVITY_PORT');
  checkPort(gatewayPort, 'CLAUDEGRAVITY_GATEWAY_PORT');
  if (gatewayPort !== 17645 && process.env.CLAUDEGRAVITY_ALLOW_TEST_PORTS !== '1') {
    fail('Bundled Relay AI 0.9.5 exposes its gateway on port 17645.');
  }

  console.log('╭─────────────────────────────────────────╮');
  console.log('│          ClaudeGravity Gateway          │');
  console.log('╰─────────────────────────────────────────╯');
  console.log('Runtime: bundled · one public localhost · Smart DNS: selective');

  restoreClaudeDesktopConfig();
  configureEngines();
  prepareAccount();

  console.log('\nЗапускаю внутренний Antigravity engine...');
  startProxy();
  await waitForHttp(`${internalBaseUrl}/health`, proxyChild, 'Antigravity engine');

  console.log('Запускаю единый ClaudeGravity gateway...');
  startRelay();
  await waitForHttp(`${gatewayBaseUrl}/health`, relayChild, 'ClaudeGravity gateway');

  const desktop = applyClaudeDesktopConfig(gatewayPort);
  desktopConfigured = true;
  launchClaudeDesktop();

  console.log('\n✓ ClaudeGravity готов');
  console.log(`  Local endpoint: ${desktop.baseUrl}`);
  console.log('  Engines: Antigravity + Relay AI (managed internally)');
  console.log('  Закройте это окно или нажмите Ctrl+C, чтобы остановить gateway.\n');

  const proxyExit = new Promise((resolveExit) => proxyChild.once('exit', (code, signal) => resolveExit({ source: 'proxy', code, signal })));
  const relayExit = new Promise((resolveExit) => relayChild.once('exit', (code, signal) => resolveExit({ source: 'relay', code, signal })));
  const result = await Promise.race([proxyExit, relayExit]);

  if (!shuttingDown) {
    console.error(`${result.source === 'proxy' ? 'Antigravity' : 'Relay'} engine остановился неожиданно.`);
    await shutdown(result.code || 1);
  }
}

process.on('SIGINT', () => void shutdown(0));
process.on('SIGTERM', () => void shutdown(0));
process.on('uncaughtException', async (error) => {
  console.error(`\nОшибка ClaudeGravity: ${error.message}`);
  await shutdown(1);
});
process.on('unhandledRejection', async (error) => {
  console.error(`\nОшибка ClaudeGravity: ${error instanceof Error ? error.message : String(error)}`);
  await shutdown(1);
});

main().catch(async (error) => {
  console.error(`\nОшибка ClaudeGravity: ${error.message}`);
  await shutdown(1);
});
