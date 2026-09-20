extends GutTest


const DialogueManagerAdapterScript = preload("res://scripts/domain/dialogue_manager_adapter.gd")


func test_missing_template_uses_chinese_fallback_response() -> void:
	var gateway := MissingTemplateGateway.new()
	var result := gateway.respond({"intent": "trade"})
	assert_eq(result["text"], "管事追问你究竟想提出什么条件。")


func test_template_gateway_reuses_cached_templates_until_cache_is_cleared() -> void:
	TemplateDialogueGateway.clear_cache()
	var gateway := TemplateDialogueGateway.new()
	var first := gateway._load_templates()
	var second := gateway._load_templates()

	assert_same(first, second)
	first["test_cache_marker"] = true
	assert_true(second.has("test_cache_marker"))
	TemplateDialogueGateway.clear_cache()
	var reloaded := gateway._load_templates()
	assert_false(reloaded.has("test_cache_marker"))


func test_dialogue_branch_maps_to_existing_event_command() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	var command := adapter.command_for_branch("echo_cave.accept")

	assert_eq(command, {"type": "accept_event", "event_id": "echo_cave"})


func test_dialogue_leave_branch_maps_to_leave_node_command() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	var command := adapter.command_for_branch("echo_cave.leave")

	assert_eq(command, {"type": "leave_node"})


func test_dialogue_leave_branch_completes_the_encounter_session() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	var state := RunState.new_run(101)
	state.current_node_id = "echo_cave"
	var session := EncounterSessionResolver.start({"id": "echo_cave", "type": "event"})
	var before_size := state.event_log.size()
	var result := adapter.apply_branch(
		state,
		session,
		"event.echo_cave.leave",
		ContentCatalog.load_all(),
		{"id": "echo_cave", "type": "event"}
	)

	assert_true(result["ok"])
	assert_eq(result["command"], {"type": "leave_node"})
	assert_true(bool(result["session"].get("completed", false)))
	assert_false(str(result["feedback"]).is_empty())
	# leave 结算写入 leave 事件 + session 事件 + dialogue_branch 元事件。
	assert_eq(result["state"].event_log.size(), before_size + 3)
	assert_eq(result["state"].event_log.back()["action"], "dialogue_branch")


func test_unknown_dialogue_branch_returns_chinese_rejection_without_state_change() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	var state := RunState.new_run(101)
	var before_version := state.event_log.size()
	var result := adapter.apply_branch(state, {}, "echo_cave.unknown", ContentCatalog.load_all())

	assert_false(result["ok"])
	assert_eq(result["reason"], "unknown_dialogue_branch")
	assert_true(str(result["feedback"]).contains("无法理解"))
	assert_eq(result["state"], state)
	assert_eq(state.event_log.size(), before_version)


func test_event_dialogue_branch_uses_resolver_and_returns_visible_feedback() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	var state := RunState.new_run(101)
	state.current_node_id = "echo_cave"
	var session := EncounterSessionResolver.start({"id": "echo_cave", "type": "event"})
	var before_health := state.health
	var result := adapter.apply_branch(
		state,
		session,
		"event.echo_cave.accept",
		ContentCatalog.load_all(),
		{"id": "echo_cave", "type": "event"}
	)

	assert_true(result["ok"])
	assert_eq(result["command"], {"type": "accept_event", "event_id": "echo_cave"})
	assert_lt(result["state"].health, before_health)
	assert_false(str(result["feedback"]).is_empty())
	# 结算链：encounter_session 事件 + dialogue_branch 元事件。
	assert_eq(result["state"].event_log.back()["action"], "dialogue_branch")
	assert_true(result["state"].event_log.any(
			func(event): return str(event.get("action", "")) == "encounter_session"))


func test_stale_dialogue_branch_is_rejected_without_state_change() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	var state := RunState.new_run(101)
	var result := adapter.apply_branch(
		state,
		{},
		"echo_cave.accept",
		ContentCatalog.load_all(),
		{},
		{"state_version": state.event_log.size() - 1}
	)

	assert_false(result["ok"])
	assert_eq(result["reason"], "action_preview_stale")
	assert_eq(result["state"], state)


