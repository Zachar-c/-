# L5 / Ending Boss Acceptance Implementation Plan

> 审阅：✅ 2026-09-06 用户审订通过（定稿）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the fixed 25-seed acceptance sweep retain at least 22 L5 and Ending results while applying central L1–L5 Boss scaling and preserving cultivation-independent Boss entry.

**Architecture:** Apply Boss scaling once in `BattleCommandFacade` before V1 battle construction. Keep acceptance progression on the real `RunController.submit_command()` path, teach the existing driver to choose mandatory hostile-caravan fights, and add only three aggregate trace fields.

**Tech Stack:** Godot 4.7.2, GDScript, JSON, GUT, PowerShell repository test scripts.

## Global Constraints

- Preserve the current V1 battle contract: battle Gu live in `gu_slots`; Gu activation uses `use_gu`; basic actions are `basic_attack`, `end_turn`, and `retreat`.
- Do not restore the retired deck / hand / discard domain model.
- Acceptance progression must continue through `RunController.submit_command()`; do not mutate run state directly, call encounter resolvers directly, or start battles directly from the driver.
- Do not weaken `EncounterSessionResolver`'s `feud_no_escape` rule. The driver must choose the available fight action when an `extreme_hostile` session cannot be left.
- Do not remove or bypass `insufficient_qi_quality`. Boss entry is cultivation-independent; Gu activation quality remains cultivation-gated.
- Boss multiplier selection may read only `encounter.layer_boss` and `catalog["v1_battle"]["boss_layer_mult"]`; it must never read player cultivation.
- Apply Boss scaling only for valid `layer_boss` values 1 through 5. A boss-tier enemy in an ordinary encounter still receives the Boss identity flag, but receives no layer multiplier unless `layer_boss` is valid.
- Scale only initial enemy HP and attack-intent damage. Preserve every other intent field and leave non-attack intent damage unchanged.
- Missing configuration, absent fields, invalid layers, nonnumeric values, and nonpositive multipliers fall back independently to `1.0`.
- Use `roundi()` for deterministic integer rounding. Positive source HP and positive source damage remain at least 1; zero source damage remains zero.
- Reuse `boss_pre_states`, `battle_turns`, `_record_battle_turn()`, `_footprint`, `_last_reject_reason`, and `DRIVE_SWEEP`; do not add a second trace exporter, report file, nested per-layer schema, or persistent diagnostic subsystem.
- The only new per-seed trace fields are `max_layer`, `reached_l5`, and `entered_ending`.
- `entered_ending` may become true only after observing `controller.current_view_name() == "Ending"`; terminal state alone is not Ending evidence.
- Do not edit `data/enemies.json` to duplicate layer multipliers. Modify `data/v1_battle.json` only if the post-wiring 25-seed evidence proves that Boss scaling itself caused a regression.
- Do not address the unrelated Dialogue Manager UID warning.
- Preserve all pre-existing user work. In particular, do not touch the currently modified Battle UI files, `MEMORY.md`, the two 2026-09-04 visual/spec documents, `分支：六卷精编版/`, `肉鸽设计-原始数据/`, `.worktrees/game-impl/`, `vendor/godot-open-rpg/`, unrelated `.claude/` content, or unrelated dialogue data.
- `data/v1_battle.json` and `tests/integration/test_drive_to_ending.gd` already contain relevant uncommitted work. Edit them incrementally; never overwrite or reset them wholesale.
- Do not commit or push unless the user explicitly authorizes it. The generic “frequent commits” convention is overridden by this repository rule.

## File And Interface Map

| Responsibility | Files | Stable interface after implementation |
| --- | --- | --- |
| Central Boss scaling | `scripts/domain/battle_command_facade.gd` | `BattleCommandFacade.start(encounter, state, catalog)` passes scaled enemy entries into `V1BattleResolver.start()`; `_v1_enemies(encounter, catalog)` remains the sole enemy conversion boundary |
| Facade regression coverage | `tests/unit/test_battle_command_facade.gd` | One existing suite covers ordinary mapping, L1–L5 scaling, fallback, rounding/bounds, and cultivation-independent Boss actions |
| Real-command acceptance driver | `tests/integration/test_drive_to_ending.gd` | `_drive(seed)` returns the existing trace plus `max_layer`, `reached_l5`, and `entered_ending`; mandatory caravan combat is submitted as an `action_card` through the controller |
| Central multiplier data | `data/v1_battle.json` | Existing `v1_battle.boss_layer_mult.one` through `.five`; conditional tuning only after measured Boss-caused regression |
| Backlog completion | `AGENTS.md` | Item 4 is marked complete/removed only after all focused and broad evidence passes |

---

### Task 1: Lock The Facade Contract With Focused Red Tests

**Files:**
- Modify: `tests/unit/test_battle_command_facade.gd`
- Read only: `data/v1_battle.json`
- Read only: `scripts/domain/v1_battle_resolver.gd`

**Interfaces:**
- Consumes: `FacadeScript.start(encounter: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary`, `FacadeScript.apply_turn(battle, state, command, catalog) -> Dictionary`, and `GuInstanceScript.new_instance(...) -> Dictionary`.
- Produces: five focused regression tests that define the exact facade behavior Task 2 must satisfy; no new test file or production API.

- [ ] **Step 1: Reconfirm and record the protected working tree before editing**

Run from the repository root:

```powershell
powershell.exe -NoProfile -Command "git status --short --branch"
```

