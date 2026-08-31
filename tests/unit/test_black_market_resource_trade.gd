extends GutTest


# 黑市资源交易最小实现台账（2026-08-31）：
# 1) 20 寿元 → 1 魂魄底蕴（soul +1）
# 2)  1 魂魄底蕴 → 10 寿元
# 3) 20 生命（health -20） → 1 魂魄底蕴
# 4)  1 魂魄底蕴 → 10 生命（health +10、max_health +10）
# 5) 20 生命 → 10 寿元
# 每条一次性：再次购买拒，退出黑市节点后不可返回。


const ResolverScript = preload("res://scripts/domain/resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _rich_state() -> RunState:
	# 起点：寿元 60、soul 3、health 30/30、max_health 30、stone 0、节点 = ridge_black_market
	var state := RunState.new_run(101)
	state.cultivator["lifespan"] = 60
	state.cultivator["soul"] = 3
	state.cultivator["soul_max"] = 5
	state.health = 30
	state.max_health = 30
	state.stone = 0
	state.current_node_id = "ridge_black_market"
	state.current_node_template_id = "ridge_black_market"
	state.current_node_layer = 1
	return state


func _buy(state: RunState, offer_id: String) -> Dictionary:
	return ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": offer_id}, catalog)


func test_offers_declared_in_catalog() -> void:
	var by_id: Dictionary = catalog.get("shop_offer_by_id", {})
	var expected := [
		["black_market_lifespan_for_soul", "lifespan", 20, "soul", 1],
		["black_market_soul_for_lifespan", "soul", 1, "lifespan", 10],
		["black_market_health_for_soul", "health", 20, "soul", 1],
		["black_market_soul_for_health", "soul", 1, "health", 10],
		["black_market_health_for_lifespan", "health", 20, "lifespan", 10],
	]
	for row in expected:
		var offer_id: String = row[0]
		assert_true(by_id.has(offer_id), "offer %s 存在" % offer_id)
		var offer: Dictionary = by_id[offer_id]
		assert_eq(str(offer.get("kind", "")), "resource_trade")
		assert_eq(str(offer.get("cost_kind", "")), row[1])
		assert_eq(int(offer.get("cost_amount", 0)), int(row[2]))
		assert_eq(str(offer.get("gain_kind", "")), row[3])
		assert_eq(int(offer.get("gain_amount", 0)), int(row[4]))


func test_lifespan_to_soul() -> void:
	var state := _rich_state()
	var out := _buy(state, "black_market_lifespan_for_soul")
	assert_true(bool(out["result"].get("ok", false)), "购买 OK")
	assert_eq(int(out["state"].cultivator["lifespan"]), 40, "扣 20 寿元")
	assert_eq(int(out["state"].cultivator["soul"]), 4, "+1 魂魄")
	assert_eq(int(out["state"].health), 30, "生命不变")


func test_soul_to_lifespan() -> void:
	var state := _rich_state()
	var out := _buy(state, "black_market_soul_for_lifespan")
	assert_true(bool(out["result"].get("ok", false)), "购买 OK")
	assert_eq(int(out["state"].cultivator["soul"]), 2, "扣 1 魂魄")
	assert_eq(int(out["state"].cultivator["lifespan"]), 70, "+10 寿元")


func test_health_to_soul() -> void:
	var state := _rich_state()
	var out := _buy(state, "black_market_health_for_soul")
	assert_true(bool(out["result"].get("ok", false)), "购买 OK")
	assert_eq(int(out["state"].health), 10, "扣 20 生命")
	assert_eq(int(out["state"].max_health), 30, "max_health 不变")
	assert_eq(int(out["state"].cultivator["soul"]), 4, "+1 魂魄")


func test_soul_to_health_max_health() -> void:
	var state := _rich_state()
	var out := _buy(state, "black_market_soul_for_health")
	assert_true(bool(out["result"].get("ok", false)), "购买 OK")
	assert_eq(int(out["state"].cultivator["soul"]), 2, "扣 1 魂魄")
	assert_eq(int(out["state"].health), 40, "+10 生命")
	assert_eq(int(out["state"].max_health), 40, "max_health +10")


func test_health_to_lifespan() -> void:
	var state := _rich_state()
	var out := _buy(state, "black_market_health_for_lifespan")
	assert_true(bool(out["result"].get("ok", false)), "购买 OK")
	assert_eq(int(out["state"].health), 10, "扣 20 生命")
	assert_eq(int(out["state"].cultivator["lifespan"]), 70, "+10 寿元")


func test_each_offer_is_one_shot() -> void:
	for offer_id in [
		"black_market_lifespan_for_soul",
		"black_market_soul_for_lifespan",
		"black_market_health_for_soul",
		"black_market_soul_for_health",
		"black_market_health_for_lifespan",
	]:
		var state := _rich_state()
		var first := _buy(state, offer_id)
		assert_true(bool(first["result"].get("ok", false)), "%s 首次成功" % offer_id)
		var second := _buy(first["state"], offer_id)
		assert_false(bool(second["result"].get("ok", false)), "%s 第二次拒" % offer_id)
		assert_eq(str(second["result"].get("reason", "")), "resource_trade_already_used")


func test_insufficient_cost_rejected_without_state_change() -> void:
	var state := _rich_state()
	state.cultivator["lifespan"] = 10  # 不够 20
	state.cultivator["soul"] = 3
	state.health = 30
	var out := _buy(state, "black_market_lifespan_for_soul")
	assert_false(bool(out["result"].get("ok", false)), "资源不足拒")
	assert_eq(int(out["state"].cultivator["lifespan"]), 10, "未扣")
	assert_eq(int(out["state"].cultivator["soul"]), 3, "未加")
	assert_eq(str(out["result"].get("reason", "")), "insufficient_lifespan")


func test_lifespan_floor_blocks_paying_to_zero() -> void:
	var state := _rich_state()
	state.cultivator["lifespan"] = 20
	state.cultivator["soul"] = 0  # 扣到 0 应被拒
	var out := _buy(state, "black_market_soul_for_lifespan")
	# soul=0 已经够 "soul<1" → 应被拒
	assert_false(bool(out["result"].get("ok", false)), "soul=0 拒")
	assert_eq(int(out["state"].cultivator["lifespan"]), 20, "未扣")