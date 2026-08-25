# Task 3 Brief: Backlash Curse System (反噬系统)

You are implementing Task 3 of the P0 lockdown batch in a Godot 4.7.2 / GDScript card roguelike. Branch `task1-vendor-open-rpg`, worktree root is your working directory.

## Global Constraints (binding)

- ASCII identifiers, JSON keys, test names, commit messages; Chinese only in `name_zh`/narrative fields.
- TDD: failing test first, then minimal implementation.
- Verify: `$env:GODOT_CONSOLE_PATH='C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'; powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all`
- Full suite must stay green: baseline is 336 unit + 6 integration (plus your new tests).
- Domain purity: no RNG outside seeded salts derived from `RunState.seed` (follow the `_pick_from`/`roll_chance` salt patterns); UI never mutates state; state changes go through immutable `RunState.append_event`.
- New RunState-persisted data MUST be wired into `_apply_after` whitelist, `_copy`, AND `to_save_data`.
- Do not touch `vendor/`. Do not push. Commit style: `feat:` concise body.
- Spec rules implemented here: R9.1 four entry points (this task wires event-cost + free-mix failure + a reusable command; elite-reward attachment lands with P1⑪), R9.2 effects disturb combat logic not raw damage, R9.3 removal channel exists with explicit cost, R9.5 intensity escalates by cultivation stage, R9.6 all gains are player-opt-in with precheck text, R5.15 curse damage bypasses shield, R2.3 precise death cause.
- Deferral note: "elite guaranteed epic" and elite-reward curse attachment are P1⑪ — do not implement.

## Requirements

1. **Data table** `data/curse.json`: array of entries
   `{ "id": str, "name_zh": str, "effect": "draw_pollution" | "essence_surcharge" | "slot_seal", "base_intensity": int >= 1, "escalation_per_stage": int >= 0 }`
   Ship 3 entries covering all three effect kinds (ids like `gu_erosion`, `essence_bloat`, `meridian_seal`; name_zh 如 蛊蚀/元石滞胀/经脉封蛊 — you choose tasteful names). `ContentCatalog.load_all` exposes `curse_by_id`; `validate` rejects unknown effect kinds, non-int intensity/escalation, missing fields.
2. **Registry** `scripts/domain/curse_registry.gd` (pure static functions, no RNG):
   - `gain_curse(state, curse_id, source) -> RunState` — appends event (`action: "curse_gained"`), stores into `state.cultivator.statuses[curse_id] = {"layers": n, "source": source}` (layers start 1).
   - `remove_curse(state, curse_id) -> RunState` — event `action: "curse_removed"`, erases entry. Full removal only (no partial de-layering).
   - `intensity(state, curse) -> int` — `(base_intensity + escalation_per_stage * (stage_index)) * layers`, where stage_index derives from existing cultivation/stage mapping (read how resolver maps stage strings one..five to indexes; reuse that ordering).
   - Statuses dict shape must survive save/load (statuses already persists via cultivator dict — verify round-trip in tests).
3. **Battle integration** in `scripts/domain/battle_resolver.gd`:
   - At battle start (`start`) compute active curses from `state.cultivator.statuses` into the battle dict (e.g., `battle["curses"]`).
   - `draw_pollution`: before the player's draw each turn, remove `min(intensity, draw_count)` cards from the top of the draw pile into a banished list on the battle dict (they do not reach hand this turn); log via result feed string.
   - `essence_surcharge`: playing a card costs +1 essence per intensity point beyond a free allowance of 2 (i.e., intensity > 2 adds `intensity - 2` extra cost); if the player cannot pay, reject the play with an existing rejection path.
   - `slot_seal`: the highest-index equipped gu is disabled for the whole battle (reuse whatever mechanism `_disable_card`/disabled flags use if present; otherwise mark it unplayable in the hand-building step).
   - **Dual-channel damage**: change `_strike(battle, amount)` to `_strike(battle, amount, channel := "attack")`. Channel `"attack"` keeps current shield-absorption behavior exactly. Channel `"curse"` ignores shield entirely and writes health directly. Route at least one curse-driven damage path through `"curse"` (e.g., draw_pollution also deals `intensity` damage via curse channel at end of player turn — pick ONE concrete rule and document it in the code). Death through this path must produce the same terminal handling as existing death so the death cause reads as backlash (verify via existing `_depleted`/finalize flow).
4. **Entry points**:
   - New resolver commands in `scripts/domain/resolver.gd::apply`: `{type: "gain_curse", curse_id, source}` and `{type: "remove_curse", curse_id}`. `remove_curse` charges stone using the existing M5 uplift pattern (`price_for`) with base price from curse.json field `removal_base_cost` (add it, int >= 1); insufficient stone → rejected `insufficient_stone`.
   - Free-mix failure (`resolver._apply_free_mix` failure branch): when configured, attach a designated curse instead of/in addition to current junk outcome — extend `refinement_recipes.json` failure payload shape minimally (e.g., optional `"fail_curse_id"`), validate reference exists.
   - One `events.json` outcome option may call gain_curse — extend the events schema the same minimal way (optional `curse_id` on a reward), validate reference.
5. Every gain/removal writes an immutable event with before/after statuses snapshot (follow existing `_event` helper style in resolver).

## Interfaces / facts you need

- `RunState.cultivator["statuses"]` already exists (empty dict today) and persists inside the cultivator dict — you do NOT need new whitelist keys for it, but verify save/load round-trip explicitly in a test.
- `battle_resolver._register_duration_effect` / `_expire_effects(tick_phase)` show the established pattern for battle-scoped timed effects; curses are run-scoped (persist across battles) so they live in RunState, and battles only project them.
- `_strike` currently absorbs damage via a shield value on the battle dict — read its body before changing the signature; default parameter keeps all existing callers compiling.
- Stage ordering: `run_state.stage` holds strings ("one"..."five"); resolver has rank/cultivation transitions — find and reuse the canonical ordering rather than inventing one.
- Rejection paths: follow `_rejected(state, reason)` / `_result(...)` conventions.
- Task 1/2 context: rarity fields exist on gu/cards/relics; pity counter lives in `loot_pity` — unrelated to your task but do not break them.

## Ambiguity resolutions (binding)

- Curses persist across battles until removed (run-scoped), matching spec R9.3's "challenge for the run".
- Only ONE concrete curse-damage rule is required now (draw_pollution dealing intensity damage via curse channel is the suggested default).
- No UI work, no settlement-statistics work in this task; result feed strings are enough.
- If you find `_strike` signature change ripples wider than battle_resolver internals, adapt callers minimally rather than redesigning.

## Report contract

Write your full report to `.superpowers/sdd/task-3-report.md` (scope, files touched, test names, verification commands + tail output, self-review findings including any deviation you had to make). Return ONLY: status (DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED), commit hash(es), one-line test summary, concerns if any.
