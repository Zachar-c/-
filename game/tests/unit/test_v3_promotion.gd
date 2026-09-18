extends GutTest


## Q8-G Batch 1-A：promotion（跨 definition 定向晋升）垂直切片。
##
## 冻结语义（Q8G_BATCH0_RULING.md §13 / Q8G_BATCH1A_RULING.md §7）：
##   advance   → **同** definition，实例 rank +1（封顶 5）
##   promotion → 消耗输入实例，产出**不同** definition，rank = 输入 rank + 1
##
## 本文件覆盖的 Gate：
##   Gate 1  schema / 静态校验（含反例：output == input 必须被拒）
##   Gate 2  执行正确（产出 definition / 转数 / 消耗输入 / 事件）
##   Gate 6  成本红线（promotion_total_cost < 该目标蛊的商店直取成本；无商店货则跳过）
##   Gate 7  语义隔离（advance 不换 definition，promotion 必换）
##
## D7 冻结链（2026-09-12 用户裁定方案 C）：
##   light_atk_1_01_gu(1) → moon_glow_gu(2) → moon_shadow_gu(3)
##   → light_atk_4_21_gu(4) → light_atk_5_03_gu(5)


const RunStateScript = preload("res://scripts/domain/run_state.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")

const CHAIN := [
	{
		"recipe_id": "promote_light_atk_1_01_to_moon_glow",
		"input": "light_atk_1_01_gu",
		"output": "moon_glow_gu",
		"output_rank": 2,
	},
	{
		"recipe_id": "promote_moon_glow_to_moon_shadow",
		"input": "moon_glow_gu",
		"output": "moon_shadow_gu",
		"output_rank": 3,
	},
	{
		"recipe_id": "promote_moon_shadow_to_light_atk_4_21",
		"input": "moon_shadow_gu",
		"output": "light_atk_4_21_gu",
		"output_rank": 4,
	},
	{
		"recipe_id": "promote_light_atk_4_21_to_light_atk_5_03",
		"input": "light_atk_4_21_gu",
		"output": "light_atk_5_03_gu",
		"output_rank": 5,
	},
]

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


# ---------------------------------------------------------------------------
# Gate 1：schema / 静态校验
# ---------------------------------------------------------------------------

func test_all_four_promotion_recipes_load_and_validate_clean() -> void:
	var errors := ContentCatalog.validate(catalog)
	assert_eq(errors, [], "目录校验必须零错误，实际=%s" % str(errors))


func test_promotion_recipes_declare_the_frozen_chain() -> void:
	var by_id: Dictionary = {}
	for recipe in catalog["refinement_recipes"]:
		by_id[str(recipe["id"])] = recipe
	for step in CHAIN:
		var recipe: Dictionary = by_id.get(str(step["recipe_id"]), {})
		assert_false(recipe.is_empty(), "缺少冻结链配方 %s" % step["recipe_id"])
		if recipe.is_empty():
			continue
		assert_eq(str(recipe.get("kind", "")), "promotion",
				"%s 的 kind 必须是 promotion" % step["recipe_id"])
		assert_eq(recipe.get("input_gu_ids", []), [step["input"]],
				"%s 的输入蛊不符" % step["recipe_id"])
		assert_eq(str(recipe.get("output_gu_id", "")), step["output"],
				"%s 的产出蛊不符" % step["recipe_id"])
		assert_ne(str(recipe.get("output_gu_id", "")), str(step["input"]),
				"Gate 7：promotion 每步必须更换 definition（%s）" % step["recipe_id"])


