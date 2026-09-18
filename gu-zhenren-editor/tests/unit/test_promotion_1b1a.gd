extends "res://addons/gut/test.gd"


# Q8-G Batch 1-B1-a (2026-09-13): force / gold / wisdom / heaven promotion
# chains - the first content batch on top of the accepted 1-B0-M material model.
#
# Gates reused from 1-A: M1 cross-definition steps (static catalog guard), the
# strict +1 rank ladder, same-school lineage, and the provisional quality-band
# mapping proposed here for F8 calibration (crude/plain/refined/prized per step).


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")

const CHAINS := {
	"force": [
		["force_atk_1_05_gu", "force_atk_2_06_gu"],
		["force_atk_2_06_gu", "force_atk_3_07_gu"],
		["force_atk_3_07_gu", "force_atk_4_08_gu"],
		["force_atk_4_08_gu", "force_atk_5_23_gu"],
	],
	"gold": [
		["gold_atk_1_21_gu", "gold_atk_2_12_gu"],
		["gold_atk_2_12_gu", "gold_atk_3_13_gu"],
		["gold_atk_3_13_gu", "gold_atk_4_14_gu"],
		["gold_atk_4_14_gu", "gold_atk_5_15_gu"],
	],
	"wisdom": [
		["wisdom_atk_1_02_gu", "wisdom_atk_2_11_gu"],
		["wisdom_atk_2_11_gu", "wisdom_atk_3_13_gu"],
		["wisdom_atk_3_13_gu", "wisdom_atk_4_18_gu"],
		["wisdom_atk_4_18_gu", "wisdom_atk_5_05_gu"],
	],
	"heaven": [
		["heaven_atk_1_12_gu", "heaven_atk_2_36_gu"],
		["heaven_atk_2_36_gu", "heaven_atk_3_13_gu"],
		["heaven_atk_3_13_gu", "heaven_atk_4_09_gu"],
		["heaven_atk_4_09_gu", "heaven_atk_5_01_gu"],
	],
}
const STONES := [10, 18, 30, 45]
const BANDS := ["crude", "plain", "refined", "prized"]


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func promotions() -> Dictionary:
	var by_id := {}
	for recipe in catalog()["refinement_recipes"]:
		if str(recipe.get("kind", "")) == "promotion":
			by_id[str(recipe["id"])] = recipe
	return by_id


func test_catalog_still_validates_clean_with_the_new_chains() -> void:
	assert_eq(ContentCatalogScript.validate(catalog()), [])


func test_four_chains_exist_with_sixteen_promotion_recipes() -> void:
	var promos := promotions()
	for school in CHAINS:
		var steps: Array = CHAINS[school]
		for i in steps.size():
			var input_gu: String = steps[i][0]
			var output_gu: String = steps[i][1]
			var recipe_id := "promote_%s_to_%s" % [input_gu.trim_suffix("_gu"), output_gu.trim_suffix("_gu")]
			assert_true(promos.has(recipe_id), "missing %s" % recipe_id)
			if promos.has(recipe_id):
				assert_eq(str(promos[recipe_id]["input_gu_ids"][0]), input_gu, "%s input drift" % recipe_id)
				assert_eq(str(promos[recipe_id]["output_gu_id"]), output_gu, "%s output drift" % recipe_id)


func test_every_step_swaps_definition_and_climbs_exactly_one_rank() -> void:
	# M1 + strict +1: output != input, output rank = input rank + 1, same school.
	var gu_by_id: Dictionary = catalog()["gu_by_id"]
	var promos := promotions()
	for school in CHAINS:
		for i in CHAINS[school].size():
			var input_gu: String = CHAINS[school][i][0]
			var output_gu: String = CHAINS[school][i][1]
			var recipe_id := "promote_%s_to_%s" % [input_gu.trim_suffix("_gu"), output_gu.trim_suffix("_gu")]
			var recipe: Dictionary = promos[recipe_id]
			assert_ne(str(recipe["output_gu_id"]), str(recipe["input_gu_ids"][0]),
					"%s violates M1" % recipe_id)
			assert_eq(int(gu_by_id[output_gu]["rank"]), int(gu_by_id[input_gu]["rank"]) + 1,
					"%s not a strict +1 step" % recipe_id)
			assert_eq(str(gu_by_id[output_gu]["school"]), str(school), "%s left the school" % recipe_id)
			assert_eq(int(recipe["input_min_rank"]), i + 1, "%s min_rank drift" % recipe_id)


func test_chain_steps_link_into_one_ladder() -> void:
	for school in CHAINS:
		for i in CHAINS[school].size() - 1:
			assert_eq(str(CHAINS[school][i][1]), str(CHAINS[school][i + 1][0]),
					"%s chain broken at step %d" % [school, i + 1])


func test_material_consumption_follows_the_provisional_quality_ladder() -> void:
	# M-8: the band-per-step mapping is a design proposal for F8 calibration, not
	# a frozen world rule - this test pins the batch's proposal so drift is loud.
	var mats: Dictionary = catalog()["loot_tables"]["materials"]
	var promos := promotions()
	for school in CHAINS:
		for i in CHAINS[school].size():
			var recipe_id := "promote_%s_to_%s" % [
				CHAINS[school][i][0].trim_suffix("_gu"), CHAINS[school][i][1].trim_suffix("_gu")]
			var consumed: Dictionary = promos[recipe_id]["materials"]
			assert_eq(consumed.keys(), ["mat_%s_%d" % [school, i + 1]],
					"%s material drift" % recipe_id)
			var instance: Dictionary = mats["mat_%s_%d" % [school, i + 1]]
			assert_eq(str(instance["quality_band"]), BANDS[i], "%s band drift" % recipe_id)


