extends GutTest


# RUL-2026-09-19-008 P2: Rank Power Budget 唯一真源门禁。
# rank_power_budget(rank) = rank1_budget * rank_step_ratio^(rank-1), 1..5 转 =
# 40 / 80 / 160 / 320 / 640,与 standard_gu_power 同值(零数值漂移)。
# standard_gu_power 是本曲线的具名投影(实现委托),其余代码不得再各自算一套
# (见 test_resolver_growth_gate 的单一定点门禁)。


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_rank_power_budget_anchors() -> void:
	var expected := [40.0, 80.0, 160.0, 320.0, 640.0]
	for rank in range(1, 6):
		assert_almost_eq(float(GuBalanceScript.rank_power_budget(rank, catalog)),
				expected[rank - 1], 0.0001)


func test_rank1_budget_anchor() -> void:
	# rank1 = human_base_health * standard_hit_ratio * rank_step_ratio = 40.
	assert_almost_eq(float(GuBalanceScript.rank1_budget(catalog)), 40.0, 0.0001)


func test_standard_gu_power_is_the_same_curve() -> void:
	for rank in range(0, 6):
		assert_almost_eq(float(GuBalanceScript.standard_gu_power(rank, catalog)),
				float(GuBalanceScript.rank_power_budget(rank, catalog)), 0.0001)


func test_rank_multiplier_is_the_dimensionless_reading() -> void:
	# rank_multiplier(rank) = budget(rank) / rank1_budget = 1/2/4/8/16.
	var rank1 := float(GuBalanceScript.rank1_budget(catalog))
	for rank in range(1, 6):
		assert_almost_eq(float(GuBalanceScript.rank_multiplier(rank, catalog)),
				float(GuBalanceScript.rank_power_budget(rank, catalog)) / rank1, 0.0001)


func test_budget_follows_config_not_hardcoded() -> void:
	var tuned := catalog.duplicate(true)
	var balance := (catalog["balance"] as Dictionary).duplicate(true)
	balance["human_base_health"] = 50
	tuned["balance"] = balance
	assert_almost_eq(float(GuBalanceScript.rank1_budget(tuned)), 20.0, 0.0001)
	assert_almost_eq(float(GuBalanceScript.rank_power_budget(1, tuned)), 20.0, 0.0001)
	assert_almost_eq(float(GuBalanceScript.rank_power_budget(5, tuned)), 320.0, 0.0001)


func test_upstream_budget_table_matches_formula() -> void:
	var upstream: Dictionary = (catalog["balance"] as Dictionary).get("rank_power_budget", {})
	var table: Dictionary = upstream.get("budget_by_rank", {})
	var step := float((catalog["balance"] as Dictionary).get("rank_step_ratio", 2.0))
	var rank1 := float(GuBalanceScript.rank1_budget(catalog))
	for rank in range(1, 6):
		assert_almost_eq(float(table.get(str(rank), -1.0)), rank1 * pow(step, rank - 1), 0.0001)


func test_hp_baseline_is_explicit() -> void:
	# D11: standard_human_hp = 100 为 SoT;player_start_hp 显式 100。
	assert_almost_eq(float(GuBalanceScript.standard_human_hp(catalog)), 100.0, 0.0001)
	assert_almost_eq(float(GuBalanceScript.player_start_hp(catalog)), 100.0, 0.0001)
