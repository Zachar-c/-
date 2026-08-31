extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_duration_card_preview_exposes_soul_control_overflow_before_submission() -> void:
	var run := _run_with_stone_shell()
	run.cultivator["soul"] = 1
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	battle["active_gu_instance_ids"] = ["gu_003"]
	var card := _card_by_definition(ActionPreviewServiceScript.preview_battle_actions(battle, run, catalog), battle, "stone_guard")

	assert_string_contains(str(card["known_risk"]), "魂魄")
	assert_string_contains(str(card["known_risk"]), "反噬")


func test_higher_rank_card_preview_exposes_rank_multiplier_cost() -> void:
	var tuned_catalog := catalog.duplicate(true)
	tuned_catalog["gu_by_id"]["small_light_gu"]["rank"] = 2
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, tuned_catalog)
	var card := _card_by_definition(ActionPreviewServiceScript.preview_battle_actions(battle, run, tuned_catalog), battle, "light_probe")

	# §16.5 信息透明：高转蛊的威力与催动真元按转数因子放大，预览必须同源披露。
	assert_string_contains(str(card["expected_gain"]), "转蛊")
	assert_string_contains(str(card["expected_gain"]), "×3")


func test_combat_fight_card_warns_about_enemy_reaction_and_damage_numbers() -> void:
	# §16.5 敌意透明：开战预览必须提前暴露反制与伤害数值，防止玩家
	# 毫无防备走进"拳脚全被吞"的必败战斗。
	var node: Dictionary = {}
	for entry_value in catalog.get("nodes", []):
		if str((entry_value as Dictionary).get("id", "")) == "beast_swarm_pass":
			node = entry_value
			break
	assert_false(node.is_empty(), "beast_swarm_pass exists in catalog")
	var run := RunState.new_run(101)
	var cards := ActionPreviewServiceScript.preview_actions(run, node, catalog)
	var fight := {}
	for card in cards:
		if str(card.get("id", "")) == "node.fight":
			fight = card
			break
	assert_false(fight.is_empty(), "node.fight preview card exists")
	var risks := ""
	for risk in fight.get("known_risk", []):
		risks += str(risk)
	assert_string_contains(risks, "反制")
	assert_string_contains(risks, "拳脚")
	assert_string_contains(risks, "2 点")
	var remedies := ""
	for remedy in fight.get("remedy_hints", []):
		remedies += str(remedy)
	assert_string_contains(remedies, "蛊")


func _run_with_stone_shell() -> RunState:
	var run := RunState.new_run(101)
	run.gu_instances["gu_002"] = {
		"instance_id": "gu_002",
		"definition_id": "stone_shell_gu",
		"state": "refined",
	}
	run.cave_aperture["stored_gu_instance_ids"].append("gu_002")
	run.sync_legacy_gu_projections()
	return run


func _card_by_definition(cards: Array, battle: Dictionary, definition_id: String) -> Dictionary:
	for instance in battle["hand"]:
		if str(instance["definition_id"]) != definition_id:
			continue
		var card_id := "battle.%s.%s" % [battle["battle_id"], instance["instance_id"]]
		for card in cards:
			if str(card["id"]) == card_id:
				return card
	push_error("Missing preview card: %s" % definition_id)
	return {}