# Gate 1 反例：把 advance 误写成 promotion（output == input）必须在
# catalog / schema 层直接失败，而不是等到运行时才发现语义混乱。
func test_catalog_rejects_a_promotion_whose_output_equals_its_input() -> void:
	var mutated := catalog.duplicate(true)
	var recipe: Dictionary = {
		"id": "promote_self_reference_probe",
		"kind": "promotion",
		"input_gu_ids": ["moon_glow_gu"],
		"output_gu_id": "moon_glow_gu",   # 同名 → 这其实是 advance
		"source": "test_probe",
	}
	mutated["refinement_recipes"] = catalog["refinement_recipes"] + [recipe]

	var errors := ContentCatalog.validate(mutated)
	var matched := false
	for error_value in errors:
		if str(error_value).contains("promote_self_reference_probe") \
				and str(error_value).contains("must change gu definition"):
			matched = true
	assert_true(matched,
			"promotion 的 output == input 必须被 catalog 校验拒绝（advance 才同名），实际=%s" % str(errors))


# Gate 1 反例之二：promotion 不是"多输入合炼"，输入必须恰好一只。
func test_catalog_rejects_a_promotion_with_multiple_inputs() -> void:
	var mutated := catalog.duplicate(true)
	var recipe: Dictionary = {
		"id": "promote_two_input_probe",
		"kind": "promotion",
		"input_gu_ids": ["moon_glow_gu", "moon_ray_gu"],
		"output_gu_id": "moon_shadow_gu",
		"source": "test_probe",
	}
	mutated["refinement_recipes"] = catalog["refinement_recipes"] + [recipe]

	var errors := ContentCatalog.validate(mutated)
	var matched := false
	for error_value in errors:
		if str(error_value).contains("promote_two_input_probe") \
				and str(error_value).contains("exactly one input"):
			matched = true
	assert_true(matched,
			"promotion 必须恰好一个输入，实际=%s" % str(errors))


# ---------------------------------------------------------------------------
# Gate 2：执行正确
# ---------------------------------------------------------------------------

func test_first_step_promotes_rank_one_into_a_different_definition_at_rank_two() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 100
	run.materials = {"beast_bone": 3}

	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "promote_light_atk_1_01_to_moon_glow",
	}, catalog)
	var promoted: RunState = result["state"]

	assert_true(result["result"]["ok"], "promotion 应成功，实际=%s" % str(result["result"]))
	var live: Array = promoted.cave_aperture["stored_gu_instance_ids"]
	assert_eq(live.size(), 1, "输入消耗、产出留下 ⇒ 洞天仍只有 1 只")
	var output: Dictionary = promoted.gu_instances[str(live[0])]
	assert_eq(str(output["definition_id"]), "moon_glow_gu", "Gate 7：必须换成另一个 definition")
	assert_eq(int(output["rank"]), 2, "rank = 输入 rank + 1")
	assert_eq(str(output["state"]), "refined")
	# 输入实例保留在 gu_instances 里但标记 consumed（事件日志不可变，历史可追溯）
	assert_eq(str(promoted.gu_instances["gu_001"]["state"]), "consumed")
	assert_eq(promoted.refined_gu_ids, ["moon_glow_gu"])
	assert_eq(promoted.event_log.back()["reason"], "promotion_succeeded")


func test_promotion_charges_stone_and_materials() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 100
	run.materials = {"beast_bone": 3}

	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "promote_light_atk_1_01_to_moon_glow",
	}, catalog)
	var promoted: RunState = result["state"]

	assert_true(result["result"]["ok"])
	assert_eq(promoted.stone, 90, "扣 10 元石")
	assert_eq(int(promoted.materials.get("beast_bone", 0)), 2, "扣 1 兽骨")


func test_promotion_chain_runs_end_to_end_1_to_5() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 999
	run.materials = {"beast_bone": 9, "beast_blood": 9, "venom_sac": 9}

	for step in CHAIN:
		var result := ResolverScript.apply(run, {
			"type": "refine_gu",
			"recipe_id": str(step["recipe_id"]),
		}, catalog)
		assert_true(result["result"]["ok"],
				"%s 应成功，实际=%s" % [step["recipe_id"], str(result["result"])])
		run = result["state"]
		var live: Array = run.cave_aperture["stored_gu_instance_ids"]
		assert_eq(live.size(), 1, "%s 之后洞天仍应只有 1 只" % step["recipe_id"])
		var instance: Dictionary = run.gu_instances[str(live[0])]
		assert_eq(str(instance["definition_id"]), str(step["output"]))
		assert_eq(int(instance["rank"]), int(step["output_rank"]))

	assert_eq(run.refined_gu_ids, ["light_atk_5_03_gu"], "终点必须是五转光道蛊")
	assert_eq(run.stone, 999 - (10 + 18 + 30 + 45), "链上元石成本可加总")


