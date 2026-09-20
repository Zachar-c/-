extends GutTest


# UI sync regression: domain snapshots and active RUI screens expose the current state.


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")
const BATTLE_SCREEN_TSCN := "res://scenes/ui/screens/battle_screen.tscn"
const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const BattleCommandFacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const NODE_CASES := [
	{"id": "neutral_wanderer", "type": "contact", "choices": ["negotiate", "deceive", "fight", "retreat"]},
	{"id": "ridge_caravan", "type": "caravan", "choices": []},
	{"id": "refinement_hollow", "type": "refinement", "choices": []},
	{"id": "cultivation_spring", "type": "cultivation", "choices": []},
	{"id": "stage_one_ledger", "type": "ledger", "choices": []},
	{"id": "ridge_black_market", "type": "shop", "choices": []},
	{"id": "echo_cave", "type": "event", "choices": []},
	{"id": "toxic_mountain_path", "type": "hazard", "choices": ["scout", "cross", "withdraw"]},
	{"id": "blood_moss_grove", "type": "wild_gu", "choices": ["harvest", "trade", "leave"]},
	{"id": "village_short_work", "type": "market", "choices": ["work", "trade", "leave"]},
	{"id": "moonlit_trail", "type": "inheritance", "choices": ["inspect", "claim", "leave"]},
	{"id": "beast_swarm_pass", "type": "combat", "choices": ["fight", "retreat", "lure"]},
	{"id": "greedy_wanderer", "type": "pursuit", "choices": ["fight", "trade", "retreat"]},
	{"id": "earth_vein_contest", "type": "earth_vein", "choices": ["ally", "scheme", "fight", "retreat"]},
	{"id": "body_imprint_ritual", "type": "seclusion", "choices": ["meditate", "take_imprint", "leave"]},
	{"id": "herbalist_commission", "type": "commission", "choices": ["accept", "trade", "leave"]},
	{"id": "ascension_window", "type": "ascension", "choices": ["attempt_ascension", "prepare", "retreat"]},
]


func test_battle_screen_surfaces_dda_boss_hint() -> void:
	var hint_text := DisplayText.dda_hint("boss_senses_gu_power")
	assert_eq(hint_text, "蛊躁动·Boss 感应到了你的蛊虫气息")
	assert_eq(DisplayText.dda_hint("unknown_hint_id"), "")

	var controller: RunController = _battle_controller()
	var snapshot: Dictionary = controller._snapshot_for("Battle")
	snapshot["dda_boss_hint"] = "boss_senses_gu_power"
	var texts := _battle_tscn_texts(snapshot)
	assert_true(_any_contains(texts, hint_text), "RUI battle screen must surface the DDA boss hint marker")


func test_battle_screen_surfaces_dda_anomaly_marker() -> void:
	var controller: RunController = _battle_controller()
	var snapshot: Dictionary = controller._snapshot_for("Battle")
	snapshot["anomalies"] = [{"id": "sys:dda_peril", "label": "险象"}]
	var texts := _battle_tscn_texts(snapshot)
	assert_true(_any_contains(texts, "险象"), "RUI battle screen must surface the DDA anomaly marker")
	assert_false(_any_contains(texts, "sys:dda_peril"), "marker id must never leak to the battle screen")


func test_battle_view_renders_hud_bars_intent_and_actions() -> void:
	var controller: RunController = _battle_controller()
	var snapshot: Dictionary = controller._snapshot_for("Battle")
	assert_eq(snapshot["enemies"].size(), 1)
	var enemy: Dictionary = snapshot["enemies"][0]
	assert_true(int(enemy["hp"]) > 0, "battle snapshot must expose enemy hp")
	assert_true(str(enemy["intent"].get("type", "")) != "", "battle snapshot must expose enemy intent")
	assert_true(snapshot["player"].has("hp"), "battle snapshot must expose player hp")
	assert_true(snapshot["player"].has("soul"), "battle snapshot must expose player soul")
	var texts := _battle_tscn_texts(snapshot)
	assert_true(_any_contains(texts, "意图："), "battle screen must render enemy intent")


