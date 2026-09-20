extends GutTest


## SIDE-FIX 2026-09-19 D：最小 data→runtime 契约测试。
## 断言：敌人数据（intents / reactions，含 phases[].intents/reactions）里声明的
## 每个字段，在 runtime 都有消费点，或显式登记在豁免表里（附原因）。
## 约束：豁免表不能为空（必须诚实登记已知缺口），也不能全豁免（垃圾桶拦截）。
## L1 明令：本测试必须能抓到 sparked / essence_burn / phases 三条（见取证注释）。


const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const V1ResolverScript = preload("res://scripts/domain/v1_battle_resolver.gd")

const RESOLVER_PATH := "res://scripts/domain/v1_battle_resolver.gd"
const FACADE_PATH := "res://scripts/domain/battle_command_facade.gd"
const PREVIEW_PATH := "res://scripts/domain/action_preview_service.gd"

## 数据键全集（与 game/data/enemies.json 实测一致；测试首断言即与 live 数据核对）。
const INTENT_FIELDS := [
	"cooldown", "damage", "essence_burn", "id", "kind", "label",
	"seal_turns", "soul_drain", "speed",
]
const PHASE_FIELDS := ["intents", "reactions", "until_hp_ratio"]
const REACTION_FIELDS := ["clue", "counter_status", "id", "label", "trigger", "window"]

## 字段 → runtime 消费点（文件 + 符号；文件包含断言逐条机械核验，防腐烂）。
const COVERAGE := {
	"intent.id": ["battle_command_facade._v1_enemies passthrough", "v1_battle_resolver last_fired key"],
	"intent.kind": ["v1_battle_resolver._resolve_enemy_intent match"],
	"intent.damage": ["v1_battle_resolver attack branch _damage_player"],
	"intent.label": ["v1_battle_resolver enemy_attack log", "action_preview_service fight risk", "battle_snapshot"],
	"intent.speed": ["v1_battle_resolver store", "battle_snapshot", "gu_enemy_actor_view"],
	"intent.cooldown": ["v1_battle_resolver._intent_ready gate"],
	"intent.essence_burn": ["battle_command_facade whitelist", "v1_battle_resolver store", "v1_battle_resolver attack-branch settle"],
	"intent.seal_turns": ["v1_battle_resolver seal branch"],
	"intent.soul_drain": ["v1_battle_resolver soul_drain branch"],
	"phase.until_hp_ratio": ["v1_battle_resolver.active_phase_index"],
	"phase.intents": ["v1_battle_resolver.select_enemy_intent (structural container)"],
	"phases": ["battle_command_facade passthrough", "v1_battle_resolver._build_enemies store"],
	"reaction.trigger": ["action_preview_service._live_counter_labels", "action_preview_service fight preview"],
	"reaction.window": ["action_preview_service._live_counter_labels", "action_preview_service fight preview"],
	"reaction.counter_status": ["action_preview_service._live_counter_labels bound/guarded flags"],
	"reaction.label": ["action_preview_service labels", "action_preview_service fight preview"],
}

## 字段豁免表（字段 → 原因）。reaction.id / reaction.clue 全仓无 runtime 读取：
## 前者是稳定标识（未来接线/遥测钩子），后者是叙事钩子（未来线索掉落接线）。
## 诚实登记，不伪造消费点。
const EXEMPT_FIELDS := {
	"reaction.id": "stable identifier; no runtime read in scripts (future wiring/telemetry hook)",
	"reaction.clue": "narrative hook; no runtime read in scripts (future clue-drop wiring)",
	"phase.reactions": "UNWIRED, not covered: (1) runtime only reads top-level reactions (action_preview_service.gd:338/:1056 enemy.get counter_revealed/reactions); phases[i].reactions has zero reads (resolver only touches phases[i].until_hp_ratio/:intents); (2) latent gap, not a live bug: all 5 phased bosses (miasma_vein_lord/thunder_crown_sovereign/blood_vein_bishop/clan_patriarch/blue_fur_jiangshi) declare per-phase reaction tables verbatim-identical to their top-level tables, so behavior is currently unchanged; (3) wiring needs a design ruling first (per-phase table REPLACES vs APPENDS the top-level table) — data does not say; must not decide unilaterally",
}

## 取值豁免表：thunder_crown_wolf.thunder_reflex counter_status="sparked"。
## 取证：game/scripts + game/docs + lore/wiki 全仓零语义定义；web-lab 明确剔除
## （build_data.mjs:79「不纳入…本页不臆造」）。无明确语义不实现，待 L1 裁决。
const EXEMPT_VALUES := {
	"sparked": "reaction counter_status with no defined semantics anywhere; pending L1 ruling; must not invent",
}

## 消费点存在性标记（文件名 → 必须包含的源码标记）。
const CONSUMPTION_MARKERS := {
	RESOLVER_PATH: ["essence_burn", "until_hp_ratio", "last_fired", "_intent_ready", "phase_shift", "cooldown_wait"],
	FACADE_PATH: ["essence_burn", "phases"],
	PREVIEW_PATH: ["counter_status", "trigger", "window"],
}

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _live_keys() -> Dictionary:
	var intents := {}
	var reactions := {}
	var phases := {}
	var enemy_by_id: Dictionary = catalog.get("enemy_by_id", {})
	for enemy_id in enemy_by_id:
		var enemy: Dictionary = enemy_by_id[enemy_id]
		for key in (enemy.get("intent", {}) as Dictionary):
			intents[key] = true
		for reaction_value in (enemy.get("reactions", []) as Array):
			for key in (reaction_value as Dictionary):
				reactions[key] = true
		for phase_value in (enemy.get("phases", []) as Array):
			var phase: Dictionary = phase_value
			for key in phase:
				phases[key] = true
			for intent_value in (phase.get("intents", []) as Array):
				for key in (intent_value as Dictionary):
					intents[key] = true
			for reaction_value in (phase.get("reactions", []) as Array):
				for key in (reaction_value as Dictionary):
					reactions[key] = true
	return {"intent": intents.keys(), "reaction": reactions.keys(), "phase": phases.keys()}