Expected: the worktree is already dirty. Record the output in the implementation notes. Do not reset, stash, clean, or overwrite any listed file. The expected relevant pre-existing edits include `data/v1_battle.json` and `tests/integration/test_drive_to_ending.gd`; unrelated Battle UI edits must remain byte-for-byte outside this task.

- [ ] **Step 2: Add a local catalog fixture for unambiguous scaling tests**

Add this helper near the other test helpers in `tests/unit/test_battle_command_facade.gd`:

```gdscript
func _catalog_with_scale_probe(
		hp: int = 20,
		damage: int = 20,
		intent_kind: String = "attack"
) -> Dictionary:
	var test_catalog := catalog.duplicate(true)
	var enemy_by_id: Dictionary = test_catalog.get("enemy_by_id", {})
	enemy_by_id["boss_scale_probe"] = {
		"id": "boss_scale_probe",
		"tier": "boss",
		"hp": hp,
		"intent": {
			"kind": intent_kind,
			"damage": damage,
			"label": "倍率探针",
			"speed": 3,
			"seal_turns": 2,
			"soul_drain": 4,
			"life_cost": 5,
			"counter_tag": "probe_counter",
		},
	}
	test_catalog["enemy_by_id"] = enemy_by_id
	return test_catalog
```

This fixture deliberately uses HP/damage 20 for the table test so every configured multiplier has an exact integer expectation.

- [ ] **Step 3: Add the ordinary-encounter non-scaling test**

Add:

```gdscript
func test_ordinary_encounter_does_not_apply_boss_layer_scaling() -> void:
	var state := RunState.new_run(101)
	var test_catalog := _catalog_with_scale_probe()
	var battle: Dictionary = FacadeScript.start(
		{"enemy_kind": "boss_scale_probe"}, state, test_catalog
	)

	assert_eq(int(battle["enemies"][0]["hp"]), 20)
	assert_eq(int(battle["enemies"][0]["intent"]["damage"]), 20)
	assert_true(bool(battle["flags"].get("boss_battle", false)),
			"boss tier still marks identity without applying a layer multiplier")
```

This separates Boss identity from layer scaling: `tier == "boss"` blocks retreat, while only `layer_boss` selects a multiplier.

- [ ] **Step 4: Add one parameterized L1–L5 table test**

Add:

```gdscript
func test_layer_boss_applies_central_l1_to_l5_hp_and_damage_multipliers() -> void:
	var state := RunState.new_run(101)
	var test_catalog := _catalog_with_scale_probe()
	var cases := [
		{"layer": 1, "hp": 20, "damage": 20},
		{"layer": 2, "hp": 22, "damage": 21},
		{"layer": 3, "hp": 24, "damage": 22},
		{"layer": 4, "hp": 27, "damage": 23},
		{"layer": 5, "hp": 30, "damage": 25},
	]

	for case in cases:
		var battle: Dictionary = FacadeScript.start({
			"enemy_kind": "boss_scale_probe",
			"layer_boss": int(case["layer"]),
		}, state, test_catalog)
		assert_eq(int(battle["enemies"][0]["hp"]), int(case["hp"]),
				"layer %d HP" % int(case["layer"]))
		assert_eq(
			int(battle["enemies"][0]["intent"]["damage"]),
			int(case["damage"]),
			"layer %d damage" % int(case["layer"])
		)
```

These expectations correspond exactly to the existing central configuration:

```text
L1: hp 1.00, damage 1.00
L2: hp 1.10, damage 1.05
L3: hp 1.20, damage 1.10
L4: hp 1.35, damage 1.15
L5: hp 1.50, damage 1.25
```

- [ ] **Step 5: Add one consolidated fallback test**

Add:

```gdscript
func test_layer_boss_scaling_falls_back_for_missing_invalid_and_nonpositive_values() -> void:
	var state := RunState.new_run(101)
	var missing := _catalog_with_scale_probe()
	missing["v1_battle"] = {}
	var missing_battle: Dictionary = FacadeScript.start({
		"enemy_kind": "boss_scale_probe", "layer_boss": 3,
	}, state, missing)
	assert_eq(int(missing_battle["enemies"][0]["hp"]), 20)
	assert_eq(int(missing_battle["enemies"][0]["intent"]["damage"]), 20)

	var invalid_layer := _catalog_with_scale_probe()
	var invalid_battle: Dictionary = FacadeScript.start({
		"enemy_kind": "boss_scale_probe", "layer_boss": 6,
	}, state, invalid_layer)
	assert_eq(int(invalid_battle["enemies"][0]["hp"]), 20)
	assert_eq(int(invalid_battle["enemies"][0]["intent"]["damage"]), 20)

	var invalid_values := _catalog_with_scale_probe()
	invalid_values["v1_battle"]["boss_layer_mult"]["three"] = {
		"hp": "not-a-number",
		"damage": 0.0,
	}
	var invalid_values_battle: Dictionary = FacadeScript.start({
		"enemy_kind": "boss_scale_probe", "layer_boss": 3,
	}, state, invalid_values)
	assert_eq(int(invalid_values_battle["enemies"][0]["hp"]), 20)
	assert_eq(int(invalid_values_battle["enemies"][0]["intent"]["damage"]), 20)
```

The two fields fall back independently; no invalid configuration may produce zeroed enemies or damage.

- [ ] **Step 6: Add one consolidated rounding, floor, zero-damage, and field-preservation test**

Add:

```gdscript
func test_layer_boss_scaling_rounds_and_preserves_positive_floors_and_nonattack_intents() -> void:
	var state := RunState.new_run(101)

	var rounded := _catalog_with_scale_probe(3, 3)
	rounded["v1_battle"]["boss_layer_mult"]["one"] = {
		"hp": 1.5, "damage": 1.5,
	}
	var rounded_battle: Dictionary = FacadeScript.start({
		"enemy_kind": "boss_scale_probe", "layer_boss": 1,
	}, state, rounded)
	assert_eq(int(rounded_battle["enemies"][0]["hp"]), 5)
	assert_eq(int(rounded_battle["enemies"][0]["intent"]["damage"]), 5)

	var floored := _catalog_with_scale_probe(1, 1)
	floored["v1_battle"]["boss_layer_mult"]["one"] = {
		"hp": 0.1, "damage": 0.1,
	}
	var floored_battle: Dictionary = FacadeScript.start({
		"enemy_kind": "boss_scale_probe", "layer_boss": 1,
	}, state, floored)
	assert_eq(int(floored_battle["enemies"][0]["hp"]), 1)
	assert_eq(int(floored_battle["enemies"][0]["intent"]["damage"]), 1)

	var zero_damage := _catalog_with_scale_probe(1, 0)
	zero_damage["v1_battle"]["boss_layer_mult"]["one"] = {
		"hp": 2.0, "damage": 2.0,
	}
	var zero_battle: Dictionary = FacadeScript.start({
		"enemy_kind": "boss_scale_probe", "layer_boss": 1,
	}, state, zero_damage)
	assert_eq(int(zero_battle["enemies"][0]["hp"]), 2)
	assert_eq(int(zero_battle["enemies"][0]["intent"]["damage"]), 0)

	var nonattack := _catalog_with_scale_probe(4, 7, "seal")
	nonattack["v1_battle"]["boss_layer_mult"]["one"] = {
		"hp": 2.0, "damage": 2.0,
	}
	var nonattack_battle: Dictionary = FacadeScript.start({
		"enemy_kind": "boss_scale_probe", "layer_boss": 1,
	}, state, nonattack)
	var intent: Dictionary = nonattack_battle["enemies"][0]["intent"]
	assert_eq(int(nonattack_battle["enemies"][0]["hp"]), 8)
	assert_eq(int(intent["damage"]), 7,
			"non-attack intent damage is not layer-scaled")
	assert_eq(str(intent["label"]), "倍率探针")
	assert_eq(int(intent["speed"]), 3)
	assert_eq(int(intent["seal_turns"]), 2)
	assert_eq(int(intent["soul_drain"]), 4)
	assert_eq(int(intent["life_cost"]), 5)
	assert_eq(str(intent["counter_tag"]), "probe_counter")
```

- [ ] **Step 7: Add one compact no-hard-cultivation-gate regression**

Add:

```gdscript
func test_rank_one_player_can_act_in_layer_five_boss_but_not_use_rank_two_gu() -> void:
	var state := RunState.new_run(101)
	state.cultivation = 1
	state.cave_aperture["stored_gu_instance_ids"] = []
	state.gu_instances = {}
	var test_catalog := catalog.duplicate(true)
	test_catalog["gu_by_id"]["rank_two_probe_gu"] = {
		"id": "rank_two_probe_gu",
		"combat": "strike",
		"school": "qi",
		"role": "attack",
		"rarity": "rare",
		"rank": 2,
		"true_qi_cost": 1,
		"v1_effect": {"kind": "strike", "amount": 3},
	}
	var instance_id := "rank_two_probe_00"
	state.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	state.gu_instances[instance_id] = GuInstanceScript.new_instance(
		"rank_two_probe_gu", instance_id, test_catalog
	)
	var battle: Dictionary = FacadeScript.start({
		"enemy_kind": "ridge_hound",
		"layer_boss": 5,
	}, state, test_catalog)

	assert_eq(int(battle["player"]["cultivation"]), 1)
	assert_true(bool(battle["flags"].get("boss_battle", false)))
	var punched: Dictionary = FacadeScript.apply_turn(
		battle, state, {"type": "basic_attack"}, test_catalog
	)
	assert_true(bool(punched.get("accepted", false)),
			"Boss layer must not gate rank-one basic actions")
	var blocked: Dictionary = FacadeScript.apply_turn(battle, state, {
		"type": "use_gu", "instance_id": instance_id,
	}, test_catalog)
	assert_false(bool(blocked.get("accepted", true)))
	assert_eq(blocked.get("feeds", []), ["insufficient_qi_quality"])
```

This test intentionally proves entry and legal action, not victory. It also proves that removing a Boss cultivation gate does not remove the independent Gu-quality rule.

- [ ] **Step 8: Run the focused facade suite and verify the intended red state**

Run:

```powershell
powershell.exe -File tools/test.ps1 -Test tests/unit/test_battle_command_facade.gd
```

Expected before Task 2:

- The ordinary mapping and cultivation/action assertions continue to pass.
- The L2–L5 table expectations fail because HP/damage are still raw.
- The rounding/floor expectations fail because no multiplier is consumed.
- The suite must actually execute the target file; parse errors, skipped scripts, or zero tests are not an acceptable red state.

If the new test code itself fails to parse, fix the test syntax and rerun until failures are behavioral assertions about missing scaling.

---

### Task 2: Apply Central Boss Multipliers In The Authoritative V1 Conversion Path

**Files:**
- Modify: `scripts/domain/battle_command_facade.gd`
- Test: `tests/unit/test_battle_command_facade.gd`
- Read only: `data/v1_battle.json`

