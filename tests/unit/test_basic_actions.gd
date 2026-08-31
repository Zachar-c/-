extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_punch_works_with_zero_essence_and_empty_hand() -> void:
	var run := RunState.new_run(101)
	run.essence = 0
	# "wild_boar" falls back to the reaction-free legacy enemy table.
	var battle := BattleResolver.start({"enemy_kind": "wild_boar"}, run, catalog)
	battle["hand"] = []
	var result := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, catalog)

	assert_true(result["accepted"])
	assert_eq(int(result["battle"]["enemy_hp"]), int(battle["enemy_hp"]) - 1)
	assert_eq(result["state"].event_log.back()["reason"], "battle_basic_attack")


func test_punch_costs_one_action_and_keeps_hand_version() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var result := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, catalog)

	assert_eq(int(result["battle"]["hand_version"]), int(battle["hand_version"]))
	assert_eq(int(result["state"].cultivator["soul"]), 1, "拳脚不耗魂魄")
	assert_eq(int(result["battle"]["actions_left"]), int(battle["actions_left"]) - 1, "拳脚耗 1 行动点")


func test_punch_triggers_known_reaction_like_direct_strike() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "neutral_stone_wanderer"}, run, catalog)
	battle["hand"] = []
	var result := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, catalog)

	assert_true(result["battle"]["revealed_reactions"].has("stone_shell"))
	assert_eq(int(result["battle"]["enemy_hp"]), int(battle["enemy_hp"]))


func test_dodge_grants_one_temp_block_consumed_by_intent() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	battle["hand"] = []
	var dodged := BattleResolver.take_turn(battle, {"type": "basic_dodge"}, run, catalog)
	assert_true(dodged["accepted"])
	assert_eq(int(dodged["battle"].get("player_block", 0)), 1, "闪避 +1 临时防御")
	assert_true(dodged["battle"]["flags"].has("dodge_used"))

	# 敌 intent 2 伤被 1 点护盾吸收 → 剩 1 伤；护盾清零
	var turn := BattleResolver.take_turn(dodged["battle"], {"type": "end_turn"}, dodged["state"], catalog)
	assert_eq(int(turn["state"].health), int(dodged["state"].health) - 1)
	assert_eq(int(turn["battle"].get("player_block", 0)), 0, "回合结束护盾清零")


func test_dodge_block_only_absorbs_one_point() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_elite_scout"}, run, catalog)
	battle["hand"] = []
	var dodged := BattleResolver.take_turn(battle, {"type": "basic_dodge"}, run, catalog)
	var turn := BattleResolver.take_turn(dodged["battle"], {"type": "end_turn"}, dodged["state"], catalog)
	# 弩箭 3 伤：护盾吸 1 → 扣 2
	assert_eq(int(turn["state"].health), int(dodged["state"].health) - 2)


func test_dodge_flag_is_consumed_by_the_next_attack_only() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	battle["hand"] = []
	var dodged := BattleResolver.take_turn(battle, {"type": "basic_dodge"}, run, catalog)
	var first := BattleResolver.take_turn(dodged["battle"], {"type": "end_turn"}, dodged["state"], catalog)
	# 护盾只在当回合生效：第二回合全额受击
	var second := BattleResolver.take_turn(first["battle"], {"type": "end_turn"}, first["state"], catalog)
	assert_eq(int(second["state"].health), int(first["state"].health) - 2)


func test_dodge_is_once_per_turn_and_costs_an_action() -> void:
	var run := RunState.new_run(101)
	run.essence = 0
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	battle["hand"] = []
	var first := BattleResolver.take_turn(battle, {"type": "basic_dodge"}, run, catalog)
	assert_true(first["accepted"])
	var second := BattleResolver.take_turn(first["battle"], {"type": "basic_dodge"}, first["state"], catalog)
	assert_true(second["feeds"].has("dodge_exhausted"), "同回合第二次闪避被拒（feeds 拒绝惯例）")