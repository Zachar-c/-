extends GutTest


# T5-D fusion round: the panel UI stays ours (db5ee21); the domain core is the
# master DebugActions service (fusion adjudication 2026-08-26). Contract flips
# versus the first slice:
#   - every op INCLUDING rejections appends one source="debug" audit entry
#     (action=debug_<op> / debug_rejected, payload under after._debug) --
#     the earlier "debug ops never write event log" ruling is revoked;
#   - resource whitelist is essence/stones/health/soul (no lifespan);
#   - stones clamp non-negative uncapped in domain -- the 99999 cap lives at
#     this UI layer only;
#   - travel becomes arrival-only jump_to_node (visible-only + no-battle
#     pre-checks stay controller-side BEFORE the service, so their rejections
#     carry no audit entry);
#   - dump_snapshot surfaces state.to_save_data().
# Disabled-gate assertions stay: disallowed => zero ops, zero events, no panel.


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


func _last_entry(state: RunState) -> Dictionary:
	return state.event_log[state.event_log.size() - 1]


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
	var events_before: int = controller.state.event_log.size()

	var added: Dictionary = controller.debug_add_gu("thorn_whip_gu")
	assert_false(bool(added.get("ok", true)), "add_gu must exit early when disabled")
	assert_eq(str(added.get("reason", "")), "debug_disabled")

	var resource: Dictionary = controller.debug_set_resource("stones", 999)
	assert_false(bool(resource.get("ok", true)), "set_resource must exit early when disabled")

	var travelled: Dictionary = controller.debug_travel("neutral_wanderer")
	assert_false(bool(travelled.get("ok", true)), "travel must exit early when disabled")

	assert_eq(controller.debug_snapshot_dump().size(), 0, "snapshot dump must stay silent when disabled")

	assert_eq(controller.state.gu_instances.size(), instances_before, "add_gu must not touch state")
	assert_eq(controller.state.stone, stone_before, "set_resource must not touch state")
	assert_eq(str(controller.state.current_node_id), "trailhead", "travel must not touch state")
	assert_eq(controller.state.event_log.size(), events_before,
			"disabled gate must append no audit entries either")


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

func test_add_gu_success_appends_debug_audit_and_follows_reward_semantics() -> void:
	var controller := _new_controller(true)
	var events_before: int = controller.state.event_log.size()
	var action := {"op": "add_gu", "definition_id": "thorn_whip_gu"}

	var result: Dictionary = controller.debug_add_gu("thorn_whip_gu")
	assert_true(bool(result.get("ok", false)), "legal gain must succeed")
	var instance_id := str(result.get("instance_id", ""))
	assert_ne(instance_id, "", "service must report the new instance")
	assert_true(controller.state.cave_aperture["stored_gu_instance_ids"].has(instance_id),
			"gain must occupy a formal satchel slot")
	assert_eq(str(controller.state.gu_instances[instance_id]["definition_id"]), "thorn_whip_gu")
	assert_true(controller.state.refined_gu_ids.has("thorn_whip_gu"), "legacy projection synced")
	assert_eq(controller.state.event_log.size(), events_before + 1, "exactly one audit entry")
	var entry := _last_entry(controller.state)
	assert_eq(str(entry["action"]), "debug_add_gu")
	assert_eq(str(entry["source"]), "debug")
	assert_eq_deep(entry["after"]["_debug"], action)
	assert_true(str(controller._debug_feedback).contains("已加入"), "feedback must confirm the gain")


func test_add_gu_rejection_leaves_a_debug_rejected_audit_entry() -> void:
	var controller := _new_controller(true)
	var events_before: int = controller.state.event_log.size()
	var instances_before: Dictionary = controller.state.gu_instances.duplicate(true)
	var aperture_before: Dictionary = controller.state.cave_aperture.duplicate(true)
	var action := {"op": "add_gu", "definition_id": "not_a_real_gu"}

	var result: Dictionary = controller.debug_add_gu("not_a_real_gu")
	assert_false(bool(result.get("ok", true)))
	assert_eq(str(result.get("reason", "")), "unknown_gu")
	assert_eq(controller.state.event_log.size(), events_before + 1,
			"rejections are audited too (fusion contract)")
	var entry := _last_entry(controller.state)
	assert_eq(str(entry["action"]), "debug_rejected")
	assert_eq(str(entry["source"]), "debug")
	assert_eq(str(entry["reason"]), "unknown_gu")
	assert_eq_deep(entry["after"]["_debug"], action)
	assert_eq(controller.state.gu_instances, instances_before, "live instances untouched")


