# Task 4 Report: Imprint (Relic Hook) Expansion (印记层扩展, P0)

**Status: DONE_WITH_CONCERNS** (one documented interpretation call + two minor scope notes; task scope complete and verified)
**Branch:** `p0-batch-continuation` (worktree `.worktrees/verify-t3`) — **Commit: `dfb38e4`** (not pushed)

## Scope implemented

Spec rules covered per brief: R4.8 meta-grade cap (一局 ≤2), R4.9 imprint slots (取舍压力), R11.7 relic codex unlock at run end (遭遇即解锁), plus hook-layer expansion for the P0 backlash/battle-end moments.

1. **Hook enums** `scripts/domain/relic_hook_resolver.gd`:
   - `TRIGGERS` += `"on_backlash_gained"`, `"on_battle_end"`; `EFFECT_KINDS` += `"convert_backlash_to_draw"`, `"reduce_curse_intensity"`, `"grant_stone_on_battle_end"`. Existing catalog validation auto-covers the new values.
   - `apply_backlash_gained(battle, state, catalog, layers_gained)` — fires once per newly-known curse layer while a battle dict is active; queues `battle["pending_extra_draws"] += amount × layers`; feed `relic_backlash_converted`. Pure battle-dict mutation, no RNG, no RunState writes.
   - `apply_battle_end(battle, state, catalog)` — sums `grant_stone_on_battle_end` amounts across owned relics; appends ONE immutable event (`action:"relic_stone_gain"`, reason `relic_stone_on_battle_end`, `state.stone += total`); feed `relic_battle_stone`.
   - `apply_battle_start` extended with `reduce_curse_intensity`: battle-local curse projections lose `amount` intensity each, floor 0; run-scoped statuses untouched (battles only project); feed `relic_curse_reduced`.
2. **Wiring in `battle_resolver.gd`**:
   - Backlash moment = `BattleResolver.start`, right after the curse projection lands in `battle["curses"]`; layer count read from `state.cultivator.statuses` layers.
   - Consumption = `_refill_hand_after_turn` drains `pending_extra_draws` exactly once at the next refill (leftovers vanish if both piles dry), logs `{"id":"relic_backlash_draw","extra":n}`, bumps `hand_version`.
   - Battle-end funnel: new `_battle_over(...)` for victory/retreat and `_death_over(...)` for all death paths (`_end_turn` ×2, `apply_enemy_pre_turn`, plus the card-play depletion branch). Each finished battle passes through a funnel exactly once. **Death ordering constraint found during TDD**: `finalize_death()` clears `relic_ids`, so hooks evaluate on the PRE-finalization state and the terminal event closes afterwards.
   - `_retreat` gained a `catalog` parameter to reach the funnel (both call sites updated).
3. **Imprint slots (R4.9)**: `data/deck.json` += `"imprint_capacity": 4`; `ContentCatalog.validate` mirrors the `deck.capacity` positive-integer check; `DeckCapacity.imprint_capacity(catalog)` helper; `resolver._gain_relic` rejects with `imprint_capacity_exceeded` as a pure no-op when `relic_ids.size()` is at cap.
4. **Meta-grade cap (R4.8)**: relics may carry `"grade": "meta_rule"`; third meta gain rejected `meta_rule_cap_reached` (`Resolver.META_RULE_CAP = 2`). Rejection order locked per brief: capacity → meta cap. Meta gains record `{relic_id: true}` into new `RunState.meta_rules` via the immutable `gain_relic` event (`before/after` include `meta_rules` only when meta-grade) and surface result feed string `meta_rule_recorded`.
5. **RunState wiring**: `meta_rules: Dictionary` added to field declaration, `new_run`, `_copy`, `to_save_data`, `_apply_after` whitelist, AND `SaveRepository._state_from_save_data` (required so `_has_valid_event_log` checksum/last-event validation still accepts saves whose last event carries `meta_rules`). Round-trip covered by test.
6. **Codex alignment (R11.7)**: `MetaProgress.relic_codex_ids: Array[String]`; `record_run_end` scans events with reason `relic_gained` and appends target ids (same pattern as recipe unlocks); wired into `to_save_data`, `_copy`, and `SaveRepository.load_meta_from_data`.
7. **Real data**: `jade_cicada_shell` marked `"grade": "meta_rule"` (every-battle first-turn energy reads most like a standing rule change); catalog validation accepts absent grade, rejects unknown strings (`RELIC_GRADES` const).
8. **New tests** `tests/unit/test_imprint_expansion.gd` (11 tests, 56 asserts).