func test_controller_event_dialogue_accept_stays_on_encounter_with_feedback() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	_controller_travel_to_echo_cave(controller)
	var before_log := controller.state.event_log.size()
	var result := controller.submit_command({"type": "dialogue_branch", "branch_id": "event.echo_cave.accept"})

	assert_true(result["ok"])
	assert_eq(controller.current_view_name(), "Encounter")
	assert_false(str(controller.last_feedback).is_empty())
	assert_gt(controller.state.event_log.size(), before_log)
	assert_eq(controller.state.event_log.back()["action"], "dialogue_branch")
	assert_true(controller.state.event_log.any(
			func(event): return str(event.get("action", "")) == "encounter_session"))
	controller.free()


func test_controller_event_dialogue_leave_returns_to_map() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	_controller_travel_to_echo_cave(controller)
	var result := controller.submit_command({"type": "dialogue_branch", "branch_id": "event.echo_cave.leave"})

	assert_true(result["ok"])
	assert_eq(controller.current_view_name(), "Map")
	controller.free()


func test_controller_unknown_dialogue_branch_keeps_encounter_and_unchanged_log() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	_controller_travel_to_echo_cave(controller)
	var before_log := controller.state.event_log.size()
	var result := controller.submit_command({"type": "dialogue_branch", "branch_id": "event.echo_cave.unknown"})

	assert_false(result["ok"])
	assert_eq(result["reason"], "unknown_dialogue_branch")
	assert_true(str(controller.last_feedback).contains("无法理解"))
	assert_eq(controller.current_view_name(), "Encounter")
	assert_eq(controller.state.event_log.size(), before_log)
	controller.free()


# ==== 返工 P1-2：事件 ID → Dialogue title 路由 ====

## travel 到 event 节点必须把节点声明的 dialogue_title（默认 "start"）传给
## gateway.begin，而不是硬编码只传 event_id。
func test_travel_to_event_passes_dialogue_title_to_gateway() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	controller.route = _synthetic_teaching_route()
	var spy := SpyDialogueGateway.new()
	controller._dialogue_gateway = spy
	for node_id in ["ridge_caravan", "cultivation_spring", "flooded_cave"]:
		controller.submit_command({"type": "travel", "node_id": node_id})
		# E3a 三选一：休息类节点需先消费探访（skip）才能离开。
		if str(controller.current_node.get("type", "")) in ["rest", "refinement", "cultivation"]:
			controller.submit_command({"type": "rest", "mode": "skip"})
		controller.submit_command({"type": "leave_encounter"})
	controller.submit_command({"type": "travel", "node_id": "echo_cave"})

	assert_eq(str(controller.current_node.get("type", "")), "event")
	assert_eq(spy.last_begin_event_id, "echo_cave")
	assert_eq(spy.last_begin_title, "start",
			"event node without dialogue_title must open the default start title")
	controller.free()


## 事件专属 Dialogue title（gu_rot_pact）必须保留在路由结果中。
func test_adapter_begin_passes_event_specific_title() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	var result: Dictionary = adapter.begin("gu_rot_pact", "gu_rot_pact")

	assert_true(bool(result["ok"]))
	assert_eq(result["source"], "template")
	assert_eq(result["title"], "gu_rot_pact")
	assert_eq(result["event_id"], "gu_rot_pact")


# ==== 返工 P1-1：Dialogue 选择 → 领域命令桥接 ====

## 标题选择兼容入口：branch title 必须转为
## dialogue_branch 领域命令并实际结算领域效果。
func test_controller_submit_dialogue_selection_applies_branch() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	_controller_travel_to_echo_cave(controller)
	var before_log := controller.state.event_log.size()
	var result := controller.submit_dialogue_selection("event.echo_cave.accept")

	assert_true(result["ok"])
	assert_eq(result["command"], {"type": "accept_event", "event_id": "echo_cave"})
	assert_eq(controller.current_view_name(), "Encounter")
	assert_false(str(controller.last_feedback).is_empty())
	assert_gt(controller.state.event_log.size(), before_log)
	controller.free()


## 空选择标题必须被拒绝，不触发任何领域命令。
func test_controller_submit_dialogue_selection_empty_is_rejected() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	_controller_travel_to_echo_cave(controller)
	var before_log := controller.state.event_log.size()
	var result := controller.submit_dialogue_selection("")

	assert_false(result["ok"])
	assert_eq(result["reason"], "empty_dialogue_selection")
	assert_eq(controller.state.event_log.size(), before_log)
	controller.free()


# ==== 返工 P3-7：dialogue_branch 元事件接入 ====

