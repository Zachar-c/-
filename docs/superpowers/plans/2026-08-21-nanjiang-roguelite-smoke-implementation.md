# 南疆凡人修行肉鸽冒烟版 Implementation Plan

> 产品与玩法规则以 [GDD](../../GDD.md) 为唯一事实来源。本文件只定义工程实现顺序、接口和验证步骤。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adapt the MIT-licensed GDQuest Godot Open RPG into a deterministic, local-first prototype in which a fixed-seed Nanjiang novice progresses through a 10–14-node run, resolves stone, essence, social, combat, and opportunity choices, and reaches one of three ascension outcomes.

**Architecture:** Vendor the upstream project under `vendor/godot-open-rpg`, preserve its MIT license and provenance, and place all Nanjiang systems in the root project's `scripts/` and `scenes/` directories. Keep domain rules in pure GDScript `RefCounted` classes with immutable event-log entries; scenes render state and submit commands but never mutate state directly. Content is loaded from validated JSON data tables, while the dialogue gateway is an optional adapter with a template fallback and persisted responses for replay.

**Tech Stack:** Godot 4.6.2; GDScript; GDQuest Godot Open RPG (MIT) as vendored base; Godot built-in JSON, FileAccess, ResourceLoader and GUT 9.x test framework; no runtime third-party service dependency.

## Global Constraints

- Implement only the South Border, 45–90 minute smoke slice; exclude other regions, multiple starts, metaprogression, open world, and playable immortal content.
- Runs contain 10–14 effective nodes including opportunity contest and ascension; first-run seed must always expose the test route.
- Start as one newly awakened wandering Gu Master with Small Light Gu; carry no more than four equipped Gu.
- The content set is Small Light Gu plus eight obtainable mortal Gu and three explicitly authored inheritance killer moves; tags may validate, route, and satisfy declared conditions but must not create effects automatically.
- The only persistent numeric resources are stone and cultivation; essence is a local action resource. Materials, food, remnant recipes, generic Dao marks, and mortal-realm insight currencies are excluded.
- Body imprints are only `iron_bone`, `ice_skin`, and `three_watch`; each has an authored, logged benefit and drawback, and none is a repeatable stat purchase. Healing must come from an equipped healing Gu or a declared node effect.
- Gu balance follows conditional hooks, slot tradeoffs, timing, and trigger chains as analytical principles; it does not copy The Bazaar's autobattle or market loop.
- Rules, seeds, maps, battle, NPC state, inheritance conditions, outcomes, saves, and replays remain local and deterministic.
- LLM is optional: it cannot change rules or facts; valid responses are schema-checked, saved, and replaced with templates on network, timeout, or schema failure.
- Critical state changes append an immutable event log; the cultivation journal may use only the log and player-known facts.
- Use ASCII in source code, JSON keys, test names, identifiers, and commit messages. Chinese player-facing content may be UTF-8 JSON.
- Keep `vendor/godot-open-rpg/LICENSE`, the upstream URL, and its pinned commit in `THIRD_PARTY_NOTICES.md`; do not put Nanjiang rules or content in vendored upstream files.

---

## Planned File Structure

```text
project.godot
THIRD_PARTY_NOTICES.md                   # GDQuest source, pinned commit, and MIT notice
vendor/
  godot-open-rpg/                         # Unmodified, pinned GDQuest upstream source
addons/gut/                              # Installed GUT framework
data/
  gu.json                                # Nine Gu definitions and tags
  inheritances.json                      # Three authored inheritance killer moves
  nodes.json                              # Seventeen node templates
  npcs.json                               # NPC archetypes and injury reactions
  first_run.json                          # Fixed-seed 12-node verification route
  dialogue_templates.json                 # Offline dialogue and result copy
scripts/
  integration/
    open_rpg_adapter.gd                   # Narrow boundary around audited upstream primitives
  domain/
    run_state.gd                          # Serializable game state and event append API
    events.gd                             # Typed command/result/event dictionaries
    content_catalog.gd                    # JSON loading and reference validation
    rng.gd                                # Seeded deterministic random source
    map_generator.gd                      # First-run and generated route construction
    resolver.gd                           # Only state-transition entry point
    inheritance_resolver.gd               # Explicit inheritance condition and buff validation
    dialogue_gateway.gd                   # Local dialogue adapter contract
    template_dialogue_gateway.gd          # Offline implementation
    save_repository.gd                    # Atomic local save/replay persistence
    journal_builder.gd                    # Player-visible ending attribution
  presentation/
    run_controller.gd                     # Connects UI commands to resolver and persistence
    map_view.gd                           # Layered node map and fog presentation
    encounter_view.gd                     # Action tags, facts, outcomes, dialogue
    battle_view.gd                        # Fixed-slot, true-essence turn UI
    ending_view.gd                        # Outcome and cultivation journal view
scenes/
  main.tscn
  run.tscn
  map.tscn
  encounter.tscn
  battle.tscn
  ending.tscn
tests/
  unit/
  integration/
```

