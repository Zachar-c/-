extends GutTest


# T5-D: D5 developer debug panel (dev-build only, AGENTS.md section 16.22 hard rules).
# Locks:
#   - whole-chain gating via injectable `_debug_enabled_for_test`: disabled ->
#     panel never created + every debug method exits early with state untouched
#   - debug_add_gu drives the formal acquisition channel shape (deck capacity
#     gate identical to Resolver._reject_deck_full); over-capacity is rejected,
#     state untouched; success adds instance + stored slot + legacy projection
#   - debug_set_resource clamps every kind to its legal range (never silent death)
#   - debug_travel refuses invisible / mid-battle targets, delegates the formal
#     travel channel for visible ones
#   - debug ops NEVER append domain events (section 16.22 T5-D brief point 3)
#   - debug_snapshot_dump prints `[debug]` JSON and returns "" when gated
#   - F12 toggles the panel only when debug-enabled
#   - snapshot builder exposes the read-only `debug(controller)` section
#   - panel component renders: red DEV badge, collapsed = handle bar only


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const SnapshotBuilder = preload("res://scripts/presentation/run_snapshot_builder.gd")
const ControllerScript = preload("res://scripts/presentation/run_controller.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")

var _rui_roots: Array = []
var _rui_hosts: Array = []


func _new_controller(enabled: bool) -> RunController:
	var controller: RunController = autofree(ControllerScript.new())
	controller._debug_enabled_for_test = enabled
	add_child(controller)
	controller.start_new_run(101)
	return controller


func after_each() -> void:
	for r in _rui_roots:
		if r != null and r.has_method("unmount"):
			r.unmount()
	_rui_roots.clear()
	for h in _rui_hosts:
		if h != null and is_instance_valid(h):
			h.free()
	_rui_hosts.clear()


func _mount_screen(props: Dictionary) -> Control:
	var fn = VLib.comp("res://ui/screens/debug_panel.gd", "render")
	assert_true(fn is Callable, "debug_panel must expose render")
	if not (fn is Callable):
		return Control.new()
	var host := Control.new()
	add_child(host)
	_rui_hosts.append(host)
	_rui_roots.append(RuiRoot.create(host, VLib.fc(fn, props)))
	return host


func _collect(node: Node, out_buttons: Array, out_labels: Array) -> void:
	if node is Button:
		out_buttons.append(node)
	if node is Label:
		out_labels.append(node)
	for c in node.get_children():
		_collect(c, out_buttons, out_labels)


func _buttons_of(host: Node) -> Array:
	var buttons: Array = []
	var labels: Array = []
	_collect(host, buttons, labels)
	return buttons


func _labels_of(host: Node) -> Array:
	var buttons: Array = []
	var labels: Array = []
	_collect(host, buttons, labels)
	return labels


func _press_button(host: Node, text: String) -> bool:
	for b in _buttons_of(host):
		if b.text == text and not b.disabled:
			b.pressed.emit()
			return true
	return false


func _host_has_text(host: Node, wanted: String) -> bool:
	for l in _labels_of(host):
		if str(l.text).contains(wanted):
			return true
	return false


func _f12_event() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_F12
	ev.pressed = true
	return ev


# ---------------------------------------------------------------- gating

func test_disabled_gates_panel_creation_and_every_debug_method() -> void:
	var controller := _new_controller(false)
	assert_false(controller.debug_panel_mounted(), "disabled chain must not create the panel")
	var instances_before: int = controller.state.gu_instances.size()
	var stone_before: int = controller.state.stone

	var added: Dictionary = controller.debug_add_gu("thorn_whip_gu")
	assert_false(bool(added.get("ok", true)), "add_gu must exit early when disabled")
	assert_eq(str(added.get("reason", "")), "debug_disabled")

	var resource: Dictionary = controller.debug_set_resource("yuanstone", 999)
	assert_false(bool(resource.get("ok", true)), "set_resource must exit early when disabled")

	var travelled: Dictionary = controller.debug_travel("neutral_wanderer")
	assert_false(bool(travelled.get("ok", true)), "travel must exit early when disabled")

	assert_eq(controller.debug_snapshot_dump(), "", "snapshot dump must stay silent when disabled")

	assert_eq(controller.state.gu_instances.size(), instances_before, "add_gu must not touch state")
	assert_eq(controller.state.stone, stone_before, "set_resource must not touch state")
	assert_eq(str(controller.state.current_node_id), "trailhead", "travel must not touch state")


