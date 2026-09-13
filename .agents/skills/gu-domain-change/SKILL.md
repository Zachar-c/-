---
name: gu-domain-change
description: Implement or revise Gu Lu Qiu Sheng domain rules, battle, map, economy, persistence, or ending behavior while preserving deterministic RunState transitions and explicit costs.
---

# Gu Domain Change

Use this skill for changes under `scripts/domain/`, or when presentation code needs a new game command. Read `AGENTS.md`, the relevant existing resolver/tests before editing. Authority is split by topic: gu, economy, combat, and synthesis follow `docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`; other mechanisms follow `docs/superpowers/specs/2026-08-25-mechanics-first-lockdown-design.md`; the older smoke design is reference only.

## Preserve The Domain Boundary

- Treat the current `RunState` as the single owner of per-run state. Rebuild it for a new run; do not introduce presentation-owned or scattered mutable gameplay state.
- Keep rules in pure, testable GDScript. UI components read snapshots and submit commands through the controller; they do not mutate gameplay state directly.
- Return a new state through the established `append_event` flow. Event entries must remain immutable after append, including nested dictionaries or arrays that could be shared with later state.
- Record every material state transition with ASCII `action`, `reason`, source, before/after facts, and targets as the surrounding resolver does. Build ending journal claims only from the log and player-known facts.
- Preserve command replay protection based on the event-log state version.

## Mechanics Guardrails

- Apply conflicts in this order: contracts, per-run meta rules, DDA, gu/card effects, enemy AI. Do not add a shortcut that bypasses an earlier layer.
- Every roll must be deterministic from the run seed and stable inputs. Follow the existing seeded-RNG conventions; do not call ambient randomness or use wall-clock state.
- Keep per-run goods, deck, resources, and temporary state out of hall persistence. Codex/recipe discovery is the narrow, explicit cross-run exception.
- A command that spends lifespan, soul, or causes backlash must preflight the exact consequence before mutation. It must reject safely or expose the declared lethal risk; never silently kill a player.
- Do not create implicit morality rewards, free power, read-back/rollback paths, or cross-run combat growth. Strong effects carry visible, commensurate costs.
- Keep curse damage separate from ordinary shieldable damage where existing rules require the direct health channel.

## Change Loop

1. Locate the closest resolver, catalog validation, and GUT tests. State the invariant that the new behavior must preserve.
2. Add or adjust the smallest focused GUT test first. Cover success, rejection without mutation, event attribution, determinism when a roll is involved, and a relevant boundary case.
3. Implement the smallest domain change. Reuse catalog data and existing resolver helpers rather than encoding game balance in presentation code.
4. Run the focused test with `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test <test-path>`.
5. Run the affected suite (`-Suite unit` or `-Suite integration`). For changes touching lifecycle, serialization, journal, or shared resolver behavior, run `powershell -ExecutionPolicy Bypass -File tools/check.ps1`.
6. Review `git diff --check` and inspect only the intended files. Keep unrelated UI worktree changes intact.

## Current Codebase Notes

- `ContentCatalog.load_all()` and `ContentCatalog.validate(...)` are the catalog boundary; data-backed features need validation coverage.
- The current codebase uses `RunState`; design documentation may call its intended successor `RunData`. Do not rename or migrate it incidentally.
- Existing randomness is derived from seed, event-log length, and an action-specific salt. Preserve stable ordering so a harmless refactor does not alter a seeded run.
- A planned centralized `PoolManager` is not a license to create parallel pool logic. Extend the established resolver/catalog path until that migration is explicitly designed.