**Interfaces:**
- Consumes: `encounter.layer_boss`, `catalog["v1_battle"]["boss_layer_mult"]`, and enemy definitions from `catalog["enemy_by_id"]`.
- Produces: private constants/helpers `BOSS_LAYER_IDS`, `_boss_layer_multipliers(...)`, `_positive_multiplier(...)`, and `_scale_positive_int(...)`; `_v1_enemies(...)` keeps its existing signature and returns V1 entries with conditionally scaled HP/attack damage.

- [ ] **Step 1: Add the fixed layer-to-configuration mapping**

Add beside `BATTLE_COMMAND_TYPES` in `scripts/domain/battle_command_facade.gd`:

```gdscript
const BOSS_LAYER_IDS := {
	1: "one",
	2: "two",
	3: "three",
	4: "four",
	5: "five",
}
```

Do not infer English names dynamically and do not accept layers outside this mapping.

- [ ] **Step 2: Add strict multiplier resolution and positive-integer scaling helpers**

Add immediately before `_v1_enemies()`:

```gdscript
static func _boss_layer_multipliers(
		encounter: Dictionary,
		catalog: Dictionary
) -> Dictionary:
	var layer := int(encounter.get("layer_boss", 0))
	if not BOSS_LAYER_IDS.has(layer):
		return {"hp": 1.0, "damage": 1.0}
	var battle_config: Dictionary = catalog.get("v1_battle", {})
	var multiplier_by_layer: Dictionary = battle_config.get(
		"boss_layer_mult", {}
	)
	var layer_config: Dictionary = multiplier_by_layer.get(
		BOSS_LAYER_IDS[layer], {}
	)
	return {
		"hp": _positive_multiplier(layer_config.get("hp", 1.0)),
		"damage": _positive_multiplier(
			layer_config.get("damage", 1.0)
		),
	}


static func _positive_multiplier(value: Variant) -> float:
	if not (value is int or value is float):
		return 1.0
	var multiplier := float(value)
	return multiplier if multiplier > 0.0 else 1.0


static func _scale_positive_int(value: int, multiplier: float) -> int:
	if value <= 0:
		return value
	return maxi(1, roundi(float(value) * multiplier))
```

Rationale encoded by these helpers:

- Invalid layer or missing dictionaries produce `{hp = 1.0, damage = 1.0}`.
- HP and damage validate independently.
- Only positive source values receive the minimum-one floor.
- Zero damage remains zero.
- No helper accepts or reads `RunState`, so cultivation cannot become a hidden scaling input.

- [ ] **Step 3: Resolve multipliers once per encounter and scale only the intended fields**

Replace the body setup and per-enemy mapping in `_v1_enemies()` with this shape while retaining all existing fields:

```gdscript
static func _v1_enemies(
		encounter: Dictionary,
		catalog: Dictionary
) -> Array:
	var enemy_by_id: Dictionary = catalog.get("enemy_by_id", {})
	var multipliers := _boss_layer_multipliers(encounter, catalog)
	var result: Array = []
	var kinds: Array = []
	if encounter.has("enemy_kinds"):
		kinds = (
			encounter.get("enemy_kinds", []) as Array
		).duplicate()
	elif encounter.has("enemy_kind"):
		kinds.append(str(encounter.get("enemy_kind", "")))
	for kind_value in kinds:
		var kind := str(kind_value)
		var definition: Dictionary = enemy_by_id.get(kind, {})
		var intent: Dictionary = definition.get("intent", {})
		var intent_kind := str(intent.get("kind", "attack"))
		var source_damage := int(intent.get("damage", 0))
		var mapped_damage := source_damage
		if intent_kind == "attack":
			mapped_damage = _scale_positive_int(
				source_damage,
				float(multipliers["damage"])
			)
		result.append({
			"id": kind,
			"label": str(definition.get(
				"label", definition.get("name", kind)
			)),
			"hp": _scale_positive_int(
				int(definition.get("hp", 1)),
				float(multipliers["hp"])
			),
			"intent": {
				"kind": intent_kind,
				"damage": mapped_damage,
				"label": str(intent.get("label", "蓄力")),
				"speed": int(intent.get("speed", 0)),
				"seal_turns": int(intent.get(
					"seal_turns", 0
				)),
				"soul_drain": int(intent.get(
					"soul_drain", 0
				)),
				"life_cost": int(intent.get(
					"life_cost", 0
				)),
				"counter_tag": str(intent.get(
					"counter_tag", ""
				)),
			},
		})
	return result
```

Do not move scaling into `V1BattleResolver`, enemy JSON, map generation, or controller code. `BattleCommandFacade` is the boundary where encounter context and catalog enemy definitions are both available.

- [ ] **Step 4: Run the focused facade suite to green**

Run:

```powershell
powershell.exe -File tools/test.ps1 -Test tests/unit/test_battle_command_facade.gd
```

Expected: PASS. Specifically verify from the assertions that:

- ordinary encounters remain raw;
- L1–L5 resolve to 20/20, 22/21, 24/22, 27/23, and 30/25;
- invalid/missing values fall back to raw numbers;
- `roundi(4.5)` yields 5;
- positive values floor at 1 and zero damage stays zero;
- non-attack intent damage and auxiliary fields are preserved;
- a rank-one player can start and punch in a layer-five Boss battle;
- the rank-two Gu is still rejected with `insufficient_qi_quality`.

- [ ] **Step 5: Inspect the focused diff for scope leaks**

Run:

```powershell
powershell.exe -NoProfile -Command "git diff -- scripts/domain/battle_command_facade.gd tests/unit/test_battle_command_facade.gd"
```

