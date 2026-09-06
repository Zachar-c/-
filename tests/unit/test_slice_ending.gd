extends GutTest

## S6 L1 收官切片验收：击败 pacing.ending_after_stage 指定层的 Boss 即全局
## 收官（outcome=success → won），状态转 terminal，视图切入 Ending。

const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")


func test_layer_one_boss_victory_closes_the_slice() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(20260914, "light", [], ["slay_gu_ten"])
	# 直接把当前节点置为路由上的 L1 Boss 站点实例（地图寻路非本单验收点），
	# 验证收官钩子：victory + layer_boss=1 + pacing.ending_after_stage=one → Ending。
	for route_node in controller.route:
		if str(route_node.get("template_id", "")) == "layer_boss_stand_1":
			controller.current_node = route_node.duplicate(true)
			break
	assert_false(controller.current_node.is_empty(), "layer-1 boss stand must be on the slice route")
	controller.state.current_node_id = str(controller.current_node.get("id", ""))
	controller.state.current_node_template_id = "layer_boss_stand_1"
	controller._start_battle()
	assert_eq(controller.current_view_name(), "Battle", "boss contact must start the battle")
	var slay_id := ""
	for instance_id in controller.state.gu_instances:
		if str(controller.state.gu_instances[instance_id].definition_id) == "test_slay_gu":
			slay_id = str(instance_id)
	assert_false(slay_id.is_empty(), "slay gu from the opening buff must be playable here")
	controller.submit_command({"type": "use_gu", "instance_id": slay_id})
	assert_eq(controller.current_view_name(), "Ending", "victory over the final configured boss must enter settlement")
	assert_eq(str(controller.state.terminal_state), "success", "run must be terminal after slice closure")


func test_pacing_key_is_the_slice_contract() -> void:
	# 直接读数据表断言切片契约：收官层 = 第一层。
	var raw: Dictionary = _read_pacing()
	assert_eq(str(raw.get("ending_after_stage", "")), "one", "slice ends after layer one")


func _read_pacing() -> Dictionary:
	var file := FileAccess.open("res://data/pacing.json", FileAccess.READ)
	assert_false(file == null, "pacing.json readable")
	return JSON.parse_string(file.get_as_text())