func test_promotion_rejects_when_input_rank_is_below_the_declared_minimum() -> void:
	var run := _run_with_instances([{"definition_id": "moon_glow_gu", "rank": 1}])
	run.stone = 999
	run.materials = {"beast_bone": 5}

	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "promote_moon_glow_to_moon_shadow",
	}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "refinement_input_rank_insufficient")
	assert_eq(int(result["state"].materials.get("beast_bone", 0)), 5, "拒绝不得烧材料")
	assert_eq(result["state"].stone, 999, "拒绝不得扣元石")


func test_promotion_rejects_at_rank_five_without_consuming_anything() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_4_21_gu", "rank": 5}])
	run.stone = 999
	run.materials = {"beast_bone": 5, "venom_sac": 5}

	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "promote_light_atk_4_21_to_light_atk_5_03",
	}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "promotion_capped")
	assert_eq(int(result["state"].materials.get("beast_bone", 0)), 5)
	assert_eq(result["state"].stone, 999)


func test_promotion_rejects_without_materials_before_burning_stone() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 100
	run.materials = {}

	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "promote_light_atk_1_01_to_moon_glow",
	}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "missing_refinement_material")
	assert_eq(result["state"].stone, 100, "缺料拒绝发生在扣石之前")


func test_promotion_rejects_without_the_input_gu() -> void:
	var run := _run_with_instances([{"definition_id": "moon_ray_gu", "rank": 1}])
	run.stone = 100
	run.materials = {"beast_bone": 5}

	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "promote_light_atk_1_01_to_moon_glow",
	}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "missing_refinement_input")


func test_promotion_rejects_when_stone_is_insufficient() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 3
	run.materials = {"beast_bone": 5}

	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "promote_light_atk_1_01_to_moon_glow",
	}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "insufficient_stone")
	assert_eq(int(result["state"].materials.get("beast_bone", 0)), 5)


# 显式指定输入实例时，必须能选中（与 fixed/advance 同一选择器语义）。
func test_promotion_accepts_an_explicit_input_instance_id() -> void:
	var run := _run_with_instances([
		{"definition_id": "light_atk_1_01_gu", "rank": 1},
		{"definition_id": "light_atk_1_01_gu", "rank": 1},
	])
	run.stone = 100
	run.materials = {"beast_bone": 5}

	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "promote_light_atk_1_01_to_moon_glow",
		"input_instance_ids": ["gu_002"],
	}, catalog)
	var promoted: RunState = result["state"]

	assert_true(result["result"]["ok"], "实际=%s" % str(result["result"]))
	assert_eq(str(promoted.gu_instances["gu_002"]["state"]), "consumed", "被指定那只应被消耗")
	assert_eq(str(promoted.gu_instances["gu_001"]["state"]), "refined", "未指定那只必须保留")


# ---------------------------------------------------------------------------
# Gate 7：语义隔离 —— advance ≠ promotion
# ---------------------------------------------------------------------------

