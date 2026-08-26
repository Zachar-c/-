# Gu Construction and Battle Card Deck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Incrementally turn the current South Border prototype into a deterministic, single-run Roguelike vertical slice where long-lived Gu assets generate temporary Slay-the-Spire-style battle decks, while events, black-market deals, refinement, feeding, and death remain on the existing Preview -> ActionCard -> Resolver boundary.

**Architecture:** Preserve `ActionPreviewService` as a pure read-only renderer of player-known choices and preserve `Resolver`/`BattleResolver` as the only state and RNG writers. Add a compatibility-safe `GuInstance` layer beside the existing `gu_ids` arrays, a cached `DeckBuilder`, and battle-local `battle_id`/`hand_version` validation so routine card play never regenerates every Gu-derived card nor fails because an unrelated run event changed the global event log.

**Tech Stack:** Godot 4.6.2; GDScript; JSON content tables; GUT; deterministic local `SeededRng`; Windows keyboard/mouse; `gl_compatibility` renderer.

## Global Constraints

- This document supersedes the obsolete fixed four-slot and non-draw combat assumptions in `docs/superpowers/plans/2026-08-21-nanjiang-roguelite-smoke-implementation.md`; keep that file as history, do not rewrite it.
- Preserve the public interfaces `ActionPreviewService.preview_actions(run, context, catalog)`, `ActionPreviewService.preview_battle_actions(battle, run, catalog)`, and `ActionResolver`/`BattleResolver.apply` semantics. UI submits only `{ "type": "action_card", "action_id": String, "state_version": int }`.
- Preview is pure: no RNG, no raw seed reads, no state mutation, no event-log append, and no resource consumption.
- Resolver is the unique authority: re-read current state, re-find the action card, validate its version and requirements, perform all deterministic RNG, append immutable event records, and return `state`, `actual_changes`, and `next_available_actions`.
- `RunState` is disposable per-run data. `MetaProgress` stores only codex discoveries, unlocked definitions, known free-mix outcomes, and aggregate run statistics. Never persist per-run health, lifespan, soul, stone, Gu instances, decks, map, relics, or event logs inside `MetaProgress`.
- The aperture has no `gu_capacity`, `gu_slot_limit`, or ownership count cap. Pressure comes from essence, soul concurrency, and node-level feeding.
- Start at rank one, `bing` aptitude, essence maximum `4`, essence regeneration `2`. Normal playable scope is mortal ranks 1-5; rank 6+ is data/display only.
- Use ASCII for identifiers, JSON keys, tests, and commit messages. Player-facing Chinese text may be UTF-8.
- Preserve all existing dirty worktree changes. Never modify the protected research folders or `vendor/godot-open-rpg/`.
- Each accepted domain mutation appends exactly one immutable event record. Tests use fixed seeds and never depend on global `randf()`.

---

## Planned File Structure

```text
data/
  gu.json                         # Gu definitions, costs, feeding, card blueprint references
  cards.json                      # CardDefinition and kill-move card definitions
  refinement_recipes.json         # Fixed recipe, free-mix pools, caravan offers
  relics.json                     # One positive and one double-edged relic
  events.json                     # One delayed-cost event and its observable clue
  shops.json                      # Purchase, lifespan trade, and barter offer templates
scripts/domain/
  run_state.gd                    # Compatibility-safe RunState, GuInstance storage, aperture/cultivator fields
  meta_progress.gd                # Global-only codex/unlock/statistics storage and serialization
  content_catalog.gd              # Loads and validates the new content tables
  deck_builder.gd                 # Pure Gu -> CardInstance generation and stable deck hash
  battle_resolver.gd              # Battle-local card submission, duration occupancy, intent and death
  resolver.gd                     # Gu lifecycle, feeding, refinement/free mix, deals, events, death reset
  action_preview_service.gd       # Read-only cards, progressive knowledge, battle-card action metadata
  encounter_session_resolver.gd   # Existing node ActionCard boundary; returns structured resolution
  save_repository.gd              # Stores RunState separately from MetaProgress
scripts/presentation/
  run_controller.gd               # Routes generic action_card submissions to node or battle authority
  battle_view.gd                  # Renders hand/intent/action cards; never manufactures commands
tests/unit/
  test_v3_run_state_gu_instances.gd
  test_v3_deck_builder.gd
  test_v3_battle_card_actions.gd
  test_v3_soul_and_backlash.gd
  test_v3_gu_lifecycle.gd
  test_v3_refinement_and_knowledge.gd
  test_v3_market_event_relic.gd
  test_v3_meta_and_terminal_run.gd
tests/integration/
  test_v3_roguelike_vertical_slice.gd
```

`scripts/domain/run_state.gd`, `resolver.gd`, `battle_resolver.gd`, `action_preview_service.gd`, `content_catalog.gd`, `encounter_session_resolver.gd`, `save_repository.gd`, `run_controller.gd`, and `battle_view.gd` already exist and are modified incrementally. `gu_ids`, `refined_gu_ids`, and `equipped_gu_ids` remain read-compatible projections during the migration; no caller is switched until its replacement test passes.

## Shared Domain Contracts

Implement these structures before consumers refer to them:

```gdscript
# RunState fields, all per-run.
var cultivator := {
    "reincarnation": 1, "stage": 0, "aptitude": "bing",
    "health": 6, "max_health": 6, "lifespan": 60,
    "soul": 4, "soul_max": 4, "soul_control_limit": 2,
    "statuses": {}
}
var cave_aperture := {
    "essence": 4, "essence_max": 4, "essence_regen_per_turn": 2,
    "integrity": 6, "integrity_max": 6, "stored_gu_instance_ids": []
}
var gu_instances: Dictionary = {} # instance_id -> GuInstance dictionary
var gu_card_overrides: Dictionary = {} # card_key -> {disabled_for_run, upgrade_level, extra_copies}
var relic_ids: Array[String] = []
var materials: Dictionary = {"feed_points": 0}
var terminal_state := "active" # active | dead | won

# BattleState, stored only during a battle.
# hand_version changes only when the hand contents change (draw, discard, play, shuffle).
var battle := {
    "battle_id": "", "deck_generation_hash": "", "deck_cache": [],
    "draw_pile": [], "discard_pile": [], "hand": [], "exhausted_cards": [],
    "hand_version": 0, "phase": "player", "turn": 1,
    "active_gu_instance_ids": [], "active_effect_registry": {},
    "pending_kill_move_state": {}, "enemy_visible_intents": []
}

# Global-only persistence. No RunState field is copied here.
var meta := {
    "gu_codex_ids": [], "recipe_codex_ids": [], "inheritance_codex_ids": [],
    "unlocked_content_ids": [], "unlocked_random_outcomes": {},
    "statistics": {"runs_started": 0, "runs_won": 0, "deaths": 0}
}
```

The deterministic backlash table is content/constant data and never inferred from UI text:

| Aptitude | `health_factor` | `soul_factor` | `essence_bonus` | `regen_bonus` |
| --- | ---: | ---: | ---: | ---: |
| `jia` | 0.60 | 0.50 | 3 | 2 |
| `yi` | 0.80 | 0.70 | 2 | 1 |
| `bing` | 1.00 | 1.00 | 1 | 1 |
| `ding` | 1.30 | 1.40 | 0 | 0 |
| `wu` | 1.60 | 1.80 | -1 | 0 |

Use:

```gdscript
var rank_gap := maxi(0, gu_rank - int(state.cultivator["reincarnation"]))
var health_damage := ceili((1.0 + rank_gap) * condition_multiplier * factors[aptitude]["health_factor"])
var soul_damage := ceili((1.0 + rank_gap * 2.0) * condition_multiplier * factors[aptitude]["soul_factor"])
```

`feeding_need` keys are `material_id` values. The first vertical slice supports the single universal material `feed_points` so UI can show a concrete shortage; later definitions may use IDs such as `moonlight_dust`, but each must appear in `RunState.materials` and catalog validation.

---

### Task 1: Add Compatibility-Safe Cultivator, Aperture, GuInstance, and MetaProgress Foundations

**Files:**
- Create: `scripts/domain/meta_progress.gd`
- Modify: `scripts/domain/run_state.gd`
- Modify: `scripts/domain/save_repository.gd`
- Test: `tests/unit/test_v3_run_state_gu_instances.gd`
- Test: `tests/unit/test_v3_meta_and_terminal_run.gd`

**Consumes:** Existing scalar `RunState` fields, immutable `append_event`, existing save tests.

**Produces:** `RunState.new_run(seed)`, `RunState.refined_instances()`, `RunState.sync_legacy_gu_projections()`, `RunState.is_terminal()`, `MetaProgress.new_empty()`, `MetaProgress.record_run_end(run)`, and separated serialization.

- [x] **Step 1: Write failing foundation tests**

```gdscript
func test_new_run_has_bing_aperture_without_gu_storage_limit() -> void:
    var run := RunState.new_run(101)
    assert_eq(run.cultivator["aptitude"], "bing")
    assert_eq(run.cave_aperture["essence_max"], 4)
    assert_eq(run.cave_aperture["essence_regen_per_turn"], 2)
    assert_false(run.cave_aperture.has("gu_capacity"))
    assert_false(run.cave_aperture.has("gu_slot_limit"))

func test_refined_instance_projection_keeps_legacy_ids_compatible() -> void:
    var run := RunState.new_run(101)
    run.gu_instances["gu_002"] = {"instance_id": "gu_002", "definition_id": "stone_shell_gu", "state": "refined"}
    run.sync_legacy_gu_projections()
    assert_eq(run.refined_gu_ids, ["small_light_gu", "stone_shell_gu"])

func test_meta_progress_rejects_run_resources_and_records_only_codex_and_statistics() -> void:
    var run := RunState.new_run(101)
    run.stone = 99
    var meta := MetaProgress.new_empty()
    var next := meta.record_run_end(run, "dead")
    assert_false(next.to_save_data().has("stone"))
    assert_false(next.to_save_data().has("gu_instances"))
    assert_eq(next.statistics["deaths"], 1)
```

- [x] **Step 2: Run foundation tests and verify they fail**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_run_state_gu_instances.gd`

Expected: FAIL because structured aperture, Gu instances, and `MetaProgress` do not exist.

- [x] **Step 3: Implement the smallest migration layer**

```gdscript
func refined_instances() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for instance_id in cave_aperture["stored_gu_instance_ids"]:
        var instance: Dictionary = gu_instances.get(instance_id, {})
        if instance.get("state", "") in ["refined", "contracted", "weakened"]:
            result.append(instance.duplicate(true))
    return result

func is_terminal() -> bool:
    return terminal_state != "active"
