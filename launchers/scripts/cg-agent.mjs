#!/usr/bin/env node

import { readFile, writeFile, readdir, stat, realpath, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { resolve, relative, dirname, sep } from 'node:path';
import { exec as execCb } from 'node:child_process';
import { promisify } from 'node:util';

const exec = promisify(execCb);

function parseArgs(argv) {
  const out = {
    repo: process.cwd(),
    model: 'gemini-3.1-pro-high',
    maxTurns: 24,
    task: '',
    taskFile: '',
    baseUrl: process.env.CG_AGENT_BASE_URL || 'http://127.0.0.1:18080',
    apiKey: process.env.CG_AGENT_API_KEY || 'antigravity',
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--repo') out.repo = argv[++i];
    else if (a === '--model') out.model = argv[++i];
    else if (a === '--task') out.task = argv[++i];
    else if (a === '--task-file') out.taskFile = argv[++i];
    else if (a === '--max-turns') out.maxTurns = Number(argv[++i]);
    else if (a === '--base-url') out.baseUrl = argv[++i];
    else if (a === '--api-key') out.apiKey = argv[++i];
    else if (a === '--help' || a === '-h') out.help = true;
    else if (!a.startsWith('-') && !out.task) out.task = a;
  }
  return out;
}

function usage() {
  console.log(`cg-agent - Gemini coding worker through the managed ClaudeGravity engine

Usage:
  cg-agent --repo <path> --task "implement feature"
  cg-agent --repo <path> --task-file task.md

Options:
  --model <id>       default: gemini-3.1-pro-high
  --max-turns <n>    default: 24
  --base-url <url>   default: http://127.0.0.1:18080
  --api-key <key>    default: antigravity

ClaudeGravity must already be running. CG-Agent intentionally does not start or own
the Antigravity engine; the main ClaudeGravity supervisor owns that lifecycle.
`);
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  usage();
  process.exit(0);
}

const root = resolve(args.repo);
if (!existsSync(root)) throw new Error(`Repository path does not exist: ${root}`);

let task = args.task;
if (args.taskFile) task = await readFile(resolve(args.taskFile), 'utf8');
if (!task.trim()) {
  usage();
  throw new Error('Task is required.');
}

function insideRoot(path) {
  const rel = relative(root, path);
  return rel === '' || (!rel.startsWith(`..${sep}`) && rel !== '..');
}

async function safePath(input, allowMissing = false) {
  const abs = resolve(root, input || '.');
  if (!insideRoot(abs)) throw new Error(`Path escapes repository: ${input}`);
  if (!allowMissing) {
    const rp = await realpath(abs);
    if (!insideRoot(rp)) throw new Error(`Symlink escapes repository: ${input}`);
    return rp;
  }
  const parent = await realpath(dirname(abs));
  if (!insideRoot(parent)) throw new Error(`Parent escapes repository: ${input}`);
  return abs;
}

async function ensureProxy() {
  for (let i = 0; i < 4; i++) {
    try {
      const response = await fetch(`${args.baseUrl}/health`, { signal: AbortSignal.timeout(2500) });
      if (response.ok) return;
    } catch {
      // Retry briefly in case the managed supervisor is still starting.
    }
    await new Promise((resolveWait) => setTimeout(resolveWait, 500));
  }

  throw new Error(
    `ClaudeGravity engine is not ready at ${args.baseUrl}. ` +
    'Start ClaudeGravity first and wait until its WebUI reports READY. ' +
    'CG-Agent no longer runs acc/start or creates a second proxy process.'
  );
}

const tools = [
  {
    name: 'read_file',
    description: 'Read a UTF-8 text file inside the repository.',
    input_schema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        start_line: { type: 'integer' },
        end_line: { type: 'integer' },
      },
      required: ['path'],
    },
  },
  {
    name: 'write_file',
    description: 'Create or fully replace a UTF-8 text file inside the repository.',
    input_schema: {
      type: 'object',
      properties: { path: { type: 'string' }, content: { type: 'string' } },
      required: ['path', 'content'],
    },
  },
  {
    name: 'list_files',
    description: 'List files/directories inside a repository path.',
    input_schema: { type: 'object', properties: { path: { type: 'string' } } },
  },
  {
    name: 'search_text',
    description: 'Search text recursively in repository files. Skips .git and common dependency/build directories.',
    input_schema: {
      type: 'object',
      properties: {
        query: { type: 'string' },
        path: { type: 'string' },
        max_results: { type: 'integer' },
      },
      required: ['query'],
    },
  },
  {
    name: 'shell',
    description: 'Run a shell command in the repository root. Use for tests, lint, git diff/status, builds and repository inspection. Do not commit, push, hard-reset or force-clean.',
    input_schema: {
      type: 'object',
      properties: { command: { type: 'string' }, timeout_ms: { type: 'integer' } },
      required: ['command'],
    },
  },
];

