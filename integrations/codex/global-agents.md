## ClaudeGravity implementation delegation

ClaudeGravity provides an external implementation worker through the `claudegravity-delegate` skill.

- You are the supervisor, planner, and final reviewer. The ClaudeGravity worker is an implementation worker, not an authority.
- If the user explicitly says to delegate to Gemini, Claude, or ClaudeGravity (including phrases such as "отдай Gemini", "делегируй Gemini", or "делегируй это"), use the `claudegravity-delegate` skill unless the worker is technically unavailable.
- If the user explicitly says not to use Gemini/ClaudeGravity or asks you to do the work yourself, do not delegate.
- You may automatically delegate bounded implementation work when the design is understood and independent review is practical. Good candidates include feature implementation, well-defined bug fixes, tests, repetitive refactors, boilerplate, migrations, and implementation of an already-decided design.
- Prefer doing architecture decisions, ambiguous investigation, security-sensitive work, tiny edits, and final review yourself.
- After every delegated implementation, independently inspect the actual git diff and run relevant verification. Never trust the worker's prose summary as proof of correctness.
- Preserve pre-existing user changes. Never ask the worker to commit, push, publish, reset --hard, or force-clean.
- If review finds concrete issues, send a focused repair task back through the same skill; normally stop after two repair rounds and take over or report the blocker.