func test_enabled_chain_mounts_the_panel_exactly_once() -> void:
	var controller := _new_controller(true)
	assert_true(controller.debug_panel_mounted(), "dev build must create the panel")
	controller.ensure_ui()
	var hosts := 0
	for child in controller.get_children():
		if str(child.name) == "DebugPanelHost":
			hosts += 1
	assert_eq(hosts, 1, "ensure_ui must not duplicate the panel host")


func test_f12_toggles_the_panel_only_when_enabled() -> void:
	var controller := _new_controller(false)
	controller._unhandled_key_input(_f12_event())
	assert_false(controller._debug_panel_open, "F12 must be inert when disabled")
	controller._debug_enabled_for_test = true
	controller._unhandled_key_input(_f12_event())
	assert_true(controller._debug_panel_open, "F12 must expand the panel")
	controller._unhandled_key_input(_f12_event())
	assert_false(controller._debug_panel_open, "F12 must collapse the panel again")


# ---------------------------------------------------------------- add gu

func test_add_gu_rejects_unknown_id_without_touching_state() -> void:
	var controller := _new_controller(true)
	var before: Dictionary = controller.state.gu_instances.duplicate(true)
	var result: Dictionary = controller.debug_add_gu("not_a_real_gu")
	assert_false(bool(result.get("ok", true)))
	assert_eq(str(result.get("reason", "")), "unknown_gu")
	assert_eq(controller.state.gu_instances, before)


func test_add_gu_over_capacity_is_rejected_and_state_is_unchanged() -> void:
	var controller := _new_controller(true)
	controller.catalog["deck"]["capacity"] = 1
	var instances_before: Dictionary = controller.state.gu_instances.duplicate(true)
	var aperture_before: Dictionary = controller.state.cave_aperture.duplicate(true)
	var events_before: int = controller.state.event_log.size()

	var result: Dictionary = controller.debug_add_gu("thorn_whip_gu")
	assert_false(bool(result.get("ok", true)), "over-capacity gain must be rejected")
	assert_eq(str(result.get("reason", "")), "deck_capacity_exceeded")
	assert_eq(controller.state.gu_instances, instances_before, "capacity rejection must leave instances untouched")
	assert_eq(controller.state.cave_aperture, aperture_before, "capacity rejection must leave slots untouched")
	assert_eq(controller.state.event_log.size(), events_before, "debug ops must not append events")


func test_add_gu_success_follows_the_formal_acquisition_shape_without_events() -> void:
	var controller := _new_controller(true)
	var events_before: int = controller.state.event_log.size()

	var result: Dictionary = controller.debug_add_gu("thorn_whip_gu")
	assert_true(bool(result.get("ok", false)), "legal gain must succeed")
	var instance_id := str(result.get("instance_id", ""))
	assert_ne(instance_id, "", "success must report the new instance")
	assert_true(controller.state.cave_aperture["stored_gu_instance_ids"].has(instance_id),
			"gain must occupy a formal satchel slot")
	assert_eq(str(controller.state.gu_instances[instance_id]["definition_id"]), "thorn_whip_gu")
	assert_true(controller.state.refined_gu_ids.has("thorn_whip_gu"), "legacy projection must refresh")
	assert_eq(controller.state.event_log.size(), events_before, "debug gains must never write domain events")
	assert_true(str(controller._debug_feedback).contains("已加入"), "feedback must confirm the gain")


# ---------------------------------------------------------------- resources