## Interpretation note (binding-ambiguity reconciliation)

The brief says wire the backlash moment "wherever `curse_registry.gain_curse` result becomes known during battle projection / battle dict update", while the binding note says the trigger fires "per curse-layer gained during an active battle only (run-scoped gains outside battle do not fire hooks)". In this codebase there is NO mid-battle curse-gain path today (all `gain_curse` callers are run-scoped node actions; battles only project curses at start). The single live moment where curse layers meet an active battle is the projection inside `BattleResolver.start` — so that is the wired firing point, one fire per projected layer, with the pending-draw consumed once at the next refill. Consequence: pre-existing curses cause their layers to fire once at each battle start (the gain itself never fires anything outside a battle). If future batches add true mid-battle gains, they should route through `apply_backlash_gained(battle, state, catalog, layers)` to inherit the same semantics.

## Files touched (commit dfb38e4)

- `data/deck.json`, `data/relics.json`
- `scripts/domain/relic_hook_resolver.gd`, `scripts/domain/battle_resolver.gd`, `scripts/domain/resolver.gd`, `scripts/domain/run_state.gd`, `scripts/domain/content_catalog.gd`, `scripts/domain/deck_capacity.gd`, `scripts/domain/meta_progress.gd`, `scripts/domain/save_repository.gd`
- `tests/unit/test_imprint_expansion.gd` (new, 11 tests)

## Test names

test_backlash_gained_queues_next_turn_draw_once_per_curse_layer, test_apply_backlash_gained_reports_conversion_feed_and_stacks_pending, test_battle_end_stone_grant_fires_once_on_retreat_with_feed, test_battle_end_stone_grant_fires_exactly_once_on_death_path, test_reduce_curse_intensity_floors_projection_at_battle_start_only, test_imprint_capacity_rejection_leaves_state_untouched, test_meta_grade_cap_allows_two_then_rejects_third, test_meta_rules_survive_run_save_round_trip, test_real_jade_cicada_shell_is_meta_rule_and_catalog_stays_valid, test_validate_rejects_unknown_grade_and_missing_imprint_capacity, test_record_run_end_unlocks_relic_codex_and_round_trips

## Verification commands + tail output

- RED first: `-Test tests/unit/test_imprint_expansion.gd` before implementation → parse errors / failing (symbols absent).
- `$env:GODOT_CONSOLE_PATH='C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'; powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_imprint_expansion.gd`
  → `Tests 11 / Passing Tests 11 / Asserts 56 ... ---- All tests passed! ----`
- Full suite: `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all` → `EXIT=0`
  ```
  Totals
  Scripts              63
  Tests               364
  Passing Tests       364
  Asserts            2472
  ---- All tests passed! ----
  Totals
  Scripts               3
  Tests                 6
  Passing Tests         6
  Asserts              23
  ---- All tests passed! ----
  ```
  Baseline preserved + 11 new (353→364 unit; 6 integration unchanged).
- Per-script parse gate: `godot --headless --check-only -s <file>` clean for all 9 touched scripts.

## Self-review findings

- `meta_rules` triple wiring verified (whitelist/copy/save) PLUS load-side restore in SaveRepository — without it `_has_valid_event_log` would silently reject saves whose last event carries `meta_rules`.
- Death-path ordering bug caught by the failing test (stone grant evaluated after `finalize_death` saw empty `relic_ids`); fixed by evaluating hooks pre-finalization (`_death_over`).
- No RNG anywhere in the new code; the extra-draw reshuffle reuses the existing seeded `_battle_rng_seed` salt family (+`drawn_extra` salt offset).
- Rejections are pure no-ops (event log length asserted unchanged for both capacity and meta-cap paths).
- Exactly-once semantics asserted for both triggers (pending counter reset + single `relic_stone_on_battle_end` event counted on retreat and death).
- ASCII identifiers throughout; no Chinese outside data `name_zh`; vendor untouched; nothing pushed; only the 11 task files committed (pre-existing `.import` line-ending noise left alone).
- Process incident (no impact): an intermediate bulk-edit attempt via PowerShell `-replace` re-encoded `battle_resolver.gd` and corrupted its UTF-8 comments; detected immediately via parse error, restored from HEAD, edits reapplied with proper tooling. Final file verified UTF-8-clean (Chinese intent labels intact) and full suite green.

## Concerns