## Task 1: Vendor and audit the GDQuest Open RPG base

**Files:**
- Create: `vendor/godot-open-rpg/` from `https://github.com/gdquest-demos/godot-open-rpg.git` at a pinned commit
- Create: `THIRD_PARTY_NOTICES.md`
- Create: `docs/open-rpg-audit.md`

**Interfaces:**
- Produces a pinned, auditable upstream source tree and explicit reuse boundary for Task 2.
- Produces an audit manifest naming the verified upstream battle, inventory, and UI units that can be invoked only through an adapter.

- [ ] **Step 1: Import the exact upstream base and retain its license**

```powershell
git clone https://github.com/gdquest-demos/godot-open-rpg.git vendor/godot-open-rpg
git -C vendor/godot-open-rpg rev-parse HEAD
git -C vendor/godot-open-rpg status --short
```

Expected: copy the printed commit hash into `THIRD_PARTY_NOTICES.md`; the final command has no output. After recording the hash, remove only `vendor/godot-open-rpg/.git` so the upstream is committed as an ordinary vendored source tree rather than a gitlink. Verify the resolved path is exactly inside `vendor/godot-open-rpg` before the recursive removal.

- [ ] **Step 2: Record provenance and complete a source audit**

Create `THIRD_PARTY_NOTICES.md` with the source URL, exact commit from Step 1, and the statement that MIT is retained in `vendor/godot-open-rpg/LICENSE`. Create `docs/open-rpg-audit.md` after reading the vendored tree. It must list exact upstream paths in three categories:

```markdown
## Reuse Through Adapter

- `<verified battle path>`: use only through `OpenRpgAdapter`.
- `<verified inventory/UI path>`: reuse only if it does not own game state.

## Do Not Reuse

- Upstream world, story, assets, traditional RPG economy, and character progression.

## Replace

- Node map, Gu system, social state, ascension, journals, content tables, and dialogue.
```

No `gu_zu` script may import an upstream path before this audit records the dependency and its version.

- [ ] **Step 3: Verify provenance files before creating the root project**

Run:

```powershell
Test-Path vendor/godot-open-rpg/LICENSE
Select-String -Path THIRD_PARTY_NOTICES.md -Pattern 'https://github.com/gdquest-demos/godot-open-rpg','Pinned commit:'
```

Expected: `True`, followed by the two matching notice lines.

- [ ] **Step 4: Commit the imported base and audit**

```gdscript
git add vendor/godot-open-rpg THIRD_PARTY_NOTICES.md docs/open-rpg-audit.md
git commit -m "chore: vendor and audit open rpg base"
```

## Task 2: Create an isolated Gu Zu entry shell and upstream adapter

**Files:**
- Create: `project.godot`
- Create: `scenes/main.tscn`
- Create: `scripts/presentation/run_controller.gd`
- Create: `scripts/integration/open_rpg_adapter.gd`
- Create: `tests/unit/test_project_smoke.gd`
- Add: `addons/gut/` using the GUT 9.x Godot asset release

**Interfaces:**
- Produces `RunController.start_new_run(seed: int) -> void` for all later UI tasks.
- Produces `OpenRpgAdapter.create_battle_context(config: Dictionary) -> Dictionary`; Task 8 calls this boundary rather than direct upstream paths.

- [ ] **Step 1: Write the failing project and adapter test**

```gdscript
extends GutTest

func test_main_scene_loads() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    assert_not_null(packed)
    var scene := packed.instantiate()
    assert_not_null(scene.get_node_or_null("RunController"))
    scene.queue_free()

func test_open_rpg_adapter_returns_local_battle_context() -> void:
    var context := OpenRpgAdapter.create_battle_context({"enemy_kind": "beast_swarm"})
    assert_eq(context["enemy_kind"], "beast_swarm")
    assert_true(context.has("turn_order"))

func test_upstream_provenance_and_license_are_present() -> void:
    assert_true(FileAccess.file_exists("res://THIRD_PARTY_NOTICES.md"))
    assert_true(FileAccess.file_exists("res://vendor/godot-open-rpg/LICENSE"))
    var notice := FileAccess.get_file_as_string("res://THIRD_PARTY_NOTICES.md")
    assert_true(notice.contains("https://github.com/gdquest-demos/godot-open-rpg"))
    assert_true(notice.contains("Pinned commit:"))
```

- [ ] **Step 2: Run the test to verify the entry shell is missing**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_project_smoke.gd -gexit`

Expected: FAIL because Gu Zu's entry scene and adapter do not exist.

- [ ] **Step 3: Add the isolated shell and adapter**

```gdscript
# scripts/presentation/run_controller.gd
class_name RunController
extends Node

