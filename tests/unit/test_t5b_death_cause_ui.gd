extends GutTest


# T5-B: D2 death-line warning hardening + precise death-cause overlay and
# settlement linkage. Locks:
#   - death_cause_short presentation mapping (display_text.gd)
#   - death_cause/{id,short,text} snapshot fields on BOTH ending paths
#     (builder `ending()` and the battle-death `_show_death` inline state),
#     empty for non-death endings
#   - ☠ danger rows: whole-row clickable only when wired, blood-bar stylebox
#   - pure-UI overlay gate on battle/encounter screens (no controller roundtrip)
#   - 死因 badge on the ending screen for death endings only


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const SnapshotBuilder = preload("res://scripts/presentation/run_snapshot_builder.gd")
const DisplayTextScript = preload("res://scripts/presentation/display_text.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")

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
		# 立即 free（queue_free 是延迟的，脚本收尾时仍会挂成孤儿，触发 GUT 警告）。
		if h != null and is_instance_valid(h):
			h.free()
	_rui_hosts.clear()


func _mount_screen(screen_path: String, props: Dictionary) -> Control:
	var fn = VLib.comp(screen_path, "render")
	assert_true(fn is Callable, screen_path + " must expose render")
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


func _press_button(host: Node, text: String, occurrence := 0) -> bool:
	var buttons: Array = []
	var labels: Array = []
	_collect_controls(host, buttons, labels)
	var seen := 0
	for b in buttons:
		if b.text == text and not b.disabled:
			if seen == occurrence:
				b.pressed.emit()
				return true
			seen += 1
	return false


func _has_button_with_text(host: Node, prefix: String) -> bool:
	var buttons: Array = []
	var labels: Array = []
	_collect_controls(host, buttons, labels)
	for b in buttons:
		if str(b.text).begins_with(prefix):
			return true
	return false


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


func test_display_text_maps_precise_death_cause_shorts() -> void:
	assert_eq(DisplayTextScript.death_cause_short("death_cause_lifespan"), "寿元枯竭")
	assert_eq(DisplayTextScript.death_cause_short("death_cause_soul"), "魂魄耗尽")
	assert_eq(DisplayTextScript.death_cause_short("death_cause_backlash"), "反噬爆发")
	assert_eq(DisplayTextScript.death_cause_short("death_cause_battle"), "战局失利")
	assert_eq(DisplayTextScript.death_cause_short(""), "")
	assert_eq(DisplayTextScript.death_cause_short("unknown_id"), "")


func test_ending_builder_carries_death_cause_only_for_deaths() -> void:
	var controller := _new_controller()
	var journal: Array[Dictionary] = []
	var save_data: Dictionary = controller.state.to_save_data()
	var death_view: Dictionary = SnapshotBuilder.ending(controller, {"outcome": "death", "conditions": {}}, journal, save_data)
	assert_eq(str(death_view.get("ending_type")), "death")
	assert_eq(str(death_view.get("death_cause_id")), "death_cause_battle",
			"a fresh healthy run dying must attribute to battle, not resources")
	assert_eq(str(death_view.get("death_cause")), DisplayTextScript.death_cause("death_cause_battle"))
	assert_eq(str(death_view.get("death_cause_short")), "战局失利")
	var retreat_view: Dictionary = SnapshotBuilder.ending(controller, {"outcome": "survived_failure", "conditions": {}}, journal, save_data)
	assert_eq(str(retreat_view.get("death_cause_id")), "", "non-death endings must not carry a death cause id")
	assert_eq(str(retreat_view.get("death_cause")), "", "non-death endings must not say 死因未明")
	assert_eq(str(retreat_view.get("death_cause_short")), "")


func test_battle_death_report_path_injects_death_cause_fields() -> void:
	var controller := _new_controller()
	controller.force_death_for_test("stone_palm")
	var view: Dictionary = controller._ending_state
	assert_eq(str(view.get("ending_type")), "death")
	assert_eq(str(view.get("death_cause_id")), "death_cause_battle",
			"_show_death inline state must carry the precise cause id")
	assert_eq(str(view.get("death_cause_short")), "战局失利")
	assert_ne(str(view.get("death_cause")), "")