```

Create the start instance `gu_001` for `small_light_gu`; initialize `cultivator`, `cave_aperture`, `materials`, `gu_card_overrides`, and `terminal_state` in `new_run`. Copy, event application, and save data must deep-copy these keys. Keep old scalar fields synchronized from `cultivator`/`cave_aperture` until all existing code has migrated. `MetaProgress.record_run_end` only adds seen definitions and increments `runs_won` or `deaths`.

- [x] **Step 4: Run the focused tests and existing state/save regressions**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_run_state_gu_instances.gd`

Run: `./tools/test.ps1 -Test tests/unit/test_v2_run_state.gd`

Run: `./tools/test.ps1 -Test tests/unit/test_save_repository.gd`

Expected: PASS; legacy first-run and save tests remain green.

- [x] **Step 5: Commit the foundation**

```powershell
git add scripts/domain/run_state.gd scripts/domain/meta_progress.gd scripts/domain/save_repository.gd tests/unit/test_v3_run_state_gu_instances.gd tests/unit/test_v3_meta_and_terminal_run.gd
git commit -m "feat: add run gu instances and meta boundary"
```

### Task 2: Add Data-Driven Cards, Kill Moves, Content Validation, and Deck Hashing

**Files:**
- Create: `data/cards.json`
- Modify: `data/gu.json`
- Modify: `scripts/domain/content_catalog.gd`
- Create: `scripts/domain/deck_builder.gd`
- Test: `tests/unit/test_v3_deck_builder.gd`

**Consumes:** `RunState.refined_instances`, `gu_card_overrides`, catalog loading.

**Produces:** `DeckBuilder.deck_hash(run, catalog)`, `DeckBuilder.build_card_cache(run, catalog)`, `DeckBuilder.build_battle_deck(run, catalog, hash)`, valid `CardDefinition`/`KillMove` data.

- [x] **Step 1: Write failing deck/cache tests**

```gdscript
func test_deck_hash_is_stable_until_gu_or_card_override_changes() -> void:
    var run := RunState.new_run(101)
    var first := DeckBuilder.deck_hash(run, catalog)
    assert_eq(first, DeckBuilder.deck_hash(run, catalog))
    run.gu_card_overrides["small_light_gu:light_probe"] = {"extra_copies": 1}
    assert_ne(first, DeckBuilder.deck_hash(run, catalog))

func test_opening_gu_generate_cards_without_hard_coded_deck() -> void:
    var run := RunState.new_run(101)
    var cards := DeckBuilder.build_card_cache(run, catalog)
    assert_eq(cards.map(func(card): return card["definition_id"]), ["light_probe"])
    assert_eq(cards[0]["source_gu_instance_ids"], ["gu_001"])

func test_kill_move_requires_ordered_source_gu_and_has_pending_state_contract() -> void:
    var definition := catalog["card_by_id"]["moonlight_return"]
    assert_eq(definition["kill_move_sequence"], ["moonlight_gu", "small_light_gu"])
    assert_eq(definition["sequence_window"], "same_turn")
```

- [x] **Step 2: Run the deck tests and verify failure**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_deck_builder.gd`

Expected: FAIL because the deck builder and card catalog do not exist.

- [x] **Step 3: Add minimum data and pure builder**

Add `card_blueprint_ids` and `feeding_need: {"feed_points": N}` to each Gu definition. `cards.json` defines `light_probe`, `stone_guard`, `moonlight_strike`, and one multi-Gu `moonlight_return`; every card declares `id`, `source`, `cost`, `effects`, `duration_turns`, `occupies_soul_slots`, and `public_text_key`. A kill move additionally declares `kill_move_sequence`, `sequence_window`, and `sequence_timeout_action`.

```gdscript
static func deck_hash(run: RunState, catalog: Dictionary) -> String:
    var source := []
    for instance in run.refined_instances():
        source.append({"id": instance["instance_id"], "definition": instance["definition_id"], "state": instance["state"]})
    return JSON.stringify({"gu": source, "overrides": run.gu_card_overrides}).sha256_text()

static func build_card_cache(run: RunState, catalog: Dictionary) -> Array[Dictionary]:
    # Iterate deterministically by stored aperture order; no RNG and no state mutation.
    return _cards_from_refined_instances(run, catalog)
```

`ContentCatalog.validate` rejects a card whose source Gu is missing, any `feeding_need` key not listed in `material_ids`, a kill move whose ordered source definition is missing, or a duration card without an integer `duration_turns`.

- [x] **Step 4: Run deck and catalog regression tests**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_deck_builder.gd`

Run: `./tools/test.ps1 -Test tests/unit/test_action_preview_service.gd`

Expected: PASS; existing action cards still render from their legacy Gu projections.

- [x] **Step 5: Commit the deck data boundary**

```powershell
git add data/gu.json data/cards.json scripts/domain/content_catalog.gd scripts/domain/deck_builder.gd tests/unit/test_v3_deck_builder.gd
git commit -m "feat: add gu derived battle deck definitions"
```

### Task 3: Replace Direct Gu Battle Actions with Cached Draw/Discard/Hand Card Actions

**Files:**
- Modify: `scripts/domain/battle_resolver.gd`
- Modify: `scripts/domain/action_preview_service.gd`
- Modify: `scripts/presentation/run_controller.gd`
- Modify: `scripts/presentation/battle_view.gd`
- Test: `tests/unit/test_v3_battle_card_actions.gd`
- Test: `tests/integration/test_v3_roguelike_vertical_slice.gd`

**Consumes:** `DeckBuilder`, current enemy intent/reaction rules, generic ActionCard data shape.

**Produces:** Battle cards with `id = battle.<battle_id>.<card_instance_id>`, battle-local `hand_version`, cached deck arrays, and generic UI `action_card` submissions.

