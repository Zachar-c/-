extends GutTest


# 五转梯度（2026-08-28/29 design ruling）幸存部分：
# - 数据层：每个敌人带手写 turn 基线（1..5）。
# - refine 节点同蛊升阶：stone + 材料、rank 封顶 5；advance 配方 Schema 校验拒绝跨名。
# legacy 的"层差缩放 HP/+伤"与"rank 提伤/提 essence 消耗"在 V1 战斗里改由敌人
# authored + cultivation 门槛实现（随 battle_resolver.gd 退役，B1 桶 C）。

const RunStateScript = preload("res://scripts/domain/run_state.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_enemies_carry_turn_baseline() -> void:
	for enemy in catalog.get("enemies", []):
		var turn := int(enemy.get("turn", -1))
		assert_between(turn, 1, 5, "every enemy needs an authored turn within 1..5 (%s)" % str(enemy.get("id", "")))


func test_advance_recipe_raises_rank_and_costs_stone() -> void:
	var run = RunStateScript.new_run(101)
	run.stone = 6
	run.materials["beast_blood"] = 1
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "advance_small_light_gu"}, catalog)
	assert_true(result["result"]["ok"], str(result["result"]))
	assert_eq(int(result["state"].highest_owned_rank("small_light_gu")), 2)
	assert_eq(int(result["state"].stone), 0, "advance charges the declared stone cost")
	assert_eq(int(result["state"].materials.get("beast_blood", 0)), 0, "advance consumes the declared materials")


func test_advance_rejects_when_stone_is_missing() -> void:
	var run = RunStateScript.new_run(101)
	run.stone = 0
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "advance_small_light_gu"}, catalog)
	assert_false(result["result"]["ok"])
	assert_eq(int(result["state"].highest_owned_rank("small_light_gu")), 1)


func test_catalog_rejects_mismatched_advance_recipe() -> void:
	var bad := catalog.duplicate(true)
	bad["refinement_recipes"] = (bad.get("refinement_recipes", []) as Array).duplicate()
	bad["refinement_recipes"].append({
		"id": "bad_advance", "kind": "advance",
		"input_gu_ids": ["small_light_gu"], "output_gu_id": "thorn_whip_gu",
	})
	var errors := ContentCatalogScript.validate(bad)
	assert_gt(errors.size(), 0, "an advance recipe onto another name must fail validation")
