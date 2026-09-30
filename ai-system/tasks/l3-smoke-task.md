# L3 smoke task (low-value)

STATUS READY_FOR_REVIEW
TYPE content

GOAL
Prove the L3 auto-fallback dispatcher can hand a bounded low-value task to a cheap local worker without manual prompt copy.

SCOPE
- Work only under `ai-system/tasks/`.
- Create or overwrite `ai-system/tasks/l3-smoke-result.md`.
- Do not touch product code, Wiki, game data, secrets, or Git.

ACCEPTANCE
1. `l3-smoke-result.md` exists.
2. It contains a single line beginning with `L3_SMOKE_OK`.
3. The line includes the model slot actually used (for example `mimo-v2.6-flash`).
4. No other repository files change.

RETURN
Follow `WORKER_HANDOFF_TEMPLATE.md` in short form. If acceptance cannot be met, report BLOCKED with the exact reason.