async function runTool(name, input) {
  if (name === 'read_file') {
    const p = await safePath(input.path);
    const text = await readFile(p, 'utf8');
    if (!input.start_line && !input.end_line) return text.slice(0, 200000);
    const lines = text.split(/\r?\n/);
    const start = Math.max(1, input.start_line || 1);
    const end = Math.min(lines.length, input.end_line || lines.length);
    return lines.slice(start - 1, end).map((line, i) => `${start + i}: ${line}`).join('\n');
  }

  if (name === 'write_file') {
    const p = await safePath(input.path, true);
    await mkdir(dirname(p), { recursive: true });
    await writeFile(p, input.content, 'utf8');
    return `Wrote ${relative(root, p)} (${Buffer.byteLength(input.content, 'utf8')} bytes)`;
  }

  if (name === 'list_files') {
    const p = await safePath(input.path || '.');
    const entries = await readdir(p, { withFileTypes: true });
    return entries.slice(0, 500).map((entry) => `${entry.isDirectory() ? 'dir ' : 'file'} ${entry.name}`).join('\n');
  }

  if (name === 'search_text') {
    const base = await safePath(input.path || '.');
    const query = String(input.query);
    const max = Math.min(Math.max(Number(input.max_results || 100), 1), 300);
    const skip = new Set(['.git', 'node_modules', 'dist', 'build', '.next', '.venv', 'venv', 'target', 'coverage']);
    const results = [];

    async function walk(dir) {
      if (results.length >= max) return;
      for (const entry of await readdir(dir, { withFileTypes: true })) {
        if (results.length >= max) break;
        if (skip.has(entry.name)) continue;
        const p = resolve(dir, entry.name);
        if (!insideRoot(p)) continue;
        if (entry.isDirectory()) {
          await walk(p);
          continue;
        }
        let text;
        try {
          if ((await stat(p)).size > 2_000_000) continue;
          text = await readFile(p, 'utf8');
        } catch {
          continue;
        }
        const lines = text.split(/\r?\n/);
        for (let i = 0; i < lines.length && results.length < max; i++) {
          if (lines[i].includes(query)) results.push(`${relative(root, p)}:${i + 1}: ${lines[i].slice(0, 500)}`);
        }
      }
    }

    await walk(base);
    return results.join('\n') || 'No matches.';
  }

  if (name === 'shell') {
    const command = String(input.command);
    if (/\bgit\s+(push|commit|reset\s+--hard|clean\s+-[a-zA-Z]*f)/i.test(command)) {
      throw new Error('Blocked destructive/publishing git command. The supervisor owns commit/push/reset/clean.');
    }
    const timeout = Math.min(Math.max(Number(input.timeout_ms || 120000), 1000), 600000);
    try {
      const { stdout, stderr } = await exec(command, {
        cwd: root,
        timeout,
        maxBuffer: 4 * 1024 * 1024,
        windowsHide: true,
      });
      return `${stdout}${stderr ? `\n[stderr]\n${stderr}` : ''}`.slice(0, 300000);
    } catch (error) {
      return `exit/error: ${error.message}\nstdout:\n${error.stdout || ''}\nstderr:\n${error.stderr || ''}`.slice(0, 300000);
    }
  }

  throw new Error(`Unknown tool: ${name}`);
}

async function callModel(messages) {
  const response = await fetch(`${args.baseUrl}/v1/messages`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'anthropic-version': '2023-06-01',
      'x-api-key': args.apiKey,
      authorization: `Bearer ${args.apiKey}`,
    },
    body: JSON.stringify({
      model: args.model,
      max_tokens: 16384,
      system: `You are Gemini acting as an implementation engineer under a Codex supervisor. Work only inside the provided repository. Inspect existing architecture before editing. Use tools to read and modify files and to run relevant tests/lint/typecheck. Keep changes focused on the task. Never commit, push, reset --hard, force-clean, or publish changes. Do not merely describe code: implement it. When finished, summarize changed files and verification results for the supervisor. Repository root: ${root}`,
      messages,
      tools,
    }),
    signal: AbortSignal.timeout(600000),
  });

  const text = await response.text();
  if (!response.ok) throw new Error(`Proxy ${response.status}: ${text.slice(0, 4000)}`);
  return JSON.parse(text);
}

await ensureProxy();
console.error(`[cg-agent] repo=${root}`);
console.error(`[cg-agent] model=${args.model}`);
console.error(`[cg-agent] engine=${args.baseUrl}`);

const messages = [{ role: 'user', content: task }];
let finalText = '';
for (let turn = 1; turn <= args.maxTurns; turn++) {
  console.error(`[cg-agent] turn ${turn}/${args.maxTurns}`);
  const response = await callModel(messages);
  const content = Array.isArray(response.content) ? response.content : [];
  messages.push({ role: 'assistant', content });

  const toolUses = content.filter((block) => block?.type === 'tool_use');
  const texts = content.filter((block) => block?.type === 'text').map((block) => block.text).filter(Boolean);
  if (texts.length) finalText = texts.join('\n');

  if (!toolUses.length) {
    console.log(finalText || JSON.stringify(response, null, 2));
    process.exit(0);
  }

  const results = [];
  for (const toolUse of toolUses) {
    console.error(`[cg-agent] tool ${toolUse.name}`);
    try {
      const result = await runTool(toolUse.name, toolUse.input || {});
      results.push({ type: 'tool_result', tool_use_id: toolUse.id, content: String(result) });
    } catch (error) {
      results.push({ type: 'tool_result', tool_use_id: toolUse.id, is_error: true, content: error.message });
    }
  }
  messages.push({ role: 'user', content: results });
}

throw new Error(`Agent exceeded max turns (${args.maxTurns}).`);