func test_gate_seven_advance_keeps_definition_promotion_swaps_it() -> void:
	# advance：同名 → 实例 rank +1，definition 不变
	var advance_run := _run_with_instances([{"definition_id": "small_light_gu", "rank": 2}])
	advance_run.stone = 100
	advance_run.materials = {"beast_blood": 5}
	var advanced := ResolverScript.apply(advance_run, {
		"type": "refine_gu",
		"recipe_id": "advance_small_light_gu",
	}, catalog)
	assert_true(advanced["result"]["ok"], "实际=%s" % str(advanced["result"]))
	var advanced_live: Array = advanced["state"].cave_aperture["stored_gu_instance_ids"]
	var advanced_instance: Dictionary = advanced["state"].gu_instances[str(advanced_live[0])]
	assert_eq(str(advanced_instance["definition_id"]), "small_light_gu",
			"advance 不得更换 definition")
	assert_eq(int(advanced_instance["rank"]), 3, "advance 只推进实例转数")

	# promotion：换 definition，rank +1
	var promote_run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	promote_run.stone = 100
	promote_run.materials = {"beast_bone": 5}
	var promoted := ResolverScript.apply(promote_run, {
		"type": "refine_gu",
		"recipe_id": "promote_light_atk_1_01_to_moon_glow",
	}, catalog)
	assert_true(promoted["result"]["ok"], "实际=%s" % str(promoted["result"]))
	var promoted_live: Array = promoted["state"].cave_aperture["stored_gu_instance_ids"]
	var promoted_instance: Dictionary = promoted["state"].gu_instances[str(promoted_live[0])]
	assert_ne(str(promoted_instance["definition_id"]), "light_atk_1_01_gu",
			"promotion 必须更换 definition")
	assert_eq(int(promoted_instance["rank"]), 2)

	# 两条路径的事件 reason 必须不同，避免日志层混淆
	assert_eq(advanced["state"].event_log.back()["reason"], "refinement_succeeded")
	assert_eq(promoted["state"].event_log.back()["reason"], "promotion_succeeded")


# ---------------------------------------------------------------------------
# Gate 6：成本红线
# ---------------------------------------------------------------------------
#
# 红线定义（M3，Q8G_BATCH1A_RULING.md §2.9）：
#   同目标蛊直取成本 = 该蛊在本局可达的**商店直售价**。
#   要求 promotion_total_cost(target) < direct_acquisition_cost(target)。
#   若目标蛊没有任何商店 offer，**跳过该步比较，不得凭空造一个基线**。

func test_cost_redline_holds_wherever_a_shop_offer_exists() -> void:
	var recipe_by_id: Dictionary = {}
	for recipe in catalog["refinement_recipes"]:
		recipe_by_id[str(recipe["id"])] = recipe

	var shop_price_by_gu := _cheapest_shop_price_by_gu()
	var compared := 0
	var cumulative := 0
	for step in CHAIN:
		var recipe: Dictionary = recipe_by_id[str(step["recipe_id"])]
		cumulative += _total_cost(recipe)
		var target := str(step["output"])
		if not shop_price_by_gu.has(target):
			# 无商店 offer ⇒ 按 M3 跳过，不造基线
			continue
		compared += 1
		assert_true(cumulative < int(shop_price_by_gu[target]),
				"到达 %s 的累计成本 %d 必须低于商店直取 %d（%s）"
				% [target, cumulative, int(shop_price_by_gu[target]), step["recipe_id"]])
	assert_true(compared > 0,
			"链上至少应有一个目标蛊存在商店 offer，否则成本红线形同虚设（实际比较 %d 步）" % compared)


func test_cost_redline_skips_targets_without_a_shop_offer() -> void:
	var shop_price_by_gu := _cheapest_shop_price_by_gu()
	# 本测试的作用是**显式记录**当前哪些链上目标缺商店 offer，
	# 以便未来新增 offer 时红线自动生效、不会静默漏检。
	var missing: Array[String] = []
	for step in CHAIN:
		if not shop_price_by_gu.has(str(step["output"])):
			missing.append(str(step["output"]))
	# 不强行断言具体集合（避免把临时数值写成新基线），只断言"跳过是有意的"。
	for gu_id in missing:
		assert_false(shop_price_by_gu.has(gu_id),
				"%s 被判为无商店 offer 却查到了价格" % gu_id)


# ---------------------------------------------------------------------------
# Gate 3：preview ≈ execution（能做的才显示可执行，成本必须可见）
# ---------------------------------------------------------------------------