func test_death_line_widget_rows_clickable_only_when_wired() -> void:
	var lines := {
		"shouyuan": {"name": "寿元", "remaining": 3, "max": 60, "danger": true, "cause_id": "death_cause_lifespan"},
		"hunpo": {"name": "魂魄", "remaining": 9, "max": 10, "danger": false},
		"backlash": {"name": "反噬", "remaining": 3, "max": 3, "danger": true, "cause_id": "death_cause_backlash"},
	}
	var wired_host := _mount_screen("res://ui/widgets/gu_death_line_warning.gd",
			{"death_lines": lines, "on_view": func(_cid = ""): pass})
	var buttons: Array = []
	var labels: Array = []
	_collect_controls(wired_host, buttons, labels)
	assert_eq(buttons.size(), 2, "exactly the two danger rows become buttons")
	assert_true(_has_button_with_text(wired_host, "☠ 寿元"), "danger rows use the ☠ prefix")
	assert_true(_host_has_text(wired_host, "· 魂魄"), "safe rows keep the plain prefix")
	for b in buttons:
		var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
		assert_true(sb != null and sb.bg_color.is_equal_approx(Color(0.55, 0.18, 0.15, 0.25)),
				"danger rows carry the translucent blood bar")
		assert_true(b.has_theme_font_size_override("font_size") and b.get_theme_font_size("font_size") == 15,
				"danger rows are emphasized (+2 over the 13px base)")
	var bare_host := _mount_screen("res://ui/widgets/gu_death_line_warning.gd", {"death_lines": lines})
	var bare_buttons: Array = []
	var bare_labels: Array = []
	_collect_controls(bare_host, bare_buttons, bare_labels)
	assert_eq(bare_buttons.size(), 0, "unwired warning renders no buttons")
	assert_true(_host_has_text(bare_host, "☠ 寿元"), "unwired danger rows still show the ☠ marker")


func test_battle_screen_danger_row_opens_and_closes_death_cause_overlay() -> void:
	var commands := {
		"play_card": func(_cid = "", _tgt = ""): pass,
		"end_turn": func(): pass,
		"flee": func(): pass,
	}
	var state := {
		"enemies": [{"id": "e1", "name": "铁皮山猪", "hp": 20, "max_hp": 30, "intent": {"type": "attack", "value": 12, "detail": "冲撞"}}],
		"player": {"hp": 24, "max_hp": 30, "shield": 0, "primordial": 3, "soul": 4, "statuses": []},
		"hand": [],
		"can_ultimate": false,
		"resources": {"yuanstone": 12, "shouyuan": 5, "hunpo": 1, "material": 0},
		"contracts": [],
		"anomalies": [],
		"death_lines": {
			"shouyuan": {"id": "shouyuan", "name": "寿元", "value": 55, "threshold": 55,
				"remaining": 5, "max": 60, "danger": true, "cause_id": "death_cause_lifespan", "detail": "寿元耗尽即死。"},
		},
	}
	var host := _mount_screen("res://ui/screens/battle_screen.gd", {"state": state, "commands": commands})
	for i in 3:
		await get_tree().process_frame
	assert_true(_press_button(host, "☠ 寿元 55/55"), "the danger death-line row itself must be clickable")
	for i in 3:
		await get_tree().process_frame
	assert_true(_host_has_text(host, "死因 · 寿元"), "overlay header names the line")
	assert_true(_host_has_text(host, "当前值：5 / 上限：60"), "overlay shows current vs cap")
	assert_false(_host_has_text(host, "距离死线余量"), "Fix1: constant-zero margin line removed entirely")
	assert_true(_host_has_text(host, "成因：寿元耗尽即死。"), "overlay explains the cause")
	assert_false(_host_has_text(host, "⚠ 确认"), "the overlay must not reuse confirm-dialog semantics")
	assert_true(_press_button(host, "关闭"), "overlay offers a close action")
	for i in 3:
		await get_tree().process_frame
	assert_false(_host_has_text(host, "成因：寿元耗尽即死。"), "closing hides the overlay")
	assert_true(_press_button(host, "结束回合"), "screen remains interactive after close")


func test_encounter_screen_danger_row_opens_death_cause_overlay() -> void:
	var commands := {
		"choose_option": func(_a = ""): pass,
		"confirm_danger": func(_a = ""): pass,
		"leave": func(): pass,
	}
	var state := {
		"node": {"title": "幽林遭遇", "desc": "林中传来异响。", "type": "contact"},
		"actions": [{"id": "leave", "label": "离开", "detail": "", "dangerous": false}],
		"intel": {},
		"resources": {"yuanstone": 12, "shouyuan": 40, "hunpo": 1, "material": 0},
		"contracts": [],
		"anomalies": [],
		"death_lines": {
			"hunpo": {"id": "hunpo", "name": "魂魄", "value": 4, "threshold": 4,
				"remaining": 1, "max": 6, "danger": true, "cause_id": "death_cause_soul", "detail": "魂魄耗尽即死。"},
		},
	}
	var host := _mount_screen("res://ui/screens/encounter_screen.gd", {"state": state, "commands": commands})
	for i in 3:
		await get_tree().process_frame
	assert_true(_press_button(host, "☠ 魂魄 4/4"), "danger row opens the cause overlay")
	for i in 3:
		await get_tree().process_frame
	assert_false(_host_has_text(host, "距离死线余量"), "Fix1: no margin line on the encounter overlay either")
	assert_true(_host_has_text(host, "成因：魂魄耗尽即死。"))
	assert_true(_press_button(host, "关闭"))
	for i in 3:
		await get_tree().process_frame
	assert_false(_host_has_text(host, "成因：魂魄耗尽即死。"))


