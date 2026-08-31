extends GutTest


# 交易节点最小实现台账（2026-08-31）：
# - 一转小光蛊 50、 月蓝花瓣 3、 月光蛊 250、 野猪王牙 15、
#   玉皮蛊 400、 白猪力蛊 500、 二转白玉蛊进阶蛊方 1500
# - 二转白玉蛊进阶 玉皮蛊 + 白猪力蛊 + 野猪王牙 + 50 元石 → 二转白玉蛊


const ResolverScript = preload("res://scripts/domain/resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _state_with_stone(amount: int) -> RunState:
	var state := RunState.new_run(101)
	state.stone = amount
	# Shop tier/price 公式以 state.current_node_layer=0 → layer 1 价格 0%，
	# 不签合约、notoriety=0，shop_visits=0：原价通过。
	return state


func _seed_gu(state: RunState, def_id: String, instance_id: String) -> RunState:
	var instances: Dictionary = state.gu_instances.duplicate(true)
	var aperture: Dictionary = state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	instances[instance_id] = {"instance_id": instance_id, "definition_id": def_id, "state": "refined"}
	stored.append(instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var next := state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "test_seed_gu",
		"before": {"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		"after": {"gu_instances": instances, "cave_aperture": aperture},
		"reason": "trade_test_fixture",
		"source": "test_trade_node_minimum",
		"targets": [],
	})
	next.gu_instances = instances
	next.cave_aperture = aperture
	next.sync_legacy_gu_projections()
	return next


func _refine_with_instances(state: RunState, recipe_id: String, instance_ids: Array) -> Dictionary:
	var cmd := {"type": "refine_gu", "recipe_id": recipe_id, "input_instance_ids": instance_ids.duplicate()}
	return ResolverScript.apply(state, cmd, catalog)


func test_shop_offers_match_user_price_table() -> void:
	var by_id: Dictionary = catalog.get("shop_offer_by_id", {})
	var expected := {
		"purchase_small_light_gu": 50,
		"purchase_moon_blue_petal": 3,
		"purchase_moonlight_gu_250": 250,
		"purchase_boar_king_tusk": 15,
		"purchase_jade_skin_gu": 400,
		"purchase_white_boar_strength_gu": 500,
		"purchase_white_jade_recipe": 1500,
	}
	for offer_id in expected:
		assert_true(by_id.has(offer_id), "offer %s 存在" % offer_id)
		assert_eq(int((by_id[offer_id] as Dictionary).get("stone_cost", -1)), int(expected[offer_id]),
			"offer %s 价 = %d" % [offer_id, expected[offer_id]])


func test_purchase_small_light_gu_deducts_stone_and_adds_gu() -> void:
	var state := _state_with_stone(50)
	var out := ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": "purchase_small_light_gu"}, catalog)
	assert_true(bool(out["result"].get("ok", false)), "购买 OK")
	assert_eq(int(out["state"].stone), 0, "扣 50 元石")
	assert_true(out["state"].refined_gu_ids.has("small_light_gu"), "入 refined_gu_ids")


func test_purchase_moon_blue_petal_credits_materials() -> void:
	var state := _state_with_stone(3)
	var out := ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": "purchase_moon_blue_petal"}, catalog)
	assert_true(bool(out["result"].get("ok", false)), "购买 OK")
	assert_eq(int(out["state"].materials.get("moon_blue_petal", 0)), 1, "材料入袋 1")


func test_purchase_moonlight_gu_deducts_stone() -> void:
	var state := _state_with_stone(250)
	var out := ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": "purchase_moonlight_gu_250"}, catalog)
	assert_true(bool(out["result"].get("ok", false)), "购买 OK")
	assert_eq(int(out["state"].stone), 0, "扣 250")


func test_purchase_boar_king_tusk_credits_materials() -> void:
	var state := _state_with_stone(15)
	var out := ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": "purchase_boar_king_tusk"}, catalog)
	assert_true(bool(out["result"].get("ok", false)), "购买 OK")
	assert_eq(int(out["state"].materials.get("boar_king_tusk", 0)), 1, "材料入袋 1")


func test_purchase_jade_skin_and_white_boar_succeeds() -> void:
	var state := _state_with_stone(1000)
	var out1 := ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": "purchase_jade_skin_gu"}, catalog)
	assert_true(bool(out1["result"].get("ok", false)), "玉皮蛊购买 OK")
	assert_eq(int(out1["state"].stone), 600, "扣 400 → 剩 600")
	var out2 := ResolverScript.apply(out1["state"], {"type": "shop_purchase", "offer_id": "purchase_white_boar_strength_gu"}, catalog)
	assert_true(bool(out2["result"].get("ok", false)), "白猪力蛊购买 OK（剩余 600 元石也够）")
	assert_true(out2["state"].refined_gu_ids.has("jade_skin_gu"))
	assert_true(out2["state"].refined_gu_ids.has("white_boar_strength_gu"))


func test_purchase_white_jade_recipe_unlocks_knowledge() -> void:
	var state := _state_with_stone(1500)
	var out := ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": "purchase_white_jade_recipe"}, catalog)
	assert_true(bool(out["result"].get("ok", false)), "蛊方购买 OK")
	assert_eq(int(out["state"].stone), 0, "扣 1500 → 剩 0")
	assert_true(out["state"].global_codex_ids.has("white_jade_advance"),
		"white_jade_advance 写入 global_codex_ids")
	# 重复购买应被拒且不扣款
	var replay := ResolverScript.apply(out["state"], {"type": "shop_purchase", "offer_id": "purchase_white_jade_recipe"}, catalog)
	assert_false(bool(replay["result"].get("ok", false)), "重复购买拒")
	assert_eq(int(replay["state"].stone), 0, "未扣款")


func test_refine_white_jade_requires_inputs_and_stone() -> void:
	var state := _state_with_stone(50)
	state = _seed_gu(state, "jade_skin_gu", "gu_test_jade_001")
	state = _seed_gu(state, "white_boar_strength_gu", "gu_test_white_001")
	# 白玉基础蛊方：玉皮蛊+白猪力蛊+50 元石（默认解锁）；野猪王牙进阶方另需魂魄并发 ≥3。
	var out := _refine_with_instances(state, "white_jade_basic", ["gu_test_jade_001", "gu_test_white_001"])
	assert_true(bool(out["result"].get("ok", false)), "炼蛊 OK")
	assert_true(out["state"].refined_gu_ids.has("white_jade_gu"), "二转白玉蛊入 refined_gu_ids")
	assert_eq(int(out["state"].stone), 0, "扣 50 元石")
	# 输出蛊被实例化
	var found := false
	for inst in (out["state"] as RunState).gu_instances.values():
		if str(inst.get("definition_id", "")) == "white_jade_gu":
			found = true
			break
	assert_true(found, "实例化新蛊")


func test_refine_rejects_when_inputs_missing() -> void:
	var state := _state_with_stone(50)
	state.materials["boar_king_tusk"] = 0
	state = _seed_gu(state, "jade_skin_gu", "gu_test_jade_002")
	# 缺白猪力蛊 + 缺材料
	var out := _refine_with_instances(state, "white_jade_advance", ["gu_test_jade_002"])
	assert_false(bool(out["result"].get("ok", false)), "资源不足应被拒")
	assert_eq(int(out["state"].stone), 50, "未扣款")
	assert_eq(int(out["state"].materials.get("boar_king_tusk", 0)), 0, "未扣材料")