func test_set_resource_clamps_every_kind_to_legal_ranges() -> void:
	var controller := _new_controller(true)

	assert_eq(int(controller.debug_set_resource("health", 999)["applied"]), 6, "health caps at max_health")
	assert_eq(int(controller.state.cultivator["health"]), 6)
	assert_eq(int(controller.debug_set_resource("health", -5)["applied"]), 1, "health floors at 1 (no silent death)")

	assert_eq(int(controller.debug_set_resource("yuanstone", 100000)["applied"]),
			int(controller.DEBUG_STONE_CAP), "yuanstone respects the hard cap")
	assert_eq(int(controller.debug_set_resource("yuanstone", -3)["applied"]), 0)

	assert_eq(int(controller.debug_set_resource("soul", 99)["applied"]), 4, "soul caps at soul_max")
	assert_eq(int(controller.debug_set_resource("soul", 0)["applied"]), 1, "soul floors at 1")

	assert_eq(int(controller.debug_set_resource("lifespan", 0)["applied"]), 1, "lifespan floors at 1")

	assert_eq(int(controller.debug_set_resource("essence", 50)["applied"]), 4, "essence caps at capacity")
	assert_eq(int(controller.debug_set_resource("essence", -1)["applied"]), 0)


func test_set_resource_rejects_non_integer_values() -> void:
	var controller := _new_controller(true)
	var stone_before: int = controller.state.stone
	var result: Dictionary = controller.debug_set_resource("yuanstone", "abc")
	assert_false(bool(result.get("ok", true)))
	assert_eq(str(result.get("reason", "")), "invalid_number")
	assert_eq(controller.state.stone, stone_before)
	var unknown: Dictionary = controller.debug_set_resource("karma", 3)
	assert_false(bool(unknown.get("ok", true)))
	assert_eq(str(unknown.get("reason", "")), "unknown_kind")


# ---------------------------------------------------------------- travel

func test_travel_refuses_nodes_outside_current_visibility() -> void:
	var controller := _new_controller(true)
	var result: Dictionary = controller.debug_travel("stage_one_ledger")
	assert_false(bool(result.get("ok", true)), "cross-layer jumps must be refused")
	assert_eq(str(result.get("reason", "")), "invisible_node")
	assert_eq(str(controller.state.current_node_id), "trailhead")


func test_travel_refuses_while_a_battle_is_running() -> void:
	var controller := _new_controller(true)
	controller.current_battle = {"enemy_kind": "beast_swarm"}
	var result: Dictionary = controller.debug_travel("neutral_wanderer")
	assert_false(bool(result.get("ok", true)))
	assert_eq(str(result.get("reason", "")), "battle_in_progress")
	assert_eq(str(controller.state.current_node_id), "trailhead")


func test_travel_drives_the_formal_channel_for_a_visible_node() -> void:
	var controller := _new_controller(true)
	var result: Dictionary = controller.debug_travel("neutral_wanderer")
	assert_true(bool(result.get("ok", false)), "visible-node jump must succeed")
	assert_eq(str(controller.state.current_node_id), "neutral_wanderer")
	assert_eq(str(controller.current_session.get("node_id", "")), "neutral_wanderer",
			"formal channel must begin the encounter session")


# ---------------------------------------------------------------- dump + snapshot

func test_snapshot_dump_returns_parseable_run_data_with_debug_prefix_log() -> void:
	var controller := _new_controller(true)
	var dumped: String = controller.debug_snapshot_dump()
	assert_ne(dumped, "", "enabled dump must return JSON")
	var parsed = JSON.parse_string(dumped)
	assert_true(parsed is Dictionary, "dump must be valid JSON")
	assert_eq(int(parsed["seed"]), 101)
	assert_true(parsed.has("event_count"), "dump must carry event count")
	assert_true(parsed.has("loot_pity"), "dump must carry pity counters")


func test_snapshot_builder_exposes_readonly_debug_section() -> void:
	var controller := _new_controller(true)
	var section: Dictionary = SnapshotBuilder.debug(controller)
	assert_true(section.has("loot_pity"))
	assert_true(section.has("material_pity"))
	assert_true(section.has("pool_excluded_ids"))
	assert_true(section.has("seed"))
	assert_true(section.has("event_count"))
	assert_true(section.has("dda_percentile"))
	assert_eq(int(section["loot_pity"]), int(controller.state.loot_pity))
	assert_eq(int(section["seed"]), 101)
	assert_eq(int(section["event_count"]), controller.state.event_log.size())
	var excluded: Array = section["pool_excluded_ids"]
	assert_eq(excluded.size(), 0, "pool exclusion is not landed in domain yet - honest empty")
	# Night batch R14.6⑧: DDA 评估分数已实装（score/max + band label）。
	var evaluated := DdaResolverScript.evaluate(controller.state, controller.catalog)
	assert_eq(str(section["dda_percentile"]), "%d/%d %s" % [int(evaluated["score"]), 10, str(evaluated["label"])])


