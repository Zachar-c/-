extends GutTest


# T5-C: D3 settlement review hardening. Locks:
#   - ending_type -> achievement chain copy (display_text.gd, six endings)
#   - settlement_extras read-only projection: route_summary layers (visited
#     nodes grouped by stage, boss-layer flag from catalog enemy tier),
#     run_record counters scanned from event_log (synthesis attempts counted by
#     outcome reasons only -- the materials-spent event must not inflate),
#     boss phase shifts, reserved zero DDA slot
#   - BOTH ending paths carry the extras + achievement + max_rank
#     (builder `ending()` and the battle-death `_show_death` inline state)
#   - ending screen renders: 达成 chain line under the type badge, narrow route
#     strip above decisions (EMBER on boss layers), 本局记录 block before the
#     codex panel, ★新 GOLD prefix on unlocks, 离局清零 small print,
#     最高转数 stat line
#   - minimal runs without route/record data hide both panels entirely
#   - hard constraints §16.6: settlement offers exactly 返回大厅 / 查看图鉴,
#     never any 读档 / 回溯 affordance


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const SnapshotBuilder = preload("res://scripts/presentation/run_snapshot_builder.gd")
const DisplayTextScript = preload("res://scripts/presentation/display_text.gd")

var _rui_roots: Array = []
var _rui_hosts: Array = []


func _new_controller() -> RunController:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(101)
	return controller


func after_each() -> void:
	for r in _rui_roots:
		if r != null and r.has_method("unmount"):
			r.unmount()
	_rui_roots.clear()
	for h in _rui_hosts:
		# free at once (queue_free would leak orphans into the next test).
		if h != null and is_instance_valid(h):
			h.free()
	_rui_hosts.clear()


func _mount_screen(props: Dictionary) -> Control:
	var fn = VLib.comp("res://ui/screens/ending_screen.gd", "render")
	assert_true(fn is Callable, "ending_screen must expose render")
	if not (fn is Callable):
		return Control.new()
	var host := Control.new()
	add_child(host)
	_rui_hosts.append(host)
	_rui_roots.append(RuiRoot.create(host, VLib.fc(fn, props)))
	return host


func _collect_controls(node: Node, out_buttons: Array, out_labels: Array) -> void:
	if node is Button:
		out_buttons.append(node)
	if node is Label:
		out_labels.append(node)
	for c in node.get_children():
		_collect_controls(c, out_buttons, out_labels)


func _host_has_text(host: Node, wanted: String) -> bool:
	var buttons: Array = []
	var labels: Array = []
	_collect_controls(host, buttons, labels)
	for l in labels:
		if str(l.text).contains(wanted):
			return true
	return false


func _find_label_exact(node: Node, wanted: String) -> Label:
	if node is Label and str(node.text) == wanted:
		return node
	for c in node.get_children():
		var found := _find_label_exact(c, wanted)
		if found != null:
			return found
	return null


func test_display_text_maps_achievement_chain_for_all_endings() -> void:
	assert_eq(DisplayTextScript.ending_achievement("success"), "五转功成，渡劫飞升，完整走完晋升之路")
	assert_eq(DisplayTextScript.ending_achievement("death"), "寿元、魂魄或反噬一线归零，身死道消")
	assert_eq(DisplayTextScript.ending_achievement("gu_fall"), "反噬彻底吞噬人身，蛊化坠落为蛊")
	assert_eq(DisplayTextScript.ending_achievement("risky"), "携险渡劫成功，代价留身而路已通")
	assert_eq(DisplayTextScript.ending_achievement("retreat"), "机缘未至而主动抽身，保命另寻出路")
	assert_eq(DisplayTextScript.ending_achievement("true_ending"), "窥破轮回真相，走出真正属于自己的路")
	assert_eq(DisplayTextScript.ending_achievement(""), "")
	assert_eq(DisplayTextScript.ending_achievement("unknown_kind"), "")