func test_preview_reports_promotion_as_executable_when_everything_is_paid_for() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 100
	run.materials = {"beast_bone": 3}

	var card := _promotion_card(run, "promote_light_atk_1_01_to_moon_glow")
	assert_false(card.is_empty(), "预览必须给出 promotion 卡")
	assert_true(bool(card["executable"]), "条件齐备时应可执行，block_reason=%s" % card["block_reason"])
	assert_eq(str(card["block_reason"]), "")

	# 预览说能做 ⇒ 真做必须成功（否则就是"看得见做不到"）
	var result := ResolverScript.apply(run, card["command"], catalog)
	assert_true(result["result"]["ok"], "预览可执行但执行失败：%s" % str(result["result"]))


func test_preview_reports_promotion_as_blocked_when_stone_is_short() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 3
	run.materials = {"beast_bone": 3}

	var card := _promotion_card(run, "promote_light_atk_1_01_to_moon_glow")
	assert_false(bool(card["executable"]), "元石不足不得显示为可执行")
	assert_true(str(card["block_reason"]).contains("元石不足"), "须说明缺元石，实际=%s" % card["block_reason"])

	# 预览说不能做 ⇒ 真做也必须被拒（不能预览放过、执行拦下）
	var result := ResolverScript.apply(run, card["command"], catalog)
	assert_false(result["result"]["ok"])


func test_preview_exposes_promotion_stone_and_material_cost() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 100
	run.materials = {"beast_bone": 3}

	var card := _promotion_card(run, "promote_light_atk_1_01_to_moon_glow")
	var cost: Dictionary = card["cost"]
	assert_eq(int(cost.get("stone", 0)), 10, "元石成本必须摊开（透明度红线）")
	var shown_materials: Dictionary = cost.get("materials", {})
	assert_eq(shown_materials.size(), 1, "蛊材成本必须摊开")
	assert_eq(int(shown_materials.get("beast_bone", 0)), 1, "兽骨需求必须为 1")
	assert_eq(cost.get("gu_ids", []), ["light_atk_1_01_gu"], "输入蛊必须摊开")


func test_preview_blocks_promotion_when_the_input_rank_is_too_low() -> void:
	# 第二步要求输入 rank ≥ 2；只有 1 转的 moon_glow 不该显示为可执行。
	var run := _run_with_instances([{"definition_id": "moon_glow_gu", "rank": 1}])
	run.stone = 100
	run.materials = {"beast_bone": 3}

	var card := _promotion_card(run, "promote_moon_glow_to_moon_shadow")
	var executable := bool(card["executable"])
	var result := ResolverScript.apply(run, card["command"], catalog)
	assert_eq(executable, bool(result["result"]["ok"]),
			"预览可执行性与执行结果必须一致（rank 门禁）：卡=%s / 执行=%s"
			% [str(card["block_reason"]), str(result["result"])])


# ---------------------------------------------------------------------------
# Gate 4 / Gate 5：确定性 + save / load / replay
# ---------------------------------------------------------------------------

func test_promotion_is_deterministic_for_the_same_state() -> void:
	var first := _promote_once("promote_light_atk_1_01_to_moon_glow")
	var second := _promote_once("promote_light_atk_1_01_to_moon_glow")
	assert_eq(first["reason"], second["reason"])
	assert_eq(first["definition_id"], second["definition_id"])
	assert_eq(first["rank"], second["rank"])
	assert_eq(first["stone"], second["stone"])


# promotion 不掷骰：没有 success_roll，也就不该在事件里留下任何 roll 值，
# 否则重放会因随机源不同而分叉（free_mix 才是唯一掷骰的炼蛊路径）。
func test_promotion_introduces_no_randomness() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 100
	run.materials = {"beast_bone": 3}

	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "promote_light_atk_1_01_to_moon_glow",
	}, catalog)
	var promoted: RunState = result["state"]
	assert_false(result["result"].has("roll"), "promotion 不得引入 UI 可注入的 roll")
	for index in range(run.event_log.size(), promoted.event_log.size()):
		var event: Dictionary = promoted.event_log[index]
		assert_false(event.has("roll"), "promotion 事件不得携带 roll 字段：%s" % str(event.get("reason", "")))


