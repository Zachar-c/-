extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_stone_wanderer_exposes_intent_and_visible_clues() -> void:
	var battle := BattleResolver.start({"enemy_kind": "neutral_stone_wanderer"}, RunState.new_run(101), catalog)

	assert_eq(battle["phase"], "player")
	assert_eq(battle["visible_intent"]["id"], "stone_palm")
	assert_true(battle["clues"].has("stone_dust"))
	assert_true(battle["clues"].has("steady_stance"))


func test_direct_strike_triggers_stone_shell_before_damage() -> void:
	var state := RunState.new_run(101)
	state.refined_gu_ids.append("thorn_whip_gu")
	var battle := BattleResolver.start({"enemy_kind": "neutral_stone_wanderer"}, state, catalog)
	var turn := BattleResolver.take_turn(battle, {"type": "use_gu", "gu_id": "thorn_whip_gu", "mode": "strike"}, state, catalog)

	assert_eq(turn["battle"]["enemy_hp"], battle["enemy_hp"])
	assert_true(turn["battle"]["revealed_reactions"].has("stone_shell"))
	assert_eq(turn["battle"]["log"].back()["id"], "stone_shell")


func test_bind_then_strike_bypasses_stone_shell_and_kills_wounded_enemy() -> void:
	var state := RunState.new_run(101)
	state.refined_gu_ids.append("thorn_whip_gu")
	var battle := BattleResolver.start({"enemy_kind": "neutral_stone_wanderer", "enemy_hp": 2}, state, catalog)
	var bound := BattleResolver.take_turn(battle, {"type": "use_gu", "gu_id": "thorn_whip_gu", "mode": "bind"}, state, catalog)
	var strike := BattleResolver.take_turn(bound["battle"], {"type": "use_gu", "gu_id": "thorn_whip_gu", "mode": "strike"}, bound["state"], catalog)

	assert_true(strike["finished"])
	assert_eq(strike["result"], "victory")
	assert_eq(strike["battle"]["enemy_hp"], 0)


func test_end_turn_executes_visible_lethal_intent_and_records_death() -> void:
	var state := RunState.new_run(101)
	state.health = 2
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, state, catalog)
	var turn := BattleResolver.take_turn(battle, {"type": "end_turn"}, state, catalog)

	assert_true(turn["finished"])
	assert_eq(turn["result"], "death")
	assert_eq(turn["state"].health, 0)
	assert_eq(turn["battle"]["final_blow"]["id"], "pounce")