func test_settlement_extras_group_route_summary_by_visited_layers() -> void:
	var controller := _new_controller()
	controller.route = [
		{"id": "n1", "type": "contact", "stage": "one"},
		{"id": "n2", "type": "shop", "stage": "one"},
		{"id": "nm", "type": "market", "stage": "three"},
		{"id": "nb", "type": "combat", "stage": "five", "enemy_kind": "miasma_vein_lord"},
	]
	controller.state.node_flags = {"n1": "completed", "n2": "completed", "nb": "completed"}
	var extras: Dictionary = SnapshotBuilder.settlement_extras(controller)
	var route: Array = extras.get("route_summary", [])
	assert_eq(route.size(), 2, "unvisited nm skipped; same-stage visits share one layer")
	assert_eq(int(route[0].get("layer", 0)), 1)
	assert_eq(int(route[1].get("layer", 0)), 2)
	assert_eq((route[0].get("types", []) as Array).size(), 2, "same-stage visits share one layer chip")
	assert_eq(str((route[0].get("types", []) as Array)[0]), "接触", "types carry Chinese display labels")
	assert_eq(bool(route[0].get("boss", true)), false)
	assert_eq(bool(route[1].get("boss", false)), true, "catalog boss-tier enemy flags the layer")
	assert_eq(str((route[1].get("types", []) as Array)[0]), "交锋")


func test_settlement_extras_empty_when_nothing_visited() -> void:
	var controller := _new_controller()
	var extras: Dictionary = SnapshotBuilder.settlement_extras(controller)
	var route: Array = extras.get("route_summary", [])
	assert_eq(route.size(), 0)


func test_run_record_counts_only_outcome_reasons_and_shifts() -> void:
	var controller := _new_controller()
	var s = controller.state
	s = s.append_event({"action": "battle_synthesize", "before": {}, "after": {}, "reason": "battle_synthesis_materials_spent"})
	s = s.append_event({"action": "battle_synthesize", "before": {}, "after": {}, "reason": "battle_synthesis_succeeded"})
	s = s.append_event({"action": "battle_synthesize", "before": {}, "after": {}, "reason": "battle_synthesis_failed"})
	s = s.append_event({"action": "boss_phase_shift", "before": {}, "after": {"_from": 0, "_to": 1}, "reason": "boss_phase_shift"})
	controller.state = s
	var record: Dictionary = SnapshotBuilder.settlement_extras(controller).get("run_record", {})
	assert_eq(int(record.get("synthesis_attempts", 0)), 2, "materials-spent bookkeeping event must not count as an attempt")
	assert_eq(int(record.get("synthesis_ok", 0)), 1)
	assert_eq(int(record.get("synthesis_fail", 0)), 1)
	assert_eq(int(record.get("boss_phase_shifts", 0)), 1)
	assert_eq(int(record.get("dda_triggers", 0)), 0, "DDA is unimplemented; reserved slot stays zero")


func test_both_ending_paths_carry_review_fields() -> void:
	var controller := _new_controller()
	controller.route = [
		{"id": "nb", "type": "combat", "stage": "five", "enemy_kind": "miasma_vein_lord"},
	]
	controller.state.node_flags = {"nb": "completed"}
	var save_data: Dictionary = controller.state.to_save_data()
	var view: Dictionary = SnapshotBuilder.ending(controller, {"outcome": "success", "conditions": {}}, [], save_data)
	assert_true(view.has("route_summary"), "builder ending() must project route_summary")
	assert_true(view.has("run_record"), "builder ending() must project run_record")
	assert_eq(int(view.get("max_rank", 0)), int(controller.state.cultivator.get("reincarnation", 0)), "max_rank comes from the cultivator track")
	assert_ne(str(view.get("achievement", "")), "", "builder ending() must resolve the achievement chain")
	var death_view: Dictionary = SnapshotBuilder.ending(controller, {"outcome": "death", "conditions": {}}, [], save_data)
	assert_eq(str(death_view.get("achievement")), DisplayTextScript.ending_achievement("death"))
	controller.force_death_for_test("stone_palm")
	var inline: Dictionary = controller._ending_state
	assert_true(inline.has("route_summary"), "battle-death inline state must carry route_summary")
	assert_true(inline.has("run_record"), "battle-death inline state must carry run_record")
	assert_eq(int(inline.get("max_rank", 0)), int(controller.state.cultivator.get("reincarnation", 0)))
	assert_eq(str(inline.get("achievement")), DisplayTextScript.ending_achievement("death"))


