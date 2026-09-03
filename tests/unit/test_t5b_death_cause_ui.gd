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
var _tscn_hosts: Array = []


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
	for t in _tscn_hosts:
		if t != null and is_instance_valid(t):
			t.free()
	_tscn_hosts.clear()


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


## 挂载 Godot 官方 .tscn 节点树屏（遭遇屏已迁离 RUITK）。
## mount_snapshot 可能早于 _ready()，屏内自行兜底补刷新。
func _mount_tscn_screen(scene_path: String, snapshot: Dictionary, commands: Dictionary) -> Control:
	var inst: Control = (load(scene_path) as PackedScene).instantiate()
	add_child(inst)
	_tscn_hosts.append(inst)
	if inst.has_method("mount_snapshot"):
		inst.mount_snapshot(snapshot, commands)
	return inst


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


func test_battle_screen_keeps_danger_on_existing_top_bar_without_death_line_overlay() -> void:
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
	# 战斗屏已迁到 Godot 官方 .tscn。
	var host := _mount_tscn_screen(
			"res://scenes/ui/screens/battle_screen.tscn", state, commands)
	for i in 3:
		await get_tree().process_frame
	assert_null(host.get_node_or_null("Root/CauseOverlay"),
			"battle may not mount a standalone death-cause overlay")
	assert_false(_host_has_text(host, "☠"), "battle may not render independent death-line rows")
	var chip := host.find_child("ChipShouyuan", true, false) as Control
	assert_not_null(chip, "battle top bar must retain its lifespan resource chip")
	if chip == null:
		return
	assert_eq(chip.tooltip_text, "寿元耗尽即死。",
			"danger detail belongs to the existing lifespan resource chip")
	assert_true(_press_button(host, "结束回合"), "screen remains interactive with a danger warning")


func test_encounter_screen_keeps_danger_on_existing_top_bar_without_death_line_overlay() -> void:
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
	var host := _mount_tscn_screen(
			"res://scenes/ui/screens/encounter_screen.tscn", state, commands)
	for i in 3:
		await get_tree().process_frame
	assert_null(host.get_node_or_null("Root/CauseOverlay"),
			"encounter may not mount a standalone death-cause overlay")
	assert_false(_host_has_text(host, "☠"), "encounter may not render independent death-line rows")
	var chip := host.find_child("ChipHunpo", true, false) as Control
	assert_not_null(chip, "encounter top bar must retain its soul resource chip")
	if chip == null:
		return
	assert_eq(chip.tooltip_text, "魂魄耗尽即死。",
			"danger detail belongs to the existing soul resource chip")


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
	var death_host := _mount_tscn_screen(
			"res://scenes/ui/screens/ending_screen.tscn", death_state, commands)
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
	var retreat_host := _mount_tscn_screen(
			"res://scenes/ui/screens/ending_screen.tscn", retreat_state, commands)
	for i in 3:
		await get_tree().process_frame
	assert_false(_host_has_text(retreat_host, "死因 · "), "non-death endings show no cause badge")


## 快照→顶栏端到端契约。真实 RunState 逼近寿元预警 → 屏幕实际消费的
## 快照路径（controller._snapshot_for("Battle")）→ RuiRoot 挂载 battle_screen →
## 断言死因说明进入既有寿元资源 chip 的 tooltip，不生成独立面板。
func test_real_snapshot_death_lines_feed_battle_top_bar_tooltip_end_to_end() -> void:
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
	var want_detail := str(shouyuan["detail"])
	assert_ne(want_detail, "", "builder must supply the cause detail")

	# Consumer side: mount the real screen with the real snapshot.
	var commands := {
		"play_card": func(_cid = "", _tgt = ""): pass,
		"end_turn": func(): pass,
	}
	# 战斗屏已迁到 Godot 官方 .tscn。
	var host := _mount_tscn_screen(
			"res://scenes/ui/screens/battle_screen.tscn", snapshot, commands)
	for i in 3:
		await get_tree().process_frame
	assert_null(host.get_node_or_null("Root/CauseOverlay"),
			"the real screen must not recreate a death-cause overlay")
	var chip := host.find_child("ChipShouyuan", true, false) as Control
	assert_not_null(chip, "battle top bar must retain its lifespan resource chip")
	if chip == null:
		return
	assert_eq(chip.tooltip_text, want_detail,
			"builder detail flows to the existing lifespan chip tooltip")
