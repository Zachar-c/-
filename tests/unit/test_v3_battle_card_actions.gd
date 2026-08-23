extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_playing_card_moves_only_cached_instances_without_rebuilding_full_deck() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var initial_hash := str(battle["deck_generation_hash"])
	var initial_cache: Array = battle["deck_cache"].duplicate(true)

	var result := BattleResolver.apply_action_card(battle, run, _first_card_command(battle), catalog)

	assert_true(result["accepted"])
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
	battle["hand_version"] = int(battle["hand_version"]) + 1

	var result := BattleResolver.apply_action_card(battle, run, command, catalog)

	assert_false(result["accepted"])
	assert_eq(result["feeds"], ["battle_hand_stale"])
	assert_eq(result["state"], run)


func test_battle_preview_reads_hand_and_uses_battle_local_version() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var cards := ActionPreviewServiceScript.preview_battle_actions(battle, run, catalog)
	var hand_card := _card(cards, _first_card_command(battle)["action_id"])

	assert_eq(hand_card["state_version"], battle["hand_version"])
	assert_eq(hand_card["command"], {})
	assert_eq(hand_card["cost"]["spirit"], 1)
	assert_eq(hand_card["expected_gain"], ["照出敌方异状并推进试探。"])

func test_battle_starts_with_a_limited_hand_and_keeps_remaining_cards_in_draw_pile() -> void:
	var run := _run_with_three_card_sources()
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)

	assert_eq(battle["deck_cache"].size(), 3)
	assert_eq(battle["hand"].size(), 2)
	assert_eq(battle["draw_pile"].size(), 1)


func test_end_turn_discards_remaining_hand_then_refills_from_cached_piles() -> void:
	var run := _run_with_three_card_sources()
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var previous_version := int(battle["hand_version"])

	var result := BattleResolver.apply_action_card(battle, run, {
		"type": "action_card",
		"action_id": "battle.end_turn",
		"state_version": previous_version,
	}, catalog)

	assert_true(result["accepted"])
	assert_eq(result["battle"]["hand"].size(), 2)
	assert_eq(
		result["battle"]["hand"].size() + result["battle"]["draw_pile"].size() + result["battle"]["discard_pile"].size(),
		result["battle"]["deck_cache"].size()
	)
	assert_gt(int(result["battle"]["hand_version"]), previous_version)


func _run_with_three_card_sources() -> RunState:
	var run := RunState.new_run(101)
	run.gu_instances["gu_002"] = {"instance_id": "gu_002", "definition_id": "stone_shell_gu", "state": "refined"}
	run.gu_instances["gu_003"] = {"instance_id": "gu_003", "definition_id": "moonlight_gu", "state": "refined"}
	run.cave_aperture["stored_gu_instance_ids"].append_array(["gu_002", "gu_003"])
	run.sync_legacy_gu_projections()
	return run

func _first_card_command(battle: Dictionary) -> Dictionary:
	var card: Dictionary = battle["hand"][0]
	return {
		"type": "action_card",
		"action_id": "battle.%s.%s" % [str(battle["battle_id"]), str(card["instance_id"])],
		"state_version": int(battle["hand_version"]),
	}

func _card(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card.get("id", "")) == id:
			return card
	push_error("Missing battle action card: %s" % id)
	return {}