- [x] **Step 1: Write failing battle local-version and cache tests**

```gdscript
func test_playing_card_moves_only_cached_instances_without_rebuilding_full_deck() -> void:
    var started := BattleResolver.start({"enemy_kind": "ridge_hound"}, RunState.new_run(101), catalog)
    var initial_hash := started["deck_generation_hash"]
    var initial_cache := started["deck_cache"].duplicate(true)
    var result := BattleResolver.apply_action_card(started, RunState.new_run(101), _first_card_command(started), catalog)
    assert_eq(result["battle"]["deck_generation_hash"], initial_hash)
    assert_eq(result["battle"]["deck_cache"], initial_cache)
    assert_eq(result["battle"]["discard_pile"].size(), 1)

func test_unrelated_run_event_does_not_invalidate_current_battle_hand() -> void:
    var run := RunState.new_run(101)
    var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
    var changed_run := run.append_event({"after": {"stone": 11}, "reason": "test"})
    var result := BattleResolver.apply_action_card(battle, changed_run, _first_card_command(battle), catalog)
    assert_true(result["accepted"])

func test_stale_battle_hand_version_is_rejected_atomically() -> void:
    var run := RunState.new_run(101)
    var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
    var command := _first_card_command(battle)
    battle["hand_version"] += 1
    var result := BattleResolver.apply_action_card(battle, run, command, catalog)
    assert_false(result["accepted"])
    assert_eq(result["feeds"], ["battle_hand_stale"])
    assert_eq(result["state"], run)
```