1. **Interpretation call** (above): `on_backlash_gained` fires at battle-start projection because no mid-battle gain path exists; flagged for coordinator confirmation against spec §16.x wording.
2. **Scope note A**: `shop_barter`'s relic reward still bypasses BOTH imprint capacity and meta cap (pre-existing gap — barter already bypassed deck-style gates; brief scoped capacity/meta logic to `_gain_relic` only). Recommend closing in a later hardening pass.
3. **Scope note B**: the card-play depletion death branch keeps its historical `finished:false/"ongoing"` flags (only state/battle/feeds now flow through the hook); surfacing it as a proper immediate death result is a pre-existing UX edge left out of this task's minimal diff.

## Fix round 1

Commit: `209bd44` on `p0-batch-continuation` (worktree `.worktrees/verify-t3`, HEAD was `dfb38e4`; not pushed).

### Findings addressed

1. **Important - barter gate bypass (fixed)**: extracted shared pure gate `Resolver._can_gain_relic(state, catalog, relic_id) -> String` (`""` = allowed; order: unknown -> already_owned -> imprint capacity -> meta cap, preserving the locked brief ordering). `_gain_relic` now delegates to it. `_shop_barter` routes its relic reward through the same gate: on rejection the barter still resolves as a normal success WITHOUT the relic reward (input gu stays consumed, event written) and emits feed `relic_reward_blocked_<reason>`; on acceptance with a `"grade": "meta_rule"` relic it records `meta_rules[relic_id] = true` into the event before/after and `RunState.meta_rules`, mirroring `_gain_relic` exactly, plus a `meta_rule_recorded` feed. The live exploit path (shops.json `barter_unknown_gu` -> sole meta-rule relic `jade_cicada_shell`) is closed.
2. **Minor - feeds overwrite (fixed)**: new static helper `_append_result_feed(result, feed)` appends without clobbering pre-existing feeds; used by both `_gain_relic` and `_shop_barter` (dedupe by feed id).
3. **Minor - codex membership filter (fixed, minimal ripple)**: `MetaProgress.record_run_end(run, outcome, catalog := {})` gains an OPTIONAL third parameter - no signature break for existing callers. When catalog is supplied, relic targets absent from `relic_by_id` are skipped; when omitted, historical permissive behavior is retained (asserted in test). Only production call site updated: `run_controller.gd` passes its catalog.

### Files touched

- `scripts/domain/resolver.gd`: `_can_gain_relic`, `_append_result_feed`; `_gain_relic` refactor; `_shop_barter` gating + meta_rules recording + feeds.
- `scripts/domain/meta_progress.gd`: optional catalog param + membership filter in relic-codex scan.
- `scripts/presentation/run_controller.gd`: pass catalog to record_run_end.
- `tests/unit/test_imprint_expansion.gd`: 4 new tests + `_add_test_barter_offer` helper.

### New tests (written first; red confirmed 11 passing / 4 failing before implementation)

- `test_barter_relic_reward_blocked_at_full_imprint_capacity_resolves_without_relic` (covers both blocked reasons: capacity AND meta cap through barter)
- `test_barter_granting_meta_rule_relic_records_meta_rules_and_feed`
- `test_meta_rule_result_feed_appends_instead_of_overwrites`
- `test_record_run_end_skips_relic_targets_missing_from_catalog_when_provided`

### Commands + tail output

TDD red (new file run): `tools/test.ps1 -Suite unit -Test tests/unit/test_imprint_expansion.gd` -> `Tests 15 / Passing 11 / Failing 4`.
Post-fix file run: same command -> `Scripts 1 / Tests 15 / Passing Tests 15 / Asserts 78 ---- All tests passed! ----`.
Full suite: `$env:GODOT_CONSOLE_PATH='...Godot_v4.7.2-stable_win64_console.exe'; powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all` ->
```
unit:
Scripts              63
Tests               368
Passing Tests       368
Asserts            2494
---- All tests passed! ----
integration:
Scripts               3
Tests                 6
Passing Tests         6
Asserts              23
---- All tests passed! ----
```
Baseline 364 unit + 6 integration preserved; 368 = 364 + 4 new.

### Notes

- Behavior change (intentional, more transparent): barter rewarding an ALREADY-OWNED relic previously skipped silently; now emits `relic_reward_blocked_relic_already_owned`. No prior test depended on silence.
- Pre-existing `.import` line-ending churn in the worktree left unstaged/untouched; known harmless `.git/worktrees/gu-zhenren-push Permission denied` prune error appeared on commit as expected.
