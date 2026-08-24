# Codex → ClaudeGravity delegation

ClaudeGravity can be used as an implementation worker under Codex. Codex remains the planner, supervisor, and final reviewer; Gemini/Claude performs bounded implementation work through `CG-Agent`.

## Installation

Install normal ClaudeGravity first and wait for `READY`, then install the developer worker integration.

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-cg-agent.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-cg-agent.ps1 | iex
```

The installer adds:

- `CG-Agent` — low-level implementation worker;
- `CG-Delegate` — supervisor-oriented wrapper around the worker;
- `CD-Delegate` — compatibility alias;
- `~/.claudegravity/bin/cg-delegate` and `cd-delegate` stable user shims;
- global Codex delegation instructions in the effective `$CODEX_HOME/AGENTS.md` or `AGENTS.override.md`;
- the global `claudegravity-delegate` Codex skill under `~/.agents/skills/`.

The global AGENTS integration is idempotent. ClaudeGravity maintains only the block between its HTML markers and preserves unrelated user instructions.

If Codex does not show the skill immediately after installation, restart Codex.

## Usage from Codex

You can delegate explicitly:

```text
Отдай Gemini реализацию этой задачи, сам потом проверь diff и тесты.
```

```text
Делегируй это ClaudeGravity.
```

```text
Use Gemini for the implementation and review its work yourself.
```

You can also ask Codex to choose automatically:

```text
Разберись с задачей. Хорошо изолированные implementation-части можешь делегировать Gemini, финальный review сделай сам.
```

And you can disable delegation for a task:

```text
Сделай сам, Gemini не используй.
```

The skill may also be invoked explicitly as `$claudegravity-delegate` in Codex environments that expose skill selection.

## Direct command

The normal stable command installed for Codex is:

macOS / Linux:

```bash
~/.claudegravity/bin/cg-delegate --repo /path/to/project --task "Implement the requested change"
```

Windows:

```powershell
& "$env:USERPROFILE\.claudegravity\bin\cg-delegate.cmd" --repo C:\Projects\app --task "Implement the requested change"
```

`cd-delegate` is the same command under a compatibility alias.

For non-trivial tasks prefer `--task-file` so Codex can give the worker a structured specification without shell-quoting problems.

## Supervisor contract

`cg-delegate` does not approve the worker's result. It:

1. records pre-existing `git status --short` so unrelated user work is visible;
2. runs the existing `cg-agent` worker;
3. prints current `git status --short`;
4. prints `git diff --stat`;
5. runs `git diff --check`;
6. prints `REVIEW_REQUIRED` and hands control back to Codex.

Codex is then expected to inspect the complete relevant diff and independently run tests, lint, typecheck, and/or build. If review finds concrete issues, Codex can send a focused repair task through the same delegate, normally for no more than two repair rounds.

The worker must not commit, push, publish, hard-reset, or force-clean. Final acceptance stays with Codex or the developer.
