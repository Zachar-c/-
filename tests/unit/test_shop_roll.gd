extends GutTest


## E7 黑市货架（2026-09-10）：每店只摆 N 件货 + 保底 + 越权拒绝。
##
## 设计要点（与两次开源调研的结论对齐，见 reports/2026-09-10-oss-research-and-rng-defect.md）：
##  · **货要抽架、服务常驻**：只有 `SHOP_GOODS_KINDS` 里的"货"才受货架限制，
##    `resource_trade`（黑市兑换）/ `wash_notoriety` / `recipe_unlock` / `soul_boost` 等
##    柜台业务恒可用。
##  · **洗牌取前 N**（不是加权抽 N 次）：天然不重复。
##  · **保底**：每架至少 1 件本层可出的最高档。
##  · **确定性**：种子 = (局种子, 节点模板 id)；不新增存档字段。


const RunStateScript = preload("res://scripts/domain/run_state.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ShopRulesScript = preload("res://scripts/domain/shop_command_rules.gd")

const NODE_A := "ridge_black_market"
const NODE_B := "village_short_work"

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _state(layer: int, node_key: String = NODE_A, seed_value: int = 20260910) -> RunState:
	var run = RunStateScript.new_run(seed_value)
	run.current_node_layer = layer
	run.current_node_template_id = node_key
	run.stone = 999
	return run


func _tier_of(offer_id: String) -> int:
	return int((catalog["shop_offer_by_id"].get(offer_id, {}) as Dictionary).get("tier", 1))


func test_stock_is_deterministic_for_the_same_node() -> void:
	var first := ResolverScript.shop_stock(_state(3), catalog)
	var second := ResolverScript.shop_stock(_state(3), catalog)
	assert_eq(first, second, "同一局种子 + 同一节点，货架必须一致（反复进出不刷货）")
	assert_gt(first.size(), 0, "层 3 必须有货可上")


func test_stock_differs_between_nodes() -> void:
	var a := ResolverScript.shop_stock(_state(3, NODE_A), catalog)
	var b := ResolverScript.shop_stock(_state(3, NODE_B), catalog)
	assert_ne(a, b, "不同节点必须是不同的货架")


func test_slot_count_follows_the_layer() -> void:
	var expected := {1: 4, 2: 5, 3: 5, 4: 6, 5: 6}
	for layer in [1, 2, 3, 4, 5]:
		var state := _state(layer)
		var stock := ResolverScript.shop_stock(state, catalog)
		var pool := ShopRulesScript.shop_goods_pool(state, catalog)
		assert_eq(stock.size(), expected[layer], "层 %d 的货架应为 %d 件" % [layer, expected[layer]])
		assert_true(stock.size() <= pool.size(), "货架不得超过可选池（层 %d）" % layer)


func test_stock_never_repeats_an_offer() -> void:
	for layer in [1, 3, 5]:
		var stock := ResolverScript.shop_stock(_state(layer), catalog)
		var seen := {}
		for offer_id in stock:
			assert_false(seen.has(offer_id), "同架不得重复：%s（层 %d）" % [offer_id, layer])
			seen[offer_id] = true


func test_stock_always_includes_the_layer_top_tier_when_available() -> void:
	for layer in [1, 2, 3, 4, 5]:
		var state := _state(layer)
		var cap := ResolverScript.shop_max_tier(state, catalog)
		var pool := ShopRulesScript.shop_goods_pool(state, catalog)
		var has_top_in_pool := false
		for offer_id in pool:
			if _tier_of(offer_id) == cap:
				has_top_in_pool = true
		if not has_top_in_pool:
			continue
		var stock := ResolverScript.shop_stock(state, catalog)
		var has_top := false
		for offer_id in stock:
			if _tier_of(offer_id) == cap:
				has_top = true
		assert_true(has_top, "层 %d 的货架必须保底一件最高档（tier=%d）" % [layer, cap])


func test_buying_off_shelf_goods_is_rejected() -> void:
	var state := _state(3)
	var stock := ResolverScript.shop_stock(state, catalog)
	var pool := ShopRulesScript.shop_goods_pool(state, catalog)
	var off_shelf := ""
	for offer_id in pool:
		if not stock.has(offer_id):
			off_shelf = offer_id
	if off_shelf.is_empty():
		pass_test("层 3 的池恰好全上架，无越权样本")
		return
	var result := ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": off_shelf}, catalog)
	assert_false(bool(result["result"]["ok"]), "不在货架上的货必须被拒（%s）" % off_shelf)
	assert_eq(str(result["result"]["reason"]), "shop_offer_not_in_stock")


func test_on_shelf_goods_can_be_bought() -> void:
	var state := _state(1)
	var stock := ResolverScript.shop_stock(state, catalog)
	var affordable := ""
	for offer_id in stock:
		var offer: Dictionary = catalog["shop_offer_by_id"].get(offer_id, {})
		if str(offer.get("kind", "")) == "purchase":
			affordable = offer_id
			break
	if affordable.is_empty():
		pass_test("层 1 货架上没有 purchase 类货，跳过")
		return
	var result := ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": affordable}, catalog)
	assert_true(bool(result["result"]["ok"]), "架上的货必须可买：%s → %s" % [affordable, str(result["result"])])


func test_services_stay_available_regardless_of_shelf() -> void:
	# 服务（黑市兑换）不是"货"，不应受货架限制。
	var state := _state(1)
	var service_ids: Array[String] = []
	for offer_key in catalog["shop_offer_by_id"]:
		var offer: Dictionary = catalog["shop_offer_by_id"][offer_key]
		if str(offer.get("kind", "")) == "resource_trade":
			service_ids.append(str(offer_key))
	assert_gt(service_ids.size(), 0, "数据里应有黑市兑换服务")
	for service_id in service_ids:
		assert_true(ResolverScript.shop_offer_is_stocked(state, catalog, service_id),
				"服务必须常驻可用：%s" % service_id)


func test_empty_goods_pool_yields_empty_stock_and_unknown_offer_is_not_stocked() -> void:
	var bare_catalog := {
		"shop_offer_by_id": {},
		"pacing": {"layers": {"1": {"shop_max_tier": 1, "shop_price_pct": 0}}},
	}
	var state := _state(1)
	assert_eq(ResolverScript.shop_stock(state, bare_catalog), [], "无货可上时货架为空，不得崩")
	assert_false(ResolverScript.shop_offer_is_stocked(state, bare_catalog, "no_such_offer"),
			"未知货 id 不得视为在架")