func test_battle_snapshot_projects_multiple_enemies_piles_and_actions() -> void:
	var controller := _battle_controller()
	controller.current_battle = BattleCommandFacadeScript.start({
		"enemy_kinds": ["ridge_hound", "neutral_stone_wanderer"],
	}, controller.state, controller.catalog)
	var snapshot: Dictionary = controller._snapshot_for("Battle")

	assert_eq(snapshot["enemies"].size(), 2)
	assert_eq(snapshot["default_target_id"], snapshot["enemies"][0]["id"])
	assert_true(snapshot["enemies"][1].has("statuses"))
	# V1 契约：无牌库/弃牌堆，只有行动点（念头分档）与蛊槽。
	assert_true((snapshot["piles"] as Dictionary).is_empty(), "V1 battle must not expose card piles")
	assert_true(snapshot["actions"].has("max"))
	assert_true(snapshot["actions"].has("left"))
	assert_eq(int(snapshot["actions"]["max"]), 2, "action budget = soul-tier 2 for 底蕴 1")
	assert_eq(int(snapshot["actions"]["left"]), 2, "actions start full")
	# V1 敌人 id 直映（非旧卡牌 enemy_id）；意图 kind 直映。
	assert_eq(str(snapshot["enemies"][0]["id"]), "ridge_hound")
	assert_eq(str(snapshot["enemies"][0]["intent"]["type"]), "attack")


func test_battle_snapshot_carries_all_eight_v2_groups() -> void:
	var controller := _battle_controller()
	var snapshot: Dictionary = controller._snapshot_for("Battle")
	for index in range(1, 9):
		var key := "group%d_%s" % [
			index, ["gu_ledger", "core", "recipes", "feeding", "market", "body", "action", "soul"][index - 1]]
		assert_true(snapshot.has(key), "real Battle snapshot must carry %s" % key)
	assert_eq_deep(snapshot["group1_gu_ledger"]["gu_used"],
			controller.state.battle2_ledger.get("gu_used", {}))


func test_battle_view_hud_uses_programmatic_icons() -> void:
	var controller: RunController = _battle_controller()
	var snapshot: Dictionary = controller._snapshot_for("Battle")
	var resources: Dictionary = snapshot.get("resources", {})
	assert_eq(resources.size(), 3, "battle hud must expose only the three status resource chips")
	for key in ["yuanstone", "shouyuan", "hunpo"]:
		assert_true(resources.has(key), "battle hud missing resource chip %s" % key)
	assert_false(resources.has("material"), "materials belong in the satchel, not the status bar")


func test_battle_hud_shows_formula_true_qi_max() -> void:
	var controller: RunController = _battle_controller()
	var snapshot: Dictionary = controller._snapshot_for("Battle")
	# V1 真元：上限=境界基础(一转10)×资质倍率(丙2)=20，开局满。
	var primordial := int(snapshot["player"]["primordial"])
	var primordial_max := int(snapshot["player"]["primordial_max"])
	assert_eq(primordial, 20, "battle snapshot must carry current true qi")
	assert_eq(primordial_max, 20, "true qi must respect the aptitude-staged cap")
	assert_true(primordial <= primordial_max, "true qi must never exceed the cap")


func test_battle_hud_shows_multitasking_capacity() -> void:
	var controller: RunController = _battle_controller()
	var snapshot: Dictionary = controller._snapshot_for("Battle")
	assert_true(snapshot["player"].has("soul"), "multitasking capacity must be visible through the soul bar")
	assert_eq(int(snapshot["player"]["soul"]), int(controller.state.cultivator.get("soul", 0)))


func test_battle_snapshot_hides_flee_on_boss_tier_battles() -> void:
	# R-boss-no-retreat: boss battles must not offer the flee button at all.
	var common: RunController = _battle_controller()
	assert_eq(bool(common._snapshot_for("Battle").get("flee_available", true)), true,
			"common battle keeps the retreat button")
	var boss: RunController = _battle_controller()
	boss.current_battle["flags"] = {"boss_battle": true}
	assert_eq(bool(boss._snapshot_for("Battle").get("flee_available", true)), false,
			"boss battle hides the retreat button")


func _battle_controller() -> RunController:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller.start_new_run(101)
	controller.current_node = {"id": "beast_swarm_pass", "type": "combat", "enemy_kind": "ridge_hound"}
	controller.state.encounter_session = EncounterSessionResolverScript.start(controller.current_node)
	controller._start_battle()
	return controller