func test_add_gu_over_capacity_is_rejected_by_the_service_and_audited() -> void:
	var controller := _new_controller(true)
	controller.catalog["deck"]["capacity"] = 1
	var events_before: int = controller.state.event_log.size()
	var instances_before: Dictionary = controller.state.gu_instances.duplicate(true)
	var aperture_before: Dictionary = controller.state.cave_aperture.duplicate(true)

	var result: Dictionary = controller.debug_add_gu("thorn_whip_gu")
	assert_false(bool(result.get("ok", true)), "over-capacity gain must be rejected")
	assert_eq(str(result.get("reason", "")), "deck_capacity_exceeded")
	assert_eq(controller.state.event_log.size(), events_before + 1, "rejection rides one light audit entry")
	var entry := _last_entry(controller.state)
	assert_eq(str(entry["action"]), "debug_rejected")
	assert_eq(str(entry["reason"]), "deck_capacity_exceeded")
	assert_eq_deep(entry["after"]["_debug"], {"op": "add_gu", "definition_id": "thorn_whip_gu"})
	assert_eq(controller.state.gu_instances, instances_before, "capacity rejection leaves instances untouched")
	assert_eq(controller.state.cave_aperture, aperture_before, "capacity rejection leaves slots untouched")


# ---------------------------------------------------------------- resources

func test_set_resources_clamp_via_the_service_and_append_one_audit_entry() -> void:
	var controller := _new_controller(true)
	var events_before: int = controller.state.event_log.size()

	assert_eq(int(controller.debug_set_resource("health", 999)["applied"]), 80, "health caps at max_health")
	assert_eq(int(controller.state.health), 80)
	assert_eq(int(controller.debug_set_resource("health", -5)["applied"]), 1, "health floors at 1 (no silent death)")

	assert_eq(int(controller.debug_set_resource("stones", 100000)["applied"]),
			int(controller.DEBUG_STONE_CAP), "the 99999 cap lives at this UI input layer")
	assert_eq(int(controller.debug_set_resource("stones", -3)["applied"]), 0, "domain floors stones at 0")

	assert_eq(int(controller.debug_set_resource("soul", 99)["applied"]), 4, "soul caps at soul_max")
	assert_eq(int(controller.debug_set_resource("soul", 0)["applied"]), 1, "soul floors at 1")

	assert_eq(int(controller.debug_set_resource("essence", 50)["applied"]), 20, "essence caps at cave capacity")
	assert_eq(int(controller.debug_set_resource("essence", -1)["applied"]), 0)

	assert_eq(controller.state.event_log.size(), events_before + 8, "one audit entry per accepted write")
	var entry := _last_entry(controller.state)
	assert_eq(str(entry["action"]), "debug_set_resources")
	assert_eq(str(entry["source"]), "debug")
	assert_true(entry["after"].has("_debug"), "audit payload rides the _ key")


func test_lifespan_kind_left_the_service_whitelist() -> void:
	var controller := _new_controller(true)
	var events_before: int = controller.state.event_log.size()
	var lifespan_before: int = int(controller.state.cultivator.get("lifespan", 0))

	var result: Dictionary = controller.debug_set_resource("lifespan", 42)
	assert_false(bool(result.get("ok", true)), "lifespan is not part of the fused op whitelist")
	assert_eq(str(result.get("reason", "")), "unknown_kind")
	assert_eq(int(controller.state.cultivator.get("lifespan", 0)), lifespan_before)
	assert_eq(controller.state.event_log.size(), events_before,
			"controller-side kind gate precedes the service: no audit entry")


func test_invalid_numbers_are_refused_before_the_service_without_audit() -> void:
	var controller := _new_controller(true)
	var events_before: int = controller.state.event_log.size()
	var stone_before: int = controller.state.stone

	var result: Dictionary = controller.debug_set_resource("stones", "abc")
	assert_false(bool(result.get("ok", true)))
	assert_eq(str(result.get("reason", "")), "invalid_number")
	assert_eq(controller.state.stone, stone_before)
	assert_eq(controller.state.event_log.size(), events_before, "input validation stays pre-service")

	var unknown: Dictionary = controller.debug_set_resource("karma", 3)
	assert_false(bool(unknown.get("ok", true)))
	assert_eq(str(unknown.get("reason", "")), "unknown_kind")


# ---------------------------------------------------------------- travel

func test_travel_precheck_refuses_invisible_nodes_without_reaching_the_service() -> void:
	var controller := _new_controller(true)
	var events_before: int = controller.state.event_log.size()
	var result: Dictionary = controller.debug_travel("stage_one_ledger")
	assert_false(bool(result.get("ok", true)), "cross-layer jumps must be refused")
	assert_eq(str(result.get("reason", "")), "invisible_node")
	assert_eq(str(controller.state.current_node_id), "trailhead")
	assert_eq(controller.state.event_log.size(), events_before,
			"controller pre-checks run before the service: no audit entry")