## apply_branch 成功结算后必须产生不可变 dialogue_branch 元事件（分支选择入日志，
## 供结局归因/回放），EventFactory.dialogue_branch 不再是死代码。
func test_apply_branch_appends_dialogue_branch_event_on_success() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	var state := RunState.new_run(101)
	state.current_node_id = "echo_cave"
	var session := EncounterSessionResolver.start({"id": "echo_cave", "type": "event"})
	var result := adapter.apply_branch(
		state,
		session,
		"event.echo_cave.accept",
		ContentCatalog.load_all(),
		{"id": "echo_cave", "type": "event"}
	)

	assert_true(result["ok"])
	var branch_event: Dictionary = {}
	for event_value in result["state"].event_log:
		var event: Dictionary = event_value
		if str(event.get("action", "")) == "dialogue_branch":
			branch_event = event
			break
	assert_false(branch_event.is_empty(), "accepted branch must append a dialogue_branch event")
	assert_eq(str(branch_event["after"].get("branch_id", "")), "event.echo_cave.accept")
	assert_eq(str(branch_event["after"].get("event_id", "")), "echo_cave")
	assert_eq(str(branch_event["after"].get("outcome", "")), "accepted")


func _controller_travel_to_echo_cave(controller) -> void:
	# 节点收窄后（2026-09-06）first_run 骨架不再含 event 模板；对话/遭遇语义
	# 用本地合成路线夹具保护（模板仍由 nodes.json 提供，域支持不变）。
	controller.route = _synthetic_teaching_route()
	# 合成夹具路线 caravan -> cultivation -> hazard -> event，全程无战斗节点。
	# E3a 三选一：休息类节点未消费探访不许离开（rest_choice_required），
	# 夹具对休息类节点先走「放弃收益并离开」（rest mode=skip）再离场。
	for node_id in ["ridge_caravan", "cultivation_spring", "flooded_cave"]:
		controller.submit_command({"type": "travel", "node_id": node_id})
		if str(controller.current_node.get("type", "")) in ["rest", "refinement", "cultivation"]:
			controller.submit_command({"type": "rest", "mode": "skip"})
		controller.submit_command({"type": "leave_encounter"})
	controller.submit_command({"type": "travel", "node_id": "echo_cave"})
	assert_eq(str(controller.current_node.get("type", "")), "event")


## 教学/事件对话测试的本地合成路线：由 nodes.json 模板构成事件链，与地图
## 生成（pacing/first_run，已收窄为战斗/休息/商店）解耦。
func _synthetic_teaching_route() -> Array[Dictionary]:
	var catalog: Dictionary = ContentCatalog.load_all()
	var by_id := {}
	for node_value in catalog.get("nodes_data", {}).get("nodes", []):
		by_id[str((node_value as Dictionary).get("id", ""))] = node_value
	var order := ["ridge_caravan", "cultivation_spring", "flooded_cave", "echo_cave"]
	var route: Array[Dictionary] = []
	for index in order.size():
		var node: Dictionary = (by_id[order[index]] as Dictionary).duplicate(true)
		node["start"] = index == 0
		node["visible"] = index <= 1
		node["template_id"] = order[index]
		node["layer"] = 1
		node["row"] = index
		node["next_ids"] = [order[index + 1]] if index < order.size() - 1 else []
		route.append(node)
	return route


# ==== 复审 P1-A/P1-C/P2：模板分支路由 ====


## 下划线 title 必须映射到既有 accept_event 命令。
func test_underscore_accept_branch_maps_to_event_command() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	assert_eq(adapter.command_for_branch("echo_cave_accept"),
			{"type": "accept_event", "event_id": "echo_cave"})
	assert_eq(adapter.command_for_branch("gu_rot_pact_accept"),
			{"type": "accept_event", "event_id": "gu_rot_pact"})


## 下划线 title 的 leave 分支必须映射到 leave_node 命令。
func test_underscore_leave_branch_maps_to_leave_node_command() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	assert_eq(adapter.command_for_branch("echo_cave_leave"), {"type": "leave_node"})
	assert_eq(adapter.command_for_branch("gu_rot_pact_leave"), {"type": "leave_node"})


