extends "res://addons/gut/test.gd"


# Q8-G 1-D (2026-09-13): drop tiering - wire the quality-band materials into
# the battle loot pools and open the common-battle basic-gu chance, closing
# the reachability debts of the material front batch.
#
# Provisional band-to-tier mapping (design proposal, F8 calibrates):
#   common pool += 19 crude (weight 3)        - 普通战拾取基础资源
#   elite  pool += 18 plain (w3) + 18 refined (w1)
#   boss   pool += 18 refined (w2) + 18 prized (w3)
# bone bands 2-4 and all light materials stay unwired (registered debts).
# Batch 0 Q6 also opens common gu_chance_pct 0 -> 6 (低概率基础蛊).


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")

const SCHOOLS := [
	"blood", "bone", "dream", "earth", "fire", "force", "gold", "heaven", "human",
	"luck", "qi", "refine", "slave", "soul", "sword", "water", "wind", "wisdom", "wood",
]
# bone is the deferred school: only its crude band exists; light has none.
const FULL_LADDER_SCHOOLS := [
	"blood", "dream", "earth", "fire", "force", "gold", "heaven", "human",
	"luck", "qi", "refine", "slave", "soul", "sword", "water", "wind", "wisdom", "wood",
]
const NON_STARTER_INPUTS := [
	"dream_atk_1_09_gu", "earth_atk_1_05_gu", "heaven_atk_1_12_gu", "luck_atk_1_08_gu",
	"refine_atk_1_10_gu", "water_atk_1_12_gu", "wind_atk_1_07_gu", "wood_atk_1_11_gu",
]


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func loot() -> Dictionary:
	return catalog()["loot_tables"]["loot"]


func _pool_ids(tier: String) -> Array:
	var ids := []
	for entry_value in loot()[tier]["material_pool"]:
		if entry_value is String:
			ids.append(str(entry_value))
		else:
			ids.append(str(entry_value["id"]))
	return ids


func _pool_weight(tier: String, material_id: String) -> int:
	for entry_value in loot()[tier]["material_pool"]:
		if entry_value is String and str(entry_value) == material_id:
			return 1
		elif entry_value is Dictionary and str(entry_value["id"]) == material_id:
			return int(entry_value["weight"])
	return 0


func test_catalog_still_validates_clean() -> void:
	assert_eq(ContentCatalogScript.validate(catalog()), [])


func test_band_materials_are_wired_to_the_provisional_tiers() -> void:
	# band 1 -> common, band 2 -> elite, band 3 -> elite+boss, band 4 -> boss.
	var bands := {1: ["common"], 2: ["elite"], 3: ["elite", "boss"], 4: ["boss"]}
	for school in FULL_LADDER_SCHOOLS:
		for band in bands:
			var material_id := "mat_%s_%d" % [school, band]
			for tier in ["common", "elite", "boss"]:
				var wired: bool = _pool_ids(tier).has(material_id)
				if (bands[band] as Array).has(tier):
					assert_true(wired, "%s missing from %s" % [material_id, tier])
				else:
					assert_false(wired, "%s unexpectedly in %s" % [material_id, tier])


func test_provisional_weights_favor_the_quality_bands() -> void:
	for school in SCHOOLS:
		assert_eq(_pool_weight("common", "mat_%s_1" % school), 3)
	for school in FULL_LADDER_SCHOOLS:
		assert_eq(_pool_weight("elite", "mat_%s_2" % school), 3)
		assert_eq(_pool_weight("boss", "mat_%s_4" % school), 3)
	# bone bands 2-4 stay unwired (deferred school)
	assert_eq(_pool_weight("elite", "mat_bone_2"), 0)
	assert_eq(_pool_weight("boss", "mat_bone_4"), 0)
	# legacy entries keep weight 1 / plain-string form
	assert_eq(_pool_weight("common", "beast_bone"), 1)
	assert_eq(_pool_weight("boss", "moon_dew"), 1)


func test_legacy_pool_entries_are_untouched() -> void:
	var common_ids := _pool_ids("common")
	assert_true(common_ids.has("beast_blood"))
	assert_true(common_ids.has("beast_bone"))
	assert_true(common_ids.has("moon_blue_petal"))
	var boss_ids := _pool_ids("boss")
	assert_true(boss_ids.has("moon_dew"))
	assert_true(boss_ids.has("venom_sac"))


func test_validation_rejects_an_unknown_weighted_material() -> void:
	var cat := catalog()
	cat["loot_tables"]["loot"]["common"]["material_pool"].append({"id": "not_a_material", "weight": 3})
	var errors: Array[String] = ContentCatalogScript.validate(cat)
	var matched := false
	for error_value in errors:
		if str(error_value).contains("references unknown material not_a_material"):
			matched = true
	assert_true(matched, "weighted entries must pass the same material registry check")


func test_weighted_rolls_are_deterministic_for_the_same_seed() -> void:
	# True determinism: the same seed run twice through the weighted pool must
	# produce the identical material sequence.
	for run_seed in range(1, 11):
		var first := LootResolverScript.settle_victory(
			{"enemy_kind": "ridge_hound", "layer": 1}, RunStateScript.new_run(run_seed, null), catalog())
		var second := LootResolverScript.settle_victory(
			{"enemy_kind": "ridge_hound", "layer": 1}, RunStateScript.new_run(run_seed, null), catalog())
		assert_eq(str(first["loot"]["material_ids"]), str(second["loot"]["material_ids"]),
				"seed %d diverged" % run_seed)


func test_band_materials_actually_drop_in_a_seeded_sweep() -> void:
	# Gate B sketch: sweep many seeded common victories and assert at least a
	# few crude-band materials come out of the wired pool (not just registry).
	var crude_drops := {}
	for run_seed in range(1, 61):
		var run := RunStateScript.new_run(run_seed, null)
		var rolled := LootResolverScript.settle_victory({"enemy_kind": "ridge_hound", "layer": 1}, run, catalog())
		for material_id in rolled["loot"]["material_ids"]:
			if str(material_id).begins_with("mat_"):
				crude_drops[str(material_id)] = true
	assert_gt(crude_drops.size(), 5, "seeded sweep should surface several crude materials, got %d" % crude_drops.size())


func test_common_battles_now_offer_low_chance_basic_gu() -> void:
	# Batch 0 Q6: 普通战低概率获得基础型蛊. The eight non-starter promotion
	# inputs are all present in their school pools (verified below), so opening
	# the common chance makes every school's 1->2 input battle-reachable.
	assert_eq(int(loot()["common"]["gu_chance_pct"]), 6)
	var school_pools: Dictionary = catalog()["school_pools"]
	for gu_id in NON_STARTER_INPUTS:
		var school := str(gu_id.split("_")[0])
		assert_true(school_pools.has(school), "%s school pool missing" % school)
		assert_true(_contains(school_pools[school], gu_id), "%s not in its school pool" % gu_id)


func _contains(node: Variant, gu_id: String) -> bool:
	if node is String:
		return str(node) == gu_id
	if node is Array:
		for item in node:
			if _contains(item, gu_id):
				return true
		return false
	if node is Dictionary:
		for key in node:
			if _contains(node[key], gu_id):
				return true
	return false
