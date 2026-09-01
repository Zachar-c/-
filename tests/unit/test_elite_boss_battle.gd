extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_elite_enemy_battle_starts_with_data_stats() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_elite_scout"}, run, catalog)

	assert_eq(str(battle["enemy_kind"]), "ridge_elite_scout")
	assert_eq(int(battle["enemy_hp"]), 6)


func test_boss_enemy_pre_turn_deals_intent_damage() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "miasma_vein_lord"}, run, catalog)
	assert_eq(int(battle["enemy_hp"]), 8)

	var pre := BattleResolver.apply_enemy_pre_turn(battle, run, catalog)
	assert_false(pre["finished"])
	assert_eq(int(pre["state"].health), 78)
	assert_eq(int(pre["battle"]["log"].back()["damage"]), 2)


func test_new_enemy_labels_exist_in_display_text() -> void:
	assert_eq(DisplayText.enemy("ridge_elite_scout"), "山脊悍客")
	assert_eq(DisplayText.enemy("miasma_vein_lord"), "瘴脉蛊主")