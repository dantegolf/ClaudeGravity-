---
name: claudegravity-delegate
description: Delegate bounded coding implementation from Codex to the ClaudeGravity Gemini/Claude worker, then independently review its real changes. Use when the user says "delegate to Gemini", "use Gemini", "отдай Gemini", "делегируй Gemini", "делегируй это", or when an isolated implementation task is a good candidate for automatic offload.
---

# ClaudeGravity Delegate

Use ClaudeGravity as an implementation worker. You are the supervisor, planner, and final reviewer.

## User overrides

- If the user explicitly asks to delegate to Gemini/Claude/ClaudeGravity, you must delegate unless the worker is technically unavailable.
- If the user says not to delegate, to do it yourself, or to avoid Gemini/ClaudeGravity, do not use this skill.
- If explicit delegation fails because ClaudeGravity is unavailable, report that fact clearly. Do not pretend delegation happened.

## When to delegate automatically

Prefer delegation for a reasonably bounded implementation unit such as:

- feature implementation after the intended behavior is understood;
- well-defined bug fixes;
- tests and regression coverage;
- repetitive or mechanical refactors;
- boilerplate, migrations, adapters, and serializers;
- implementation of a design that Codex has already decided.

Prefer doing the work yourself when the task is primarily:

- architecture or product/design decisions;
- initial investigation where the root cause is still unknown;
- final code review;
- a tiny edit where delegation adds more overhead than value;
- security-sensitive work, secrets, credentials, destructive operations, or publishing.

## Find the delegate command

Prefer the fixed user shim installed by ClaudeGravity:

- Unix/macOS: `$HOME/.claudegravity/bin/cg-delegate`
- Windows: `%USERPROFILE%\.claudegravity\bin\cg-delegate.cmd`

`cd-delegate` is an equivalent compatibility alias.

If the fixed shim does not exist, try the ClaudeGravity installation launchers directly:

- macOS: `$HOME/Documents/ClaudeGravity/CG-Delegate.sh`
- Linux: `$HOME/ClaudeGravity/CG-Delegate.sh`
- Windows: the `CG-Delegate.cmd` inside the user's Documents `ClaudeGravity` directory.

Do not silently substitute a different third-party agent.

## Delegation procedure

1. Inspect enough of the repository to understand the requested change.
2. Decide the intended behavior, constraints, likely files, and acceptance criteria yourself.
3. Preserve any pre-existing user changes. Inspect `git status --short` before delegation.
4. Write a precise task file for the worker. Prefer a temporary task file over a long shell-quoted `--task` string.
5. Invoke the delegate with the current repository path and the task file.
6. Do not trust the worker's summary as evidence of correctness.
7. Independently inspect `git status --short`, `git diff --check`, and the complete relevant `git diff`.
8. Independently run the appropriate tests, lint, typecheck, and/or build.
9. Review scope, architecture, error handling, regressions, and unintended edits.
10. If there are concrete problems, delegate a focused repair task containing the reviewer findings. Normally use at most two repair rounds unless the user asks otherwise.
11. You are responsible for final acceptance and the user-facing summary.

## Worker task format

Give the worker a task with this structure when practical:

```text
TASK
<one concrete implementation objective>

CONTEXT
<relevant architecture, files, current behavior>

REQUIREMENTS
1. <required behavior>
2. <required tests or verification>
3. Preserve existing public behavior unless explicitly changed.

CONSTRAINTS
- Keep the change focused.
- Preserve unrelated user changes.
- Do not commit, push, publish, reset --hard, or force-clean.
- Do not redesign unrelated code.

VERIFICATION
<commands or checks the worker should run>

RETURN
Summarize changed files, implementation choices, and checks executed.
```

## Invocation examples

Unix/macOS:

```bash
TASK_FILE="$(mktemp)"
cat > "$TASK_FILE" <<'EOF'
<task specification>
EOF
"$HOME/.claudegravity/bin/cg-delegate" --repo "$PWD" --task-file "$TASK_FILE"
rm -f "$TASK_FILE"
```

Windows PowerShell:

```powershell
$TaskFile = Join-Path $env:TEMP "claudegravity-task.md"
@'
<task specification>
'@ | Set-Content -LiteralPath $TaskFile -Encoding UTF8
& "$env:USERPROFILE\.claudegravity\bin\cg-delegate.cmd" --repo (Get-Location).Path --task-file $TaskFile
Remove-Item -LiteralPath $TaskFile -Force -ErrorAction SilentlyContinue
```

If the user specifies a worker model, pass `--model <id>`. Otherwise use the ClaudeGravity worker default.

## Review contract

The worker edits the working tree; the working tree is the handoff state. Treat the actual files and git diff as authoritative, not the model's prose report.

Never ask the worker to commit or push. Do not let worker output replace your own final review.