func test_snapshot_builder_debug_section_survives_missing_state() -> void:
	var controller: RunController = autofree(ControllerScript.new())
	var section: Dictionary = SnapshotBuilder.debug(controller)
	assert_eq(section.size(), 0, "no active run must yield an empty section")


# ---------------------------------------------------------------- panel rendering

func test_panel_expanded_renders_dev_badge_and_operation_buttons() -> void:
	var controller := _new_controller(true)
	var props: Dictionary = controller._debug_props()
	props["open"] = true
	var host := _mount_screen(props)
	for i in 3:
		await get_tree().process_frame

	assert_true(_host_has_text(host, "调试"), "red DEV badge text must exist")
	var badge_color_matched := false
	for l in _labels_of(host):
		if str(l.text) == "调试":
			badge_color_matched = l.get_theme_color("font_color").is_equal_approx(GuStyle.DANGER)
	assert_true(badge_color_matched, "DEV badge must render in DANGER red")

	for wanted in ["加蛊", "应用", "跳", "打印 RunData 快照", "收起"]:
		var found := false
		for b in _buttons_of(host):
			if str(b.text).begins_with(wanted):
				found = true
		assert_true(found, "expanded panel must expose button %s" % wanted)


func test_panel_collapsed_shows_only_the_handle_bar() -> void:
	var controller := _new_controller(true)
	var props: Dictionary = controller._debug_props()
	props["open"] = false
	var host := _mount_screen(props)
	for i in 3:
		await get_tree().process_frame

	var buttons := _buttons_of(host)
	assert_eq(buttons.size(), 1, "collapsed panel must show only the handle toggle")
	assert_true(str(buttons[0].text).begins_with("展开"), "handle must offer expanding")
	assert_false(_host_has_text(host, "加蛊"), "sections must hide while collapsed")
	assert_false(_host_has_text(host, "保底计数"), "pool intel must hide while collapsed")


func test_panel_renders_pool_intel_rows_and_feedback_toast() -> void:
	var controller := _new_controller(true)
	var props: Dictionary = controller._debug_props()
	props["open"] = true
	props["feedback"] = "调试：已加入 刺须蛊（实例 gu_002）"
	var host := _mount_screen(props)
	for i in 3:
		await get_tree().process_frame

	assert_true(_host_has_text(host, "保底计数 · 蛊 0 / 材料 0"), "pity counters must render read-only")
	assert_true(_host_has_text(host, "当前种子 101"), "run seed must render read-only")
	assert_true(_host_has_text(host, "池排除列表：（无）"), "empty exclusion list must say so honestly")
	assert_true(_host_has_text(host, "调试：已加入"), "feedback must surface through the toast row")


func test_panel_toggle_command_flips_controller_state() -> void:
	var controller := _new_controller(true)
	var commands: Dictionary = controller._debug_props()["commands"]
	assert_true(commands.has("toggle_open"), "panel must receive toggle command")
	assert_true(commands.has("add_gu"), "panel must receive add_gu command")
	assert_true(commands.has("apply_resource"), "panel must receive apply_resource command")
	assert_true(commands.has("travel"), "panel must receive travel command")
	assert_true(commands.has("snapshot_dump"), "panel must receive snapshot_dump command")
	assert_false(controller._debug_panel_open)
	commands["toggle_open"].call()
	assert_true(controller._debug_panel_open, "handle toggle must flip the controller flag")
	commands["toggle_open"].call()
	assert_false(controller._debug_panel_open)


func test_panel_commands_drive_input_state_for_later_ops() -> void:
	var controller := _new_controller(true)
	var commands: Dictionary = controller._debug_props()["commands"]
	commands["set_gu_input"].call("thorn_whip_gu")
	assert_eq(controller._debug_gu_input, "thorn_whip_gu")
	commands["set_res_kind"].call("soul")
	assert_eq(controller._debug_res_kind, "soul")
	commands["set_res_value"].call("42")
	assert_eq(controller._debug_res_value, "42")
