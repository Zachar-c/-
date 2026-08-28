extends GutTest


# 黑市分层上架（2026-08-29 裁定）：货阶高于当前大层的货不露面、不可购买；
# 层越深价格乘数越高——价格与稀有度同步上升。

const RunStateScript = preload("res://scripts/domain/run_state.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")

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
	var result := ResolverScript.apply(run, {"type": "shop_purchase", "offer_id": "purchase_moonlight"}, catalog)
	assert_true(result["result"]["ok"], str(result["result"]))
	# 层价：基价 6 → price_for（无恶名=6）→ L3 +20% → 8（7.2 取整）。
	assert_eq(int(result["state"].stone), 99 - 7, "the layer price multiplier must apply (6 -> price_for 6 -> +20% int = 7)")


func test_shop_snapshot_only_lists_offers_within_the_layer_tier_cap() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.catalog = catalog
	controller.state = _state_at_layer(1, 50)
	var snapshot: Dictionary = RunSnapshotBuilderScript.shop(controller)
	var ids: Array[String] = []
	for offer in snapshot.get("offers", []):
		ids.append(str(offer.get("id", "")))
	assert_false(ids.has("purchase_moonlight"), "tier-3 goods stay off the layer-1 shelf")
	assert_true(ids.has("purchase_stone_shell"), "tier-1 goods remain on the shelf")

	controller.state = _state_at_layer(3, 50)
	var deep: Dictionary = RunSnapshotBuilderScript.shop(controller)
	var deep_ids: Array[String] = []
	for offer in deep.get("offers", []):
		deep_ids.append(str(offer.get("id", "")))
	assert_true(deep_ids.has("purchase_moonlight"), "tier-3 goods surface on layer 3")
	assert_false(deep_ids.has("purchase_moon_glow"), "tier-5 goods stay off the layer-3 shelf")