func _check(coverage: Dictionary, exempt: Dictionary) -> Array:
	var missing: Array = []
	for field in INTENT_FIELDS:
		var key := "intent.%s" % field
		if not coverage.has(key) and not exempt.has(key):
			missing.append(key)
	for field in PHASE_FIELDS:
		var key := "phase.%s" % field
		if not coverage.has(key) and not exempt.has(key):
			missing.append(key)
	if not coverage.has("phases") and not exempt.has("phases"):
		missing.append("phases")
	for field in REACTION_FIELDS:
		var key := "reaction.%s" % field
		if not coverage.has(key) and not exempt.has(key):
			missing.append(key)
	return missing


func test_live_data_keys_match_expected_sets() -> void:
	var live := _live_keys()
	var intent_live: Array = live["intent"]
	intent_live.sort()
	var intent_expected: Array = INTENT_FIELDS.duplicate()
	intent_expected.sort()
	assert_eq(intent_live, intent_expected, "new intent field in data must be triaged into COVERAGE or EXEMPT_FIELDS")
	var reaction_live: Array = live["reaction"]
	reaction_live.sort()
	var reaction_expected: Array = REACTION_FIELDS.duplicate()
	reaction_expected.sort()
	assert_eq(reaction_live, reaction_expected, "new reaction field in data must be triaged")
	var phase_live: Array = live["phase"]
	phase_live.sort()
	var phase_expected: Array = PHASE_FIELDS.duplicate()
	phase_expected.sort()
	assert_eq(phase_live, phase_expected, "new phase field in data must be triaged")


func test_every_field_covered_or_exempt() -> void:
	var missing := _check(COVERAGE, EXEMPT_FIELDS)
	assert_eq(missing, [], "every enemy data field needs a consumption point or a reasoned exemption")


func test_exempt_table_guards() -> void:
	assert_false(EXEMPT_FIELDS.is_empty(), "empty exempt table must fail: known gaps must be honestly registered")
	var total := INTENT_FIELDS.size() + PHASE_FIELDS.size() + REACTION_FIELDS.size() + 1
	assert_true(EXEMPT_FIELDS.size() < total, "full exemption must fail: the table must not become a trash can")
	assert_true(EXEMPT_VALUES.has("sparked"), "sparked must stay registered until L1 rules")


func test_consumption_markers_exist_in_sources() -> void:
	for path in CONSUMPTION_MARKERS:
		var source := FileAccess.get_file_as_string(str(path))
		assert_false(source.is_empty(), "must be able to read %s" % str(path))
		for marker in (CONSUMPTION_MARKERS[path] as Array):
			assert_true(source.contains(str(marker)),
					"%s must contain consumption point %s" % [str(path), str(marker)])


func test_sparked_declared_but_unconsumed() -> void:
	var wolf: Dictionary = (catalog.get("enemy_by_id", {}) as Dictionary).get("thunder_crown_wolf", {})
	var statuses: Array = []
	for reaction_value in (wolf.get("reactions", []) as Array):
		statuses.append(str((reaction_value as Dictionary).get("counter_status", "")))
	assert_true(statuses.has("sparked"), "precondition: data still declares sparked")
	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	var resolver := FileAccess.get_file_as_string(RESOLVER_PATH)
	assert_false(preview.contains("sparked"), "no invented sparked handling in preview")
	assert_false(resolver.contains("sparked"), "no invented sparked handling in resolver")


func test_facade_carries_phases_and_burn_fields() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "thunder_crown_sovereign"}, state, catalog)
	var enemy: Dictionary = battle["enemies"][0]
	assert_eq((enemy.get("phases", []) as Array).size(), 2)
	var burn_found := false
	for phase_value in (enemy.get("phases", []) as Array):
		for intent_value in ((phase_value as Dictionary).get("intents", []) as Array):
			if int((intent_value as Dictionary).get("essence_burn", 0)) == 2:
				burn_found = true
	assert_true(burn_found, "essence_burn must survive the facade passthrough inside phases")
	assert_true(enemy["intent"].has("essence_burn"), "top intent carries the burn key (default 0)")
	assert_true(enemy["intent"].has("cooldown"), "top intent carries the cooldown key")
	assert_true(enemy["intent"].has("id"), "top intent carries the id key")


func test_negative_control_erased_coverage_is_caught() -> void:
	var sabotaged: Dictionary = (COVERAGE as Dictionary).duplicate(true)
	sabotaged.erase("intent.essence_burn")
	var missing := _check(sabotaged, EXEMPT_FIELDS)
	assert_eq(missing, ["intent.essence_burn"], "erasing one consumption point must fail the check")
	var sabotaged_exempt: Dictionary = (EXEMPT_FIELDS as Dictionary).duplicate(true)
	sabotaged_exempt.erase("reaction.clue")
	var missing2 := _check(COVERAGE, sabotaged_exempt)
	assert_eq(missing2, ["reaction.clue"], "erasing one exemption must fail the check")
