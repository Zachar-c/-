extends GutTest

# EncounterSessionResolver 会话门禁守卫（发布阻断修复 1）：
# extreme_hostile 只应在战斗未决时阻止离场；节点内战斗胜利进入 post_battle
# 阶段后必须允许 leave_node 并回到地图（软锁修复）。


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _state(seed_value: int = 101) -> RunState:
	return RunState.new_run(seed_value)


func test_post_battle_extreme_hostile_allows_leave() -> void:
	# 单元层：会话已进入 post_battle（战斗已决）时，extreme_hostile 不得再
	# 以 feud_no_escape 卡死离场。
	var state := _state()
	state.current_node_id = "ridge_black_market"
	var begun: Dictionary = EncounterSessionResolverScript.begin(state, {"id": "ridge_black_market", "type": "shop"}, catalog)
	var session: Dictionary = begun["session"].duplicate(true)
	session["stance"] = "extreme_hostile"
	session["flags"]["reputation_extreme"] = true
	session["phase"] = "post_battle"
	var left: Dictionary = EncounterSessionResolverScript.apply(
		state, session, {"type": "leave_node"}, catalog, {"id": "ridge_black_market", "type": "shop"})
	assert_true(bool(left["result"].get("ok", false)), "post_battle leave must succeed, got %s" % str(left["result"]))
	assert_eq(str(left["session"].get("completion_reason", "")), "player_left")


func test_active_extreme_hostile_still_blocks_leave() -> void:
	# 反例守住原语义：战斗未决（phase=active）时离场仍被拒。
	var state := _state()
	var begun: Dictionary = EncounterSessionResolverScript.begin(state, {"id": "ridge_caravan", "type": "caravan"}, catalog)
	var session: Dictionary = begun["session"].duplicate(true)
	session["stance"] = "extreme_hostile"
	session["flags"]["reputation_extreme"] = true
	var left: Dictionary = EncounterSessionResolverScript.apply(
		state, session, {"type": "leave_node"}, catalog, {"id": "ridge_caravan", "type": "caravan"})
	assert_false(bool(left["result"].get("ok", true)))
	assert_eq(str(left["result"].get("reason", "")), "feud_no_escape")


func test_extreme_hostile_battle_victory_leaves_to_map() -> void:
	# 真实命令链：extreme_hostile 遭遇 → node.fight → 敌先手 → 胜利 →
	# post_battle 阶段 → leave_encounter → 回到 Map（软锁不复现）。
	var controller := RunControllerScript.new()
	controller.catalog = catalog
	controller.start_new_run(101)
	var traveled: Dictionary = controller.submit_command({"type": "travel", "node_id": "neutral_wanderer"})
	assert_true(bool(traveled.get("ok", false)), "travel must reach the neutral wanderer")
	# 强行进入极端敌对姿态（领域姿势在 begin 里按声望掷出，这里注入等价状态）。
	controller.current_session["stance"] = "extreme_hostile"
	controller.current_session["flags"]["reputation_extreme"] = true
	controller.state.encounter_session["stance"] = "extreme_hostile"
	controller.state.encounter_session["flags"]["reputation_extreme"] = true
	var fight: Dictionary = controller.submit_command({
		"type": "action_card",
		"action_id": "node.fight",
		"state_version": controller.state.event_log.size(),
		"node_id": str(controller.state.current_node_id),
		"session_node_id": str(controller.state.current_node_id),
	})
	var fight_payload: Dictionary = fight.get("result", fight) as Dictionary
	assert_true(controller.current_view_name() == "Battle", "fight must open the battle, got view=%s payload=%s" % [controller.current_view_name(), str(fight_payload)])
	# 流程夹具：敌行 HP 压到 1，任一伤害一击致胜（与既有 victory 链路测试同款）。
	for enemy_row_value in controller.current_battle.get("enemies", []):
		var enemy_row: Dictionary = enemy_row_value
		enemy_row["hp"] = 1
	controller.current_battle["enemy_hp"] = 1
	var result: Dictionary = controller.submit_command({
		"type": "basic_attack",
		"state_version": controller.state.event_log.size(),
	})
	assert_eq(str(result.get("result", "")), "victory", "battle must end in victory")
	assert_eq(str(controller.current_session.get("phase", "")), "post_battle")
	# ★ 软锁断言：极端敌对 + 战后阶段必须能离场回地图。
	var left: Dictionary = controller.submit_command({"type": "leave_encounter"})
	var payload: Dictionary = left.get("result", left) as Dictionary
	assert_true(
		bool(payload.get("ok", false)),
		"post-battle leave must succeed, got %s (current=%s session_node=%s phase=%s)" % [
			str(payload.get("reason", payload)),
			str(controller.state.current_node_id),
			str(controller.current_session.get("node_id", "")),
			str(controller.current_session.get("phase", "")),
		]
	)
	assert_eq(controller.current_view_name(), "Map")
	controller.free()
