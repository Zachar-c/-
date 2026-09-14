extends GutTest

# 发布阻断修复 4：分层经济可达性。
# 裁定：pacing.layers.N.stone_budget = 该层「中位收入」的可测真值；每层必须
# 存在至少一件「同层有效成长物」（purchase/soul_boost/recipe_unlock/
# material_purchase 且 tier ≤ 层）经层加价（shop_layer_price）后不超预算。
# 首次商店（大层 1 货架）必须含 流派协同 / 续航 / 升阶候选 三分类之一及全部。
# 商店购买不得推动保底计数（与掉落/奖励池隔离）。


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _layer_price(pct: int, base: int) -> int:
	var state := RunStateScript.new_run(42)
	return ResolverScript.shop_layer_price(catalog, state, base)


func _growth_offers() -> Array:
	var offers: Array = []
	for offer_value in catalog.get("shop_offer_by_id", {}).values():
		var offer: Dictionary = offer_value
		if str(offer.get("kind", "")) in ["purchase", "soul_boost", "recipe_unlock", "material_purchase"]:
			offers.append(offer)
	return offers


func test_each_layer_has_an_affordable_same_layer_growth_offer() -> void:
	for layer_value in catalog.get("pacing", {}).get("layers", {}):
		var layer := str(layer_value)
		var cfg: Dictionary = catalog["pacing"]["layers"][layer_value]
		var budget := int(cfg.get("stone_budget", -1))
		assert_gt(budget, 0, "pacing layer %s must declare stone_budget" % layer)
		var cheapest := -1
		for offer in _growth_offers():
			if int(offer.get("tier", 99)) > int(layer):
				continue
			var price := _layer_price(int(cfg.get("shop_price_pct", 0)), int(offer.get("stone_cost", 0)))
			if cheapest < 0 or price < cheapest:
				cheapest = price
		assert_true(cheapest >= 0, "layer %s must have at least one growth offer in-shelf" % layer)
		assert_true(cheapest <= budget, "layer %s: cheapest growth offer %d must fit the median income budget %d" % [layer, cheapest, budget])


func test_first_shop_shelf_has_synergy_sustain_and_rankup_candidates() -> void:
	# 静态货架（tier ≤ 大层 1，shop_max_tier=1）三分类齐备。
	var synergy := false
	var sustain := false
	var rankup := false
	var school_pools: Dictionary = catalog.get("school_pools", {})
	var advance_inputs := {}
	for recipe_value in catalog.get("refinement_recipes", []):
		var recipe: Dictionary = recipe_value
		if str(recipe.get("kind", "")) != "advance":
			continue
		for input_value in recipe.get("input_gu_ids", []):
			advance_inputs[str(input_value)] = true
	for offer in _growth_offers():
		if int(offer.get("tier", 99)) > 1:
			continue
		var gu_id := str(offer.get("gu_id", ""))
		if not gu_id.is_empty():
			for school_value in school_pools:
				var pool: Array = school_pools[school_value]
				if pool.has(gu_id):
					synergy = true
			if advance_inputs.has(gu_id):
				rankup = true
		if str(offer.get("kind", "")) == "soul_boost" or not str(offer.get("material_id", "")).is_empty():
			sustain = true
	assert_true(synergy, "大层 1 货架必须有流派协同蛊（石壳蛊=力道）")
	assert_true(sustain, "大层 1 货架必须有续航（魂丹/材料）")
	assert_true(rankup, "大层 1 货架必须有升阶候选（advance 配方输入蛊）")


func test_seed_101_first_caravan_shelf_is_synergistic() -> void:
	# 手工网首个商店（山脊商队）货架含力道协同+升阶候选蛊。
	var caravan_gu := {}
	for offer_value in catalog.get("caravan_offer_by_id", {}).values():
		var offer: Dictionary = offer_value
		var gu_id := str(offer.get("output_gu_id", ""))
		if not gu_id.is_empty():
			caravan_gu[gu_id] = true
	assert_true(caravan_gu.has("force_gu"), "商队货架须含力道蛊 force_gu（802 重建后替代刺鞭蛊）")


func test_shop_purchases_do_not_advance_pity() -> void:
	var state := RunStateScript.new_run(42)
	state.stone = 100
	var pity_before := int(state.loot_pity)
	var material_before: Dictionary = (state.material_pity_by_tier as Dictionary).duplicate(true)
	for _i in 3:
		var bought: Dictionary = ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": "purchase_stone_shell"}, catalog)
		state = bought["state"]
	assert_eq(int(state.loot_pity), pity_before, "商店购买不得推动蛊保底")
	# 商店购买不得推动材料保底（按 tier 计数整体不变）
	assert_eq_deep(state.material_pity_by_tier as Dictionary, material_before)