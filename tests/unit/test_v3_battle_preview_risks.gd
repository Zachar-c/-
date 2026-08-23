extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_duration_card_preview_exposes_soul_control_overflow_before_submission() -> void:
	var run := _run_with_stone_shell()
	run.cultivator["soul_control_limit"] = 0
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var card := _card_by_definition(ActionPreviewServiceScript.preview_battle_actions(battle, run, catalog), battle, "stone_guard")

	assert_string_contains(str(card["known_risk"]), "魂魄")
	assert_string_contains(str(card["known_risk"]), "反噬")


func test_higher_rank_card_preview_exposes_known_rank_backlash_before_submission() -> void:
	var tuned_catalog := catalog.duplicate(true)
	tuned_catalog["gu_by_id"]["small_light_gu"]["rank"] = 2
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, tuned_catalog)
	var card := _card_by_definition(ActionPreviewServiceScript.preview_battle_actions(battle, run, tuned_catalog), battle, "light_probe")

	assert_string_contains(str(card["known_risk"]), "高转")
	assert_string_contains(str(card["known_risk"]), "反噬")


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
