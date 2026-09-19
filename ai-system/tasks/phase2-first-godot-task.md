# Phase 2 / First Real Godot Worker Task

## Task

Remove the redundant full content-catalog parse that occurs when a normal run is started after the controller has already initialized its catalog.

## Why this task was selected

`game/scripts/presentation/run_controller.gd` currently loads and validates the catalog during `_initialize_view_flow()`, then calls `ContentCatalog.load_and_validate_all()` again in both `start_new_run()` and `start_m0_run()`. This is a concrete, bounded performance defect: opening a new run reparses the large content tables even though the controller already owns the validated catalog.

The task does not require a design decision, new gameplay rules, data rebalance, UI redesign, save-format change, or large refactor. It is suitable for the first Worker comparison because it requires code reading, lifecycle reasoning, a regression test, and focused Godot verification.

## Scope

In scope:

- `game/scripts/presentation/run_controller.gd`
- One focused regression test under `game/tests/unit/`
- Any minimal test-only support needed to prove the catalog reuse/fallback behavior

Out of scope:

- `game/data/`
- save schema or serialization
- route generation rules
- UI changes
- `ContentCatalog` redesign or caching framework
- unrelated existing working-tree changes

## Required behavior

1. A controller with a catalog already loaded during initialization must reuse that catalog when starting a normal run and when starting M0.
2. A controller created by a headless test/tool without initialization must still load the catalog before starting a run.
3. Catalog validation must still happen before a run is accepted; invalid content must preserve the existing content-error behavior.
4. Existing run initialization behavior must remain unchanged: state, route, school/buff/contract setup, and M0 setup still work.
5. Do not add a general cache, router, new abstraction layer, or timing/benchmark framework.

## Acceptance

- Add a regression assertion that distinguishes reuse from a second load (for example, a preloaded catalog marker remains available after `start_new_run()` / `start_m0_run()` while the empty-catalog fallback still loads).
- Run the focused regression test.
- Run the relevant existing controller/run tests.
- Run the full unit suite if the repository test entrypoint is available.
- Inspect the final diff and confirm only the stated scope changed.

## Execution rules

- Worker class: `normal`.
- Work in the dedicated Phase 2 worktree.
- Protect unrelated user changes.
- Do not commit or push.
- Return the Worker Protocol summary with files changed, tests run, result, and remaining risk.
