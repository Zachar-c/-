extends GutTest


# Spec-v4 phase-1 (T1.2): central balance schema + GuBalance projection.
# balance.json is the single source of truth; GuBalance only projects the
# §10/§11 formulas, and ContentCatalog.validate guards every key on load.


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_real_balance_validates_clean() -> void:
	assert_true(ContentCatalogScript.validate(catalog).is_empty(),
			str(ContentCatalogScript.validate(catalog)))
	var balance: Dictionary = catalog["balance"]
	assert_eq(float(balance.get("rank_step_ratio", 0.0)), 2.0)
	assert_eq(float(balance.get("standard_hit_ratio", 0.0)), 0.2)
	assert_eq(int(balance.get("stone_per_t1_material", 0)), 10)


func test_balance_schema_rejects_missing_negative_and_out_of_range_keys() -> void:
	var tuned := catalog.duplicate(true)
	var bad := (catalog["balance"] as Dictionary).duplicate(true)
	bad.erase("rank_step_ratio")
	tuned["balance"] = bad
	assert_true(_has(ContentCatalogScript.validate(tuned), "rank_step_ratio must be numeric"))

	bad = (catalog["balance"] as Dictionary).duplicate(true)
	bad["heavy_cost_ratio"] = -1
	tuned["balance"] = bad
	assert_true(_has(ContentCatalogScript.validate(tuned), "heavy_cost_ratio must be positive"))

	bad = (catalog["balance"] as Dictionary).duplicate(true)
	bad["quick_substitute_cap"] = 1.5
	tuned["balance"] = bad
	assert_true(_has(ContentCatalogScript.validate(tuned), "in (0, 1]"))

	bad = (catalog["balance"] as Dictionary).duplicate(true)
	bad["feed_tier"] = [2.0, 0.5]
	tuned["balance"] = bad
	assert_true(_has(ContentCatalogScript.validate(tuned), "feed_tier"))

	bad = (catalog["balance"] as Dictionary).duplicate(true)
	bad["dragon_fish_replacement"] = [95, 90, 80]
	tuned["balance"] = bad
	assert_true(_has(ContentCatalogScript.validate(tuned), "dragon_fish_replacement"))


func test_rank_multiplier_matches_spec_table() -> void:
	# §10.1: ranks 1..5 -> 1 / 2 / 4 / 8 / 16 (projected, never stored as data).
	assert_eq(float(GuBalanceScript.rank_multiplier(1, catalog)), 1.0)
	assert_eq(float(GuBalanceScript.rank_multiplier(3, catalog)), 4.0)
	assert_eq(float(GuBalanceScript.rank_multiplier(5, catalog)), 16.0)


func test_standard_gu_power_and_fixed_defense_match_spec() -> void:
	# §10.3: ranks 1..5 -> 40 / 80 / 160 / 320 / 640; fixed defense = 20%.
	assert_eq(float(GuBalanceScript.standard_gu_power(1, catalog)), 40.0)
	assert_eq(float(GuBalanceScript.standard_gu_power(4, catalog)), 320.0)
	assert_almost_eq(float(GuBalanceScript.fixed_defense(3, catalog)), 32.0, 0.001)


func test_cost_and_recovery_projections_read_the_config() -> void:
	assert_almost_eq(float(GuBalanceScript.actual_cost_percent(
			float(catalog["balance"]["standard_activation_cost"]),
			float(catalog["balance"]["light_cost_ratio"]), catalog)), 0.05, 0.0001)
	assert_almost_eq(float(GuBalanceScript.natural_recovery(catalog)), 0.01, 0.0001)


func _has(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false