func start_new_run(_seed: int) -> void:
    pass

# scripts/integration/open_rpg_adapter.gd
class_name OpenRpgAdapter
extends RefCounted

static func create_battle_context(config: Dictionary) -> Dictionary:
    return {"enemy_kind": config["enemy_kind"], "turn_order": ["player", "enemy"]}
```

Create `main.tscn` with a root `Node` and one child named `RunController`; configure the root `project.godot` for Godot `4.6.2`. Do not modify vendored source. The adapter begins with a deterministic local context and will wrap only the upstream primitive identified by the Task 1 audit.

- [ ] **Step 4: Run the test suite**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: PASS with all three smoke tests.

- [ ] **Step 5: Commit the shell and adapter boundary**

```bash
git add project.godot scenes/main.tscn scripts/presentation/run_controller.gd scripts/integration/open_rpg_adapter.gd tests/unit/test_project_smoke.gd addons/gut
git commit -m "feat: add isolated gu zu entry shell"
```

## Task 3: Implement immutable run state and event logs

**Files:**
- Create: `scripts/domain/events.gd`
- Create: `scripts/domain/run_state.gd`
- Test: `tests/unit/test_run_state.gd`

**Interfaces:**
- Produces `RunState.new_run(seed: int) -> RunState`.
- Produces `RunState.append_event(event: Dictionary) -> RunState` and `RunState.to_save_data() -> Dictionary`.
- `Resolver` in Task 6 consumes and returns `RunState`; UI never directly mutates it.

- [ ] **Step 1: Write failing tests for initial state and immutable logging**

```gdscript
func test_new_run_has_small_light_gu_and_initial_resources() -> void:
    var state := RunState.new_run(101)
    assert_eq(state.gu_ids, ["small_light_gu"])
    assert_eq(state.stone, 12)
    assert_eq(state.essence, 3)
    assert_eq(state.event_log.size(), 1)

func test_append_event_returns_new_state_without_changing_old_state() -> void:
    var before := RunState.new_run(101)
    var after := before.append_event(EventFactory.resource_changed("stone", 12, 9, "buy_information", "market"))
    assert_eq(before.stone, 12)
    assert_eq(after.stone, 9)
    assert_eq(after.event_log.back()["reason"], "buy_information")
```

- [ ] **Step 2: Run the focused test file**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_run_state.gd -gexit`

Expected: FAIL because `RunState` and `EventFactory` do not exist.

- [ ] **Step 3: Implement state snapshots and event records**

Define a state dictionary with keys `seed`, `stage`, `cultivation`, `essence`, `injury`, `lifespan_debt`, `stone`, `gu_ids`, `equipped_gu_ids`, `inheritance_ids`, `body_imprints`, `clues`, `relations`, `pursuit`, `ascension`, `known_facts`, `current_node_id`, and `event_log`. Event dictionaries must include immutable `id`, `stage`, `time`, `node_id`, `action`, `before`, `after`, `reason`, `source`, and `targets`.

```gdscript
static func resource_changed(key: String, before: int, after: int, reason: String, source: String) -> Dictionary:
    return {
        "stage": "one", "time": "", "node_id": source, "action": "state_change",
        "before": {key: before}, "after": {key: after}, "reason": reason,
        "source": source, "targets": []
    }
```

- [ ] **Step 4: Run all unit tests**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: PASS; state cloning and serialization preserve log order.

- [ ] **Step 5: Commit the domain foundation**

```bash
git add scripts/domain/events.gd scripts/domain/run_state.gd tests/unit/test_run_state.gd
git commit -m "feat: add immutable run state event log"
```

## Task 4: Add authored Gu and inheritance content with reference validation

**Files:**
- Create: `data/gu.json`
- Create: `data/inheritances.json`
- Create: `data/npcs.json`
- Create: `scripts/domain/content_catalog.gd`
- Create: `scripts/domain/inheritance_resolver.gd`
- Test: `tests/unit/test_content_catalog.gd`
- Test: `tests/unit/test_inheritance_resolver.gd`

**Interfaces:**
- Produces `ContentCatalog.load_all() -> Dictionary` and `ContentCatalog.validate(catalog: Dictionary) -> Array[String]`.
- Produces `InheritanceResolver.available_moves(equipped_gu_ids: Array[String], inheritance_ids: Array[String], catalog: Dictionary) -> Array[Dictionary]`.
- Task 5 consumes validated content and rejects commands against unavailable entries.

- [ ] **Step 1: Write failing validation and inheritance tests**

