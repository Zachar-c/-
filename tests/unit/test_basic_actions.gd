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


func test_punch_does_not_touch_hand_version_or_soul() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var result := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, catalog)

	assert_eq(int(result["battle"]["hand_version"]), int(battle["hand_version"]))
	assert_eq(int(result["state"].cultivator["soul"]), 4)


func test_punch_triggers_known_reaction_like_direct_strike() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "neutral_stone_wanderer"}, run, catalog)
	battle["hand"] = []
	var result := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, catalog)

	assert_true(result["battle"]["revealed_reactions"].has("stone_shell"))
	assert_eq(int(result["battle"]["enemy_hp"]), int(battle["enemy_hp"]))


func test_dodge_exempts_slower_attack_and_is_consumed() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	battle["hand"] = []
	var dodged := BattleResolver.take_turn(battle, {"type": "basic_dodge"}, run, catalog)
	assert_true(dodged["accepted"])
	assert_true(dodged["battle"]["flags"].has("dodging"))

	var turn := BattleResolver.take_turn(dodged["battle"], {"type": "end_turn"}, dodged["state"], catalog)
	assert_eq(int(turn["state"].health), 6)
	assert_false(turn["battle"]["flags"].has("dodging"))
	assert_true(bool(turn["battle"]["log"].back().get("dodged", false)))


func test_dodge_fails_against_faster_attack() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_elite_scout"}, run, catalog)
	battle["hand"] = []
	var dodged := BattleResolver.take_turn(battle, {"type": "basic_dodge"}, run, catalog)
	var turn := BattleResolver.take_turn(dodged["battle"], {"type": "end_turn"}, dodged["state"], catalog)

	assert_eq(int(turn["state"].health), 3)
	assert_false(bool(turn["battle"]["log"].back().get("dodged", false)))


func test_dodge_flag_is_consumed_by_the_next_attack_only() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	battle["hand"] = []
	var dodged := BattleResolver.take_turn(battle, {"type": "basic_dodge"}, run, catalog)
	var first := BattleResolver.take_turn(dodged["battle"], {"type": "end_turn"}, dodged["state"], catalog)
	# The flag is gone: a second end turn takes full damage again
	# (pounce deals 2 since the opening-fairness retune).
	var second := BattleResolver.take_turn(first["battle"], {"type": "end_turn"}, first["state"], catalog)
	assert_eq(int(second["state"].health), 4)


func test_dodge_can_be_readied_repeatedly_without_cost() -> void:
	var run := RunState.new_run(101)
	run.essence = 0
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	battle["hand"] = []
	var first := BattleResolver.take_turn(battle, {"type": "basic_dodge"}, run, catalog)
	var second := BattleResolver.take_turn(first["battle"], {"type": "basic_dodge"}, first["state"], catalog)

	assert_true(second["accepted"])
	assert_eq(second["state"].event_log.back()["reason"], "battle_basic_dodge")