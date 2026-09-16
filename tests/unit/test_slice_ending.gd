extends GutTest

## S6 收官切片验收 —— **2026-09-15 用户裁定后改写**。
##
## 旧契约：击败 `pacing.ending_after_stage` 指定层的 Boss 即**全局强制收官**。
## 新契约：该键改为「**收官可选起始层**」——击败该层关底后开放 `close_run`，
## 玩家可继续深入（Run 保持非终局），也可随时主动收官。
##
## 为什么改：旧强制收官让生产配置（`ending_after_stage == "one"`）下单局只有
## 约 3–12 场战斗就终结（实测 seed 101：62 步 / 3 场胜仗 / 最高 2 转），
## 转数与蛊阶成长链（1→5）永远走不完，局内没有成长空间。

const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")
const SocialCommandRules = preload("res://scripts/domain/social_command_rules.gd")


func _boss_controller() -> RunController:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(20260914, "light", [], ["slay_gu_ten"])
	# 直接把当前节点置为路由上的 L1 Boss 站点实例（地图寻路非本单验收点）。
	for route_node in controller.route:
		if str(route_node.get("template_id", "")) == "layer_boss_stand_1":
			controller.current_node = route_node.duplicate(true)
			break
	assert_false(controller.current_node.is_empty(), "layer-1 boss stand must be on the slice route")
	controller.state.current_node_id = str(controller.current_node.get("id", ""))
	controller.state.current_node_template_id = "layer_boss_stand_1"
	controller._start_battle()
	assert_eq(controller.current_view_name(), "Battle", "boss contact must start the battle")
	return controller


func _slay_instance_id(controller) -> String:
	for instance_id in controller.state.gu_instances:
		if str(controller.state.gu_instances[instance_id].definition_id) == "test_slay_gu":
			return str(instance_id)
	return ""


## 核心行为变更：L1 关底胜利**不再**强制收官。
func test_layer_one_boss_victory_no_longer_force_ends() -> void:
	var controller := _boss_controller()
	var slay_id := _slay_instance_id(controller)
	assert_false(slay_id.is_empty(), "slay gu from the opening buff must be playable here")
	controller.submit_command({"type": "use_gu", "instance_id": slay_id})
	assert_ne(controller.current_view_name(), "Ending", "L1 关底胜利不得直接跳结算")
	assert_eq(str(controller.state.terminal_state), "active", "Run 必须保持非终局，玩家可继续")
	assert_true(SocialCommandRules.closure_available(controller.state, controller.catalog),
			"关底胜利后收官转为可选")
	assert_eq(str(controller.state.node_flags.get("boss_defeated_L1", "")), "true",
			"关底击败必须留痕（收官判据来源）")


## 玩家主动收官 = 正常结局路径。
func test_player_can_close_the_run_voluntarily() -> void:
	var controller := _boss_controller()
	var slay_id := _slay_instance_id(controller)
	controller.submit_command({"type": "use_gu", "instance_id": slay_id})
	controller.submit_command({"type": "close_run"})
	assert_eq(controller.current_view_name(), "Ending", "主动收官必须进入结算页")
	assert_eq(str(controller.state.terminal_state), "success", "收官后 Run 转终局")
	assert_eq(str(controller.state.event_log[-1].get("action", "")), "close_run",
			"收官归因只能来自事件日志")


func test_pacing_key_is_the_closure_threshold_contract() -> void:
	# 直接读数据表断言契约：收官可选起始层 = 第一层（不再等于"必然收官层"）。
	var raw: Dictionary = _read_pacing()
	assert_eq(str(raw.get("ending_after_stage", "")), "one", "closure threshold is layer one")
	assert_true((raw.get("layers", {}) as Dictionary).has("2"),
			"更深层拓扑必须存在，否则「继续深入」无处可去")


func _read_pacing() -> Dictionary:
	var file := FileAccess.open("res://data/pacing.json", FileAccess.READ)
	assert_false(file == null, "pacing.json readable")
	return JSON.parse_string(file.get_as_text())
