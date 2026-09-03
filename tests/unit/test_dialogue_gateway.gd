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
	var spy := SpyDialogueGateway.new()
	controller._dialogue_gateway = spy
	for node_id in ["ridge_caravan", "cultivation_spring", "flooded_cave"]:
		controller.submit_command({"type": "travel", "node_id": node_id})
		controller.submit_command({"type": "leave_encounter"})
	controller.submit_command({"type": "travel", "node_id": "echo_cave"})

	assert_eq(str(controller.current_node.get("type", "")), "event")
	assert_eq(spy.last_begin_event_id, "echo_cave")
	assert_eq(spy.last_begin_title, "start",
			"event node without dialogue_title must open the default start title")
	controller.free()


## 事件专属 Dialogue title（gu_rot_pact）必须被 adapter 透传给 balloon 入口。
func test_adapter_begin_passes_event_specific_title() -> void:
	var adapter := DialogueManagerAdapterScript.new()
	var result: Dictionary = adapter.begin("gu_rot_pact", "gu_rot_pact")

	assert_true(bool(result["ok"]))
	assert_eq(result["title"], "gu_rot_pact")
	assert_eq(result["event_id"], "gu_rot_pact")


# ==== 返工 P1-1：Dialogue 选择 → 领域命令桥接 ====

## Dialogue Manager balloon 选择桥接入口：标题报告（非入口 title）必须转为
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
	# seed 101 首跑路线 caravan -> cultivation -> hazard -> event，全程无战斗节点。
	for node_id in ["ridge_caravan", "cultivation_spring", "flooded_cave"]:
		controller.submit_command({"type": "travel", "node_id": node_id})
		controller.submit_command({"type": "leave_encounter"})
	controller.submit_command({"type": "travel", "node_id": "echo_cave"})
	assert_eq(str(controller.current_node.get("type", "")), "event")


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
