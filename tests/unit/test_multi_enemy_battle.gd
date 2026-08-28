extends GutTest


var catalog: Dictionary
var run: RunState


func before_each() -> void:
	catalog = ContentCatalog.load_all()
	run = RunState.new_run(101)


func test_multi_enemy_battle_has_stable_ids_and_independent_intents() -> void:
	var battle := BattleResolver.start({
		"enemy_kinds": ["ridge_hound", "neutral_stone_wanderer"],
	}, run, catalog)

	assert_eq(battle["enemies"].size(), 2)
	assert_eq(battle["enemies"][0]["enemy_id"], "%s:e0" % battle["battle_id"])
	assert_eq(battle["enemies"][1]["enemy_id"], "%s:e1" % battle["battle_id"])
	assert_eq(battle["enemies"][0]["kind"], "ridge_hound")
	assert_eq(battle["enemies"][1]["kind"], "neutral_stone_wanderer")
	assert_true(battle["enemies"][0]["visible_intent"].has("id"))
	assert_true(battle["enemies"][1]["visible_intent"].has("id"))


func test_single_target_card_only_damages_selected_living_enemy() -> void:
	var battle := _two_enemy_battle()
	var target_id := str(battle["enemies"][1]["enemy_id"])
	var before_hp := int(battle["enemies"][0]["hp"])
	var target_hp := int(battle["enemies"][1]["hp"])

	var result := BattleResolver.apply_action_card(battle, run, _first_card_command(battle, target_id), catalog)

	assert_true(result["accepted"])
	assert_eq(int(result["battle"]["enemies"][0]["hp"]), before_hp)
	assert_lt(int(result["battle"]["enemies"][1]["hp"]), target_hp)


func test_missing_or_invalid_target_rejects_without_mutating_battle_or_run() -> void:
	var battle := _two_enemy_battle()
	var before := battle.duplicate(true)
	var result := BattleResolver.apply_action_card(battle, run, _first_card_command(battle, ""), catalog)

	assert_false(result["accepted"])
	assert_eq(result["feeds"], ["battle_target_invalid"])
	assert_eq(result["battle"], before)
	assert_eq(result["state"], run)


func test_legacy_single_enemy_card_command_defaults_to_only_living_target() -> void:
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var card: Dictionary = battle["hand"][0]
	var before_hp := int(battle["enemies"][0]["hp"])

	var result := BattleResolver.apply_action_card(battle, run, {
		"type": "action_card",
		"action_id": "battle.%s.%s" % [str(battle["battle_id"]), str(card["instance_id"])],
		"state_version": int(battle["hand_version"]),
	}, catalog)

	assert_true(result["accepted"])
	assert_lt(int(result["battle"]["enemies"][0]["hp"]), before_hp)


func test_legacy_single_enemy_projection_inputs_sync_into_authoritative_enemy() -> void:
	var battle := BattleResolver.start({"enemy_kind": "miasma_vein_lord"}, run, catalog)
	battle["enemy_hp"] = 5
	battle["enemy_phase_index"] = 1
	battle["intent_cooldowns"] = {"miasma_burst": 9}

	BattleResolver._select_enemy_intent(battle, run, 4)

	assert_eq(int(battle["enemies"][0]["hp"]), 5)
	assert_eq(int(battle["enemies"][0]["phase_index"]), 1)
	assert_eq(int(battle["enemies"][0]["intent_cooldowns"]["miasma_burst"]), 9)
	assert_eq(str(battle["visible_intent"]["id"]), "essence_scorch")


func test_legacy_scalar_strike_without_enemy_entities_preserves_enemy_hp() -> void:
	var battle := {"enemy_hp": 8, "intel_bonus": 1}

	BattleResolver._strike(battle, 3)

	assert_eq(int(battle["enemy_hp"]), 4)


func test_basic_punch_requires_a_living_target_without_mutation() -> void:
	var battle := _two_enemy_battle()
	var before := battle.duplicate(true)
	var result := BattleResolver.apply_action_card(battle, run, {
		"type": "action_card",
		"action_id": "battle.basic.punch",
		"state_version": int(battle["hand_version"]),
	}, catalog)

	assert_false(result["accepted"])
	assert_eq(result["feeds"], ["battle_target_invalid"])
	assert_eq(result["battle"], before)
	assert_eq(result["state"], run)


func test_enemy_turn_resolves_every_living_enemy_in_stable_order() -> void:
	var battle := _two_enemy_battle()
	battle["enemies"][0]["visible_intent"] = {"id": "first", "damage": 1, "speed": 0}
	battle["enemies"][1]["visible_intent"] = {"id": "second", "damage": 2, "speed": 0}
	var result := BattleResolver.apply_action_card(battle, run, {
		"type": "action_card",
		"action_id": "battle.end_turn",
		"state_version": int(battle["hand_version"]),
	}, catalog)

	assert_true(result["accepted"])
	assert_eq(result["state"].health, run.health - 3)
	assert_eq(result["battle"]["log"][-2]["id"], "first")
	assert_eq(result["battle"]["log"][-1]["id"], "second")


func _two_enemy_battle() -> Dictionary:
	return BattleResolver.start({
		"enemy_kinds": ["ridge_hound", "neutral_stone_wanderer"],
	}, run, catalog)


func _first_card_command(battle: Dictionary, target_id: String) -> Dictionary:
	var card: Dictionary = battle["hand"][0]
	return {
		"type": "action_card",
		"action_id": "battle.%s.%s" % [str(battle["battle_id"]), str(card["instance_id"])],
		"card_id": str(card["instance_id"]),
		"target_id": target_id,
		"state_version": int(battle["hand_version"]),
	}