Expected: only the fixed mapping, three private helpers, the local changes inside `_v1_enemies()`, and the five focused tests/helper appear. There must be no cultivation comparison, resolver change, enemy-data edit, or UI change.

---

### Task 3: Make The Fixed-Seed Driver Fight Mandatory Caravans And Observe Real Progress

**Files:**
- Modify: `tests/integration/test_drive_to_ending.gd`
- Read only: `scripts/domain/action_preview_service.gd`
- Read only: `scripts/domain/encounter_session_resolver.gd`
- Read only: `scripts/presentation/run_controller.gd`

**Interfaces:**
- Consumes: `ActionPreviewServiceScript.preview_actions(state, node, catalog) -> Array[Dictionary]`, action-card IDs plus their embedded semantic commands, `controller.submit_command(command)`, `controller.current_view_name()`, `controller.current_node`, and `controller.current_battle`.
- Produces: trace keys `max_layer: int`, `reached_l5: bool`, and `entered_ending: bool`; helper methods `_observe_progress(...)`, `_is_fight_card(...)`, `_mandatory_fight_pending(...)`, and `_fight_via_preview(...)`; aggregate assertions over the unchanged 25-seed list.

- [ ] **Step 1: Add the three trace fields and a single progress observer**

Extend the trace literal in `_drive()` with exactly:

```gdscript
var trace := {
	"seed": seed_value,
	"result": "steps_cap",
	"battles": 0,
	"boss_pre_states": [],
	"battle_turns": [],
	"death_cause": "",
	"max_layer": 0,
	"reached_l5": false,
	"entered_ending": false,
}
```

Add this helper near `_format_trace()`:

```gdscript
func _observe_progress(controller, trace: Dictionary) -> void:
	var node_layer := int(controller.current_node.get("layer", 0))
	var battle_layer := int(controller.current_battle.get("layer", 0))
	trace["max_layer"] = maxi(
		int(trace.get("max_layer", 0)),
		maxi(node_layer, battle_layer)
	)
	if int(trace["max_layer"]) >= 5:
		trace["reached_l5"] = true
	if str(controller.current_view_name()) == "Ending":
		trace["entered_ending"] = true
```

Do not add arrays of visited layers or duplicate battle snapshots.

- [ ] **Step 2: Observe Ending before terminal handling and immediately after each command step**

Restructure the top of the `_drive()` loop so observation and real Ending detection happen before terminal-state classification:

```gdscript
if controller.state == null:
	trace["result"] = "no_state"
	break
_observe_progress(controller, trace)
var view := str(controller.current_view_name())
if view == "Ending":
	trace["result"] = "ending"
	trace["death_cause"] = str(
		controller._ending_state.get("death_cause_id", "")
	)
	break
if controller.state.is_terminal():
	var battle: Dictionary = controller.current_battle
	var battle_result: Dictionary = battle.get("result", {})
	var enemy_ids: Array[String] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		enemy_ids.append(str(enemy.get("id", "?")))
	trace["result"] = "terminal@%s|hp%d|cause:%s|phase:%s|enemy:%s|ess%d|gu%d|rank2:%s" % [
		str(controller.state.current_node_id),
		int(controller.state.health),
		str(battle_result.get("cause", "?")),
		str(battle.get("phase", "?")),
		",".join(enemy_ids),
		int(controller.state.essence_capacity),
		(controller.state.gu_instances as Dictionary).size(),
		str(controller.state.cultivator.get("rank", 1)),
	]
	trace["death_cause"] = str(battle_result.get("cause", ""))
	break
if view in ["Title", "Hall"]:
	trace["result"] = "left_run"
	break
var step_result := _step(controller, view, trace)
_observe_progress(controller, trace)
```

Keep the existing terminal diagnostic body intact; only move it below the real Ending-view check.

Then tighten the non-ongoing branch:

```gdscript
if step_result != "ongoing":
	if step_result == "ending" and not bool(trace["entered_ending"]):
		trace["result"] = "ending_without_view"
	else:
		trace["result"] = step_result
	break
```

This second observation is required because `_step_encounter()` may submit `attempt_ascension` and return `"ending"` in the same iteration.

- [ ] **Step 3: Add semantic fight-card recognition and mandatory-session detection**

Add:

```gdscript
func _is_fight_card(card: Dictionary) -> bool:
	var command: Dictionary = card.get("command", {})
	return str(command.get("action_id", "")) == "fight" \
			or (
				str(command.get("type", "")) == "resolve_contact"
				and str(command.get("approach", "")) == "fight"
			)


func _mandatory_fight_pending(controller) -> bool:
	var session: Dictionary = controller.current_session
	return bool(session.get("offers_fight", false)) \
			and str(session.get("stance", "neutral")) == "extreme_hostile" \
			and str(session.get("phase", "active")) != "post_battle"
```

Do not recognize only the visible card ID. The preview service currently emits `node.fight`, but the durable semantic contract is the embedded command (`action_id == "fight"` or `resolve_contact` with `approach == "fight"`).

- [ ] **Step 4: Submit the executable fight through the action-card envelope**

Add:

```gdscript
func _fight_via_preview(controller) -> String:
	var cards: Array[Dictionary] = (
		ActionPreviewServiceScript.preview_actions(
			controller.state,
			controller.current_node,
			controller.catalog
		)
	)
	for card in cards:
		if not bool(card.get("executable", false)):
			continue
		if not _is_fight_card(card):
			continue
		var result: Dictionary = controller.submit_command({
			"type": "action_card",
			"action_id": str(card.get("id", "")),
			"state_version": controller.state.event_log.size(),
		})
		var payload: Dictionary = result.get("result", result)
		if bool(payload.get("start_battle", false)) \
				or str(controller.current_view_name()) == "Battle" \
				or bool(payload.get("ok", false)):
			return "ongoing"
		_last_reject_reason = str(
			payload.get("reason", "mandatory_fight_rejected")
		)
		return "mandatory_fight_rejected:%s" % _last_reject_reason
	var session: Dictionary = controller.current_session
	return "mandatory_fight_missing@%s:stance=%s:phase=%s" % [
		str(controller.state.current_node_id),
		str(session.get("stance", "?")),
		str(session.get("phase", "?")),
	]
```

The controller recomputes the current card from its ID, so do not send the embedded preview command directly. Do not alter `stance`, `phase`, `offers_fight`, or battle state from the test driver.

- [ ] **Step 5: Choose mandatory caravan combat after purchases and before leaving**

At the end of `_step_shop()`, replace only the unconditional final leave with:

```gdscript
if _mandatory_fight_pending(controller):
	return _fight_via_preview(controller)
return _leave(controller, "商店")
```

Keep both existing purchase loops unchanged. A normal shop/caravan still leaves exactly as before; only an active, extreme-hostile, fight-offering session branches to preview-selected combat.

- [ ] **Step 6: Expand the compact trace formatter without adding a reporting subsystem**

Change `_format_trace()` to include the three aggregate fields while retaining the existing diagnostics:

```gdscript
func _format_trace(trace: Dictionary) -> String:
	var runaways := trace.get("runaways", []) as Array
	return "%s|layer:%d|l5:%s|ending:%s|battles:%d|boss:%d|runaway:%s|turns:%s|death:%s" % [
		str(trace.get("result", "")),
		int(trace.get("max_layer", 0)),
		str(trace.get("reached_l5", false)),
		str(trace.get("entered_ending", false)),
		int(trace.get("battles", 0)),
		(trace.get("boss_pre_states", []) as Array).size(),
		",".join(runaways) if not runaways.is_empty() else "-",
		str(trace.get("battle_turns", [])),
		str(trace.get("death_cause", "")),
	]
```

Keep `_record_battle_turn()`, `_footprint`, and the failure tail as the only detailed diagnostics.

- [ ] **Step 7: Replace weak per-trace checks with explicit aggregate and soft-lock assertions**

In `test_twenty_five_seeds_reach_ending_or_terminal_with_trace()`, collect counts while driving. Print every seed only when `DRIVE_SWEEP` is enabled; otherwise print only rejected outcomes:

```gdscript
var reached_l5_count := 0
var entered_ending_count := 0
for seed_value in seeds:
	var outcome := _drive(seed_value)
	traces.append(outcome)
	if bool(outcome.get("reached_l5", false)):
		reached_l5_count += 1
	if bool(outcome.get("entered_ending", false)):
		entered_ending_count += 1
	var accepted := bool(outcome.get("entered_ending", false)) \
			or str(outcome.get("result", "")).begins_with("terminal@")
	if OS.has_environment("DRIVE_SWEEP") or not accepted:
		print("[sweep] seed %d -> %s" % [
			seed_value, _format_trace(outcome)
		])
```

After `assert_eq(traces.size(), 25)`, use these assertions:

```gdscript
for trace in traces:
	var result := str(trace.get("result", ""))
	var seed_value := int(trace.get("seed", -1))
	assert_false(result.begins_with("leave_blocked"),
			"seed %d must not soft-lock while leaving: %s" % [seed_value, _format_trace(trace)])
	assert_ne(result, "no_route",
			"seed %d must not end at no_route: %s" % [seed_value, _format_trace(trace)])
	assert_ne(result, "steps_cap",
			"seed %d must not exhaust the driver cap: %s" % [seed_value, _format_trace(trace)])
	assert_ne(result, "leave_blocked:feud_no_escape",
			"seed %d must fight an unavoidable hostile caravan" % seed_value)
	assert_true(
		bool(trace.get("entered_ending", false)) \
				or result.begins_with("terminal@"),
		"seed %d must observe Ending or a classified terminal: %s" % [
			seed_value, _format_trace(trace)
		]
	)
	if result == "ending":
		assert_true(bool(trace.get("entered_ending", false)),
				"ending result requires direct Ending-view evidence")

assert_gte(reached_l5_count, 13,
		"formal release floor: at least 13/25 seeds must reach L5")
assert_gte(entered_ending_count, 13,
		"formal release floor: at least 13/25 seeds must enter Ending")
assert_gte(reached_l5_count, 22,
		"regression floor: retain the measured 22/25 L5 baseline")
assert_gte(entered_ending_count, 22,
		"regression floor: retain the measured 22/25 Ending baseline")
```

Do not infer `entered_ending` from `result`, terminal state, death cause, or an event-log entry.

- [ ] **Step 8: Run the focused 25-seed acceptance sweep with diagnostics**

Run:

```powershell
$env:DRIVE_SWEEP = '1'
powershell.exe -File tools/test.ps1 -Test tests/integration/test_drive_to_ending.gd
Remove-Item Env:DRIVE_SWEEP
```

Expected after the driver fix and scaling wiring:

- the target file runs two tests and passes;
- at least 22/25 traces have `reached_l5=true`;
- at least 22/25 traces have `entered_ending=true`;
- seeds 43, 73, and 79 no longer end as `leave_blocked:feud_no_escape`;
- every seed is either an observed Ending or a classified `terminal@...`;
- no result is `no_route`, `steps_cap`, or any `leave_blocked...` soft lock;
- seed 101 still avoids `no_route` and all `leave_blocked` variants.

If the environment variable cleanup line is skipped because the test process fails, run `Remove-Item Env:DRIVE_SWEEP -ErrorAction SilentlyContinue` before later test commands.

- [ ] **Step 9: Classify any failure before changing balance data**

For each failing trace, classify it using the existing `boss_pre_states`, `battle_turns`, `_footprint`, current HP/enemy HP/intent, and `_last_reject_reason` as exactly one of:

```text
boss_numeric_regression
ordinary_battle_defeat
route_soft_lock
driver_command_failure
ending_observation_failure
```

Expected: no balance edit is needed if both measured counts remain at least 22 and all soft-lock assertions pass. Proceed directly to Task 5 in that case. Only `boss_numeric_regression` permits Task 4.

---

### Task 4: Conditionally Tune Only The Central Boss Multipliers

**Files:**
- Modify only if required: `data/v1_battle.json`
- Test: `tests/integration/test_drive_to_ending.gd`
- Test: `tests/unit/test_battle_command_facade.gd`

**Interfaces:**
- Consumes: failure classification and fixed-seed diagnostics from Task 3.
- Produces: the smallest measured adjustment to an existing `boss_layer_mult.<layer>.hp` or `.damage` value; no enemy-specific overrides and no assertion relaxation.

- [ ] **Step 1: Skip this task unless the evidence meets the tuning gate**

The tuning gate is true only when all of the following hold:

```text
1. reached_l5_count < 22 or entered_ending_count < 22
2. at least one previously successful fixed seed now fails in a layer Boss battle
3. the trace reaches that Boss without a route/driver error
4. the death/terminal transition occurs during that scaled Boss battle
```

If any condition is false, do not edit `data/v1_battle.json`. Do not weaken the `13` or `22` assertions.

- [ ] **Step 2: Change one central field at a time, only for the demonstrated layer**

Use the current configuration shape; retain all five keys and never add per-enemy values:

```json
"boss_layer_mult": {
  "one": {"hp": 1.0, "damage": 1.0},
  "two": {"hp": 1.1, "damage": 1.05},
  "three": {"hp": 1.2, "damage": 1.1},
  "four": {"hp": 1.35, "damage": 1.15},
  "five": {"hp": 1.5, "damage": 1.25}
}
```

Adjustment order is deterministic:

1. If the trace shows incoming intent damage causes the regression, reduce only that layer's `damage` multiplier by `0.05`, never below `1.0`.
2. Otherwise, if the trace shows the battle became an unwinnable HP grind, reduce only that layer's `hp` multiplier by `0.05`, never below `1.0`.
3. Rerun the identical 25 seeds after every single-field change; do not batch several speculative changes.
4. Stop at the first values that restore both 22/25 floors. Do not tune toward 25/25.

Before applying a computed value, record the exact old value, new value, affected layer, failing seeds, and diagnostic reason in the implementation notes. This is measured balance work, not an assertion update.

- [ ] **Step 3: Rerun the facade contract after any data adjustment**

Run:

```powershell
powershell.exe -File tools/test.ps1 -Test tests/unit/test_battle_command_facade.gd
```

Expected: PASS after updating the table-test expectations to match the deliberately approved central values. Change only the expected row(s) corresponding to the edited JSON field; all fallback, boundary, ordinary, and cultivation tests remain unchanged.

- [ ] **Step 4: Rerun the identical acceptance sweep after each single-field adjustment**

Run:

```powershell
$env:DRIVE_SWEEP = '1'
powershell.exe -File tools/test.ps1 -Test tests/integration/test_drive_to_ending.gd
Remove-Item Env:DRIVE_SWEEP
```

Expected: both `reached_l5_count` and `entered_ending_count` are at least 22, both formal 13/25 floors pass, and no soft-lock assertion fails. If a one-step adjustment does not restore the baseline, use the same evidence-driven classification before the next `0.05` single-field adjustment.

---

### Task 5: Run Broad Verification, Clean Only Temporary Evidence, And Close Backlog Item 4

**Files:**
- Modify only after every gate passes: `AGENTS.md`
- Delete only after evidence is no longer needed: `.claude-drive-sweep.log`
- Verify: all files changed by Tasks 1–4

**Interfaces:**
- Consumes: green focused facade tests, green fixed-seed sweep, optional measured central tuning, and the repository's standard verification scripts.
- Produces: complete acceptance evidence and an `AGENTS.md` backlog that no longer lists item 4 as unfinished.

- [ ] **Step 1: Run the focused tests once more without diagnostic environment state**

Run:

```powershell
Remove-Item Env:DRIVE_SWEEP -ErrorAction SilentlyContinue
powershell.exe -File tools/test.ps1 -Test tests/unit/test_battle_command_facade.gd
powershell.exe -File tools/test.ps1 -Test tests/integration/test_drive_to_ending.gd
```

Expected: both focused files PASS with no parse error, ignored script, zero-test run, or `feud_no_escape` driver failure.

- [ ] **Step 2: Run the full unit suite**

Run:

```powershell
powershell.exe -File tools/test.ps1 -Suite unit
```

Expected: PASS. Any unrelated pre-existing failure must be reported verbatim and distinguished from failures caused by this change; do not silently call the task complete while a related unit regression remains.

