extends GutTest


# 五转梯度（2026-08-28/29 design ruling）幸存部分：
# - 数据层：每个敌人**手写自己的梯度位**（`rank` 层位 + `grade` 类别），不得缺省。
#   （原承载字段 `turn` 与 `essence` 在 V1 引擎零消费，已于 2026-09-10 退役。）
# - refine 节点同蛊升阶：stone + 材料、rank 封顶 5；advance 配方 Schema 校验拒绝跨名。
# legacy 的"层差缩放 HP/+伤"与"rank 提伤/提 essence 消耗"在 V1 战斗里改由敌人
# authored + cultivation 门槛实现（随 battle_resolver.gd 退役，B1 桶 C）。

const RunStateScript = preload("res://scripts/domain/run_state.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const EnemyCatalogScript = preload("res://scripts/domain/enemy_catalog.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


## 梯度位的承载字段由 `turn` 换成 `rank`（层位）+ `grade`（类别）后，**契约不变**：
## 每个敌人必须手写自己的梯度位，缺省即失败。阶梯口径见 enemy_catalog.GRADES。
func test_enemies_carry_an_authored_rank_and_grade() -> void:
	for enemy in catalog.get("enemies", []):
		var enemy_id := str(enemy.get("id", ""))
		assert_true(enemy.has("rank"), "every enemy needs an authored rank (%s)" % enemy_id)
		assert_between(int(enemy.get("rank", -1)), 0, 5,
				"enemy rank must be within 0..5 (%s)" % enemy_id)
		assert_true(enemy.has("grade"), "every enemy needs an authored grade (%s)" % enemy_id)
		assert_true(EnemyCatalogScript.GRADES.has(str(enemy.get("grade", ""))),
				"enemy grade must be a known ladder class (%s)" % enemy_id)
		# 退役字段不得悄悄回流：要复活请连同消费点一起加回来。
		assert_false(enemy.has("turn"), "enemy turn was retired in V1 (%s)" % enemy_id)
		assert_false(enemy.has("essence"), "enemy essence was retired in V1 (%s)" % enemy_id)


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