func test_ending_screen_renders_death_cause_badge_for_deaths_only() -> void:
	var commands := {"to_hall": func(): pass, "to_codex": func(): pass}
	var death_state := {
		"title": "命丧密林",
		"ending_type": "death",
		"death_cause": "战局失利而亡——气血先一步断绝于敌手之下。",
		"death_cause_short": "战局失利",
		"key_decisions": [],
		"gains_losses": "",
		"resource_balance": {},
		"unlocks": [],
		"aftermath": "",
	}
	var death_host := _mount_screen("res://ui/screens/ending_screen.gd", {"state": death_state, "commands": commands})
	for i in 3:
		await get_tree().process_frame
	assert_true(_host_has_text(death_host, "死因 · 战局失利"), "death endings show the cause badge next to the type badge")
	var badge := _find_label_exact(death_host, "死因 · 战局失利")
	assert_true(badge != null, "badge must render as its own label for color checks")
	if badge != null:
		assert_true(badge.get_theme_color("font_color").is_equal_approx(GuStyle.CINNABAR),
				"Fix M4: the death-cause badge text must be BLOOD (not blended with the type-badge color)")
	var retreat_state := death_state.duplicate(true)
	retreat_state["ending_type"] = "retreat"
	retreat_state.erase("death_cause")
	retreat_state.erase("death_cause_short")
	var retreat_host := _mount_screen("res://ui/screens/ending_screen.gd", {"state": retreat_state, "commands": commands})
	for i in 3:
		await get_tree().process_frame
	assert_false(_host_has_text(retreat_host, "死因 · "), "non-death endings show no cause badge")


## Fix2：快照→浮层端到端契约。真实 RunState 逼近死线 → 屏幕实际消费的
## 快照路径（controller._snapshot_for("Battle")，即 _render() 所喂）→
## RuiRoot 挂载 battle_screen → 点 ☠ 行 → 断言 builder 原值逐字到达浮层。
func test_real_snapshot_death_lines_feed_battle_overlay_end_to_end() -> void:
	var controller := _new_controller()
	controller.state.cultivator["lifespan"] = 2
	controller.current_node = {"id": "beast_swarm_pass", "type": "combat", "enemy_kind": "ridge_hound"}
	controller.current_session = EncounterSessionResolverScript.start(controller.current_node)
	controller._start_battle()
	var snapshot: Dictionary = controller._snapshot_for("Battle")
	# Producer side: the real builder must flag 寿元 as a danger line with full shape.
	assert_true(snapshot.has("death_lines"), "battle snapshot must carry death_lines")
	var shouyuan: Dictionary = snapshot["death_lines"].get("shouyuan", {})
	assert_eq(str(shouyuan.get("cause_id", "")), "death_cause_lifespan")
	assert_true(bool(shouyuan.get("danger", false)), "lifespan 2 (<= floor 5) must be flagged danger by the builder")
	assert_gt(int(shouyuan.get("value", 0)), int(shouyuan.get("threshold", 0)), "danger row sits at/past the threshold")
	var want_name := str(shouyuan["name"])
	var want_current := int(shouyuan["remaining"])
	var want_max := int(shouyuan["max"])
	var want_detail := str(shouyuan["detail"])
	assert_ne(want_name, "", "builder must supply the display name")
	assert_ne(want_detail, "", "builder must supply the cause detail")

	# Consumer side: mount the real screen with the real snapshot.
	var commands := {
		"play_card": func(_cid = "", _tgt = ""): pass,
		"end_turn": func(): pass,
	}
	var host := _mount_screen("res://ui/screens/battle_screen.gd", {"state": snapshot, "commands": commands})
	for i in 3:
		await get_tree().process_frame
	var row_text := "☠ %s %d/%d" % [want_name, int(shouyuan["value"]), int(shouyuan["threshold"])]
	assert_true(_press_button(host, row_text), "builder-produced danger row must be clickable under its mapped text")
	for i in 3:
		await get_tree().process_frame
	assert_true(_host_has_text(host, "死因 · " + want_name), "name flows from builder to overlay header")
	assert_true(_host_has_text(host, "当前值：%d / 上限：%d" % [want_current, want_max]),
			"remaining/max flow from builder to the current-vs-cap line")
	assert_true(_host_has_text(host, "成因：" + want_detail), "detail flows verbatim from builder to overlay")
	assert_false(_host_has_text(host, "距离死线余量"), "no margin line anywhere in the end-to-end path")
