extends GutTest


# Spec-v4 phase-2 (T5.1): unified material table (§6.1) and rules:
# downscale_feed (§6.2, high-rank to low-rank feeding equivalence) and
# refine_up (§6.3, lossy step-by-step refining). Pure static, deterministic,
# config-driven - every multiplier comes from balance.json via GuBalance.
# Acceptance #9: divisible materials deduct precisely with remainder kept;
# indivisible excess is wasted and never refunded; named exclusive diet
# refuses value substitution.


const MaterialRulesScript = preload("res://scripts/domain/material_rules.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _material(id_value: String) -> Dictionary:
	return (catalog["loot_tables"]["materials"] as Dictionary)[id_value]


func test_materials_declare_the_section_6_1_field_set() -> void:
	# §6.1: every material declares rank / dao_tags / diet_tags / is_common /
	# is_exclusive / divisible / public_liquidity / reference_value.
	var materials_table: Dictionary = catalog["material_by_id"]
	for material_id in materials_table:
		var entry := _material(material_id)
		assert_true(int(entry.get("rank", 0)) >= 1 and int(entry.get("rank", 0)) <= 9,
				"%s rank must be 1..9" % material_id)
		assert_true(entry.get("dao_tags", null) is Array, "%s dao_tags" % material_id)
		assert_true(entry.get("diet_tags", null) is Array, "%s diet_tags" % material_id)
		for bool_key in ["is_common", "is_exclusive", "divisible"]:
			assert_true(entry.get(bool_key, null) is bool, "%s %s must be bool" % [material_id, bool_key])
		var liquidity := float(entry.get("public_liquidity", 0.0))
		assert_true(liquidity > 0.0 and liquidity <= 1.0, "%s liquidity (0,1]" % material_id)
		assert_true(int(entry.get("reference_value", 0)) >= 1, "%s reference_value" % material_id)


func test_downscale_equivalent_scales_with_turn_ratio() -> void:
	# §6.2: a rank-2 material fed at rank 1 yields reference_value * 2.0
	# equivalent units; same rank keeps the reference; three ranks double twice.
	var rank2 := _material("beast_blood").duplicate(true)
	rank2["rank"] = 2
	assert_almost_eq(float(MaterialRulesScript.downscale_equivalent(rank2, 1, catalog)),
			float(rank2["reference_value"]) * 2.0, 0.0001)
	assert_almost_eq(float(MaterialRulesScript.downscale_equivalent(rank2, 2, catalog)),
			float(rank2["reference_value"]), 0.0001)
	rank2["rank"] = 3
	assert_almost_eq(float(MaterialRulesScript.downscale_equivalent(rank2, 1, catalog)),
			float(rank2["reference_value"]) * 4.0, 0.0001)
	# Config-driven: re-tuning rank_step_ratio shifts the projection.
	var tuned := catalog.duplicate(true)
	var balance := (catalog["balance"] as Dictionary).duplicate(true)
	balance["rank_step_ratio"] = 3.0
	tuned["balance"] = balance
	assert_almost_eq(float(MaterialRulesScript.downscale_equivalent(rank2, 1, tuned)),
			float(rank2["reference_value"]) * 9.0, 0.0001)


func test_divisible_feed_deducts_precisely_and_keeps_the_remainder() -> void:
	# Acceptance #9: divisible material (e.g. beast blood) deducts exactly the
	# needed equivalent share; the leftover stays in the material.
	var blood := _material("beast_blood")
	assert_true(bool(blood["divisible"]))
	var out := MaterialRulesScript.downscale_feed(blood, 1, 5.0, catalog)
	assert_true(bool(out["ok"]), str(out))
	assert_almost_eq(float(out["equivalent"]), float(blood["reference_value"]), 0.0001)
	assert_almost_eq(float(out["consumed_fraction"]), 5.0 / float(blood["reference_value"]), 0.0001)
	assert_almost_eq(float(out["remaining_fraction"]),
			1.0 - 5.0 / float(blood["reference_value"]), 0.0001)
	assert_almost_eq(float(out["wasted"]), 0.0, 0.0001)


func test_indivisible_feed_wastes_excess_without_refund() -> void:
	# Acceptance #9: an indivisible whole (e.g. an intact bone) is consumed in
	# full; the value beyond the current need is lost, never returned.
	var bone := _material("beast_bone")
	assert_false(bool(bone["divisible"]))
	var out := MaterialRulesScript.downscale_feed(bone, 1, 0.3, catalog)
	assert_true(bool(out["ok"]), str(out))
	assert_almost_eq(float(out["consumed_fraction"]), 1.0, 0.0001)
	assert_almost_eq(float(out["wasted"]),
			float(bone["reference_value"]) - 0.3, 0.0001)
	assert_almost_eq(float(out["remaining_fraction"]), 0.0, 0.0001)


func test_named_exclusive_diet_refuses_value_substitution() -> void:
	# §6.2: a named exclusive diet must match by name - value or rank do not
	# substitute.
	assert_true(bool(MaterialRulesScript.named_diet_allowed("boar_king_tusk", "boar_king_tusk")))
	assert_false(bool(MaterialRulesScript.named_diet_allowed("moon_dew", "boar_king_tusk")))
	assert_false(bool(MaterialRulesScript.named_diet_allowed("", "boar_king_tusk")))


func test_refine_up_lossy_step_by_step() -> void:
	# §6.3: 1-turn 10 units -> 5 at turn 2 -> 2.5 at turn 3; equivalent
	# quantity ratio 4:1 (four 1-turn units refine into one 3-turn unit).
	assert_almost_eq(float(MaterialRulesScript.refine_up(10.0, 1, 2, catalog)), 5.0, 0.0001)
	assert_almost_eq(float(MaterialRulesScript.refine_up(10.0, 1, 3, catalog)), 2.5, 0.0001)
	assert_almost_eq(float(MaterialRulesScript.refine_up(4.0, 1, 3, catalog)), 1.0, 0.0001)
	assert_almost_eq(float(MaterialRulesScript.refine_up(10.0, 1, 1, catalog)), 10.0, 0.0001)
	# Downward is per-step too (value ratio 2.0 per step, no lossless jumps).
	assert_almost_eq(float(MaterialRulesScript.refine_up(1.0, 3, 1, catalog)), 4.0, 0.0001)
	# Config-driven: efficiency re-tuning shifts every step.
	var tuned := catalog.duplicate(true)
	var balance := (catalog["balance"] as Dictionary).duplicate(true)
	balance["material_refine_efficiency"] = 0.25
	tuned["balance"] = balance
	assert_almost_eq(float(MaterialRulesScript.refine_up(10.0, 1, 2, tuned)), 2.5, 0.0001)