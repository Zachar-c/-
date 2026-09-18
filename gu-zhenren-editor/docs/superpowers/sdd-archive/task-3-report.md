# Task 3 Report: Backlash Curse System (反噬系统, P0)

**Status: DONE_WITH_CONCERNS** (concern = shared-worktree concurrency, details below; task scope itself complete and verified)
**Commit: `88efecc`** on `task1-vendor-open-rpg` (not pushed)

## Scope implemented

Spec rules covered per brief: R9.1 entry points (event-cost + free-mix failure + reusable commands; elite-reward attachment deferred to P1⑪ as instructed), R9.2 effects-disturb-combat, R9.3 paid removal channel with explicit cost, R9.5 stage escalation, R9.6 opt-in gains via accept-event/free-mix, R5.15 curse damage bypasses shield, R2.3 precise death cause.

1. **Data table** `data/curse.json` — 3 entries covering all effect kinds:
   - `gu_erosion` 蛊蚀 / draw_pollution / intensity 1+1/stage / removal 6
   - `essence_bloat` 元石滞胀 / essence_surcharge / intensity 2+1/stage / removal 5
   - `meridian_seal` 经脉封蛊 / slot_seal / intensity 1+0/stage / removal 8
2. **Registry** `scripts/domain/curse_registry.gd` — pure static, zero RNG:
   - `gain_curse(state, curse_id, source)` → event `action:"curse_gained"`, statuses[curse_id]={"layers","source"} (layers start 1, stack on repeat; first source wins)
   - `remove_curse(state, curse_id)` → event `action:"curse_removed"`, full removal only
   - `intensity(state, curse)` = `(base + escalation * stage_index) * layers`
   - `project_battle_curses`, `total_intensity(projections, effect)`, `essence_surcharge(projections)` (free allowance 2), `sealed_definition_ids`
3. **Battle integration** `battle_resolver.gd`:
   - `start` projects run-scoped curses into `battle["curses"]`; new keys `banished_cards`, `pending_curse_damage`, `sealed_gu_definition_ids`, `sealed_gu_instance_ids`.
   - draw_pollution: at end of player turn banishes `min(intensity, pile)` top cards before the refill-draw; they never reach hand.
   - essence_surcharge: `+max(0, intensity-2)` on every play (`_use_gu`, so card plays included); unpaid play hits existing feed-based rejection.
   - slot_seal: highest-index equipped gu's cards filtered from deck_cache/draw_pile/hand for the whole battle; also removed from `available_gu_ids`.
   - **Dual-channel**: `_strike(battle, amount, channel := "attack")`. `"attack"` byte-for-byte preserves old behavior (all existing callers compile unchanged). `"curse"` accumulates `pending_curse_damage`, settled by `_settle_curse_damage` straight onto `state.health` bypassing guarded/dodging/intel (R5.15). The ONE concrete damage rule (documented in code): draw_pollution deals its combined intensity via curse channel each end-of-player-turn.
   - Death through curse channel uses identical terminal handling (`finalize_death()`, result "death", feed "player_dead"); cause attributed via `final_blow.id="backlash_curse"` + event reason `backlash_curse_damage`.
4. **Entry points** `resolver.gd`:
   - Commands `{type:"gain_curse", curse_id, source}` (rejects `unknown_curse`) and `{type:"remove_curse", curse_id}` (rejects `unknown_curse`/`curse_not_present`/`insufficient_stone`; charges `price_for(catalog, state, removal_base_cost)` M5 uplift; stone payment event `curse_removal_paid` then registry event).
   - Free-mix failure: optional outcome payload `fail_curse_id`; attached to junk outcomes (effect != mutate_to) as source `free_mix_failure:<outcome_id>`. Shipped configured on `free_mix.destroyed`.
   - Events: optional `curse_id` on an event entry; `_accept_event` attaches it (source `event:<id>`). Shipped new unused event `gu_rot_pact`.
5. **Catalog** `content_catalog.gd`: loads `curse.json` into `curses`/`curse_by_id`; validation rejects missing id/name_zh/effect, unknown effect kinds, non-int or <1 base_intensity, non-int or <0 escalation_per_stage, non-int or <1 removal_base_cost, recipe `fail_curse_id` and event `curse_id` references to unknown curses.

## Files touched (commit 88efecc)

