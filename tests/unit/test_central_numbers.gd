extends GutTest


# Spec-v4 phase-2 (T2.1): central number formulas and anchors.
# Every value below is projected by GuBalance from data/balance.json (single
# source of truth); anchor tables come from spec §10 (rank/gu power/heal),
# §11.2 (true-yuan down-rank discount), §11.4 (natural recovery rate by
# aptitude) and §14 (unarmed damage, strength overload, beast body scale).
# No value table may be baked into code or data beyond the config keys.


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_rank_multiplier_anchors() -> void:
	# §10.1: ranks 1..5 -> 1 / 2 / 4 / 8 / 16.
	var expected := [1.0, 2.0, 4.0, 8.0, 16.0]
	for rank in range(1, 6):
		assert_almost_eq(float(GuBalanceScript.rank_multiplier(rank, catalog)),
				expected[rank - 1], 0.0001)


func test_standard_gu_power_anchors() -> void:
	# §10.3: ranks 1..5 -> 40 / 80 / 160 / 320 / 640.
	var expected := [40.0, 80.0, 160.0, 320.0, 640.0]
	for rank in range(1, 6):
		assert_almost_eq(float(GuBalanceScript.standard_gu_power(rank, catalog)),
				expected[rank - 1], 0.0001)


func test_fixed_defense_anchors() -> void:
	# §10.3: mortal..rank 5 -> 4 / 8 / 16 / 32 / 64 / 128 (20% of a same-rank
	# effective heavy hit; mortal is rank 0 via standard_gu_power(0) = 20).
	var expected := [4.0, 8.0, 16.0, 32.0, 64.0, 128.0]
	for rank in range(0, 6):
		assert_almost_eq(float(GuBalanceScript.fixed_defense(rank, catalog)),
				expected[rank], 0.0001)


func test_human_standard_heal_anchors() -> void:
	# §10.5: ranks 1..5 -> 20 / 40 / 60 / 80 / 100 = 100 * standard_hit_ratio * rank.
	var expected := [20.0, 40.0, 60.0, 80.0, 100.0]
	for rank in range(1, 6):
		assert_almost_eq(float(GuBalanceScript.human_standard_heal(rank, catalog)),
				expected[rank - 1], 0.0001)


func test_beast_scale_body_anchors() -> void:
	# §14.3: 凡兽..五转 health / natural strength / body capacity 100..3200.
	var expected := [100.0, 200.0, 400.0, 800.0, 1600.0, 3200.0]
	for rank in range(0, 6):
		assert_almost_eq(float(GuBalanceScript.beast_scale(rank, catalog)),
				expected[rank], 0.0001)


func test_beast_same_rank_heavy_and_defense_anchors() -> void:
	# §14.3: same-rank heavy 20..640 (beast strength * unarmed ratio), fixed
	# defence 4..128 (shared mortal..rank 5 table from §10.3).
	var heavies := [20.0, 40.0, 80.0, 160.0, 320.0, 640.0]
	var defenses := [4.0, 8.0, 16.0, 32.0, 64.0, 128.0]
	for rank in range(0, 6):
		var strength := float(GuBalanceScript.beast_scale(rank, catalog))
		assert_almost_eq(float(GuBalanceScript.unarmed_raw_damage(strength, 1.0, catalog)),
				heavies[rank], 0.0001)
		assert_almost_eq(float(GuBalanceScript.fixed_defense(rank, catalog)),
				defenses[rank], 0.0001)


func test_unarmed_damage_anchor() -> void:
	# §10.2: mortal full-strength heavy = 100 * 0.2 * 1.0 = 20 raw damage.
	assert_almost_eq(float(GuBalanceScript.unarmed_raw_damage(100.0, 1.0, catalog)),
			20.0, 0.0001)


func test_overload_only_self_damages_excess_strength() -> void:
	# §14.2: self damage = max(0, strength - capacity) * unarmed_ratio * reaction.
	# At or below capacity the excess is zero, so no self damage at all.
	assert_almost_eq(float(GuBalanceScript.overload_self_damage(130.0, 100.0, catalog)),
			6.0, 0.0001)
	assert_almost_eq(float(GuBalanceScript.overload_self_damage(100.0, 100.0, catalog)),
			0.0, 0.0001)
	assert_almost_eq(float(GuBalanceScript.overload_self_damage(90.0, 100.0, catalog)),
			0.0, 0.0001)


func test_actual_cost_percent_down_rank_discount() -> void:
	# §11.2: native * rank_multiplier(gu_rank) / rank_multiplier(cultivator_rank).
	# 2-turn cultivator driving a 1-turn 10% gu: 0.1 * 1 / 2 = 5%. Same rank
	# keeps the native cost; two ranks above halves it again (0.1 * 2 / 4).
	assert_almost_eq(float(GuBalanceScript.actual_cost_percent(0.1, 1, 2, catalog)),
			0.05, 0.0001)
	assert_almost_eq(float(GuBalanceScript.actual_cost_percent(0.1, 2, 2, catalog)),
			0.1, 0.0001)
	assert_almost_eq(float(GuBalanceScript.actual_cost_percent(0.1, 2, 3, catalog)),
			0.05, 0.0001)


func test_natural_recovery_rate_by_aptitude() -> void:
	# §11.4: rate = aptitude_recovery_multiplier + aptitude_percent / 100, anchors at
	# 20% / 50% / 100% aptitude -> 0.7 / 1.0 / 1.5.
	assert_almost_eq(float(GuBalanceScript.natural_recovery(20.0, catalog)),
			0.7, 0.0001)
	assert_almost_eq(float(GuBalanceScript.natural_recovery(50.0, catalog)),
			1.0, 0.0001)
	assert_almost_eq(float(GuBalanceScript.natural_recovery(100.0, catalog)),
			1.5, 0.0001)


func test_projections_follow_balance_config_not_hardcoded() -> void:
	# Red line: formulas read balance.json (single source). Re-tuning a config
	# key shifts the projection; no anchor table is baked into code.
	var tuned := catalog.duplicate(true)
	var balance := (catalog["balance"] as Dictionary).duplicate(true)
	balance["human_base_health"] = 50
	tuned["balance"] = balance
	assert_almost_eq(float(GuBalanceScript.beast_scale(0, tuned)), 50.0, 0.0001)
	assert_almost_eq(float(GuBalanceScript.standard_gu_power(1, tuned)), 20.0, 0.0001)
	balance["aptitude_recovery_multiplier"] = 0.6
	tuned["balance"] = balance
	assert_almost_eq(float(GuBalanceScript.natural_recovery(20.0, tuned)), 0.8, 0.0001)