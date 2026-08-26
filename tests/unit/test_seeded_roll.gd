extends GutTest


# P2a C: battle intent picks and loot picks shared a hand-copied formula
# (seed*1000003 + tick*97 + salt_hash). SeededRoll owns the formula once; the
# dual-implementation comparison pins all three surfaces to identical outputs
# for identical inputs so neither side can drift again. Written while both
# private implementations still existed; they now delegate to SeededRoll.


const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
const LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")
const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")


func _state_with_tick(seed_value: int, tick: int) -> RunState:
	var run := RunState.new_run(seed_value)
	for index in tick:
		run = run.append_event({"action": "probe_%d" % index, "reason": "seeded_roll_probe"})
	return run


func test_dual_implementations_agree_with_seeded_roll_on_same_inputs() -> void:
	for seed_value in [0, 1, 7, 123, 99991]:
		for tick in [0, 1, 5, 40]:
			for salt in ["boss.intent", "loot.material.one", "loot.gu.pick.one.rare"]:
				var state := _state_with_tick(seed_value, tick)
				var from_battle: int = BattleResolverScript._seeded_index(11, state, salt)
				var from_loot: int = LootResolverScript._pick_from(11, state, salt)
				assert_eq(from_battle, from_loot,
						"dual impl drift seed=%d tick=%d salt=%s" % [seed_value, tick, salt])
				assert_eq(int(SeededRollScript.index(11, state.seed, salt, state.event_log.size())), from_battle,
						"shared helper drift seed=%d tick=%d salt=%s" % [seed_value, tick, salt])


func test_seeded_roll_matches_canonical_formula_computed_independently() -> void:
	# Hand-rolled canonical formula kept independent of production helpers.
	var cases := [
		{"seed": 42, "tick": 3, "salt": "boss.intent"},
		{"seed": 777, "tick": 12, "salt": "loot.material.three"},
	]
	for case_value in cases:
		var case_data: Dictionary = case_value
		var hash := 0
		for character in str(case_data["salt"]):
			hash = hash * 31 + character.unicode_at(0)
		var rng := SeededRng.new(int(case_data["seed"]) * 1000003 + int(case_data["tick"]) * 97 + hash)
		var expected := rng.next_index(9)
		assert_eq(int(SeededRollScript.index(9, int(case_data["seed"]), str(case_data["salt"]), int(case_data["tick"]))), expected,
				"canonical formula drift for %s" % str(case_data))


func test_seeded_roll_bound_below_two_is_zero() -> void:
	assert_eq(int(SeededRollScript.index(1, 5, "any.salt", 3)), 0)
	assert_eq(int(SeededRollScript.index(0, 5, "any.salt", 3)), 0)
