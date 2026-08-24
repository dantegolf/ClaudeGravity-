#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { execFile as execFileCb } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execFile = promisify(execFileCb);

function parseRepo(argv) {
  let repo = process.cwd();
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--repo' && argv[i + 1]) {
      repo = argv[i + 1];
      i++;
    }
  }
  return resolve(repo);
}

async function git(repo, args) {
  try {
    const { stdout, stderr } = await execFile('git', args, {
      cwd: repo,
      timeout: 120000,
      maxBuffer: 4 * 1024 * 1024,
      windowsHide: true,
    });
    return {
      ok: true,
      output: `${stdout}${stderr ? `\n[stderr]\n${stderr}` : ''}`.trim(),
    };
  } catch (error) {
    return {
      ok: false,
      output: `${error.stdout || ''}${error.stderr || ''}`.trim() || error.message,
    };
  }
}

async function runWorker(agentPath, argv) {
  return await new Promise((resolveExit, reject) => {
    const child = spawn(process.execPath, [agentPath, ...argv], {
      stdio: 'inherit',
      windowsHide: true,
    });
    child.once('error', reject);
    child.once('exit', (code, signal) => {
      if (signal) {
        reject(new Error(`CG-Agent terminated by signal ${signal}`));
        return;
      }
      resolveExit(code ?? 1);
    });
  });
}

function printSection(title, body) {
  console.error(`\n[cg-delegate] ${title}`);
  console.error(body || '(clean)');
}

const argv = process.argv.slice(2);
const repo = parseRepo(argv);
const scriptsDir = dirname(fileURLToPath(import.meta.url));
const agentPath = resolve(scriptsDir, 'cg-agent.mjs');

if (!existsSync(agentPath)) {
  throw new Error(`CG-Agent runtime not found: ${agentPath}`);
}

const beforeStatus = await git(repo, ['status', '--short']);

console.error('[cg-delegate] Codex remains the supervisor and final reviewer.');
console.error('[cg-delegate] Delegating implementation to the ClaudeGravity worker.');
console.error(`[cg-delegate] repo=${repo}`);
if (beforeStatus.ok && beforeStatus.output) {
  printSection('PRE-EXISTING WORKTREE STATUS (preserve these changes)', beforeStatus.output);
}

const exitCode = await runWorker(agentPath, argv);
if (exitCode !== 0) {
  console.error(`[cg-delegate] worker failed with exit code ${exitCode}`);
  process.exit(exitCode);
}

const [afterStatus, diffStat, diffCheck] = await Promise.all([
  git(repo, ['status', '--short']),
  git(repo, ['diff', '--stat']),
  git(repo, ['diff', '--check']),
]);

console.error('\n[cg-delegate] WORKER_DONE');
console.error('[cg-delegate] REVIEW_REQUIRED: do not trust the worker summary; inspect the actual diff and run relevant checks independently.');

if (afterStatus.ok) printSection('CURRENT WORKTREE STATUS', afterStatus.output);
else printSection('CURRENT WORKTREE STATUS UNAVAILABLE', afterStatus.output);

if (diffStat.ok) printSection('DIFF STAT', diffStat.output);
else printSection('DIFF STAT UNAVAILABLE', diffStat.output);

if (diffCheck.ok) printSection('GIT DIFF --CHECK', diffCheck.output || 'clean');
else printSection('GIT DIFF --CHECK FAILED', diffCheck.output);

console.error('\n[cg-delegate] Suggested supervisor next steps: git diff --check; git diff; relevant tests/lint/typecheck/build.');
