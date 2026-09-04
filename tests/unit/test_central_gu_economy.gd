extends GutTest

## 中央数值支配的经济方案 + 蛊方批量生成 + 展示层补齐（2026-09-04）。
## 覆盖：gu_value_by_rank 中央价值表、gen_ 蛊方批量生成（同 名升阶）、
## 升阶实例按实例转数计价、图鉴/战斗手牌的转数与效果展示。

const MetaProgressScript = preload("res://scripts/domain/meta_progress.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _run_with_gu(definition_id: String, rank: int) -> RunState:
	var run := RunState.new_run(101)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	run.gu_instances["gu_001"] = {
		"instance_id": "gu_001",
		"definition_id": definition_id,
		"state": "refined",
		"rank": rank,
	}
	run.cave_aperture["stored_gu_instance_ids"].append("gu_001")
	run.sync_legacy_gu_projections()
	return run


## 中央价值表存在且 1..5 全覆盖正整数。
func test_balance_declares_gu_value_by_rank() -> void:
	var table: Dictionary = catalog.get("balance", {}).get("gu_value_by_rank", {})
	assert_eq(table.size(), 5)
	for rank in [1, 2, 3, 4, 5]:
		assert_true(int(table.get(str(rank), 0)) > 0, "rank %d must have a positive value" % rank)


## 批量生成的 gen_ 蛊价值必须由中央表支配（禁止手写跨转字面量）。
func test_generated_gu_values_obey_central_table() -> void:
	var table: Dictionary = catalog["balance"]["gu_value_by_rank"]
	for g in catalog.get("gu", []):
		if not str(g.get("id", "")).begins_with("gen_"):
			continue
		assert_eq(int(g.get("value", 0)), int(table[str(int(g.get("rank", 1)))]),
				"gen gu %s value must equal gu_value_by_rank[rank]" % str(g.get("id", "")))


## 每只 rank 1-2 的 gen_ 蛊都有同名升阶蛊方（批量生成方案落地）。
func test_generated_gu_have_advance_recipes() -> void:
	var recipes_by_output: Dictionary = {}
	for r in catalog.get("refinement_recipes", []):
		if str(r.get("kind", "")) == "advance":
			recipes_by_output[str(r.get("output_gu_id", ""))] = r
	var gen_count := 0
	for g in catalog.get("gu", []):
		var gid := str(g.get("id", ""))
		if not gid.begins_with("gen_"):
			continue
		gen_count += 1
		var rank := int(g.get("rank", 1))
		if rank >= 3:
			continue
		assert_true(recipes_by_output.has(gid), "gen gu %s needs an advance recipe" % gid)
		if recipes_by_output.has(gid):
			var recipe: Dictionary = recipes_by_output[gid]
			assert_eq(int(recipe.get("stone_cost", 0)),
					int(catalog["balance"]["gu_value_by_rank"][str(rank)]) * 2,
					"advance stone cost must be centrally priced (2x input rank value)")
			if rank == 2:
				assert_eq(int(recipe.get("input_min_rank", 0)), 2,
						"rank2 advance must gate input_min_rank=2")
	assert_eq(gen_count, 180)


## 升阶蛊方可用：一转 gen 蛊升到二转，烧料扣石。
func test_advance_recipe_promotes_gen_gu_instance() -> void:
	var run := _run_with_gu("gen_blood_attack_001_gu", 1)
	run.materials = {"beast_bone": 1}
	run.stone = 20

	var result := Resolver.apply(run, {"type": "refine_gu", "recipe_id": "advance_gen_blood_attack_001_gu"}, catalog)

	assert_true(result["result"]["ok"], str(result["result"]))
	var refined: RunState = result["state"]
	# 升阶产出是新实例（旧 gu_001 已消耗），活实例 rank 必须是 2。
	var live_ids: Array = refined.cave_aperture["stored_gu_instance_ids"]
	assert_eq(live_ids.size(), 1)
	assert_eq(int(refined.gu_instances[str(live_ids[0])]["rank"]), 2)
	assert_eq(int(refined.materials.get("beast_bone", 0)), 0)
	assert_eq(int(refined.stone), 14)


## 二转蛊方不能被一转实例借用跳阶：input_min_rank 门禁。
func test_rank2_advance_recipe_rejects_rank1_input() -> void:
	var run := _run_with_gu("gen_blood_attack_023_gu", 1)
	run.gu_instances["gu_001"]["rank"] = 1
	run.sync_legacy_gu_projections()
	run.cultivator["soul"] = 5
	run.materials = {"beast_bone": 2}
	run.stone = 20

	var result := Resolver.apply(run, {"type": "refine_gu", "recipe_id": "advance_gen_blood_attack_023_gu"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "refinement_input_rank_insufficient")


## 升阶后的实例按实例转数计价卖出（中央表），不再按定义 rank1 低价。
func test_sell_uses_instance_rank_via_central_table() -> void:
	var run := _run_with_gu("gen_blood_attack_001_gu", 2)
	run.stone = 0

	var result := Resolver.apply(run, {"type": "sell_gu", "gu_id": "gen_blood_attack_001_gu"}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(int(result["state"].stone), 5, "rank2 gen gu must sell at table value 5")


## 图鉴蛊条目带转数与效果文本，战斗手牌不再出现「效果未明」。
func test_codex_and_hand_surface_rank_and_effect() -> void:
	var meta: Variant = MetaProgress.new()
	var gu_entries: Array = RunSnapshotBuilder._codex(catalog, meta).get("gu", [])
	assert_false(gu_entries.is_empty())
	var by_id: Dictionary = {}
	for e in gu_entries:
		by_id[str(e.get("id", ""))] = e
	var gen_entry: Dictionary = by_id.get("gen_blood_attack_001_gu", {})
	assert_eq(int(gen_entry.get("rank", 0)), 1, "codex gu entry must carry rank")
	assert_string_contains(str(gen_entry.get("effect", "")), "伤害", "codex effect text must come from role fallback")

	var battle: Dictionary = V1BattleResolver.start(_run_with_gu("gen_blood_attack_001_gu", 1), catalog, [
		{"id": "v1_test_enemy", "label": "测试敌人", "hp": 9, "intent": {"kind": "attack", "damage": 0, "label": "测试意图"}}
	])
	var hand: Array = RunSnapshotBuilder._v1_hand(battle, catalog)
	assert_false(hand.is_empty())
	for card in hand:
		if str(card.get("id", "")) == "basic_attack":
			continue
		assert_string_contains(str(card.get("summary", "")), "转", "hand card summary must carry rank prefix")
		assert_false(str(card.get("summary", "")).contains("效果未明"))


## 补名：moon_ray_gu 曾显示「未知蛊虫」。
func test_moon_ray_gu_has_chinese_name() -> void:
	assert_eq(DisplayText.gu("moon_ray_gu"), "月芒蛊")