func test_ending_screen_renders_route_strip_record_block_and_new_badges() -> void:
	var commands := {"to_hall": func(): pass, "to_codex": func(): pass}
	var state := {
		"title": "功成升仙",
		"ending_type": "success",
		"achievement": DisplayTextScript.ending_achievement("success"),
		"max_rank": 2,
		"route_summary": [
			{"layer": 1, "types": ["接触", "黑市"], "boss": false},
			{"layer": 2, "types": ["交锋"], "boss": true},
		],
		"run_record": {"synthesis_attempts": 2, "synthesis_ok": 1, "synthesis_fail": 1, "boss_phase_shifts": 1, "dda_triggers": 0},
		"key_decisions": [],
		"gains_losses": "",
		"resource_balance": {"yuanstone": 5, "shouyuan": 40},
		"unlocks": ["图鉴：火蛊"],
		"aftermath": "",
	}
	var host := _mount_screen({"state": state, "commands": commands})
	for i in 3:
		await get_tree().process_frame
	assert_true(_host_has_text(host, "达成：" + str(state["achievement"])), "chain line renders under the type panel title")
	assert_true(_host_has_text(host, "最高转数：2 转"), "§16.17 max-cultivation-rank stat line")
	assert_true(_host_has_text(host, "第1层 接触·黑市"), "route strip joins same-layer type glyphs")
	var boss_chip := _find_label_exact(host, "第2层 交锋")
	assert_true(boss_chip != null, "boss layer keeps its own chip")
	if boss_chip != null:
		assert_true(boss_chip.get_theme_color("font_color").is_equal_approx(GuStyle.RARITY_EPIC), "boss layer highlight uses epic accent")
	var plain_chip := _find_label_exact(host, "第1层 接触·黑市")
	if plain_chip != null:
		assert_false(plain_chip.get_theme_color("font_color").is_equal_approx(GuStyle.RARITY_EPIC), "non-boss layers stay dim")
	assert_true(_host_has_text(host, "战斗合成：2 次 · 成 1 / 败 1"), "record block counts attempts by outcome")
	assert_true(_host_has_text(host, "Boss 阶段切换：1 次"))
	assert_false(_host_has_text(host, "DDA"), "reserved DDA row stays hidden while empty")
	var unlock_row := _find_label_exact(host, "★新 图鉴：火蛊")
	assert_true(unlock_row != null, "settlement unlocks are marked unread-new")
	if unlock_row != null:
		assert_true(unlock_row.get_theme_color("font_color").is_equal_approx(GuStyle.ANOMALY_YELLOW), "★新 prefix renders in anomaly accent")
	assert_true(_host_has_text(host, "离局清零"), "resource panel carries the leave-run wipe small print")


func test_ending_screen_settlement_has_no_load_or_backtrack_affordance() -> void:
	var commands := {"to_hall": func(): pass, "to_codex": func(): pass}
	var state := {
		"title": "保命而退",
		"ending_type": "retreat",
		"achievement": DisplayTextScript.ending_achievement("retreat"),
		"key_decisions": [],
		"gains_losses": "",
		"resource_balance": {},
		"unlocks": [],
		"aftermath": "",
	}
	var host := _mount_screen({"state": state, "commands": commands})
	for i in 3:
		await get_tree().process_frame
	var buttons: Array = []
	var labels: Array = []
	_collect_controls(host, buttons, labels)
	assert_eq(buttons.size(), 2, "settlement exposes exactly two commands")
	var texts: Array[String] = []
	for b in buttons:
		texts.append(str(b.text))
	assert_true(texts.has("返回大厅") and texts.has("查看图鉴"), "only 返回大厅 / 查看图鉴 remain")
	for t in texts:
		assert_false(t.contains("读档") or t.contains("回溯"), "no load/backtrack affordance on settlement (§16.6)")
	for l in labels:
		var text := str(l.text)
		assert_false(text.contains("读档") or text.contains("继续上次"), "no resume wording anywhere on settlement")


func test_ending_screen_minimal_run_hides_route_and_record_panels() -> void:
	var commands := {"to_hall": func(): pass, "to_codex": func(): pass}
	var state := {
		"title": "保命而退",
		"ending_type": "retreat",
		"achievement": DisplayTextScript.ending_achievement("retreat"),
		"key_decisions": [],
		"gains_losses": "",
		"resource_balance": {},
		"unlocks": [],
		"aftermath": "",
	}
	var host := _mount_screen({"state": state, "commands": commands})
	for i in 3:
		await get_tree().process_frame
	assert_false(_host_has_text(host, "路线"), "no visited nodes means no route strip at all")
	assert_false(_host_has_text(host, "本局记录"), "empty record block hides entirely")
	assert_true(_host_has_text(host, "达成：" + str(state["achievement"])), "achievement chain still resolves")