- `data/curse.json` (new), `data/events.json`, `data/refinement_recipes.json`
- `scripts/domain/curse_registry.gd` (new), `scripts/domain/battle_resolver.gd`, `scripts/domain/content_catalog.gd`, `scripts/domain/resolver.gd`
- `tests/unit/test_curse_system.gd` (new, 17 tests)

## Test names

test_curse_table_ships_three_entries_covering_all_effect_kinds, test_curse_validation_rejects_unknown_effect_and_bad_numbers, test_validation_flags_recipe_and_event_references_to_missing_curses, test_gain_curse_stores_layers_source_and_snapshot_event, test_remove_curse_erases_entry_and_writes_snapshot_event, test_intensity_scales_by_stage_index_and_layers, test_statuses_survive_save_round_trip, test_gain_curse_command_validates_known_curse, test_remove_curse_command_charges_price_and_rejects_shortfalls, test_remove_curse_command_applies_notoriety_uplift_to_price, test_draw_pollution_banishes_cards_before_draw_and_deals_backlash_damage, test_backlash_curse_damage_kills_through_terminal_flow_as_backlash, test_essence_surcharge_adds_extra_cost_beyond_free_allowance_of_two, test_low_intensity_essence_surcharge_stays_within_free_allowance, test_slot_seal_disables_highest_index_equipped_gu_for_whole_battle, test_free_mix_failure_attaches_configured_curse, test_event_outcome_option_attaches_curse_on_accept

## Verification commands + tail output

- `$env:GODOT_CONSOLE_PATH='C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'; powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_curse_system.gd`
  → `17/17 passed ... ---- All tests passed! ----` (90 asserts)
- Per-file loop over all unit scripts except the 3 view-coupled ones (see concerns): `FAILED_SCRIPTS=0`
- `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite integration` → `Passing Tests 6 ... All tests passed`
- Full `-Suite all` currently shows 338 passed / 15 failing — every failure is in `test_v3_ui_sync.gd`, `test_v3_title_screen.gd`, `test_b3_experience_gaps.gd` view tests hitting the concurrent UI WIP in `scripts/presentation/` (see concerns). Baseline domain suites (rarity/loot pity incl.) remain green.

## Self-review findings

- `_strike` ripple check: only battle_resolver internals call it (10 call sites); default param keeps all compiling; attack-channel behavior unchanged (verified by untouched battle tests).
- No new top-level RunState keys: statuses rides inside `cultivator` (already whitelisted in `_apply_after`, duplicated in `_copy`/`to_save_data`); round-trip explicitly tested through `SaveRepository.serialize_run/load_run_from_data` including checksum.
- No RNG introduced anywhere; no vendor touches; ASCII identifiers throughout, Chinese only in `name_zh`.
- Deviations/decisions documented:
  1. Stage ladder: no one..five index mapping exists in resolver; canonical ordering found is map_generator's. Registry uses `STAGE_ORDER=["one".."five"]` (full ladder per brief wording) with unknown stage strings → index 0. Escalation is inert today since `RunState.stage` stays "one".
  2. Battle-level `use_gu` payment failures use the codebase's established feed-based rejection (`accepted` stays true); brief's "existing rejection path" mapped to that (`insufficient_essence` feed), not the stale-guard `accepted:false` path.
  3. Initial battle-setup draw is not polluted; pollution ticks on turn-based draws only (end-of-turn refill), matching "before the player's draw each turn".
  4. Multiple slot_seal curses share the single highest-index equipped gu (documented dedupe rule).

## Concerns (concurrency incident, resolved but noteworthy)

This worktree is being modified concurrently by another agent (UI batch). Mid-task their untracked WIP appeared (`scenes/ui/*`, `scripts/presentation/components/ui_theme.gd`, edits to battle/title/encounter/ending/map views, route canvas, run_controller, project.godot). A `git stash -u` I used to isolate a suspected regression captured their WIP together with mine; their live re-edits made `stash pop` abort on two files. Recovery: my untracked files were restored by the partial pop; my tracked-file edits were re-applied from the stash via a targeted `git diff stash@{0}^ stash@{0} -- <my paths> | git apply`. My commit contains exactly my 8 files. Their presentation WIP remains in working tree plus preserved stash entry (`stash@{0}`) for their recovery; the 15 failing view tests are caused solely by their in-flight changes (proven: with WIP stashed those suites pass 19/19). Recommend the coordinator serialize agents per worktree going forward.
