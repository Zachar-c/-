# Task 4 Brief: Imprint (Relic Hook) Expansion (印记层扩展)

You are implementing Task 4 of the P0 lockdown batch in a Godot 4.7.2 / GDScript card roguelike. Branch `p0-batch-continuation`, worktree root is your working directory.

## Global Constraints (binding)

- ASCII identifiers, JSON keys, test names, commit messages; Chinese only in `name_zh`/narrative fields.
- TDD: failing test first, then minimal implementation.
- Verify: `$env:GODOT_CONSOLE_PATH='C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'; powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all`
- Baseline in this worktree: 353 unit + 6 integration green — must stay green plus your new tests.
- Domain purity: no RNG outside seeded salts derived from `RunState.seed`; UI never mutates state; state changes go through immutable `RunState.append_event`.
- New top-level RunState fields MUST be wired into `_apply_after` whitelist, `_copy`, AND `to_save_data`.
- Do not touch `vendor/`. Do not push. Commit style: `feat:` concise body.

## Requirements

1. **Extend hook enums** in `scripts/domain/relic_hook_resolver.gd`:
   - `TRIGGERS` += `"on_backlash_gained"`, `"on_battle_end"`
   - `EFFECT_KINDS` += `"convert_backlash_to_draw"` (next turn draws +amount when a curse layer is gained mid-battle), `"reduce_curse_intensity"` (curse intensity reduced by amount, floor 0, at battle start), `"grant_stone_on_battle_end"` (state.stone += amount once, appended as immutable event).
   - Wire the two new triggers where those moments are already handled: backlash gain moment = wherever `curse_registry.gain_curse` result becomes known during battle projection / battle dict update; battle end moment = the victory/retreat/death finalization path in `battle_resolver` (`_victory_with_loot`, `_retreat`, terminal handling). Follow the existing resolver function style (`apply_*` returning dicts with feeds).
2. **Imprint slots**: `data/deck.json` gains `"imprint_capacity": 4`. `ContentCatalog.validate` requires positive integer (mirror the existing `deck.capacity` check). `resolver._gain_relic` rejects beyond capacity with reason `imprint_capacity_exceeded` and no state change (R4.9 取舍压力).
3. **Meta-grade imprints** (R4.8 一局 ≤2): relics may carry `"grade": "meta_rule"` (absent = normal). Gaining a meta-grade relic when two already exist → reject with reason `meta_rule_cap_reached`. Gained meta-grade relics are recorded into a new `RunState.meta_rules: Dictionary` (`{relic_id: true}`), wired into whitelist/copy/save like other fields, plus a result feed string `meta_rule_recorded`.
4. **Codex alignment (R11.7 遭遇即解锁)**: `MetaProgress` gains `relic_codex_ids: Array[String]`; `record_run_end` scans the run event log for relic-gain reasons (same pattern as recipe unlocks) and appends them; save/load of MetaProgress carries the new array (check its serialize/load functions and wire symmetrically).
5. `data/relics.json`: mark ONE existing relic as `"grade": "meta_rule"` (pick the one whose effect most reads like a rule change) so the cap path is exercisable with real data; ensure catalog validation accepts absent grade but rejects unknown grade strings.
6. Tests in NEW file `tests/unit/test_imprint_expansion.gd`:
   - New triggers fire exactly once per corresponding event (use seeded battles; assert draw/stone deltas and feed strings).
   - Capacity rejection leaves state untouched (event log length unchanged).
   - Meta cap: gaining two meta-grade relics ok, third rejected.
   - `meta_rules` persists through save/load round-trip.
   - Catalog validation: bad grade string → error; missing imprint_capacity → error.

## Interfaces / facts you need

- Task 3 landed the curse system: `data/curse.json`, `scripts/domain/curse_registry.gd` (`gain_curse/remove_curse/intensity`), battle start projects curses into `battle["curses"]`, `_strike(battle, amount, channel := "attack")` with `"curse"` bypassing shield, draw_pollution/essence_surcharge/slot_seal effects live in `battle_resolver`.
- Task 1: `ContentCatalog.RARITY_IDS` exists; relics already validate hooks against the two enums you are extending (existing checks auto-cover new values).
- `RunState.relic_ids: Array[String]` is the owned-imprints list; `resolver._gain_relic(state, command, catalog)` is the single acquisition gate — read it before adding capacity/meta logic.
- `MetaProgress` lives in `scripts/domain/meta_progress.gd` with `_copy`, save/load helpers — follow its existing codex-array patterns exactly.
- Rejection paths: `resolver._rejected(state, reason)`; feeds: `result_feed.gd` string constants style.

## Ambiguity resolutions (binding)

- "Backlash gained" trigger fires per curse-layer gained during an active battle only (run-scoped gains outside battle do not fire hooks).
- If both a normal and meta-grade relic would exceed their respective limits simultaneously, capacity rejection wins first (single rejection reason, checked in order: capacity → meta cap).
- Do NOT add UI/top-bar rendering; feed strings suffice. Do NOT touch contracts/DDA (later batches).

## Report contract

Write your full report to `.superpowers/sdd/task-4-report.md` (scope, files touched, test names, verification commands + tail output, self-review findings). Return ONLY: status (DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED), commit hash(es), one-line test summary, concerns if any.
