extends GutTest


# P2a C: battle intent picks and loot picks shared a hand-copied formula
# (seed*1000003 + tick*97 + salt_hash). SeededRoll owns the formula once;
# LootResolver keeps a private _pick_from surface, so the comparison below
# pins it to identical SeededRoll outputs for identical inputs. The legacy
# battle-resolver helpers (_seeded_index / _battle_rng_seed / _shuffled_cards)
# died with the V1 convergence (B1 bucket C) and their pins left with them.


const LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const RefineCommandRulesScript = preload("res://scripts/domain/refine_command_rules.gd")
const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")


func _state_with_tick(seed_value: int, tick: int) -> RunState:
	var run := RunState.new_run(seed_value)
	for index in tick:
		run = run.append_event({"action": "probe_%d" % index, "reason": "seeded_roll_probe"})
	return run


func test_loot_pick_matches_seeded_roll_on_same_inputs() -> void:
	for seed_value in [0, 1, 7, 123, 99991]:
		for tick in [0, 1, 5, 40]:
			for salt in ["boss.intent", "loot.material.one", "loot.gu.pick.one.rare"]:
				var state := _state_with_tick(seed_value, tick)
				var from_loot: int = LootResolverScript._pick_from(11, state, salt)
				assert_eq(int(SeededRollScript.index(11, state.seed, salt, state.event_log.size())), from_loot,
						"loot pick drift seed=%d tick=%d salt=%s" % [seed_value, tick, salt])


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


# Quality batch ②: the last hand-rolled formula copies (Resolver refinement /
# free-mix / roll_chance and the legacy numeric-salt battle seed) converged
# onto SeededRoll. The expected values below are re-derived from the old inline
# math independently, so any future drift raises a pin here.


func test_mixed_seed_and_salt_hash_match_hand_computed_constants() -> void:
	assert_eq(int(SeededRollScript.salt_hash("a")), 97)
	assert_eq(int(SeededRollScript.salt_hash("ab")), 3105)
	assert_eq(int(SeededRollScript.mixed_seed(7, "ab", 3)), 7003417)


func test_mixed_seed_int_keeps_numeric_salt_form() -> void:
	assert_eq(int(SeededRollScript.mixed_seed_int(7, 2, 3)), 7000698)
	assert_eq(int(SeededRollScript.mixed_seed_int(101, 1213, 3)), 101 * 1000003 + 3 * 97 + 1213 * 193)


func test_converged_refinement_roll_matches_old_inline_formula() -> void:
	for seed_value in [0, 1, 101, 424242]:
		var state := _state_with_tick(seed_value, 4)
		var recipe_hash := 0
		for character in "bright_thread_risk":
			recipe_hash = recipe_hash * 31 + character.unicode_at(0)
		var expected_rng := SeededRng.new(int(state.seed) * 1000003 + state.event_log.size() * 97 + recipe_hash)
		assert_eq(int(RefineCommandRulesScript._refinement_roll(state, "bright_thread_risk")), expected_rng.next_index(100) + 1,
				"refinement roll drift seed=%d" % seed_value)


func test_converged_roll_chance_matches_old_inline_formula() -> void:
	var salt := "quality.batch.converge"
	var salt_hash := 0
	for character in salt:
		salt_hash = salt_hash * 31 + character.unicode_at(0)
	for seed_value in [0, 1, 101, 424242]:
		var state := _state_with_tick(seed_value, 4)
		var expected_rng := SeededRng.new(int(state.seed) * 1000003 + state.event_log.size() * 97 + salt_hash)
		assert_eq(bool(ResolverScript.roll_chance(state, 50, salt)), bool(expected_rng.next_index(100) < 50),
				"roll chance drift seed=%d" % seed_value)


func test_free_mix_salt_convention_pinned_after_helper_removal() -> void:
	var instance_ids: Array[String] = ["small_light_gu", "trail_eye_gu"]
	var joined := "+".join(instance_ids)
	var digest := 0
	for character in joined:
		digest = digest * 31 + character.unicode_at(0)
	assert_eq(int(SeededRollScript.mixed_seed(101, joined, 4)), 101 * 1000003 + 4 * 97 + digest)


# Night batch: map generator _node_rng converged onto SeededRoll (tick=0).


func test_map_node_rng_matches_old_inline_seed_formula() -> void:
	var pairs := [
		[101, "ridge_caravan"],
		[0, "trailhead"],
		[424242, "final_boss_stand"],
		[7, "ascension_window"],
	]
	for pair in pairs:
		var seed_value: int = pair[0]
		var node_id: String = pair[1]
		var old_digest := 0
		for character in node_id:
			old_digest = old_digest * 31 + character.unicode_at(0)
		var old_seed := int(seed_value) * 1000003 + old_digest
		var expected := SeededRng.new(old_seed)
		var actual := MapGeneratorScript._node_rng(seed_value, node_id)
		for draw_index in range(3):
			var actual_draw := actual.next_index(13)
			var expected_draw := expected.next_index(13)
			assert_eq(actual_draw, expected_draw,
					"map node rng drift seed=%d node=%s draw=%d" % [seed_value, node_id, draw_index])


func test_map_node_rng_seed_equals_mixed_seed_with_zero_tick() -> void:
	var pairs := [
		[101, "ridge_caravan"],
		[0, "trailhead"],
		[424242, "final_boss_stand"],
		[7, "ascension_window"],
	]
	for pair in pairs:
		var seed_value: int = pair[0]
		var node_id: String = pair[1]
		var old_digest := 0
		for character in node_id:
			old_digest = old_digest * 31 + character.unicode_at(0)
		var old_seed := int(seed_value) * 1000003 + old_digest
		assert_eq(int(SeededRollScript.mixed_seed(seed_value, node_id, 0)), old_seed,
				"mixed seed zero tick drift seed=%d node=%s" % [seed_value, node_id])