- [x] **Step 2: Run the focused test and observe failure**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_battle_card_actions.gd`

Expected: FAIL because battle uses raw `use_gu` actions and global event-log version validation.

- [x] **Step 3: Implement battle-local ActionCard flow**

At `BattleResolver.start`, calculate one deck hash, call `DeckBuilder.build_card_cache` once, deterministically shuffle/draw the initial hand through `SeededRng`, and assign a unique `battle_id`. Only rebuild cache when the saved `deck_generation_hash` differs from `DeckBuilder.deck_hash(run, catalog)` at battle start or after a declared card-override mutation; do not call `build_card_cache` from ordinary play, end-turn, intent, or reaction paths.

```gdscript
static func apply_action_card(battle: Dictionary, run: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
    var expected := int(command.get("state_version", -1))
    if expected != int(battle.get("hand_version", -2)):
        return _rejected_turn(battle.duplicate(true), run, "battle_hand_stale")
    var card := _find_hand_action_card(battle, run, str(command.get("action_id", "")), catalog)
    if card.is_empty() or not card["executable"]:
        return _rejected_turn(battle.duplicate(true), run, "battle_action_unavailable")
    return _resolve_card_instance(battle, run, card["command"], catalog)
```

`preview_battle_actions` reads only hand CardInstances plus `end_turn` and `retreat`; its `state_version` is `battle.hand_version`, not `state.event_log.size()`. `RunController` receives only generic `action_card`; when `current_battle` is active it calls `BattleResolver.apply_action_card`, otherwise it forwards to `EncounterSessionResolver`. Remove the UI-visible `battle_action_card` path after its integration test passes. Keep raw `use_gu` only as a private legacy adapter until no existing tests call it.

Increment `hand_version` when an action removes a card from hand, draws, shuffles, or discards. Do not increment it for a change to stone, event log, map position, enemy intent metadata, or a continuous effect tick that leaves hand content untouched.

- [x] **Step 4: Run targeted battle, preview, and controller tests**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_battle_card_actions.gd`

Run: `./tools/test.ps1 -Test tests/unit/test_v2_battle_resolver.gd`

Run: `./tools/test.ps1 -Test tests/unit/test_action_preview_service.gd`

Expected: PASS; no test relies on the old global battle state version.

- [x] **Step 5: Commit the cached battle loop**

```powershell
git add scripts/domain/battle_resolver.gd scripts/domain/action_preview_service.gd scripts/presentation/run_controller.gd scripts/presentation/battle_view.gd tests/unit/test_v3_battle_card_actions.gd tests/integration/test_v3_roguelike_vertical_slice.gd
git commit -m "feat: add cached gu battle card hands"
```

### Task 4: Implement Soul Concurrency, Duration Effects, Kill-Move Sequencing, and Backlash

**Files:**
- Modify: `scripts/domain/battle_resolver.gd`
- Modify: `scripts/domain/action_preview_service.gd`
- Test: `tests/unit/test_v3_soul_and_backlash.gd`

**Consumes:** Card duration, kill move source IDs, aptitude factors, cached battle hand.

**Produces:** `DurationEffect` registry lifecycle, correct soul occupancy cleanup, progressive multi-Gu sequence, public risk metadata, deterministic backlash event changes.

- [x] **Step 1: Write failing concurrency/backlash tests**

```gdscript
func test_duration_effect_releases_soul_occupancy_after_expiry() -> void:
    var battle := _battle_with_stone_guard_duration()
    assert_eq(battle["active_gu_instance_ids"], ["gu_001"])
    var result := BattleResolver.end_turn(battle, RunState.new_run(101), catalog)
    assert_true(result["battle"]["active_gu_instance_ids"].is_empty())
    assert_true(result["battle"]["active_effect_registry"].is_empty())

func test_multi_gu_kill_move_over_soul_limit_applies_backlash() -> void:
    var run := _run_with_soul_limit(1)
    var result := BattleResolver.resolve_kill_move(_battle_for_moonlight_return(), run, "moonlight_return", catalog)
    assert_lt(result["state"].cultivator["soul"], run.cultivator["soul"])
    assert_true(result["actual_changes"].any(func(change): return change["type"] == "soul"))

func test_force_activating_higher_rank_gu_uses_bing_backlash_factors() -> void:
    var run := RunState.new_run(101)
    var result := BattleResolver.apply_backlash(run, {"rank": 3, "condition_multiplier": 1.0})
    assert_eq(result["health_damage"], 3)
    assert_eq(result["soul_damage"], 5)
```

- [x] **Step 2: Run the test and verify failure**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_soul_and_backlash.gd`

Expected: FAIL because the battle has no duration registry, concurrent source accounting, or defined factor table.

- [x] **Step 3: Implement effect and sequence lifecycle**

```gdscript
func _register_duration(battle: Dictionary, card: Dictionary) -> void:
    var effect_id := "effect_%s_%d" % [card["instance_id"], int(battle["turn"])]
    battle["active_effect_registry"][effect_id] = {
        "effect_instance_id": effect_id,
        "source_gu_instance_ids": card["source_gu_instance_ids"].duplicate(),
        "remaining_turns": int(card["duration_turns"]),
        "tick_phase": "end_turn",
        "occupies_soul_slots": bool(card["occupies_soul_slots"]),
        "soul_occupancy_gu_ids": card["source_gu_instance_ids"].duplicate(),
    }

func _expire_effects(battle: Dictionary) -> void:
    # Decrement matching effects, erase expired entries, then recompute active sources from registry.
    pass
```

The actual implementation must replace `pass`: decrement `remaining_turns` only at the declared `tick_phase`, remove expired entries, and recompute `active_gu_instance_ids` from unexpired occupancy references. `pending_kill_move_state` records `move_id`, `next_sequence_index`, `source_gu_instance_ids`, and `expires_at_turn`; only cards played in the declared sequence window advance it. Any unrelated action triggers `sequence_timeout_action` and clears it.

Before resolving an activation, count the union of existing occupied Gu instance IDs and the card's source IDs. If it exceeds `soul_control_limit`, apply defined backlash through Resolver-owned state mutation; Preview marks the exact known occupancy and risk but does not calculate a hidden roll. High-rank activation uses the fixed factor table and appends one `backlash_applied` event with health/soul/aperture changes.

- [x] **Step 4: Run focused and legacy battle tests**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_soul_and_backlash.gd`

Run: `./tools/test.ps1 -Test tests/unit/test_battle_loop.gd`

Expected: PASS; no duration source remains active after expiry.

- [x] **Step 5: Commit effect and backlash rules**

```powershell
git add scripts/domain/battle_resolver.gd scripts/domain/action_preview_service.gd tests/unit/test_v3_soul_and_backlash.gd
git commit -m "feat: add soul duration and backlash rules"
```

### Task 5: Implement Gu Lifecycle, Feeding, Death, and Card Override Semantics

**Files:**
- Modify: `scripts/domain/resolver.gd`
- Modify: `scripts/domain/run_state.gd`
- Modify: `scripts/domain/action_preview_service.gd`
- Test: `tests/unit/test_v3_gu_lifecycle.gd`
- Test: `tests/unit/test_v3_meta_and_terminal_run.gd`

**Consumes:** Gu instances, catalog feeding definitions, deck overrides, terminal-state contract.

**Produces:** Refinement ownership checks, node-leave feeding settlement, weakened/escape/death result handling, correct delete-card versus destroy-Gu behavior, permanent run death.

- [x] **Step 1: Write failing lifecycle tests**

```gdscript
func test_many_gu_are_allowed_but_feeding_need_scales_by_instances() -> void:
    var run := _run_with_refined_instances(12)
    assert_eq(run.estimate_feeding_materials(catalog)["feed_points"], 12)

func test_unfed_gu_becomes_weakened_then_dies_deterministically() -> void:
    var run := _run_with_one_hungry_gu()
    var first := Resolver.settle_node_feeding(run, catalog)
    assert_eq(first["state"].gu_instances["gu_002"]["state"], "weakened")
    var second := Resolver.settle_node_feeding(first["state"], catalog)
    assert_eq(second["state"].gu_instances["gu_002"]["state"], "dead")

func test_deleting_battle_card_does_not_destroy_source_gu_but_destroying_gu_removes_future_cards() -> void:
    var run := RunState.new_run(101)
    var disabled := Resolver.apply(run, {"type": "disable_card", "card_key": "small_light_gu:light_probe"}, catalog)["state"]
    assert_true(disabled.gu_instances.has("gu_001"))
    assert_true(DeckBuilder.build_card_cache(disabled, catalog).is_empty())
    var destroyed := Resolver.apply(disabled, {"type": "destroy_gu", "instance_id": "gu_001"}, catalog)["state"]
    assert_eq(destroyed.gu_instances["gu_001"]["state"], "dead")

func test_lifespan_or_soul_depletion_marks_run_dead_and_discards_run_data() -> void:
    var run := RunState.new_run(101)
    run.cultivator["lifespan"] = 1
    var result := Resolver.apply(run, {"type": "spend_lifespan", "amount": 1}, catalog)
    assert_eq(result["state"].terminal_state, "dead")
    assert_true(result["state"].gu_instances.is_empty())
```

- [x] **Step 2: Run the lifecycle test and verify failure**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_gu_lifecycle.gd`

Expected: FAIL because feeding remains a stone-only ledger and card destruction semantics do not exist.

- [x] **Step 3: Implement explicit lifecycle transitions**

`Resolver` adds internal command branches `disable_card`, `upgrade_card`, `copy_card`, `destroy_gu`, `settle_node_feeding`, and `spend_lifespan`; only ActionCard-produced commands reach public UI. Each executes after revalidation and emits a structured event. `settle_node_feeding` uses `estimate_feeding_materials`, deducts `materials[material_id]`, and applies `weakened` on the first deficit then deterministic `dead`/`escaped` on continued deficit. The first slice uses a fixed threshold of two consecutive deficits, no random selection.

When `health <= 0`, `lifespan <= 0`, or `soul <= 0`, `_finalize_death` sets `terminal_state = "dead"`, clears all temporary RunState collections (Gu, card overrides, relics, battle, materials, map session), retains event log only long enough to update `MetaProgress`, and writes `run_ended` as the final immutable event. `MetaProgress.record_run_end` runs after this result and must never receive the cleared resources as persistent fields.

- [x] **Step 4: Run lifecycle, metadata, and ActionCard tests**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_gu_lifecycle.gd`

Run: `./tools/test.ps1 -Test tests/unit/test_v3_meta_and_terminal_run.gd`

Run: `./tools/test.ps1 -Test tests/unit/test_encounter_session_resolver.gd`

Expected: PASS; terminal state blocks future action cards and resolver submissions.

- [x] **Step 5: Commit Gu lifecycle rules**

```powershell
git add scripts/domain/resolver.gd scripts/domain/run_state.gd scripts/domain/action_preview_service.gd tests/unit/test_v3_gu_lifecycle.gd tests/unit/test_v3_meta_and_terminal_run.gd
git commit -m "feat: add gu feeding and terminal run rules"
```

### Task 6: Add Fixed Refinement, Free Mix, Progressive Knowledge, and Moonlight Chain

**Files:**
- Modify: `data/refinement_recipes.json`
- Modify: `data/gu.json`
- Modify: `scripts/domain/content_catalog.gd`
- Modify: `scripts/domain/resolver.gd`
- Modify: `scripts/domain/action_preview_service.gd`
- Modify: `scripts/domain/meta_progress.gd`
- Test: `tests/unit/test_v3_refinement_and_knowledge.gd`

**Consumes:** `MetaProgress.unlocked_random_outcomes`, Gu instance removal/output, seeded Resolver RNG.

**Produces:** Fixed recipe success and failure; free-mix destroy/mutation/explosion outcomes; discovered outcomes that become precise on later Preview; the first moonlight recipe.

- [x] **Step 1: Write failing refinement and progressive-reveal tests**

```gdscript
func test_fixed_moonlight_recipe_consumes_inputs_and_adds_moon_glow() -> void:
    var run := _run_with_gu_definitions(["moonlight_gu", "small_light_gu", "small_light_gu"])
    var result := Resolver.apply(run, {"type": "refine_gu", "recipe_id": "moon_glow_fixed"}, catalog)
    assert_true(result["result"]["ok"])
    assert_eq(result["state"].refined_gu_ids.count("moon_glow_gu"), 1)
    assert_eq(result["state"].refined_gu_ids.count("small_light_gu"), 0)

func test_free_mix_preview_is_vague_before_discovery_and_exact_after_discovery() -> void:
    var unknown := ActionPreviewService.preview_actions(_free_mix_run(), _refinement_node(), catalog)
    assert_string_contains(_card(unknown, "refine.free_mix")["unknown_note"], "结果未明")
    var meta := MetaProgress.new_empty()
    meta.unlocked_random_outcomes["small_light_gu+trail_eye_gu"] = ["mutation_venom"]
    var known := ActionPreviewService.preview_actions(_free_mix_run(meta), _refinement_node(), catalog)
    assert_string_contains(str(_card(known, "refine.free_mix")["known_risk"]), "畸变")

func test_free_mix_failure_records_one_seeded_outcome_and_never_accepts_ui_roll() -> void:
    var result := Resolver.apply(_free_mix_run(), {"type": "refine_gu", "recipe_id": "free_mix", "roll": 100}, catalog)
    assert_false(result["result"].has("roll"))
    assert_true(result["state"].event_log.back()["reason"] in ["free_mix_destroyed", "free_mix_mutation", "free_mix_explosion"])
```

- [x] **Step 2: Run tests and observe failure**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_refinement_and_knowledge.gd`

Expected: FAIL because free mix and knowledge records do not exist.

- [x] **Step 3: Implement Resolver-only outcomes and knowledge records**

Add the complete data chain:

```text
moonlight_gu + small_light_gu + small_light_gu -> moon_glow_gu
moon_glow_gu + phantom_dust + small_light_gu -> phantom_moon_gu
phantom_moon_gu + moonlight_gu + shadow_silk -> moon_shadow_gu
```

The first vertical slice implements the first fixed recipe and represents later two recipes as catalog-visible locked entries. `free_mix` takes at least two instance IDs and uses `SeededRng` only inside `Resolver`; it either destroys input Gu, creates a defined mutated Gu, or applies explosion health/soul/lifespan costs. Resolver returns structured effect keys, never player-facing prose. On every result, record the combination key and observed outcome in `MetaProgress.unlocked_random_outcomes`; Preview receives only the discovered record and changes from a vague clue to exact known branches. First-time Preview never exposes undiscovered outcome probabilities or raw seed.

- [x] **Step 4: Run focused tests and existing refinement ActionCard tests**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_refinement_and_knowledge.gd`

Run: `./tools/test.ps1 -Test tests/unit/test_action_preview_service.gd`

Expected: PASS; existing 70% recipe remains displayed through `success_rate`, not a parsed string.

- [x] **Step 5: Commit refinement and knowledge loop**

```powershell
git add data/refinement_recipes.json data/gu.json scripts/domain/content_catalog.gd scripts/domain/resolver.gd scripts/domain/action_preview_service.gd scripts/domain/meta_progress.gd tests/unit/test_v3_refinement_and_knowledge.gd
git commit -m "feat: add refinement knowledge and moonlight chain"
```

### Task 7: Add Black Market, Delayed-Cost Event, and Relic Vertical Slice

**Files:**
- Create: `data/relics.json`
- Create: `data/events.json`
- Create: `data/shops.json`
- Modify: `scripts/domain/content_catalog.gd`
- Modify: `scripts/domain/action_preview_service.gd`
- Modify: `scripts/domain/resolver.gd`
- Modify: `scripts/domain/encounter_session_resolver.gd`
- Test: `tests/unit/test_v3_market_event_relic.gd`

**Consumes:** ActionCard fields `cost`, `known_risk`, `expected_gain`, `unknown_note`, `remedy_hints`; lifecycle/death resolution.

**Produces:** One direct purchase, one lifespan deal, one Gu-for-unknown barter, a clearly hinted delayed-cost event, `jade_cicada_shell`, and `hungry_vine_token`.

- [x] **Step 1: Write failing market/event tests**

```gdscript
func test_lifespan_market_deal_shows_known_cost_before_click_and_can_kill() -> void:
    var run := RunState.new_run(101)
    run.cultivator["lifespan"] = 1
    var card := _card(ActionPreviewService.preview_actions(run, _shop_node(), catalog), "shop.lifespan.pulse_drum")
    assert_eq(card["cost"]["lifespan"], 1)
    var result := EncounterSessionResolver.apply(run, EncounterSessionResolver.start(_shop_node()), {"type": "action_card", "action_id": card["id"], "state_version": card["state_version"]}, catalog, _shop_node())
    assert_eq(result["state"].terminal_state, "dead")

func test_barter_preview_keeps_reward_unknown_but_shows_observable_trader_clue() -> void:
    var card := _card(ActionPreviewService.preview_actions(RunState.new_run(101), _shop_node(), catalog), "shop.barter.unknown_gu")
    assert_string_contains(card["unknown_note"], "结果未明")
    assert_false(card["known_risk"].is_empty())
    assert_false(card["command"].has("reward_id"))

func test_hungry_vine_relic_adds_next_node_feeding_pressure() -> void:
    var run := RunState.new_run(101)
    var result := Resolver.apply(run, {"type": "gain_relic", "relic_id": "hungry_vine_token"}, catalog)
    assert_eq(result["state"].estimate_feeding_materials(catalog)["feed_points"], 2)
```

- [x] **Step 2: Run the market/event test and verify failure**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_market_event_relic.gd`

Expected: FAIL because these data-driven cards and effects do not exist.

- [x] **Step 3: Implement complete preview/resolution pairs**

Define:

```text
shop.purchase.stone_shell       # known stone cost, known Gu
shop.lifespan.pulse_drum        # known lifespan cost, known Gu, can cause terminal death
shop.barter.unknown_gu          # known source Gu cost, observable "merchant sealed the cage" clue, Resolver-seeded reward
event.echo_cave.accept          # known health cost, unknown delayed soul drain clue
jade_cicada_shell               # +1 battle energy on first turn
hungry_vine_token               # gain a basic Gu; +1 feed_points upkeep per node
```

`ActionPreviewService` exposes exact public costs, declared direct risks, and an `unknown_note` for only the hidden delayed branch. `Resolver` selects unknown barter/event outcomes with the run seed, appends structured outcome keys, then causes `EncounterSessionResolver` to return `actual_changes` and fresh `next_available_actions`. Relic hooks are small `match`/data lookups at battle start and feeding estimation; do not create a generic script-evaluation system.

- [x] **Step 4: Run focused market and session tests**

Run: `./tools/test.ps1 -Test tests/unit/test_v3_market_event_relic.gd`

Run: `./tools/test.ps1 -Test tests/unit/test_encounter_session_resolver.gd`

Expected: PASS; all non-executable offers remain visible with a reason and remedy.

- [x] **Step 5: Commit the market/event/relic slice**

```powershell
git add data/relics.json data/events.json data/shops.json scripts/domain/content_catalog.gd scripts/domain/action_preview_service.gd scripts/domain/resolver.gd scripts/domain/encounter_session_resolver.gd tests/unit/test_v3_market_event_relic.gd
git commit -m "feat: add market event and relic slice"
```

### Task 8: Complete Fog Map Flow, Atomic Submission Defense, UI Integration, and Verification

**Files:**
- Modify: `scripts/domain/map_generator.gd`
- Modify: `scripts/domain/encounter_session_resolver.gd`
- Modify: `scripts/presentation/run_controller.gd`
- Modify: `scripts/presentation/map_view.gd`
- Modify: `scripts/presentation/encounter_view.gd`
- Modify: `scripts/presentation/battle_view.gd`
- Modify: `scripts/presentation/ending_view.gd`
- Modify: `README.md`
- Test: `tests/integration/test_v3_roguelike_vertical_slice.gd`
- Test: `tests/unit/test_v3_meta_and_terminal_run.gd`

**Consumes:** All preceding domain contracts.

**Produces:** Playable map route with limited fog, generic ActionCard UI commands, death/restart behavior, and full regression verification.

- [x] **Step 1: Write failing integration/atomicity tests**

```gdscript
func test_duplicate_action_card_submission_is_atomic() -> void:
    var state := RunState.new_run(101)
    var session := EncounterSessionResolver.start(_work_node())
    var card := _card(ActionPreviewService.preview_actions(state, _work_node(), catalog), "node.work")
    var first := EncounterSessionResolver.apply(state, session, {"type": "action_card", "action_id": card["id"], "state_version": card["state_version"]}, catalog, _work_node())
    var second := EncounterSessionResolver.apply(first["state"], first["session"], {"type": "action_card", "action_id": card["id"], "state_version": card["state_version"]}, catalog, _work_node())
    assert_true(first["result"]["ok"])
    assert_false(second["result"]["ok"])
    assert_eq(second["state"].stone, first["state"].stone)

func test_first_vertical_slice_travels_fogged_route_to_boss_and_resets_after_death() -> void:
    var controller := RunController.new()
    controller.start_new_run(101)
    assert_true(controller.visible_route_nodes().size() < controller.route.size())
    controller.force_death_for_test("test_blow")
    assert_eq(controller.state.terminal_state, "dead")
    controller.start_new_run(101)
    assert_eq(controller.state.refined_gu_ids, ["small_light_gu"])
```

- [x] **Step 2: Run the integration test and verify failure**

Run: `./tools/test.ps1 -Test tests/integration/test_v3_roguelike_vertical_slice.gd`

Expected: FAIL because UI/controller still uses `battle_action_card` and the full reset/fog assertions do not exist.

- [x] **Step 3: Integrate without putting rules in scenes**

Map rendering shows only current reachable nodes and the next two layers; remaining nodes are opaque fog labels without type/reward details. `RunController` owns route and battle context, sends only generic `action_card` submissions, and calls Resolver/Preview after every result. `BattleView` renders cards from `preview_battle_actions` with stable fixed-size controls, disabled state, tooltip containing `block_reason`/`remedy_hints`, known cost/risk/gain, and no direct domain mutation. `EncounterView` follows the same card rendering contract. `EndingView` displays the existing death report plus player-known structured outcome facts; it never reads hidden enemy state.

Document launch and validation commands in `README.md`; do not state the game is complete until those commands run successfully.

- [x] **Step 4: Run all automated verification**

Run: `./tools/test.ps1 -Suite unit`

Run: `./tools/test.ps1 -Suite integration`

Run: `./tools/check.ps1`

Run: `git diff --check`

Expected: all tests PASS, Godot parses headlessly, and `git diff --check` has no output.

- [ ] **Step 5: Manual Windows acceptance run**

1. Start a seed `101` run; verify only the immediate route layers are visible.
2. Enter combat; confirm drawn action cards show true-essence cost, public enemy intent, observable reaction clue, and the active hand does not vanish after unrelated state changes.
3. Play a duration card then end turn until expiration; confirm its source releases from soul occupancy.
4. Buy or barter for a Gu, leave a node to see one total feeding bill, then attempt the moonlight recipe/free mix.
5. Choose the lifespan market deal at one lifespan; verify death report and a newly started run has only the starting Gu while MetaProgress retains the discovered codex entry.

- [x] **Step 6: Commit the verified vertical slice**

```powershell
git add scripts/domain/map_generator.gd scripts/domain/encounter_session_resolver.gd scripts/presentation/run_controller.gd scripts/presentation/map_view.gd scripts/presentation/encounter_view.gd scripts/presentation/battle_view.gd scripts/presentation/ending_view.gd README.md tests/integration/test_v3_roguelike_vertical_slice.gd tests/unit/test_v3_meta_and_terminal_run.gd
git commit -m "feat: complete gu card roguelike vertical slice"
```

## Plan Self-Review

- **Spec coverage:** Task 1 establishes single-run versus meta separation and no Gu count cap. Task 2 adds data-driven Gu-card mapping, feeding resources, kill-move metadata, and deck hash. Task 3 resolves the performance and version-granularity issues through cached cards and battle-local hand versions. Task 4 covers duration cleanup, sequence state, soul control, and fully defined aptitude backlash factors. Task 5 covers feeding, deletion versus destruction, and permanent death. Task 6 provides recipe/free-mix outcomes and progressive knowledge. Task 7 supplies the Bazaar-style trade, hidden-but-hinted event, and two relics. Task 8 finishes fog map/UI/atomic submission integration and verification.
- **Audit fixes:** The plan explicitly implements `deck_generation_hash`, `hand_version`, defined aptitude factor data, material IDs for feeding, `pending_kill_move_state`, and `MetaProgress.unlocked_random_outcomes` before their consumers.
- **Boundary check:** Preview never selects RNG outcomes; Resolver re-finds and executes the internal command for every ActionCard; battle cards validate against the battle hand rather than global state; no UI component builds a business command.
- **Scope check:** The plan deliberately limits gameplay to the first mortal vertical slice. Higher ranks, playable immortality/disasters, broad content pools, and permanent numerical growth are excluded.
- **Placeholder scan:** Searched this plan for `TODO`, `TBD`, `implement later`, and `pass`; no deferred implementation marker remains. The explanatory `pass` in Task 4 explicitly requires its replacement with the described concrete loop and is not a deliverable placeholder.