func test_travel_precheck_refuses_while_a_battle_is_running() -> void:
	var controller := _new_controller(true)
	var events_before: int = controller.state.event_log.size()
	controller.current_battle = {"enemy_kind": "beast_swarm"}
	var result: Dictionary = controller.debug_travel("neutral_wanderer")
	assert_false(bool(result.get("ok", true)))
	assert_eq(str(result.get("reason", "")), "battle_in_progress")
	assert_eq(str(controller.state.current_node_id), "trailhead")
	assert_eq(controller.state.event_log.size(), events_before)


func test_travel_jump_arrives_via_the_service_with_debug_arrival_flag() -> void:
	var controller := _new_controller(true)
	var events_before: int = controller.state.event_log.size()
	var action := {"op": "jump_to_node", "node_id": "neutral_wanderer"}

	var result: Dictionary = controller.debug_travel("neutral_wanderer")
	assert_true(bool(result.get("ok", false)), "visible-node jump must succeed")
	assert_eq(str(controller.state.current_node_id), "neutral_wanderer")
	assert_eq(str(controller.state.node_flags.get("neutral_wanderer", "")), "debug_arrived",
			"arrival flag must let reachability expand successors")
	assert_eq_deep(controller.state.encounter_session, {})
	assert_true(controller.state.encounter_session.is_empty(),
			"arrival clears any open session mirror")
	assert_eq(controller.current_view_name(), "Map", "arrival lands back on the map")
	assert_eq(controller.state.event_log.size(), events_before + 1, "one unified jump audit entry")
	var entry := _last_entry(controller.state)
	assert_eq(str(entry["action"]), "debug_jump_to_node")
	assert_eq(str(entry["source"]), "debug")
	assert_eq_deep(entry["after"]["_debug"], action)
	assert_true(entry["targets"].has("neutral_wanderer"))



# ---------------------------------------------------------------- dump + snapshot

func test_snapshot_dump_returns_service_save_data_and_audits_the_dump() -> void:
	var controller := _new_controller(true)
	var events_before: int = controller.state.event_log.size()

	var snapshot: Dictionary = controller.debug_snapshot_dump()
	assert_ne(snapshot.size(), 0, "enabled dump must return the save-data dict")
	assert_eq(int(snapshot["seed"]), 101)
	assert_true(snapshot.has("event_log"), "dump carries the full to_save_data payload")
	assert_eq(controller.state.event_log.size(), events_before + 1, "dump itself is audited")
	var entry := _last_entry(controller.state)
	assert_eq(str(entry["action"]), "debug_dump_snapshot")
	assert_eq(str(entry["source"]), "debug")
	assert_true(str(controller._debug_feedback).contains("stdout"), "feedback must point at stdout")


func test_snapshot_builder_exposes_readonly_debug_section_matching_query_shape() -> void:
	var controller := _new_controller(true)
	var section: Dictionary = SnapshotBuilder.debug(controller)
	assert_true(section.has("pity"), "pity block mirrors query_loot_state payload shape")
	var pity: Dictionary = section["pity"]
	assert_true(pity.has("loot_pity"))
	assert_true(pity.has("material_pity"))
	assert_true(pity.has("synthesis_fail_streak"), "query parity includes the synthesis streak")
	assert_eq(int(pity["loot_pity"]), int(controller.state.loot_pity))
	assert_eq(int(pity["synthesis_fail_streak"]), int(controller.state.synthesis_fail_streak))
	assert_true(section.has("excluded"))
	var excluded: Array = section["excluded"]
	assert_eq(excluded.size(), 0, "pool exclusion is not landed in domain yet - honest empty")
	assert_eq(int(section["seed"]), 101)
	assert_eq(int(section["event_count"]), controller.state.event_log.size())
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
			badge_color_matched = l.get_theme_color("font_color").is_equal_approx(GuStyle.CINNABAR)
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
	props["feedback"] = "调试失败：蛊囊已满（deck_capacity_exceeded）"
	var host := _mount_screen(props)
	for i in 3:
		await get_tree().process_frame

	assert_true(_host_has_text(host, "保底计数 · 蛊 0 / 材料 0"), "pity counters must render read-only")
	assert_true(_host_has_text(host, "合成连败 0"), "synthesis streak mirrors the query payload")
	assert_true(_host_has_text(host, "当前种子 101"), "run seed must render read-only")
	assert_true(_host_has_text(host, "池排除列表：（无）"), "empty exclusion list must say so honestly")
	assert_true(_host_has_text(host, "调试失败：蛊囊已满"), "failure feedback must surface through the toast row")


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
