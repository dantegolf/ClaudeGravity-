#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));

function read(path) {
  return readFileSync(resolve(root, path), 'utf8');
}

function requireText(path, needle) {
  const text = read(path);
  if (!text.includes(needle)) throw new Error(`${path} is missing required text: ${needle}`);
}

for (const path of [
  'launchers/scripts/cg-delegate.mjs',
  'launchers/scripts/install-codex-integration.mjs',
  'launchers/CG-Delegate.sh',
  'launchers/CG-Delegate.cmd',
  'launchers/CD-Delegate.sh',
  'launchers/CD-Delegate.cmd',
  '.agents/skills/claudegravity-delegate/SKILL.md',
  'integrations/codex/global-agents.md',
]) {
  read(path);
}

requireText('launchers/scripts/cg-delegate.mjs', "resolve(scriptsDir, 'cg-agent.mjs')");
requireText('launchers/scripts/cg-delegate.mjs', 'REVIEW_REQUIRED');
requireText('launchers/scripts/cg-delegate.mjs', "['diff', '--check']");
requireText('launchers/scripts/install-codex-integration.mjs', "join(home, '.agents', 'skills', 'claudegravity-delegate', 'SKILL.md')");
requireText('launchers/scripts/install-codex-integration.mjs', 'CLAUDEGRAVITY_CODEX_DELEGATION_START');
requireText('launchers/scripts/install-codex-integration.mjs', "join(binDir, 'cg-delegate')");
requireText('launchers/scripts/install-codex-integration.mjs', "join(binDir, 'cd-delegate')");
requireText('.agents/skills/claudegravity-delegate/SKILL.md', 'name: claudegravity-delegate');
requireText('.agents/skills/claudegravity-delegate/SKILL.md', 'Do not trust the worker');
requireText('integrations/codex/global-agents.md', 'claudegravity-delegate');
requireText('install-cg-agent.sh', 'install-codex-integration.mjs');
requireText('install-cg-agent.ps1', 'install-codex-integration.mjs');

console.log('Codex delegation checks passed.');
