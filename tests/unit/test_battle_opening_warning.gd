extends GutTest

# 发布阻断修复 2：低血进入敌方先手战的可见性。
# 死亡可预见红线（AGENTS）：先手意图本会在入帧时无条件结算、低血玩家瞬间
# 暴毙且无从反应。修复后：致死开场不自动结算，先亮意图+致命警告并把敌方
# 先手延后到玩家首个回合结束（确定性序列不变）；玩家未自救时仍由常规
# 结算致死，final_blow 必写、统一走 DeathReport。


const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const DeathReportBuilderScript = preload("res://scripts/domain/death_report_builder.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


func _controller() -> RunController:
	var controller := RunControllerScript.new()
	controller.catalog = ContentCatalogScript.load_all()
	add_child(controller)
	controller.start_new_run(2026)
	return controller


func _open_enemy_first(controller: RunController, hp: int) -> void:
	# 真实遭遇链的等价入口：战斗节点 + 极端敌对姿态（敌先手）。
	controller.current_node = {"id": "beast_swarm_pass", "type": "combat", "enemy_kind": "ridge_hound"}
	controller.current_session = {
		"node_id": "beast_swarm_pass", "kind": "combat", "phase": "active",
		"completed": false, "flags": {"reputation_extreme": true}, "stance": "extreme_hostile",
	}
	controller.state.current_node_id = "beast_swarm_pass"
	controller.state.health = hp
	controller.state.max_health = 8
	controller._start_battle()


func test_lethal_opening_defers_first_strike_and_warns() -> void:
	var controller := _controller()
	_open_enemy_first(controller, 2)
	assert_eq(controller.current_view_name(), "Battle", "battle screen must open despite the lethal opening")
	assert_eq(int(controller.state.health), 2, "lethal opening must NOT auto-resolve (no invisible instant death)")
	assert_true((controller.current_battle.get("flags", []) as Array).has("opening_lethal"), "opening_lethal flag must be set")
	var warned := false
	for log_entry in controller.current_battle.get("log", []):
		if str(log_entry.get("id", "")) == "opening_lethal_warning":
			warned = true
	assert_true(warned, "battle log must carry the opening_lethal_warning")
	assert_gt(int(controller.current_battle.get("visible_intent", {}).get("damage", 0)), 0, "intent must be visible with its damage")
	controller.free()


func test_unanswered_lethal_opening_dies_with_final_blow_and_report() -> void:
	var controller := _controller()
	_open_enemy_first(controller, 2)
	# 玩家未自救（直接结束回合）：敌方正常结算，先手意图命中致死。
	var turn: Dictionary = controller.submit_command({
		"type": "end_turn",
		"state_version": controller.state.event_log.size(),
		"expected_phase": "player",
	})
	assert_eq(str(turn.get("result", "")), "death", "unanswered lethal opening must resolve to death")
	assert_eq(int(controller.state.health), 0)
	var final_blow: Dictionary = controller.current_battle.get("final_blow", {})
	assert_eq(str(final_blow.get("id", "")), "pounce", "final_blow must record the killing intent")
	assert_gt(int(final_blow.get("damage", 0)), 0)
	var report: Dictionary = DeathReportBuilderScript.build(controller.current_battle, controller.state)
	assert_eq(str(report.get("final_blow", "")), "pounce", "unified DeathReport must carry final_blow")
	controller.free()


func test_nonlethal_enemy_first_keeps_regular_pre_turn() -> void:
	var controller := _controller()
	_open_enemy_first(controller, 6)
	assert_eq(int(controller.state.health), 4, "non-lethal opening keeps the automatic enemy first strike (2 dmg)")
	assert_false((controller.current_battle.get("flags", []) as Array).has("opening_lethal"), "no deferral when not lethal")
	assert_eq(controller.current_view_name(), "Battle")
	controller.free()


func test_multi_enemy_lethal_opening_sums_all_intents() -> void:
	# 围攻节点：两名敌人先手意图 2+2=4，低血 2 也须触发致死延后（单看
	# visible_intent=2 会漏判 → 入帧即死）。
	var controller := _controller()
	controller.current_node = {"id": "beast_swarm_pass", "type": "combat", "enemy_kinds": ["ridge_hound", "ridge_hound"]}
	controller.current_session = {
		"node_id": "beast_swarm_pass", "kind": "combat", "phase": "active",
		"completed": false, "flags": {"reputation_extreme": true}, "stance": "extreme_hostile",
	}
	controller.state.current_node_id = "beast_swarm_pass"
	controller.state.health = 2
	controller.state.max_health = 8
	controller._start_battle()
	assert_eq(int(controller.state.health), 2, "multi-enemy lethal opening must not auto-resolve")
	assert_true((controller.current_battle.get("flags", []) as Array).has("opening_lethal"), "summed opening must defer")
	var warned := false
	for log_entry in controller.current_battle.get("log", []):
		if str(log_entry.get("id", "")) == "opening_lethal_warning":
			assert_eq(int(log_entry.get("damage", 0)), 4, "warning must show the summed damage")
			warned = true
	assert_true(warned, "warning log must exist")
	controller.free()