#!/usr/bin/env node

import { randomUUID } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, rmSync, unlinkSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

function claudeDesktopHome() {
  if (process.env.CLAUDEGRAVITY_CLAUDE_DESKTOP_HOME) {
    return process.env.CLAUDEGRAVITY_CLAUDE_DESKTOP_HOME;
  }
  if (process.platform === 'win32') {
    return join(process.env.LOCALAPPDATA || join(homedir(), 'AppData', 'Local'), 'Claude-3p');
  }
  if (process.platform === 'linux') {
    return join(process.env.XDG_CONFIG_HOME || join(homedir(), '.config'), 'Claude-3p');
  }
  return join(homedir(), 'Library', 'Application Support', 'Claude-3p');
}

function relayHome() {
  return process.env.RELAY_AI_HOME || join(homedir(), '.relay-ai');
}

function configLibraryPath() {
  return join(claudeDesktopHome(), 'configLibrary');
}

function metaPath() {
  return join(configLibraryPath(), '_meta.json');
}

function sessionPath() {
  return join(relayHome(), 'claudegravity-desktop-session.json');
}

function safeRead(path) {
  try {
    return readFileSync(path, 'utf8');
  } catch {
    return null;
  }
}

function safeJson(path, fallback) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return fallback;
  }
}

export function restoreClaudeDesktopConfig() {
  const path = sessionPath();
  if (!existsSync(path)) return false;

  const session = safeJson(path, null);
  if (!session || typeof session !== 'object') {
    unlinkSync(path);
    return false;
  }

  if (session.configPath) {
    rmSync(session.configPath, { force: true });
  }

  const targetMeta = metaPath();
  if (session.metaExisted) {
    mkdirSync(dirname(targetMeta), { recursive: true });
    writeFileSync(targetMeta, String(session.metaContent ?? ''), 'utf8');
  } else {
    rmSync(targetMeta, { force: true });
  }

  rmSync(path, { force: true });
  return true;
}

export function applyClaudeDesktopConfig(port = 17645) {
  restoreClaudeDesktopConfig();

  const library = configLibraryPath();
  const targetMeta = metaPath();
  const existingMeta = safeRead(targetMeta);
  const meta = existingMeta ? safeJson(targetMeta, { appliedId: '', entries: [] }) : { appliedId: '', entries: [] };
  meta.entries = Array.isArray(meta.entries) ? meta.entries : [];

  const uuid = randomUUID();
  const configPath = join(library, `${uuid}.json`);
  const config = {
    inferenceProvider: 'gateway',
    inferenceGatewayBaseUrl: `http://127.0.0.1:${port}/anthropic`,
    inferenceGatewayApiKey: 'claudegravity',
    inferenceGatewayAuthScheme: 'bearer',
    coworkEgressAllowedHosts: ['*'],
  };

  mkdirSync(library, { recursive: true });
  mkdirSync(relayHome(), { recursive: true });
  writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`, 'utf8');

  meta.appliedId = uuid;
  meta.entries = meta.entries.filter((entry) => entry?.id !== uuid);
  meta.entries.push({ id: uuid, name: 'ClaudeGravity Gateway' });
  writeFileSync(targetMeta, `${JSON.stringify(meta, null, 2)}\n`, 'utf8');

  const session = {
    schemaVersion: 1,
    createdAt: new Date().toISOString(),
    uuid,
    configPath,
    metaExisted: existingMeta !== null,
    metaContent: existingMeta,
  };
  writeFileSync(sessionPath(), `${JSON.stringify(session, null, 2)}\n`, { mode: 0o600 });

  return { uuid, configPath, baseUrl: config.inferenceGatewayBaseUrl };
}

const invokedDirectly = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (invokedDirectly) {
  const command = process.argv[2] || 'apply';
  if (command === 'restore') {
    const restored = restoreClaudeDesktopConfig();
    console.log(restored ? 'Claude Desktop configuration restored.' : 'No ClaudeGravity Desktop session to restore.');
  } else {
    const port = Number(process.argv[3] || 17645);
    if (!Number.isInteger(port) || port <= 0 || port > 65535) throw new Error('Invalid gateway port.');
    const result = applyClaudeDesktopConfig(port);
    console.log(`Claude Desktop configured for ${result.baseUrl}`);
  }
}
