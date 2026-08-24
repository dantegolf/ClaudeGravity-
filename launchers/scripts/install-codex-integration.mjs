#!/usr/bin/env node

import { chmod, mkdir, readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';

const START_MARKER = '<!-- CLAUDEGRAVITY_CODEX_DELEGATION_START -->';
const END_MARKER = '<!-- CLAUDEGRAVITY_CODEX_DELEGATION_END -->';

function parseArgs(argv) {
  const out = {
    rawBase: process.env.CLAUDEGRAVITY_RAW_BASE || 'https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main',
    delegateLauncher: '',
  };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--raw-base') out.rawBase = argv[++i];
    else if (argv[i] === '--delegate-launcher') out.delegateLauncher = argv[++i];
    else if (argv[i] === '--help' || argv[i] === '-h') out.help = true;
  }
  return out;
}

function usage() {
  console.log(`install-codex-integration

Usage:
  node install-codex-integration.mjs --delegate-launcher <path> [--raw-base <url>]

Installs the ClaudeGravity Codex skill globally, adds/updates an idempotent managed
block in the effective global Codex AGENTS file, and creates stable user shims for
cg-delegate and cd-delegate.
`);
}

async function fetchText(url) {
  const response = await fetch(url, { signal: AbortSignal.timeout(30000) });
  const text = await response.text();
  if (!response.ok) throw new Error(`Failed to download ${url}: HTTP ${response.status}: ${text.slice(0, 500)}`);
  return text;
}

async function readTextIfExists(path) {
  if (!existsSync(path)) return '';
  return await readFile(path, 'utf8');
}

function mergeManagedBlock(existing, policy) {
  const block = `${START_MARKER}\n${policy.trim()}\n${END_MARKER}`;
  const start = existing.indexOf(START_MARKER);
  const end = existing.indexOf(END_MARKER);

  if ((start >= 0) !== (end >= 0) || (start >= 0 && end < start)) {
    throw new Error('Existing Codex AGENTS file contains an incomplete ClaudeGravity managed block. Fix the markers manually before reinstalling.');
  }

  if (start >= 0) {
    const after = end + END_MARKER.length;
    return `${existing.slice(0, start)}${block}${existing.slice(after)}`;
  }

  if (!existing.trim()) return `${block}\n`;
  return `${existing.trimEnd()}\n\n${block}\n`;
}

function shellQuote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

async function installShims(delegateLauncher) {
  const binDir = join(homedir(), '.claudegravity', 'bin');
  await mkdir(binDir, { recursive: true });

  if (process.platform === 'win32') {
    const content = `@echo off\r\ncall "${delegateLauncher}" %*\r\n`;
    const canonical = join(binDir, 'cg-delegate.cmd');
    const alias = join(binDir, 'cd-delegate.cmd');
    await writeFile(canonical, content, 'utf8');
    await writeFile(alias, content, 'utf8');
    return { canonical, alias };
  }

  const content = `#!/usr/bin/env bash\nset -euo pipefail\nexec ${shellQuote(delegateLauncher)} "$@"\n`;
  const canonical = join(binDir, 'cg-delegate');
  const alias = join(binDir, 'cd-delegate');
  await writeFile(canonical, content, 'utf8');
  await writeFile(alias, content, 'utf8');
  await chmod(canonical, 0o755);
  await chmod(alias, 0o755);
  return { canonical, alias };
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  usage();
  process.exit(0);
}
if (!args.delegateLauncher) {
  usage();
  throw new Error('--delegate-launcher is required.');
}

const launcher = resolve(args.delegateLauncher);
if (!existsSync(launcher)) throw new Error(`Delegate launcher not found: ${launcher}`);

const rawBase = args.rawBase.replace(/\/+$/, '');
const [policy, skill] = await Promise.all([
  fetchText(`${rawBase}/integrations/codex/global-agents.md`),
  fetchText(`${rawBase}/.agents/skills/claudegravity-delegate/SKILL.md`),
]);

const home = homedir();
const codexHome = resolve(process.env.CODEX_HOME || join(home, '.codex'));
const agentsPath = join(codexHome, 'AGENTS.md');
const overridePath = join(codexHome, 'AGENTS.override.md');
const overrideText = await readTextIfExists(overridePath);
const targetAgentsPath = overrideText.trim() ? overridePath : agentsPath;
const existingAgents = await readTextIfExists(targetAgentsPath);

await mkdir(dirname(targetAgentsPath), { recursive: true });
await writeFile(targetAgentsPath, mergeManagedBlock(existingAgents, policy), 'utf8');

const skillPath = join(home, '.agents', 'skills', 'claudegravity-delegate', 'SKILL.md');
await mkdir(dirname(skillPath), { recursive: true });
await writeFile(skillPath, skill.trimEnd() + '\n', 'utf8');

const shims = await installShims(launcher);

console.log(`Codex global instructions: ${targetAgentsPath}`);
console.log(`Codex skill: ${skillPath}`);
console.log(`Delegate command: ${shims.canonical}`);
console.log(`Compatibility alias: ${shims.alias}`);
console.log('Restart Codex if the new skill is not detected immediately.');