## P2：dialogue_branch 事件不再硬编码 stage "one"/time 0，而是反映当前阶段
## 与实际事件序号（后期分支不被误归入第一阶段）。
func test_dialogue_branch_event_carries_real_stage_and_time() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	var state := RunState.new_run(101)
	state.current_node_id = "echo_cave"
	state.stage = "two"
	state = state.append_event(EventFactory.resource_changed("stone", 1, 2, "test", "test"))
	var session := EncounterSessionResolver.start({"id": "echo_cave", "type": "event"})
	var result := adapter.apply_branch(
		state, session, "event.echo_cave.accept", ContentCatalog.load_all(),
		{"id": "echo_cave", "type": "event"}
	)

	assert_true(result["ok"])
	var branch_event: Dictionary = result["state"].event_log.back()
	assert_eq(str(branch_event.get("action", "")), "dialogue_branch")
	assert_eq(str(branch_event.get("stage", "")), "two",
			"branch event must carry the current stage, not a hardcoded one")
	assert_eq(int(branch_event.get("time", -1)), result["state"].event_log.size() - 1,
			"branch event must carry its real event index, not time zero")


## P1-C 集成：地图节点（echo_cave，first_run 可达）进入 → 玩家选择 →
## 领域结算 → 不可变日志。
func test_controller_event_full_link_node_to_dialogue_to_settlement_to_log() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	_controller_travel_to_echo_cave(controller)
	assert_eq(str(controller.current_node.get("type", "")), "event")
	assert_eq(str(controller.current_node.get("id", "")), "echo_cave")
	var before_health := controller.state.health
	var before_log := controller.state.event_log.size()

	# 事件卡提交 echo_cave_accept → submit_dialogue_selection → accept_event 结算。
	var result: Dictionary = controller.submit_dialogue_selection("echo_cave_accept")

	assert_true(result["ok"])
	assert_eq(result["command"], {"type": "accept_event", "event_id": "echo_cave"})
	assert_lt(controller.state.health, before_health, "delayed_cost must cost health")
	assert_gt(controller.state.event_log.size(), before_log)
	var branch_event: Dictionary = controller.state.event_log.back()
	assert_eq(str(branch_event.get("action", "")), "dialogue_branch")
	assert_eq(str(branch_event["after"].get("branch_id", "")), "echo_cave_accept")
	assert_eq(str(branch_event["after"].get("event_id", "")), "echo_cave")
	assert_eq(str(branch_event.get("stage", "")), "one")
	controller.free()


## P1-C 专属入口：travel 到声明 dialogue_title 的 event 节点（gu_rot_pact）
## 必须把专属 title 透传给 gateway.begin，而不是默认 start。
func test_travel_to_event_passes_specific_dialogue_title_to_gateway() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	var spy := SpyDialogueGateway.new()
	controller._dialogue_gateway = spy
	# first_run 模板不含 gu_rot_pact，用构造 route 提供可达的专属 title 事件节点。
	var echo_cave: Dictionary = {"id": "echo_cave", "stage": "two", "type": "event",
			"next_ids": ["gu_rot_pact"]}
	var gu_rot_pact: Dictionary = {"id": "gu_rot_pact", "stage": "two", "type": "event",
			"event_id": "gu_rot_pact", "dialogue_title": "gu_rot_pact", "next_ids": []}
	controller.route = [echo_cave, gu_rot_pact]
	controller.state.current_node_id = "echo_cave"
	controller.state.node_flags["echo_cave"] = true
	var travel := controller.submit_command({"type": "travel", "node_id": "gu_rot_pact"})

	assert_true(bool(travel.get("ok", false)), "gu_rot_pact must be travelable from echo_cave")
	assert_eq(str(controller.current_node.get("type", "")), "event")
	assert_eq(spy.last_begin_event_id, "gu_rot_pact")
	assert_eq(spy.last_begin_title, "gu_rot_pact",
			"event node with dialogue_title must pass its specific title to begin")
	controller.free()


class SpyDialogueGateway extends DialogueGateway:
	var last_begin_event_id := ""
	var last_begin_title := ""

	func begin(event_id: String, title: String = "start") -> Dictionary:
		last_begin_event_id = event_id
		last_begin_title = title
		return {"ok": true, "source": "spy", "event_id": event_id, "title": title}

	func respond(_context: Dictionary) -> Dictionary:
		return {}

	func apply_branch(_state, _session, _branch_id, _catalog, _node = {}, _context = {}) -> Dictionary:
		return {"ok": false, "reason": "spy"}


class MissingTemplateGateway extends TemplateDialogueGateway:
	func _load_templates() -> Dictionary:
		return {}