- [ ] **Step 3: Run the full integration suite**

Run:

```powershell
powershell.exe -File tools/test.ps1 -Suite integration
```

Expected: PASS, including the fixed 25-seed test and the seed-101 generated-route regression.

- [ ] **Step 4: Run the repository check gate**

Run:

```powershell
powershell.exe -File tools/check.ps1
```

Expected: PASS. The known Dialogue Manager invalid-UID warning may still be printed, but this task must not modify unrelated Dialogue Manager data or scenes to suppress it.

- [ ] **Step 5: Record the exact final acceptance evidence**

From the last diagnostic sweep, include the measured `reached L5` and `entered Ending` numerators exactly as printed by the run, followed by `/25`. Also record these fixed evidence lines:

```text
fixed seeds: 25
reached L5: copy the measured numerator from the final sweep, followed by /25; it must be at least 22 and therefore at least 13
entered Ending: copy the measured numerator from the final sweep, followed by /25; it must be at least 22 and therefore at least 13
leave_blocked:feud_no_escape: 0
no_route: 0
steps_cap: 0
seed 101 no_route/leave_blocked regressions: PASS
rank-one layer-five Boss creation/basic_attack: PASS
rank-two Gu at rank one -> insufficient_qi_quality: PASS
```

Do not guess or prefill either measured numerator. The assertions enforce the exact numeric floors even when console output is compact.

- [ ] **Step 6: Update `AGENTS.md` only after all completion criteria pass**

Remove or mark complete only this exact backlog item:

```text
4. 使大部分验收运行抵达 L5，且超过一半进入 Ending；层级 Boss 仅作对应一至五转量级的数值匹配考验，不作硬性 cultivation gate。
```

Do not rewrite unrelated backlog items. If any focused test, 22/25 floor, soft-lock gate, unit suite, integration suite, or repository check remains red for a related reason, leave item 4 unchanged and report the blocker.

- [ ] **Step 7: Remove only the temporary sweep log after preserving the measured evidence**

First inspect that `.claude-drive-sweep.log` is the assistant-created temporary diagnostic output and not user-authored data. Once the final measured counts and failing-seed evidence are captured, delete only that file:

```powershell
powershell.exe -NoProfile -Command "if (Test-Path '.claude-drive-sweep.log') { Remove-Item '.claude-drive-sweep.log' }"
```

Expected: `.claude-drive-sweep.log` no longer appears in status. Do not run `git clean` and do not delete any other untracked file.

- [ ] **Step 8: Review the final diff and protected working tree**

Run:

```powershell
powershell.exe -NoProfile -Command "git status --short --branch; git diff -- AGENTS.md data/v1_battle.json scripts/domain/battle_command_facade.gd tests/unit/test_battle_command_facade.gd tests/integration/test_drive_to_ending.gd"
```

Expected implementation scope:

```text
scripts/domain/battle_command_facade.gd
tests/unit/test_battle_command_facade.gd
tests/integration/test_drive_to_ending.gd
AGENTS.md                           # only after all gates pass
data/v1_battle.json                 # only if Task 4's measured tuning gate fired
```

Confirm that unrelated modified Battle UI files and untracked user/spec/memory files remain present and were not included in this task's diff. Do not commit or push.

- [ ] **Step 9: Perform final contract review before reporting completion**

Verify each statement directly against the diff and test output:

1. `BattleCommandFacade._v1_enemies()` is still the single scaling boundary.
2. No scaling helper accepts `RunState` or reads cultivation.
3. Only valid `layer_boss` 1–5 selects a multiplier.
4. Ordinary battles and non-attack intent damage are unchanged.
5. `feud_no_escape` remains unchanged in production code.
6. Mandatory fights are selected from executable action previews and submitted through `RunController.submit_command()`.
7. `entered_ending` is set only from the real Ending view and is observed both before terminal handling and after `_step()`.
8. The trace adds exactly three fields and reuses existing diagnostics.
9. Both 13/25 formal floors and 22/25 regression floors are asserted.
10. High-rank Gu activation still yields `insufficient_qi_quality` for a rank-one player.
11. `AGENTS.md` item 4 changed only after all evidence passed.
12. No commit or push occurred.

## Plan Self-Review

- **Spec coverage:** Tasks 1–2 cover central L1–L5 HP/damage scaling, fallbacks, deterministic rounding, ordinary behavior, preserved intent fields, and cultivation-independent Boss actions. Task 3 covers hostile-caravan fight selection, direct Ending observation, the three minimal trace fields, aggregate floors, soft-lock rejection, diagnostics reuse, and seed 101. Task 4 covers the explicitly conditional central-only balance path. Task 5 covers broad verification, backlog closure, temporary-log cleanup, and preservation of unrelated work.
- **Placeholder scan:** The plan contains no `TBD`, `TODO`, “implement later,” unspecified error handling, or references to undefined production interfaces. The only run-derived values are final measured counts, which must be copied from actual output rather than guessed.
- **Type and property consistency:** The plan consistently uses `layer_boss`, `catalog["v1_battle"]["boss_layer_mult"]`, `gu_slots`, `use_gu`, `basic_attack`, `insufficient_qi_quality`, `max_layer`, `reached_l5`, `entered_ending`, `current_node`, `current_battle`, `current_session`, and `current_view_name()`. Helper signatures and call sites match across tasks.
- **Scope check:** No second facade test file, cultivation suite, trace/report subsystem, direct resolver path, enemy-specific multiplier copy, visual change, or unrelated warning cleanup is included.