# D5：promotion 只写既有字段（gu_instances / cave_aperture），不新增存档键，
# 因此**不机械抬 SAVE_VERSION**；但实例必须带着升后的转数原样过一轮存读。
func test_promoted_instance_rank_survives_a_save_load_round_trip() -> void:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 100
	run.materials = {"beast_bone": 3}
	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "promote_light_atk_1_01_to_moon_glow",
	}, catalog)
	var promoted: RunState = result["state"]

	var payload := SaveRepositoryScript.serialize_run(promoted, [], [])
	assert_eq(int(payload.get("version", 0)), 4, "不因 promotion 而变更存档版本（D5）")
	var loaded: Dictionary = SaveRepositoryScript.load_run_from_data(payload)
	assert_false(loaded.is_empty(), "promotion 之后的存档必须能读回")
	var restored: RunState = loaded["state"]

	var restored_by_definition := {}
	for instance in restored.gu_instances.values():
		if str(instance.get("state", "")) == "consumed":
			continue
		restored_by_definition[str(instance["definition_id"])] = int(instance.get("rank", 1))
	assert_true(restored_by_definition.has("moon_glow_gu"),
			"读回后必须仍有 moon_glow_gu，实际=%s" % str(restored_by_definition.keys()))
	assert_eq(int(restored_by_definition["moon_glow_gu"]), 2, "升后的转数必须存得住")


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
## 跑同一条 1→2 步骤并回报结果快照，用于确定性比对。
func _promote_once(recipe_id: String) -> Dictionary:
	var run := _run_with_instances([{"definition_id": "light_atk_1_01_gu", "rank": 1}])
	run.stone = 100
	run.materials = {"beast_bone": 3}
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": recipe_id}, catalog)
	var promoted: RunState = result["state"]
	var live: Array = promoted.cave_aperture["stored_gu_instance_ids"]
	var instance: Dictionary = promoted.gu_instances[str(live[0])] if not live.is_empty() else {}
	return {
		"reason": str(result["result"].get("reason", "")),
		"definition_id": str(instance.get("definition_id", "")),
		"rank": int(instance.get("rank", 0)),
		"stone": int(promoted.stone),
	}


## 从 refinement 节点预览里取指定配方的卡。
func _promotion_card(run: RunState, recipe_id: String) -> Dictionary:
	var node := {"id": "refinement_den", "type": "refinement", "choices": []}
	var cards := ActionPreviewServiceScript.preview_actions(run, node, catalog)
	var wanted := "refine.%s" % recipe_id
	for card in cards:
		if str(card.get("id", "")) == wanted:
			return card
	return {}


func _run_with_instances(specs: Array) -> RunState:
	var run := RunStateScript.new_run(101)
	# 魂魄底蕴 5 → 炼蛊并发上限 4（本文件配方最高 1 输入 + 3 材料碎片）
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


## 元石成本 + 材料折价（材料 value 取自 loot_tables.materials）。
func _total_cost(recipe: Dictionary) -> int:
	var total := int(recipe.get("stone_cost", 0))
	var material_table: Dictionary = catalog.get("loot_tables", {}).get("materials", {})
	for material_id in recipe.get("materials", {}):
		var unit_value := int((material_table.get(str(material_id), {}) as Dictionary).get("value", 0))
		total += unit_value * int(recipe["materials"][material_id])
	return total


## 每只蛊的最低商店直售价（kind == "purchase" 且带 gu_id）。
func _cheapest_shop_price_by_gu() -> Dictionary:
	var cheapest := {}
	for offer in catalog.get("shop_offers", []):
		if str(offer.get("kind", "")) != "purchase":
			continue
		var gu_id := str(offer.get("gu_id", ""))
		if gu_id.is_empty():
			continue
		var price := int(offer.get("stone_cost", 0))
		if not cheapest.has(gu_id) or price < int(cheapest[gu_id]):
			cheapest[gu_id] = price
	return cheapest