func test_force_chain_runs_end_to_end_from_rank_one_to_rank_five() -> void:
	var run := _run_with_instances([{"definition_id": "force_atk_1_05_gu", "rank": 1}])
	run.stone = 500
	for band in [1, 2, 3, 4]:
		run.materials["mat_force_%d" % band] = 4

	var current := run
	for i in CHAINS["force"].size():
		var input_gu: String = CHAINS["force"][i][0]
		var output_gu: String = CHAINS["force"][i][1]
		var recipe_id := "promote_%s_to_%s" % [input_gu.trim_suffix("_gu"), output_gu.trim_suffix("_gu")]
		var result := ResolverScript.apply(current, {"type": "refine_gu", "recipe_id": recipe_id}, catalog())
		assert_true(result["result"]["ok"], "step %d failed: %s" % [i + 1, str(result["result"])])
		current = result["state"]
		var live: Array = current.cave_aperture["stored_gu_instance_ids"]
		assert_eq(live.size(), 1)
		var output: Dictionary = current.gu_instances[str(live[0])]
		assert_eq(str(output["definition_id"]), output_gu)
		assert_eq(int(output["rank"]), i + 2)

	assert_eq(int(current.stone), 500 - 10 - 18 - 30 - 45, "stone ledger drifted")


func test_promotion_rejects_without_the_band_material() -> void:
	var run := _run_with_instances([{"definition_id": "gold_atk_1_21_gu", "rank": 1}])
	run.stone = 100
	run.materials = {"beast_bone": 9}  # wrong material on purpose

	var result := ResolverScript.apply(run, {
		"type": "refine_gu", "recipe_id": "promote_gold_atk_1_21_to_gold_atk_2_12",
	}, catalog())
	assert_false(result["result"]["ok"], "missing band material must reject")


# --- Economic Red Line Gate (M3): promotion_total_cost(target) must stay below
# --- the cheapest direct shop acquisition of the same target. No baseline, no
# --- comparison - and never a fabricated one.

func _total_cost(recipe: Dictionary) -> int:
	var total := int(recipe.get("stone_cost", 0))
	var material_table: Dictionary = catalog()["loot_tables"]["materials"]
	for material_id in recipe.get("materials", {}):
		var unit_value := int((material_table.get(str(material_id), {}) as Dictionary).get("value", 0))
		total += unit_value * int(recipe["materials"][material_id])
	return total


func _cheapest_shop_price_by_gu() -> Dictionary:
	var cheapest := {}
	for offer in catalog().get("shop_offers", []):
		if str(offer.get("kind", "")) != "purchase":
			continue
		var gu_id := str(offer.get("gu_id", ""))
		if gu_id.is_empty():
			continue
		var price := int(offer.get("stone_cost", 0))
		if not cheapest.has(gu_id) or price < int(cheapest[gu_id]):
			cheapest[gu_id] = price
	return cheapest


func test_economic_red_line_holds_wherever_a_shop_offer_exists() -> void:
	var recipe_by_id: Dictionary = promotions()
	var shop_price_by_gu := _cheapest_shop_price_by_gu()
	# The baseline mechanism itself must be alive (light-chain targets do have
	# offers), otherwise the red line below would pass vacuously forever.
	assert_gt(shop_price_by_gu.size(), 0, "shop baseline map is empty - red line is blind")
	for school in CHAINS:
		var cumulative := 0
		for i in CHAINS[school].size():
			var input_gu: String = CHAINS[school][i][0]
			var output_gu: String = CHAINS[school][i][1]
			var recipe_id := "promote_%s_to_%s" % [input_gu.trim_suffix("_gu"), output_gu.trim_suffix("_gu")]
			cumulative += _total_cost(recipe_by_id[recipe_id])
			if not shop_price_by_gu.has(output_gu):
				continue  # M3: no offer, no comparison, no fabricated baseline
			assert_true(cumulative < int(shop_price_by_gu[output_gu]),
					"%s cumulative %d must stay below direct shop price %d"
					% [output_gu, cumulative, int(shop_price_by_gu[output_gu])])


func test_economic_red_line_records_targets_without_a_baseline() -> void:
	# Explicit skip ledger: all sixteen targets currently have no shop offer.
	# The moment any of them gains one, the holds-test above starts comparing
	# automatically - nothing can silently slip past the red line.
	var shop_price_by_gu := _cheapest_shop_price_by_gu()
	var skipped := 0
	for school in CHAINS:
		for i in CHAINS[school].size():
			var output_gu: String = CHAINS[school][i][1]
			if shop_price_by_gu.has(output_gu):
				continue
			skipped += 1
			assert_false(shop_price_by_gu.has(output_gu),
					"%s was skipped yet has a price" % output_gu)
	assert_eq(skipped, 16, "skip ledger drifted - update the batch doc if offers changed")


func _run_with_instances(specs: Array) -> RunState:
	var run := RunStateScript.new_run(101)
	run.cultivator["soul"] = 5
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	for index in specs.size():
		var spec: Dictionary = specs[index]
		var instance_id := "gu_%03d" % (index + 1)
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": str(spec["definition_id"]),
			"state": "refined",
			"rank": int(spec.get("rank", 1)),
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()
	return run
