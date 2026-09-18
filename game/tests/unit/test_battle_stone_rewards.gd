extends "res://addons/gut/test.gd"


# Q8-G 1-C (2026-09-13): battle stone production. Batch 0 §4 froze the shape -
# battle is the main stone producer, reward = tier base + layer modifier,
# provisional numbers in balance.battle_stone_rewards. These tests pin the
# producer semantics (net-new stones, deterministic, risk-linked) so F8 can
# recalibrate the numbers without touching the settlement contract.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func make_state(run_seed: int) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func test_catalog_still_validates_clean() -> void:
	assert_eq(ContentCatalogScript.validate(catalog()), [])


func test_common_victory_grants_the_configured_base_at_layer_one() -> void:
	var run := make_state(7)
	var before := int(run.stone)
	var result := LootResolverScript.settle_victory({"enemy_kind": "ridge_hound", "layer": 1}, run, catalog())
	assert_eq(int(result["loot"]["stone_reward"]), 3, "common layer-1 base must be the configured 3")
	assert_eq(int(result["state"].stone), before + 3, "stones must be net-new production")


func test_risk_ranks_income_common_below_elite_below_boss_at_same_layer() -> void:
	# Batch 0 §4.1: 风险 ↑ → 收益 ↑. Same layer, same seed, only the tier moves.
	var incomes := {}
	for tier in ["common", "elite", "boss"]:
		var kind := "ridge_hound"
		if tier == "elite":
			kind = "ridge_elite_scout"
		elif tier == "boss":
			kind = "miasma_vein_lord"
		var run := make_state(7)
		run.stone = 0
		var result := LootResolverScript.settle_victory({"enemy_kind": kind, "layer": 1}, run, catalog())
		incomes[tier] = int(result["loot"]["stone_reward"])
	assert_true(incomes["common"] < incomes["elite"], "elite must out-produce common")
	assert_true(incomes["elite"] < incomes["boss"], "boss must out-produce elite")


func test_layer_scales_the_reward_upward() -> void:
	var per_layer := {}
	for layer in range(1, 6):
		var run := make_state(11)
		run.stone = 0
		var result := LootResolverScript.settle_victory({"enemy_kind": "ridge_hound", "layer": layer}, run, catalog())
		per_layer[layer] = int(result["loot"]["stone_reward"])
	assert_eq(per_layer[1], 3)
	for layer in range(2, 6):
		assert_true(per_layer[layer] >= per_layer[layer - 1],
				"layer %d must not pay less than layer %d" % [layer, layer - 1])
	assert_gt(per_layer[5], per_layer[1], "layer 5 must out-produce layer 1")


func test_reward_is_deterministic_across_seeds_for_the_same_tier_and_layer() -> void:
	var rewards := {}
	for run_seed in range(1, 31):
		var run := make_state(run_seed)
		run.stone = 0
		var result := LootResolverScript.settle_victory({"enemy_kind": "ridge_hound", "layer": 3}, run, catalog())
		rewards[run_seed] = int(result["loot"]["stone_reward"])
	var distinct := {}
	for run_seed in rewards:
		distinct[rewards[run_seed]] = true
	assert_eq(distinct.size(), 1, "stone reward must depend only on tier+layer, never the loot rolls")


func test_stone_gain_is_event_logged_with_before_and_after() -> void:
	var run := make_state(7)
	run.stone = 10
	var result := LootResolverScript.settle_victory({"enemy_kind": "ridge_hound", "layer": 1}, run, catalog())
	var events: Array = result["state"].event_log
	var found := false
	for entry in events:
		if str(entry.get("reason", "")) == "loot_stone_gained":
			found = true
			assert_eq(int(entry["before"]["stone"]), 10)
			assert_eq(int(entry["after"]["stone"]), 13)
	assert_true(found, "stone production must hit the immutable event log")


func test_elite_cost_binding_still_applies_alongside_the_reward() -> void:
	var run := make_state(7)
	run.stone = 0
	var result := LootResolverScript.settle_victory({"enemy_kind": "ridge_elite_scout", "layer": 1}, run, catalog())
	assert_eq(int(result["loot"]["stone_reward"]), 8, "elite still produces its base income")
	assert_true(result.has("cost"), "elite cost binding must remain attached")


func test_f8_lite_ten_common_victories_fund_the_first_promotion_step() -> void:
	# Structural check only (NOT full-economy sustainability): under the current
	# provisional numbers, basic battle income covers the cheapest promotion
	# step's stones - a minimal economic loop exists. Full run-map income vs.
	# long-term costs belongs to F8 calibration.
	var earned := 0
	for run_seed in range(1, 11):
		var run := make_state(run_seed)
		run.stone = 0
		var result := LootResolverScript.settle_victory({"enemy_kind": "ridge_hound", "layer": 1}, run, catalog())
		earned += int(result["loot"]["stone_reward"])
	assert_gte(earned, 10, "ten common victories must fund at least one promotion step")
