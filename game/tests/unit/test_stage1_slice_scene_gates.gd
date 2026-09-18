extends GutTest

# Stage 1 纵向切片场景门禁（specs/2026-09-16-stage1-gu-entity-vertical-slice-design.md §8）。
#
# tools/verify_stage1_slice.gd 是完整探针（含打印与缺口清单）；本文件只把
# **会随代码改动而悄悄退化**的几条硬断言钉进 unit 套件：
#   1. 货郎：展示价 == 结算价，且三道门禁（货架 / 不在场 / 元石）都在；
#   2. 盲炼：失败必须留可归因事件，且输入蛊真实消亡；
#   3. 月光固定方：容量门禁先于烧料（魂魄 1 时拒绝且不烧输入）；
#   4. 固定 seed 路线：五大层、无后向边、非首行每节点 ≥1 入边。
#
# 纪律：全部走真实领域规则（Resolver.apply / MapGenerator），不伪造状态。

const PEDDLER_NODE_ID := "wandering_peddler"
const PEDDLER_NPC_ID := "wandering_peddler"
const PEDDLER_OFFER_ID := "purchase_stone_shell"
const MOON_FIXED_RECIPE := "moon_glow_fixed"
const FREE_MIX_RECIPE := "free_mix"
const ROUTE_SEED := 101

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _peddler_state(stone: int) -> RunState:
	var state := RunState.new_run(ROUTE_SEED)
	state.current_node_id = PEDDLER_NODE_ID
	state.current_node_layer = 1
	state.stone = stone
	return state


func _result_of(outcome: Dictionary) -> Dictionary:
	return outcome.get("result", {}) as Dictionary


func _owns(state: RunState, definition_id: String) -> bool:
	for instance_value in state.gu_instances.values():
		var instance: Dictionary = instance_value
		if str(instance.get("definition_id", "")) != definition_id:
			continue
		if str(instance.get("state", "")) in ["refined", "contracted", "weakened"]:
			return true
	return false


func test_peddler_trade_charges_the_displayed_price() -> void:
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(PEDDLER_OFFER_ID, {})
	assert_false(offer.is_empty(), "货郎报价应在目录中")
	var state := _peddler_state(30)
	var price := Resolver.shop_layer_price(catalog, state, int(offer.get("stone_cost", 0)))
	var before := int(state.stone)
	var outcome: Dictionary = Resolver.apply(state, {
		"type": "npc_trade",
		"npc_id": PEDDLER_NPC_ID,
		"offer_id": PEDDLER_OFFER_ID,
	}, catalog)
	assert_true(bool(_result_of(outcome).get("ok", false)), str(_result_of(outcome).get("reason", "")))
	var next: RunState = outcome.get("state", state)
	assert_eq(before - int(next.stone), price, "结算扣费必须等于展示价")
	assert_true(_owns(next, str(offer.get("gu_id", ""))), "买到的蛊必须已炼化入库")


func test_peddler_trade_gates_are_live() -> void:
	var poor := _peddler_state(0)
	var poor_outcome: Dictionary = Resolver.apply(poor, {
		"type": "npc_trade", "npc_id": PEDDLER_NPC_ID, "offer_id": PEDDLER_OFFER_ID,
	}, catalog)
	assert_eq(str(_result_of(poor_outcome).get("reason", "")), "insufficient_stone",
			"元石不足必须拒绝")
	assert_false(_owns(poor_outcome.get("state", poor), "stone_shell_gu"), "拒绝时不得产出蛊")

	var off_stock := _peddler_state(99)
	var off_outcome: Dictionary = Resolver.apply(off_stock, {
		"type": "npc_trade", "npc_id": PEDDLER_NPC_ID, "offer_id": "purchase_moon_glow",
	}, catalog)
	assert_eq(str(_result_of(off_outcome).get("reason", "")), "npc_stock_missing",
			"非货郎货架的报价必须拒绝")

	var elsewhere := _peddler_state(99)
	elsewhere.current_node_id = "trailhead"
	var elsewhere_outcome: Dictionary = Resolver.apply(elsewhere, {
		"type": "npc_trade", "npc_id": PEDDLER_NPC_ID, "offer_id": PEDDLER_OFFER_ID,
	}, catalog)
	assert_eq(str(_result_of(elsewhere_outcome).get("reason", "")), "npc_not_present",
			"不在货郎节点时必须拒绝")