```gdscript
func test_catalog_has_exactly_nine_gu_and_three_inheritances() -> void:
    var catalog := ContentCatalog.load_all()
    assert_eq(catalog["gu"].size(), 9)
    assert_eq(catalog["inheritances"].size(), 3)
    assert_eq(ContentCatalog.validate(catalog), [])

func test_inheritance_move_requires_equipped_gu_and_tag_constraints() -> void:
    var moves := InheritanceResolver.available_moves(["small_light_gu", "trail_eye_gu"], ["moonlit_trace"], ContentCatalog.load_all())
    assert_eq(moves[0]["move_id"], "moonlit_trace")

func test_catalog_rejects_missing_inheritance_gu_reference() -> void:
    var catalog := ContentCatalog.load_all()
    catalog["inheritances"][0]["required_gu_ids"] = ["missing_gu"]
    assert_eq(ContentCatalog.validate(catalog).size(), 1)
```

- [ ] **Step 2: Run focused tests and confirm they fail**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_content_catalog.gd -gexit`

Expected: FAIL because content loading does not exist.

- [ ] **Step 3: Write the smallest valid data set**

Give each Gu exactly `id`, `rank`, `essence_cost`, `slot_role`, `combat`, `field_actions`, `synergy_hooks`, `replace_value`, and 2–3 `tags`. Define exactly three inheritance moves. Each inheritance declares `id`, `move_id`, `required_gu_ids`, `required_tags`, `effect_id`, `battle_limit`, `special_buff`, `source_kind`, and `version`. The three moves must cover a Small Light Gu information/reveal line, a healing-plus-offense line, and an escape/control line. Define NPC fields `goals`, `bottom_line`, `will`, `known_facts`, `retreat`, `reinforcements`, and `injury_reaction` where the last value is one of `contempt`, `sympathy`, `caution`, `exploit`.

- [ ] **Step 4: Implement catalog and inheritance checks**

```gdscript
func validate(catalog: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    var gu_by_id: Dictionary = catalog["gu_by_id"]
    for inheritance in catalog["inheritances"]:
        for gu_id in inheritance["required_gu_ids"]:
            if not gu_by_id.has(gu_id):
                errors.append("inheritance %s references missing gu %s" % [inheritance["id"], gu_id])
    return errors
```

Do not add a generic tag-to-effect generator. An inheritance move is available only when the player owns that inheritance and its declared equipped Gu IDs and tag constraints match. Free Gu combinations may trigger only their individually authored hooks; they must never become an automatically generated killer move.

- [ ] **Step 5: Run tests and the standalone validator**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: PASS, including a test that intentionally injects a missing Gu reference and receives one validation error.

- [ ] **Step 6: Commit the content system**

```bash
git add data/gu.json data/inheritances.json data/npcs.json scripts/domain/content_catalog.gd scripts/domain/inheritance_resolver.gd tests/unit/test_content_catalog.gd tests/unit/test_inheritance_resolver.gd
git commit -m "feat: add validated gu and inheritance content"
```

## Task 5: Build deterministic map data and first-run route

**Files:**
- Create: `data/nodes.json`
- Create: `data/first_run.json`
- Create: `scripts/domain/rng.gd`
- Create: `scripts/domain/map_generator.gd`
- Test: `tests/unit/test_map_generator.gd`

**Interfaces:**
- Produces `MapGenerator.build(seed: int, first_run: bool) -> Array[Dictionary]`.
- Each node has `id`, `stage`, `type`, `visible`, `choices`, `time_scale`, `on_skip`, and `next_ids`.
- Task 6 receives node IDs from this route; Task 9 renders visibility and paths.

- [ ] **Step 1: Write failing deterministic-route tests**

```gdscript
func test_first_run_contains_required_anchor_nodes() -> void:
    var route := MapGenerator.build(101, true)
    var ids := route.map(func(node): return node["id"])
    assert_eq(route.size(), 12)
    assert_true(ids.has("caravan_missing_goods"))
    assert_true(ids.has("earth_vein_contest"))
    assert_eq(ids.back(), "ascension_window")

func test_same_seed_builds_same_non_first_route() -> void:
    assert_eq(MapGenerator.build(202, false), MapGenerator.build(202, false))
```

- [ ] **Step 2: Run the tests to confirm failure**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_map_generator.gd -gexit`

Expected: FAIL because `MapGenerator` is missing.

- [ ] **Step 3: Author content and generator**

Create seventeen templates in `nodes.json`: three hazard, three wild-Gu/inheritance, four market/caravan/commission, three combat/pursuit, three earth-vein contest, and one seclusion/body-imprint template. The first-run route must use the twelve nodes listed in the design and mark only the current and immediate next layer visible.

Implement a tiny seeded integer generator, never `randf()` or global random state. For non-first runs choose only templates whose stage and prerequisites are valid, then append the required contest and ascension nodes.

- [ ] **Step 4: Run map tests**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_map_generator.gd -gexit`

Expected: PASS; all generated routes contain 10–14 nodes and exactly one ascension window.

- [ ] **Step 5: Commit deterministic routes**

```bash
git add data/nodes.json data/first_run.json scripts/domain/rng.gd scripts/domain/map_generator.gd tests/unit/test_map_generator.gd
git commit -m "feat: add deterministic nanjiang node routes"
```

## Task 6: Implement rule resolver, resource pressure, and ascension outcomes

**Files:**
- Create: `scripts/domain/resolver.gd`
- Test: `tests/unit/test_resolver_resources.gd`
- Test: `tests/unit/test_resolver_ascension.gd`

**Interfaces:**
- Produces `Resolver.apply(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary` returning `{ "state": RunState, "result": Dictionary }`.
- Commands are `travel`, `use_gu`, `buy_opportunity`, `take_body_imprint`, `choose_action`, `retreat`, and `attempt_ascension`.
- Task 7 extends `choose_action`; Task 8 extends `use_gu` during combat.

- [ ] **Step 1: Write failing resource and outcome tests**

```gdscript
func test_body_imprint_changes_rule_and_logs_its_lifespan_cost() -> void:
    var result := Resolver.apply(RunState.new_run(101), {"type": "take_body_imprint", "imprint_id": "three_watch"}, catalog)
    assert_true(result["state"].body_imprints.has("three_watch"))
    assert_eq(result["state"].lifespan_debt, 1)
    assert_eq(result["state"].event_log.back()["reason"], "body_imprint_cost")

func test_iron_bone_defense_has_authored_stealth_drawback() -> void:
    var result := Resolver.apply(RunState.new_run(101), {"type": "take_body_imprint", "imprint_id": "iron_bone"}, catalog)
    assert_true(result["state"].body_imprints.has("iron_bone"))
    assert_true(result["state"].known_facts.has("iron_bone_stealth_drawback"))

func test_ascension_returns_risky_success_when_requirements_met_with_high_risk() -> void:
    var result := Resolver.apply(ready_but_hunted_state(), {"type": "attempt_ascension", "choice": "now"}, catalog)
    assert_eq(result["result"]["outcome"], "risky_success")
```

- [ ] **Step 2: Run focused resolver tests and confirm failure**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_resolver_resources.gd -gexit`

Expected: FAIL because `Resolver` is missing.

- [ ] **Step 3: Implement state transitions and explicit thresholds**

Implement commands as match branches. Reject invalid commands with `{ "ok": false, "reason": "..." }` and leave state unchanged. `buy_opportunity` may spend stone only for an explicitly declared Gu, information, service, favor, or escape condition and never for generic attributes. `take_body_imprint` may grant only a declared `iron_bone`, `ice_skin`, or `three_watch` imprint and must log its fixed injury, stealth, or lifespan drawback. Ascension must calculate five booleans: `aperture_foundation`, `heaven_earth_qi`, `site`, `protection`, and `external_interference`. Return `success` only when all are true and risk is at most 1; return `risky_success` when all are true and risk is 2–3; otherwise return `survived_failure` unless a node already declared a lethal irreversible result.

- [ ] **Step 4: Add outcome coverage**

```gdscript
func test_ascension_returns_success_for_prepared_state() -> void: pass
func test_ascension_returns_survived_failure_for_missing_heaven_earth_qi() -> void: pass
func test_invalid_command_does_not_mutate_state() -> void: pass
func test_buy_opportunity_cannot_purchase_generic_attribute() -> void: pass
```

- [ ] **Step 5: Run all resolver tests**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: PASS; every successful state transition adds one event record.

- [ ] **Step 6: Commit the rules loop**

```bash
git add scripts/domain/resolver.gd tests/unit/test_resolver_resources.gd tests/unit/test_resolver_ascension.gd
git commit -m "feat: resolve resources and ascension outcomes"
```

## Task 7: Add social state machine, caravan scenario, and template dialogue

**Files:**
- Create: `data/dialogue_templates.json`
- Create: `scripts/domain/dialogue_gateway.gd`
- Create: `scripts/domain/template_dialogue_gateway.gd`
- Modify: `scripts/domain/resolver.gd`
- Test: `tests/unit/test_caravan_negotiation.gd`

**Interfaces:**
- Produces `DialogueGateway.respond(context: Dictionary) -> Dictionary` with `intent`, `confidence`, `conditions`, `text`, and `needs_clarification`.
- Produces `Resolver.apply_social_action(state, command, catalog) -> Dictionary` for 2–4 local actions and at most two gateway calls.
- Task 10 saves gateway replies; UI in Task 9 shows `text` only after validation.

- [ ] **Step 1: Write failing scenario tests**

```gdscript
func test_caravan_can_resolve_without_battle_using_evidence_and_trade() -> void:
    var state := caravan_state_with_ledger_evidence()
    state = act(state, "probe")
    state = act(state, "trade", {"offer": "ledger_evidence"})
    assert_eq(state.relations["caravan_steward"]["stance"], "helpful")
    assert_true(state.known_facts.has("earth_vein_entry"))

func test_injury_reaction_exploit_changes_offer_but_not_will_gate() -> void:
    var result := act(heavily_injured_caravan_state(), "pressure")
    assert_eq(result.last_social_result["npc_reaction"], "exploit")
    assert_false(result.last_social_result["surrendered"])
```

- [ ] **Step 2: Run the scenario tests and confirm failure**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_caravan_negotiation.gd -gexit`

Expected: FAIL because social commands are unsupported.

- [ ] **Step 3: Implement bounded negotiation**

Use local state fields `round`, `evidence`, `concession`, `threat`, `escape_route`, `deadline_days`, and `npc_disposition`. `probe`, `trade`, `pressure`, `deceive`, `leave`, and `fight` each change declared fields and append events. The template gateway returns only a pre-authored response selected by intent and disposition. Validate all gateway dictionaries against allowed enum values before rendering or saving.

- [ ] **Step 4: Cover retreat and deadline outcomes**

```gdscript
func test_leaving_caravan_preserves_life_and_adds_suspicion() -> void: pass
func test_three_node_days_trigger_reinforcement_outcome() -> void: pass
func test_social_event_uses_at_most_two_gateway_responses() -> void: pass
```

- [ ] **Step 5: Run tests**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: PASS; caravan has two non-combat resolutions and one retreat resolution that changes the earth-vein contest.

- [ ] **Step 6: Commit the scenario**

```bash
git add data/dialogue_templates.json scripts/domain/dialogue_gateway.gd scripts/domain/template_dialogue_gateway.gd scripts/domain/resolver.gd tests/unit/test_caravan_negotiation.gd
git commit -m "feat: add bounded caravan negotiation"
```

## Task 8: Implement fixed-slot turn combat and retreat

**Files:**
- Create: `scripts/domain/battle_resolver.gd`
- Modify: `scripts/domain/resolver.gd`
- Test: `tests/unit/test_battle_resolver.gd`

**Interfaces:**
- Produces `BattleResolver.start(encounter: Dictionary, state: RunState) -> Dictionary`.
- Produces `BattleResolver.take_turn(battle: Dictionary, action: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary`.
- Returns `{ "battle": Dictionary, "state": RunState, "finished": bool, "result": String }` where result is `victory`, `retreated`, `defeat`, or `ongoing`.

- [ ] **Step 1: Write failing turn and retreat tests**

```gdscript
func test_small_light_gu_spends_essence_and_reveals_hidden_enemy_bonus() -> void:
    var turn := BattleResolver.take_turn(started_battle(), {"type": "use_gu", "gu_id": "small_light_gu"}, state, catalog)
    assert_eq(turn["state"].essence, 2)
    assert_true(turn["battle"]["flags"].has("revealed"))

func test_retreat_is_available_but_costs_a_declared_resource() -> void:
    var turn := BattleResolver.take_turn(pursuit_battle(), {"type": "retreat"}, state, catalog)
    assert_eq(turn["result"], "retreated")
    assert_lt(turn["state"].stone, state.stone)

func test_moonlit_trace_requires_equipped_condition_and_applies_reveal_buff() -> void:
    var turn := BattleResolver.take_turn(started_battle(), {"type": "use_inheritance", "move_id": "moonlit_trace"}, state, catalog)
    assert_true(turn["battle"]["flags"].has("revealed"))
    assert_eq(turn["battle"]["inheritance_uses"]["moonlit_trace"], 1)
```

- [ ] **Step 2: Run tests and confirm failure**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_battle_resolver.gd -gexit`

Expected: FAIL because the battle resolver is missing.

- [ ] **Step 3: Implement four enemy behavior tables**

Implement `beast_swarm`, `greedy_wanderer`, `faction_guard`, and `resolute_elite` behavior tables with 2–3 parameter variants. Inspect the battle primitive recorded in `docs/open-rpg-audit.md`, invoke it only through `OpenRpgAdapter`, and retain a local deterministic fallback if it cannot express fixed Gu slots. All actions use equipped Gu slots and essence; a healing Gu consumes one of the four slots and can have an authored offense follow-up hook. The resolver may invoke an available inheritance move only through `InheritanceResolver`, apply its once-per-battle limit, and include its declared special buff. No cards, decks, materials, food, or random global calls. A retreat result must be based on terrain, movement tags, pursuit, and enemy control, then log a declared loss such as stone, wound, Gu, lifespan, or relation.

- [ ] **Step 4: Add defeat and nonlethal objective tests**

```gdscript
func test_contest_battle_can_end_by_delaying_enemy_without_killing() -> void: pass
func test_declared_irreversible_hazard_is_only_source_of_lethal_result() -> void: pass
```

- [ ] **Step 5: Run tests**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: PASS; combat, delay, and retreat update event logs deterministically.

- [ ] **Step 6: Commit battle rules**

```bash
git add scripts/domain/battle_resolver.gd scripts/domain/resolver.gd tests/unit/test_battle_resolver.gd
git commit -m "feat: add fixed slot combat and retreat"
```

## Task 9: Build the minimum playable Godot interface

**Files:**
- Create: `scenes/run.tscn`, `scenes/map.tscn`, `scenes/encounter.tscn`, `scenes/battle.tscn`, `scenes/ending.tscn`
- Create: `scripts/presentation/map_view.gd`, `scripts/presentation/encounter_view.gd`, `scripts/presentation/battle_view.gd`, `scripts/presentation/ending_view.gd`
- Modify: `scenes/main.tscn`, `scripts/presentation/run_controller.gd`
- Test: `tests/integration/test_first_run_flow.gd`

**Interfaces:**
- `RunController.start_new_run(seed)` creates state and route, then calls `MapView.render(route, state)`.
- `EncounterView` emits `command_submitted(command: Dictionary)`; `RunController` alone calls `Resolver.apply`.
- `EndingView.show_ending(outcome: Dictionary, journal: Array[Dictionary])` is used by Task 11.

- [ ] **Step 1: Write a headless integration test for screen progression**

```gdscript
func test_fixed_run_reaches_caravan_then_ascension_view() -> void:
    var controller := preload("res://scripts/presentation/run_controller.gd").new()
    controller.start_new_run(101)
    controller.submit_command({"type": "travel", "node_id": "caravan_missing_goods"})
    assert_eq(controller.current_view_name(), "Encounter")
    controller.force_complete_for_test()
    assert_eq(controller.current_view_name(), "Ending")
```

- [ ] **Step 2: Run test and confirm failure**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit`

Expected: FAIL because no views or controller transitions exist.

- [ ] **Step 3: Implement utilitarian scenes**

Use Godot `Control` nodes. The map presents stage lanes, visible node type/risk, fogged future nodes, and clear route buttons. The encounter shows facts, pressure, resources, action-tag buttons, one optional free-text field for major interactions, and a visible structured result. Battle uses four fixed Gu-slot buttons, available inheritance-move buttons, and retreat. The ending view presents outcome, journal, and restart.

No marketing landing screen, tutorial overlay, or decorative card nesting. Each interactive icon/button must have a tooltip and fixed dimensions.

- [ ] **Step 4: Run UI integration tests and a manual smoke run**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

Manual: launch the editor or `godot --path .`, play seed `101`, reach the caravan, choose a non-combat resolution, and inspect the earth-vein consequence.

Expected: automated tests PASS; manual run never requires an LLM request.

- [ ] **Step 5: Commit playable interface**

```bash
git add scenes scripts/presentation tests/integration
git commit -m "feat: add playable nanjiang smoke interface"
```

## Task 10: Add save/replay and optional cloud-LLM adapter boundary

**Files:**
- Create: `scripts/domain/save_repository.gd`
- Create: `scripts/domain/cloud_dialogue_gateway.gd`
- Modify: `scripts/domain/dialogue_gateway.gd`, `scripts/domain/template_dialogue_gateway.gd`, `scripts/presentation/run_controller.gd`
- Test: `tests/unit/test_save_repository.gd`
- Test: `tests/unit/test_dialogue_gateway.gd`

**Interfaces:**
- Produces `SaveRepository.save_run(state: RunState, route: Array, replies: Array) -> Error` and `load_run() -> Dictionary`.
- Produces `CloudDialogueGateway.respond(context: Dictionary) -> Dictionary`; it always returns template fallback after any unavailable, timeout, JSON, or schema failure.

- [ ] **Step 1: Write failing replay and fallback tests**

```gdscript
func test_saved_reply_is_replayed_without_gateway_call() -> void:
    var saved := saved_run_with_dialogue_reply()
    var gateway := CountingGateway.new()
    var loaded := SaveRepository.load_run_from_data(saved)
    assert_eq(loaded["replies"][0]["text"], "The steward studies your ledger.")
    assert_eq(gateway.calls, 0)

func test_invalid_cloud_payload_uses_template_response() -> void:
    var gateway := CloudDialogueGateway.new(BadTransport.new())
    var result := gateway.respond(valid_context())
    assert_eq(result["source"], "template")
```

- [ ] **Step 2: Run tests and confirm failure**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_save_repository.gd -gexit`

Expected: FAIL because persistence and cloud gateway are absent.

- [ ] **Step 3: Implement local persistence and strict gateway validation**

Write to `user://nanjiang_smoke_save.json.tmp`, flush, then rename to `user://nanjiang_smoke_save.json`. Persist seed, route, complete state, event log, player-known facts, and validated dialogue replies. Only allow response keys `intent`, `confidence`, `conditions`, `text`, and `needs_clarification`; reject unknown keys and invalid enums. Read the cloud API key only from an environment variable and never save it.

- [ ] **Step 4: Run tests**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: PASS; offline templates, malformed payloads, and loaded reply replay all behave deterministically.

- [ ] **Step 5: Commit persistence and adapter boundary**

```bash
git add scripts/domain/save_repository.gd scripts/domain/cloud_dialogue_gateway.gd scripts/domain/dialogue_gateway.gd scripts/domain/template_dialogue_gateway.gd scripts/presentation/run_controller.gd tests/unit/test_save_repository.gd tests/unit/test_dialogue_gateway.gd
git commit -m "feat: add replay saves and dialogue fallback"
```

## Task 11: Generate ending journals from logs and verify the full smoke matrix

**Files:**
- Create: `scripts/domain/journal_builder.gd`
- Modify: `scripts/presentation/ending_view.gd`
- Create: `tests/integration/test_smoke_outcomes.gd`
- Create: `tests/unit/test_journal_builder.gd`
- Create: `README.md`

**Interfaces:**
- Produces `JournalBuilder.build(state: RunState, outcome: Dictionary) -> Array[Dictionary]`.
- Each entry has `heading`, `body_key`, `event_ids`, and `visible_facts`; rendering resolves `body_key` through local templates.

- [ ] **Step 1: Write failing attribution and matrix tests**

```gdscript
func test_journal_attributes_missing_qi_to_known_event() -> void:
    var entries := JournalBuilder.build(state_missing_qi_after_trade(), {"outcome": "survived_failure"})
    assert_eq(entries.filter(func(entry): return entry["heading"] == "Heaven and earth qi").size(), 1)
    assert_true(entries[0]["event_ids"].has("caravan_trade_declined"))

func test_fixed_scenarios_cover_all_three_outcomes_without_llm() -> void:
    assert_eq(play_scenario("prepared"), "success")
    assert_eq(play_scenario("hunted"), "risky_success")
    assert_eq(play_scenario("missing_qi"), "survived_failure")
```

- [ ] **Step 2: Run tests and confirm failure**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_smoke_outcomes.gd -gexit`

Expected: FAIL because journal construction is missing.

- [ ] **Step 3: Implement journal routing and final documentation**

Build entries only from event-log IDs and known facts. Include five ascension conditions, stone balance, cultivation progression, body-imprint or lifespan consequence, relationship outcome, key turning point, and one of four survived-failure endings. Do not send journal input to an LLM. Write `README.md` with Godot version, GUT installation, test command, launch command, fixed seed `101`, optional environment variable name for cloud dialogue, and offline fallback behavior.

- [ ] **Step 4: Run complete verification**

Run:

```bash
godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
godot --headless --path . --quit-after 3
git diff --check
```

Expected: all unit and integration tests PASS; project boots headlessly; no whitespace errors.

- [ ] **Step 5: Manually run the acceptance matrix**

1. Play seed `101` offline and resolve the caravan without combat; verify the contest has a changed entry or reduced interference.
2. Accept a body imprint; verify its declared drawback and that the journal names the decision.
3. Trigger a retreat; verify a declared loss and continued run.
4. Load a saved social event; verify no cloud request is made and displayed text matches the saved reply.
5. Complete prepared, hunted, and missing-qi scenarios; verify success, risky success, and survived failure with player-known-only journals.

- [ ] **Step 6: Commit the verified vertical slice**

```bash
git add scripts/domain/journal_builder.gd scripts/presentation/ending_view.gd tests/integration/test_smoke_outcomes.gd tests/unit/test_journal_builder.gd README.md
git commit -m "feat: complete nanjiang smoke slice"
```

## Plan Self-Review

- **Spec coverage:** Tasks 1–2 establish an auditable MIT base and integration boundary; Tasks 3 and 11 implement event logs and journals; Tasks 4 and 5 cover Gu, inheritance, and routes; Task 6 covers stone, body-imprint pressure, and three ascension outcomes; Tasks 7 and 10 cover bounded, optional LLM dialogue; Task 8 covers non-card combat, inheritance moves, and retreat; Task 9 covers map fog and the playable interface; Task 11 covers the required deterministic smoke matrix.
- **Scope check:** North Plain, Eastern Sea, Central Continent, additional backgrounds, full dynamic combination generation, and playable immortal content remain explicitly absent.
- **Consistency check:** `RunState` is the only state input/output through resolver, battle, persistence, and journal layers. Inheritance content uses declared equipped-Gu IDs and tags consistently; free Gu hooks do not generate killer moves. Gateway replies are always validated and persisted before replay.
- **Placeholder scan:** This plan contains no deferred implementation markers. File paths, commands, interfaces, and test assertions are specified for every task.