## 这里走 instantiate + mount_snapshot，文本收集复用 _collect_label_texts。
func _battle_tscn_texts(snapshot: Dictionary) -> Array[String]:
	var host := Control.new()
	add_child_autofree(host)
	host.add_child(TscnMountHelper.instantiate(BATTLE_SCREEN_TSCN, snapshot, {}))
	var out: Array[String] = []
	_collect_label_texts(host, out)
	return out
func _collect_label_texts(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append(str(node.text))
	for c in node.get_children():
		_collect_label_texts(c, out)


func _any_contains(texts: Array[String], substring: String) -> bool:
	for text in texts:
		if text.contains(substring):
			return true
	return false


func test_gu_orb_renders_for_every_known_gu() -> void:
	for gu_id in ["small_light_gu", "moonlight_gu", "moon_glow_gu", "phantom_moon_gu", "moon_shadow_gu", "stone_shell_gu", "trail_eye_gu", "thorn_whip_gu", "blood_moss_gu", "mist_step_gu", "venom_thread_gu", "shadow_veil_gu", "pulse_drum_gu"]:
		var orb: Control = autofree(load("res://scripts/presentation/gu_orb.gd").new())
		add_child(orb)
		orb.gu_id = gu_id
		assert_eq(str(orb.gu_id), gu_id)


func test_enemy_catalog_labels_cover_real_enemy_kinds() -> void:
	assert_eq(DisplayText.enemy("neutral_stone_wanderer"), "石甲散修")
	assert_eq(DisplayText.enemy("ridge_hound"), "山脊猎犬")


func test_controller_records_and_persists_meta_on_death() -> void:
	if FileAccess.file_exists("user://nanjiang_smoke_meta.json"):
		DirAccess.remove_absolute("user://nanjiang_smoke_meta.json")
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller.start_new_run(101)
	controller.force_death_for_test("test_blow")
	var saved = SaveRepository.load_meta_file()
	assert_not_null(saved)
	assert_eq(int(saved.statistics.get("deaths", 0)), 1)


func test_run_save_round_trips_through_disk_json() -> void:
	var state := RunState.new_run(101)
	state.health = 4
	state.encounter_session = {"node_id": "neutral_wanderer", "completed": false}
	var result: Error = SaveRepository.save_run(state, MapGenerator.build(101, true), [])
	assert_eq(result, OK)
	var loaded := SaveRepository.load_run()
	assert_false(loaded.is_empty())
	assert_eq(int(loaded["state"].health), 4)


func test_same_encounter_card_cannot_be_applied_twice() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	state.current_node_id = "neutral_wanderer"
	state.stone = 20
	var node := {"id": "neutral_wanderer", "type": "contact", "choices": ["negotiate", "deceive", "fight", "retreat"]}
	var began := EncounterSessionResolverScript.begin(state, node)
	state = began["state"]
	var card := ActionPreviewServiceScript.find_card(state, node, "node.deceive", catalog)
	assert_false(card.is_empty())
	assert_true(bool(card.get("executable", false)))
	var first := EncounterSessionResolverScript.apply(state, began["session"], {
		"type": "action_card",
		"action_id": "node.deceive",
		"state_version": int(card["state_version"]),
		"node_id": "neutral_wanderer",
		"session_node_id": "neutral_wanderer",
	}, catalog, node)
	assert_true(bool(first["result"].get("ok", false)), "first use of the action must succeed")
	state = first["state"]
	var consumed := ActionPreviewServiceScript.find_card(state, node, "node.deceive", catalog)
	assert_false(bool(consumed.get("executable", false)), "action card must be consumed after success")
	var second := EncounterSessionResolverScript.apply(state, state.encounter_session, {
		"type": "action_card",
		"action_id": "node.deceive",
		"state_version": int(state.event_log.size()),
		"node_id": "neutral_wanderer",
		"session_node_id": "neutral_wanderer",
	}, catalog, node)
	assert_false(bool(second["result"].get("ok", false)), "consumed action card must be rejected")
	assert_eq(int(state.stone), 22, "second use must not grant rewards again")


func test_controller_save_and_load_expose_feedback() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller.start_new_run(101)
	var save_result := controller.submit_command({"type": "save_run"})
	assert_true(bool(save_result.get("ok", false)))
	assert_false(str(save_result.get("feedback", "")).is_empty())
	var load_result := controller.submit_command({"type": "load_run"})
	assert_true(bool(load_result.get("ok", false)))
	assert_false(str(load_result.get("feedback", "")).is_empty())
