# Codex + CG-Agent

CG-Agent is an optional Gemini implementation worker that uses the Antigravity engine already managed by ClaudeGravity.

Before running it, start ClaudeGravity normally and wait until the WebUI reports `READY`. CG-Agent connects to the managed loopback engine at `http://127.0.0.1:18080`; it does not start a second `acc` proxy.

Example:

```bash
~/ClaudeGravity/CG-Agent.sh --repo "$PWD" --task-file /tmp/gemini-task.md
```

On macOS the default ClaudeGravity directory is under `~/Documents/ClaudeGravity`.

On Windows:

```powershell
& "$HOME\Documents\ClaudeGravity\CG-Agent.cmd" --repo "$PWD" --task-file "$env:TEMP\gemini-task.md"
```

Rules for the supervisor:

- Write a concrete implementation task with acceptance criteria.
- Let Gemini inspect and modify the repository through CG-Agent.
- Never trust the worker's success report by itself.
- After CG-Agent finishes, independently inspect `git diff` and `git status`.
- Run the relevant tests, lint, typecheck and build yourself.
- If review fails, send a narrower remediation task to CG-Agent.
- The Gemini worker must not commit, push, hard-reset, force-clean or publish changes.
