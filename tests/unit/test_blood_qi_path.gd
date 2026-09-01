extends GutTest


# Spec-v4 phase-2 (T8.1): blood-qi dual-tag single inventory (§15.1) and qi
# accumulation (§15.2). Blood qi is one divisible material with both dao tags;
# the blood and qi paths contest the SAME RunState.materials stock (single
# source - the exit condition). Pure static, deterministic, zero dice.


const BloodQiRulesScript = preload("res://scripts/domain/blood_qi_rules.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_blood_qi_is_dual_tag_divisible_single_stock() -> void:
	# §15.1: one material, two dao tags, divisible; blood and qi paths spend
	# the same real inventory.
	var blood: Dictionary = catalog["loot_tables"]["materials"]["beast_blood"]
	assert_true((blood["dao_tags"] as Array).has("blood"))
	assert_true((blood["dao_tags"] as Array).has("qi"))
	assert_true(bool(blood["divisible"]))
	var materials := {"beast_blood": 10.0}
	var blood_path := BloodQiRulesScript.claim_inventory(materials, "beast_blood", 3.0, "blood")
	assert_true(bool(blood_path["ok"]), str(blood_path))
	# The qi path sees the same, already-deducted stock.
	var qi_view := BloodQiRulesScript.claim_inventory(blood_path["materials"], "beast_blood", 2.0, "qi")
	assert_almost_eq(float(qi_view["materials"]["beast_blood"]), 5.0, 0.0001,
			"alternating deducts never diverge (single source)")
	var drained := BloodQiRulesScript.claim_inventory(qi_view["materials"], "beast_blood", 5.0, "blood")
	assert_almost_eq(float(drained["materials"]["beast_blood"]), 0.0, 0.0001)
	var empty := BloodQiRulesScript.claim_inventory(drained["materials"], "beast_blood", 1.0, "qi")
	assert_false(bool(empty["ok"]))
	assert_eq(str(empty["reason"]), "insufficient_inventory")


func test_blood_yield_scales_with_health_rank_and_means() -> void:
	# §15.1: target health, rank, death method and means decide the yield;
	# deep extraction costs time/tools and leaves a blood trail.
	var skim := BloodQiRulesScript.blood_yield(100.0, 1, 1.0, "skim", catalog)
	assert_almost_eq(float(skim["yield"]), float(100.0 * 0.01), 0.0001)
	var deep := BloodQiRulesScript.blood_yield(100.0, 1, 1.0, "deep", catalog)
	assert_true(float(deep["yield"]) > float(skim["yield"]))
	assert_eq(int(deep["extra"]["time_cost"]), 1)
	assert_eq(int(deep["extra"]["blood_trail"]), 1)
	var rank3 := BloodQiRulesScript.blood_yield(100.0, 3, 1.0, "skim", catalog)
	assert_almost_eq(float(rank3["yield"]), float(100.0 * 0.01 * 4.0), 0.0001)
	# Config-driven: re-tuning the yield ratio shifts the projection.
	var tuned := catalog.duplicate(true)
	var balance := (catalog["balance"] as Dictionary).duplicate(true)
	balance["blood_yield_ratio"] = 0.02
	tuned["balance"] = balance
	assert_almost_eq(float(BloodQiRulesScript.blood_yield(100.0, 1, 1.0, "skim", tuned)["yield"]),
			2.0, 0.0001)


func test_self_bleed_enforces_rank_health_and_lethal_confirm() -> void:
	# §15.1: bleed cannot refine above the cultivator's own rank; low health
	# refuses; a foreseeable death carries the second-confirmation marker.
	var high_rank := BloodQiRulesScript.self_bleed(50.0, 2, 3, 10.0, catalog)
	assert_false(bool(high_rank["ok"]))
	assert_eq(str(high_rank["reason"]), "bleed_rank_exceeds_cultivator")
	var broke := BloodQiRulesScript.self_bleed(50.0, 2, 2, 51.0, catalog)
	assert_false(bool(broke["ok"]))
	assert_eq(str(broke["reason"]), "insufficient_health")
	var safe := BloodQiRulesScript.self_bleed(50.0, 2, 2, 10.0, catalog)
	assert_true(bool(safe["ok"]), str(safe))
	assert_false(bool(safe["lethal_confirm_required"]))
	var lethal := BloodQiRulesScript.self_bleed(50.0, 2, 2, 50.0, catalog)
	assert_true(bool(lethal["lethal_confirm_required"]))
	assert_eq(str(lethal["cause"]), "self_bleed")


func test_qi_accumulation_requires_a_declared_curve() -> void:
	# §15.2: no curve -> refusal (no universal damage conversion); a declared
	# curve settles deterministically with its cap and minimum unit.
	var undeclared := BloodQiRulesScript.accumulate_qi({"beast_blood": 5.0}, {})
	assert_false(bool(undeclared["ok"]))
	assert_eq(str(undeclared["reason"]), "no_declared_curve")
	var curve := {"units_per_step": 1.0, "cap": 8.0, "min_units": 2.0}
	var below := BloodQiRulesScript.accumulate_qi({"beast_blood": 1.0}, curve)
	assert_false(bool(below["ok"]))
	assert_eq(str(below["reason"]), "below_min_units")
	var normal := BloodQiRulesScript.accumulate_qi({"beast_blood": 5.0}, curve)
	assert_true(bool(normal["ok"]), str(normal))
	assert_almost_eq(float(normal["effect_units"]), 5.0, 0.0001)
	var capped := BloodQiRulesScript.accumulate_qi({"beast_blood": 12.0}, curve)
	assert_true(bool(capped["capped"]))
	assert_almost_eq(float(capped["consumed"]), 8.0, 0.0001)


func test_blood_trade_gate_public_refusal_and_secret_threshold() -> void:
	# §15.1: blood qi resists public trade (market refusal continuity) and
	# enters gated secret channels with declared world consequences.
	var blood: Dictionary = catalog["loot_tables"]["materials"]["beast_blood"]
	var public := BloodQiRulesScript.trade_gate(blood, "public", catalog)
	assert_false(bool(public["ok"]))
	assert_eq(str(public["reason"]), "refused_public_channel")
	var secret := BloodQiRulesScript.trade_gate(blood, "secret", catalog)
	assert_true(bool(secret["ok"]), str(secret))
	assert_eq(str(secret["requires"]), "secret_market_gate")
	assert_true((secret["consequences"] as Array).has("pursuit_risk"))


func test_zero_randomness_audit() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/domain/blood_qi_rules.gd")
	for token in ["SeededRoll", "roll(", "rand", "randomize"]:
		assert_false(source.contains(token), "blood_qi_rules.gd must not reference %s" % token)