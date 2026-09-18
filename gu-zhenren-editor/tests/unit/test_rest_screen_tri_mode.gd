extends GutTest
## E4 表现层（规格 §4 路由 + §7 E4 验收：三选一 UI / 无死按钮）。
## - travel 分发：rest/refinement/cultivation 三个模板统一进 Rest 屏。
## - 休息屏渲染 mode_groups 的修炼/炼蛊两组卡片，「执行」经 mode_action 下发。
## - 炼蛊子屏：经休息屏打开的 Refine「离开」返回休息屏；直连 Refine 语义不变。

const RunCommandBuilderScript = preload("res://scripts/presentation/run_command_builder.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const TscnMountHelperScript = preload("res://tests/unit/tscn_mount_helper.gd")
const REST_SCREEN_TSCN := "res://scenes/ui/screens/rest_screen.tscn"

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


# ---- 路由：三个休息类模板统一 Rest 屏 ----

## 单支两节点路线：caravan(交易) → 单个休息类模板（路线 commit 分支后兄弟
## 不可达，故每个模板一条独立路线）。target ∈ refinement_hollow / cultivation_spring。
func _rest_class_route(target: String) -> Array[Dictionary]:
	var by_id := {}
	for node_value in catalog.get("nodes_data", {}).get("nodes", []):
		by_id[str((node_value as Dictionary).get("id", ""))] = node_value
	var order := ["ridge_caravan", target]
	var route: Array[Dictionary] = []
	for index in order.size():
		var node: Dictionary = (by_id[order[index]] as Dictionary).duplicate(true)
		node["start"] = index == 0
		node["visible"] = true
		node["template_id"] = order[index]
		node["layer"] = 1
		node["row"] = index
		node["next_ids"] = [] if index == order.size() - 1 else [target]
		route.append(node)
	return route


func _boot_at_caravan() -> RunController:
	# 引导链与 first_slice 同款：boot 后先 travel 起点车队并离开，
	# 使目标休息类节点进入可达集（路线 commit 分支语义）。
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(101)
	return controller


func _travel_to_target(target: String) -> RunController:
	var controller := _boot_at_caravan()
	controller.route = _rest_class_route(target)
	controller.submit_command({"type": "travel", "node_id": "ridge_caravan"})
	controller.submit_command({"type": "leave_encounter"})
	assert_eq(controller.current_view_name(), "Map")
	controller.submit_command({"type": "travel", "node_id": target})
	return controller


func test_travel_dispatch_sends_refinement_to_rest_screen() -> void:
	var controller := _travel_to_target("refinement_hollow")
	assert_eq(controller.current_view_name(), "Rest",
			"refinement template must land on the Rest screen (E4a unified dispatch)")
	# 探访未消费，离开被领域拒绝；skip 后放行（三选一门禁与休整节点同口径）。
	var blocked: Dictionary = controller.submit_command({"type": "leave_encounter"})
	assert_false(bool((blocked.get("result", blocked) as Dictionary).get("ok", true)),
			"unconsumed refinement visit must not allow leave")
	controller.submit_command({"type": "rest", "mode": "skip"})
	controller.submit_command({"type": "leave_encounter"})
	assert_eq(controller.current_view_name(), "Map")
	controller.free()


func test_travel_dispatch_sends_cultivation_to_rest_screen() -> void:
	var controller := _travel_to_target("cultivation_spring")
	assert_eq(controller.current_view_name(), "Rest",
			"cultivation template must land on the Rest screen (E4a unified dispatch)")
	controller.free()


# ---- 休息屏：mode_groups 修炼/炼蛊两组卡片 + mode_action 下发 ----

func test_rest_screen_renders_cultivation_and_refine_group_cards() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	state.cultivation = 1
	state.stone = 12
	state.cave_aperture["stored_gu_instance_ids"] = ["gu_001", "gu_002"]
	state.gu_instances = {
		"gu_001": {"definition_id": "small_light_gu", "state": "refined"},
		"gu_002": {"definition_id": "light_probe", "state": "refined"},
	}
	var stub := _StubController.new()
	stub.state = state
	stub.current_node = {"id": "rest_shrine", "type": "rest"}
	stub.catalog = catalog
	var snapshot: Dictionary = RunSnapshotBuilderScript.rest(stub)
	var fired: Array[String] = []
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child(host)
	autofree(host)
	host.add_child(TscnMountHelperScript.instantiate(REST_SCREEN_TSCN, snapshot,
			{"mode_action": func(id): fired.append(str(id))}))
	for _frame in 3:
		await get_tree().process_frame
	assert_true(TscnMountHelperScript.has_text(host, "调息冥想"), "修炼 group must render meditate card")
	assert_true(TscnMountHelperScript.has_text(host, "冲击二转"), "修炼 group must render cultivate card")
	assert_true(TscnMountHelperScript.has_text(host, "炼蛊合药"), "炼蛊 group must render refine card")
	assert_true(TscnMountHelperScript.has_text(host, "自由配对"), "炼蛊 group must render free_pair card")
	# 无死按钮：前两张「执行」依次对应 meditate / cultivate，按下即经 mode_action 下发。
	var exec_buttons: Array[Button] = []
	_collect_exec_buttons(host, exec_buttons)
	assert_gte(exec_buttons.size(), 4, "four mode cards must expose an execute button each")
	exec_buttons[0].pressed.emit()
	exec_buttons[1].pressed.emit()
	assert_eq(fired, ["meditate", "cultivate"] as Array[String],
			"mode card execute buttons must dispatch mode_action with the card id")


func test_rest_screen_hides_mode_groups_without_mode_groups_payload() -> void:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child(host)
	autofree(host)
	host.add_child(TscnMountHelperScript.instantiate(REST_SCREEN_TSCN, {
		"resources": {}, "contracts": [], "anomalies": [], "death_lines": {},
		"choices": [{"id": "heal", "label": "调息回血", "detail": "", "cost": "", "disabled": false, "reason": "", "curse_warning": false}],
	}, {}))
	for _frame in 3:
		await get_tree().process_frame
	assert_false(TscnMountHelperScript.has_text(host, "调息冥想"),
			"mode groups must stay hidden when the snapshot carries no mode_groups")


# ---- 炼蛊子屏：离开语义 + 通道预选 ----

func test_refine_subview_leave_returns_to_rest_and_preselects_channel() -> void:
	var controller := _travel_to_target("refinement_hollow")
	assert_eq(controller.current_view_name(), "Rest")
	# 休息屏「炼蛊」卡 → 子屏（自由配对通道预选）。
	controller.open_refine_subview("free_pair")
	assert_eq(controller.current_view_name(), "Refine")
	var snapshot: Dictionary = controller._snapshot_for("Refine")
	assert_true(bool(snapshot.get("from_rest", false)), "subview snapshot must flag from_rest")
	assert_eq(str(snapshot.get("initial_channel", "")), "free_pair")
	# 子屏「离开」→ 回休息屏（不发 leave_encounter）。
	var commands: Dictionary = RunCommandBuilderScript.for_screen("Refine", controller)
	commands["leave"].call()
	assert_eq(controller.current_view_name(), "Rest",
			"subview leave must return to the rest tri-choice, not end the visit")
	# 路由直连（非子屏）语境：离开直接提交 leave_encounter——探访未消费，
	# 会被领域 rest_choice_required 拒绝（拒绝本身就是「走到了领域」的证据）。
	controller.open_refine_subview()
	controller._refine_from_rest = false
	var flags_before: Dictionary = controller.state.node_flags.duplicate()
	commands = RunCommandBuilderScript.for_screen("Refine", controller)
	commands["leave"].call()
	assert_eq(controller.current_view_name(), "Refine",
			"non-subview leave must hit the domain (refused while visit unconsumed)")
	assert_eq(str(controller.last_result.get("reason", "")), "rest_choice_required")
	assert_eq(controller.state.node_flags, flags_before, "rejected leave must not mutate flags")
	controller.free()


# ---- 夹具 ----

func _collect_exec_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button and str((node as Button).text) == "执行":
		out.append(node as Button)
	for child in node.get_children():
		_collect_exec_buttons(child, out)


class _StubController:
	extends RefCounted
	var state: RunState
	var current_node: Dictionary
	var catalog: Dictionary
	var current_session: Dictionary = {}
	var current_battle: Dictionary = {}
