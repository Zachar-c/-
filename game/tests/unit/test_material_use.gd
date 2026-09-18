extends GutTest


# 材料消费第四通路「直接使用」（2026-08-28 产出与消费闭环批）：
# - loot_tables.materials.*.use 声明 health/essence 增量与文案；
# - 负向增量受死亡可预见红线约束：执行前预检，会耗尽气血直接拒绝；
# - 纯材料配方（input_gu_ids 为空）走同一 refine_gu 入口——蛊虫=材料+蛊虫两条炼制路。

const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_use_material_consumes_stock_and_heals() -> void:
	var run := RunState.new_run(101)
	run.materials["beast_blood"] = 1
	run.health = 2

	var result := ResolverScript.apply(run, {"type": "use_material", "material_id": "beast_blood"}, catalog)

	assert_true(result["result"]["ok"], str(result["result"]))
	assert_eq(int(result["state"].health), 4, "beast_blood heals 2")
	assert_eq(int(result["state"].materials.get("beast_blood", 0)), 0, "one unit consumed")
	assert_eq(str(result["state"].event_log.back()["reason"]), "material_used")
	assert_true((result["state"].event_log.back()["targets"] as Array).has("beast_blood"))


func test_use_material_heal_never_exceeds_max_health() -> void:
	var run := RunState.new_run(101)
	run.materials["beast_blood"] = 2
	run.health = int(run.max_health) - 1

	var result := ResolverScript.apply(run, {"type": "use_material", "material_id": "beast_blood"}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(int(result["state"].health), int(run.max_health), "heal clamps at max_health")


func test_use_material_restores_essence_up_to_capacity() -> void:
	var run := RunState.new_run(101)
	run.materials["moon_dew"] = 1
	run.essence = 1

	var result := ResolverScript.apply(run, {"type": "use_material", "material_id": "moon_dew"}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(int(result["state"].essence), 3, "moon_dew restores 2 essence")
	assert_eq(int(result["state"].materials.get("moon_dew", 0)), 0)


func test_use_material_rejects_when_out_of_stock() -> void:
	var run := RunState.new_run(101)

	var result := ResolverScript.apply(run, {"type": "use_material", "material_id": "beast_blood"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(str(result["result"]["reason"]), "no_material_to_use")


func test_use_material_rejects_unknown_material() -> void:
	var run := RunState.new_run(101)

	var result := ResolverScript.apply(run, {"type": "use_material", "material_id": "dragon_scale"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(str(result["result"]["reason"]), "unknown_material")


func test_use_material_rejects_material_without_use_declaration() -> void:
	var tuned := catalog.duplicate(true)
	(tuned["loot_tables"]["materials"] as Dictionary)["beast_blood"] = {"name_zh": "兽血", "value": 2}
	var run := RunState.new_run(101)
	run.materials["beast_blood"] = 1

	var result := ResolverScript.apply(run, {"type": "use_material", "material_id": "beast_blood"}, tuned)

	assert_false(result["result"]["ok"])
	assert_eq(str(result["result"]["reason"]), "material_not_usable")


func test_lethal_material_use_is_prechecked_and_refused() -> void:
	# 死亡可预见红线：毒囊 -1 气血，血量 1 时执行必死——拒绝而非静默致死。
	var run := RunState.new_run(101)
	run.materials["venom_sac"] = 1
	run.health = 1

	var result := ResolverScript.apply(run, {"type": "use_material", "material_id": "venom_sac"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(str(result["result"]["reason"]), "material_use_lethal")
	assert_eq(int(result["state"].health), 1, "precheck leaves health untouched")
	assert_eq(int(result["state"].materials.get("venom_sac", 0)), 1, "precheck leaves stock untouched")


func test_lethal_material_use_allowed_when_survivable() -> void:
	var run := RunState.new_run(101)
	run.materials["venom_sac"] = 1
	run.health = 5

	var result := ResolverScript.apply(run, {"type": "use_material", "material_id": "venom_sac"}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(int(result["state"].health), 4, "venom_sac costs 1 health when survivable")


func test_pure_material_recipe_forges_gu_without_gu_inputs() -> void:
	var run := RunState.new_run(101)
	run.materials["beast_bone"] = 2

	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "stone_shell_bone_forge"}, catalog)

	assert_true(result["result"]["ok"], str(result["result"]))
	assert_eq(int(result["state"].refined_gu_ids.count("stone_shell_gu")), 1)
	assert_eq(int(result["state"].materials.get("beast_bone", 0)), 0, "materials consumed by the forge")
	assert_true((result["state"].event_log.back()["targets"] as Array).has("recipe:stone_shell_bone_forge"))


func test_pure_material_recipe_rejects_without_materials() -> void:
	var run := RunState.new_run(101)

	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "stone_shell_bone_forge"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(str(result["result"]["reason"]), "missing_refinement_material")


func test_advance_recipes_declare_real_material_costs() -> void:
	# 2026-08-28 裁定：升阶不只烧元石——每一张 advance 配方必须声明材料代价。
	for recipe_value in catalog.get("refinement_recipes", []):
		var recipe: Dictionary = recipe_value
		if str(recipe.get("kind", "")) != "advance":
			continue
		assert_gt((recipe.get("materials", {}) as Dictionary).size(), 0,
			"advance recipe %s must declare materials" % str(recipe.get("id", "")))
