# P0 Lockdown Batch Implementation Plan (T2–T5)

Branch: `task1-vendor-open-rpg` (worktree `.worktrees/game-impl`). Baseline: T1 rarity model landed at `fee0cf7` (329 unit + 6 integration green).

## Global Constraints (bind every task)

- ASCII identifiers, JSON keys, test names, commit messages; Chinese only in `name_zh`/narrative fields.
- TDD: failing test first, then minimal implementation. Verify with:
  `$env:GODOT_CONSOLE_PATH='C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'; powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all`
  Full suite must stay green: currently 329 unit + 6 integration.
- Domain purity: no RNG outside seeded salts derived from `RunState.seed` + event position; UI never mutates state; state changes go through immutable `RunState.append_event` (new fields MUST be added to `_apply_after` whitelist, `_copy`, and `to_save_data`).
- Do not touch `vendor/`. Do not push. Small focused commits (`feat:`/`test:`/`docs:`).
- Spec refs are from `docs/superpowers/specs/2026-08-25-mechanics-first-lockdown-design.md`.
- Known deferral (not a task gap): spec R13.1 clause "精英与突破节点必掉史诗及以上" requires loot redesign and is scheduled with P1⑪ 精英奖励代价绑定 — do not implement here.

## Task 2: Rare pity counter (spec R13.1)

1. `RunState`: add `loot_pity: int = 0`; wire into `to_save_data`, `_copy`, `_apply_after` whitelist.
2. `LootResolver._roll_gu`: a gu drop roll that passes the chance gate counts as one adventure drop.
   - Before the rarity roll: if `state.loot_pity >= 3`, force rarity roll over non-common buckets only (weights renormalized; salt `"loot.gu.rarity.forced.<tier>"`).
   - After producing a gu: rarity ≥ rare → pity resets to 0; common → pity + 1. New pity value rides the loot event's `after` payload (`"loot_pity"` key) so replays reproduce it.
3. Chance-gate failures and shop purchases never touch the counter (shop purchases are fixed offers today — document in code comment).
4. Tests (`tests/unit/test_loot_pity.gd`): forced rare+ on 4th consecutive common drop across distinct seeds; reset on rare+; counter persisted through save/load round-trip; determinism (same seed → same sequence).

## Task 3: Backlash curse system (spec R9.1–R9.6, R5.15)

1. New `data/curse.json`: entries `{id, name_zh, effect kind (draw_pollution | essence_surcharge | slot_seal), base_intensity, escalation_per_stage}`. Catalog loads as `curse_by_id`; validate kinds/integers/references.
2. `RunState.cultivator.statuses`: curses stored as `{curse_id: {"layers": int, "source": str}}`. Add helper accessors on RunState or a small `scripts/domain/curse_registry.gd` (pure functions): gain_curse / remove_curse / intensity(state, curse) where intensity scales with cultivation stage (R9.5).
3. Battle integration in `battle_resolver`: draw pollution removes N cards from next draw; essence surcharge adds cost to played cards; slot seal disables one equipped gu for the battle. Curse damage uses a new `channel` parameter on `_strike(battle, amount, channel)` — channel `"curse"` bypasses shield and writes health directly (R5.15). Death via curse must route through the existing terminal flow so the death cause reads backlash (R2.3).
4. Entry points (all player-opt-in, R9.6): new resolver command effects usable by `events.json` outcomes and `shops.json` offers — `gain_curse` (with explicit precheck text), plus free-mix failure outcome may attach a configured curse (R10.2). Removal command `remove_curse` costs stone via existing `price_for` escalation (R9.3).
5. Every gain/removal writes an immutable event with before/after statuses.
6. Tests (`tests/unit/test_curse_system.gd`): gain/remove round-trip; escalation by stage; curse damage ignores shield; death cause attribution; event-log writes; removal cost charged.

## Task 4: Imprint (relic hook) expansion (spec R4.8, R4.9, R11.7, §16.19 synergy)

1. Extend `RelicHookResolver.TRIGGERS` with `"on_backlash_gained"` and `"on_battle_end"`; extend `EFFECT_KINDS` with `"convert_backlash_to_draw"`, `"reduce_curse_intensity"`, `"grant_stone_on_battle_end"`. Wire the two new triggers inside `battle_resolver`/`resolver` paths that already emit backlash/battle-end events.
2. Imprint slots: `deck.json` gains `"imprint_capacity": 4`; `ContentCatalog.validate` requires positive integer. `_gain_relic` rejects beyond capacity with reason `imprint_capacity_exceeded` (R4.9).
3. Meta-grade imprints: relic field `"grade": "meta_rule"` (absent = normal). Gaining a meta-grade relic when two already exist is rejected with reason `meta_rule_cap_reached`; gained ones are recorded into a new `RunState.meta_rules: Dictionary` (whitelist/copy/save wiring like Task 2) and surface a result feed string (top-bar visibility lands with contracts later).
4. Codex: gaining any relic already records codex? If not present, add relic id to `MetaProgress.relic_codex_ids` on gain (encounter-unlock aligns R11.7).
5. Tests (`tests/unit/test_imprint_expansion.gd`): new triggers fire exactly once per event; capacity rejection; meta cap rejection; meta_rules persistence; catalog validation of grade values.

## Task 5: Dual removal channels (spec R4.3, R6.8, R8.1, §16.15)

1. `deck.json` gains `"service_limits": {"remove_card": 2, "remove_imprint": 2, "remove_curse": 2}` (validated positive ints). Per-run usage counters live in `RunState.node_flags` keys `svc_used_<service>`.
2. New resolver commands: `remove_card` (destroy one gu instance + its cards), `remove_imprint` (drop one non-meta relic), `remove_curse` (already added in Task 3 — reuse; ensure pricing shares the same limit pool). Price = base × M5 escalation via `price_for`-style uplift keyed by usage count (R6.8); reject beyond limits with `service_limit_exceeded`.
3. Rest node: rest command accepts optional `"mode"`: heal (existing behavior) OR removal request carrying target id. One mode per rest visit (node_flag `rest_mode_used`). Removal at rest is free but consumes the visit (opportunity cost, R8.1).
4. `can_direct_drop` guard: gu definitions may carry `"can_direct_drop": false`; `_destroy_gu` on such a gu is rejected with reason `cursed_gu_not_directly_droppable` and instead appends a backlash event (small notoriety or curse layer) — never silent (§16.15).
5. Presentation: `display_text.gd` strings distinguishing 【移除】 vs 【池排除】 wording.
6. Tests (`tests/unit/test_removal_channels.gd`): each channel removes its object type; price escalation and caps; rest mutual exclusion; can_direct_drop guard fires negative consequence; all events logged.

## Final review

Whole-branch review against lockdown spec Part 1 rules R4/R5/R9/R13 + §16.16/16.19 constraints, using Minor-findings ledger accumulated during task reviews.
