extends GutTest


# 黑市分层上架（2026-08-29 裁定）：货阶高于当前大层的货不露面、不可购买；
# 层越深价格乘数越高——价格与稀有度同步上升。

const RunStateScript = preload("res://scripts/domain/run_state.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ShopRulesScript = preload("res://scripts/domain/shop_command_rules.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _state_at_layer(layer: int, stone: int) -> RunState:
	var run = RunStateScript.new_run(101)
	run.stone = stone
	run.current_node_layer = layer
	return run


func test_high_tier_offer_is_locked_on_shallow_layers() -> void:
	var run := _state_at_layer(1, 99)
	var result := ResolverScript.apply(run, {"type": "shop_purchase", "offer_id": "purchase_moonlight"}, catalog)
	assert_false(result["result"]["ok"], "tier-3 goods are locked on layer 1")
	assert_eq(str(result["result"]["reason"]), "shop_tier_locked")


func test_tiered_offer_unlocks_on_its_layer_with_layered_price() -> void:
	var run := _state_at_layer(3, 99)
	# 「解锁」与「层价」分两件事断言 —— 保底那件未必是 purchase 类。
	# ① 解锁：层 3 的可选池必须已经含 tier-3 货。
	var pool := ShopRulesScript.shop_goods_pool(run, catalog)
	var unlocked := false
	for offer_id in pool:
		if int((catalog["shop_offer_by_id"][offer_id] as Dictionary).get("tier", 1)) == 3:
			unlocked = true
	assert_true(unlocked, "层 3 的可选池必须含 tier-3 货（货阶解锁）")

	# ② 层价：从**本店货架**上取一件 purchase 货，独立重算层价后购买。
	var target := ""
	for offer_id in ResolverScript.shop_stock(run, catalog):
		if str((catalog["shop_offer_by_id"][offer_id] as Dictionary).get("kind", "")) == "purchase":
			target = offer_id
			break
	assert_ne(target, "", "层 3 货架应含 purchase 货")
	if target.is_empty():
		return
	var base := int((catalog["shop_offer_by_id"][target] as Dictionary).get("stone_cost", 0))
	var pct := int((catalog["pacing"]["layers"]["3"] as Dictionary).get("shop_price_pct", 0))
	var expected := base + int(base * pct / 100.0)
	var result := ResolverScript.apply(run, {"type": "shop_purchase", "offer_id": target}, catalog)
	assert_true(result["result"]["ok"], str(result["result"]))
	assert_eq(int(result["state"].stone), 99 - expected,
			"层价乘数必须生效（%s 基价 %d → 层价 %d）" % [target, base, expected])


func test_shop_snapshot_only_lists_offers_within_the_layer_tier_cap() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.catalog = catalog
	controller.state = _state_at_layer(1, 50)
	var snapshot: Dictionary = RunSnapshotBuilderScript.shop(controller)
	var ids: Array[String] = []
	for offer in snapshot.get("offers", []):
		ids.append(str(offer.get("id", "")))
	assert_false(ids.has("purchase_moonlight"), "tier-3 goods stay off the layer-1 shelf")
	# 断言「层 1 仍有 tier-1 的货」而非「某一件具体货在架上」——货架是种子化
	# 洗牌出来的，货池扩容后具体哪件上货架会变，硬钉 id 是脆弱断言。
	var has_tier1_purchase := false
	for offer_id in ids:
		var offer: Dictionary = catalog["shop_offer_by_id"].get(offer_id, {})
		if str(offer.get("kind", "")) == "purchase" and int(offer.get("tier", 1)) == 1:
			has_tier1_purchase = true
	assert_true(has_tier1_purchase, "tier-1 goods remain on the shelf；实际=%s" % str(ids))

	controller.state = _state_at_layer(3, 50)
	var deep: Dictionary = RunSnapshotBuilderScript.shop(controller)
	var deep_ids: Array[String] = []
	for offer in deep.get("offers", []):
		deep_ids.append(str(offer.get("id", "")))
	# E7（2026-09-10）：层 3 上架的货必须全部出现在列表里（不多不少），超阶货仍不露面。
	for offer_id in ResolverScript.shop_stock(controller.state, catalog):
		assert_true(deep_ids.has(offer_id), "架上的货必须可见：%s" % offer_id)
	assert_false(deep_ids.has("purchase_moon_glow"), "tier-5 goods stay off the layer-3 shelf")