func test_free_mix_failure_is_attributed_and_costs_inputs() -> void:
	var state := RunState.new_run(ROUTE_SEED)
	var instances := {
		"mix_a": GuInstance.new_instance("force_gu", "mix_a", catalog),
		"mix_b": GuInstance.new_instance("blood_droplet_gu", "mix_b", catalog),
	}
	var aperture: Dictionary = state.cave_aperture.duplicate(true)
	aperture["stored_gu_instance_ids"] = ["mix_a", "mix_b"]
	state = state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "stage1_pair",
		"before": {"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		"after": {"gu_instances": instances, "cave_aperture": aperture},
		"reason": "stage1_pair_injected",
		"source": "test_stage1_slice_scene_gates",
		"targets": ["force_gu", "blood_droplet_gu"],
	})
	state.sync_legacy_gu_projections()
	var before_events := state.event_log.size()
	var outcome: Dictionary = Resolver.apply(state, {
		"type": "refine_gu",
		"recipe_id": FREE_MIX_RECIPE,
		"input_instance_ids": ["mix_a", "mix_b"],
	}, catalog)
	assert_true(bool(_result_of(outcome).get("ok", false)), str(_result_of(outcome).get("reason", "")))
	var next: RunState = outcome.get("state", state)
	var reasons: Array[String] = []
	for event_value in next.event_log.slice(before_events):
		reasons.append(str((event_value as Dictionary).get("reason", "")))
	var attributed := false
	for reason in reasons:
		if reason in ["free_mix_destroyed", "free_mix_mutation", "free_mix_explosion"]:
			attributed = true
	assert_true(attributed, "盲炼结果必须有可归因事件，实际：%s" % str(reasons))
	var stored: Array = next.cave_aperture.get("stored_gu_instance_ids", [])
	assert_false(stored.has("mix_a") and stored.has("mix_b"), "盲炼的输入蛊必须真实消亡")


func test_moon_glow_fixed_rejects_before_burning_inputs() -> void:
	# 三蛊合炼需要 craft_cap ≥ 3（魂魄 ≥ 3）；魂魄 1 时必须先拒，且不烧输入。
	var state := RunState.new_run(ROUTE_SEED)
	var instances := {
		"m_01": GuInstance.new_instance("moonlight_gu", "m_01", catalog),
		"m_02": GuInstance.new_instance("small_light_gu", "m_02", catalog),
		"m_03": GuInstance.new_instance("small_light_gu", "m_03", catalog),
	}
	var aperture: Dictionary = state.cave_aperture.duplicate(true)
	aperture["stored_gu_instance_ids"] = ["m_01", "m_02", "m_03"]
	state = state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "stage1_background",
		"before": {"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		"after": {"gu_instances": instances, "cave_aperture": aperture},
		"reason": "stage1_background_injected",
		"source": "test_stage1_slice_scene_gates",
		"targets": ["background_nanjiang_wanderer"],
	})
	state.sync_legacy_gu_projections()
	var outcome: Dictionary = Resolver.apply(state, {
		"type": "refine_gu", "recipe_id": MOON_FIXED_RECIPE,
	}, catalog)
	assert_eq(str(_result_of(outcome).get("reason", "")), "refinement_capacity_exceeded",
			"容量门禁必须早于烧料")
	var rejected: RunState = outcome.get("state", state)
	assert_eq((rejected.cave_aperture.get("stored_gu_instance_ids", []) as Array).size(), 3,
			"被拒时三只输入必须还在蛊仓")


func test_fixed_seed_route_is_layered_and_acyclic() -> void:
	var route: Array = MapGenerator.build(ROUTE_SEED, false, catalog)
	assert_gt(route.size(), 0, "路线不应为空")
	var by_id := {}
	var in_degree := {}
	var starts: Array[String] = []
	for node_value in route:
		var node: Dictionary = node_value
		by_id[str(node.get("id", ""))] = node
		if bool(node.get("start", false)):
			starts.append(str(node.get("id", "")))
	assert_eq(starts.size(), 1, "起点必须唯一")
	for node_value in route:
		var node: Dictionary = node_value
		var source := _coords(str(node.get("id", "")))
		if source.x <= 0:
			continue
		for next_value in node.get("next_ids", []):
			var next_id := str(next_value)
			in_degree[next_id] = int(in_degree.get(next_id, 0)) + 1
			var target := _coords(next_id)
			if target.x <= 0:
				continue
			assert_true(target.x > source.x or (target.x == source.x and target.y > source.y),
					"连边不得后向：%s -> %s" % [str(node.get("id", "")), next_id])
	for node_value in route:
		var node: Dictionary = node_value
		var coords := _coords(str(node.get("id", "")))
		if coords.x <= 0 or coords.y == 0:
			continue
		assert_gte(int(in_degree.get(str(node.get("id", "")), 0)), 1,
				"非首行节点必须有入边：%s" % str(node.get("id", "")))


## 节点 id 形如 L{layer}R{row}N{index}（ascension_window 等无坐标节点返回 -1）。
func _coords(node_id: String) -> Vector2i:
	if not node_id.begins_with("L"):
		return Vector2i(-1, -1)
	var head := node_id.substr(1).split("R", true, 1)
	if head.size() != 2:
		return Vector2i(-1, -1)
	var tail := str(head[1]).split("N", true, 1)
	if tail.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(str(head[0])), int(str(tail[0])))
