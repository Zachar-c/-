extends GutTest


# T5-A: D1 confirm-dialog family + D4 save toast.
# Locks the R1.5 save feedback wording, the snapshot toast passthrough,
# the reserved hall version-warning slot (§16.22), the map save_run command
# surface, and the R6.7 emergency-payment confirm gate.


const SAVE_FEEDBACK := "进度已保存 · 关闭游戏后可继续本次冒险"

const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")

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
		if h != null and is_instance_valid(h):
			h.queue_free()
	_rui_hosts.clear()


func _mount_screen(screen_path: String, props: Dictionary) -> Control:
	var fn = VLib.comp(screen_path, "render")
	assert_true(fn is Callable, screen_path + " must expose render")
	if not (fn is Callable):
		return Control.new()
	var host := Control.new()
	add_child(host)
	_rui_hosts.append(host)
	# Retain the RuitkRoot: unreferenced roots can be collected, silently
	# stopping scheduled re-renders (RunController keeps its root as a member).
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


func _host_has_text(host: Node, wanted: String) -> bool:
	var buttons: Array = []
	var labels: Array = []
	_collect_controls(host, buttons, labels)
	for l in labels:
		if str(l.text).contains(wanted):
			return true
	return false


func test_save_run_feedback_uses_continue_wording() -> void:
	var controller := _new_controller()
	var result := controller.submit_command({"type": "save_run"})
	assert_true(bool(result.get("ok", false)), "save_run must succeed")
	assert_eq(str(result.get("feedback", "")), SAVE_FEEDBACK)


func test_load_run_feedback_never_says_du_dang() -> void:
	if FileAccess.file_exists("user://nanjiang_smoke_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nanjiang_smoke_save.json"))
	var controller := _new_controller()
	var result := controller.submit_command({"type": "load_run"})
	assert_false(str(result.get("feedback", "")).contains("读档"), "no load-save wording allowed (R1.5)")
	assert_false(controller.last_feedback.contains("读档"), "toast text must avoid 读档 wording")


func test_map_snapshot_exposes_toast_from_controller_feedback() -> void:
	var controller := _new_controller()
	assert_eq(str(controller._snapshot_for("Map").get("toast", "missing")), "", "toast empty before feedback")
	controller.submit_command({"type": "save_run"})
	assert_eq(str(controller._snapshot_for("Map").get("toast", "missing")), SAVE_FEEDBACK)


func test_hall_snapshot_reserves_version_warning_slot() -> void:
	var controller := _new_controller()
	var snapshot: Dictionary = controller._snapshot_for("Title")
	assert_true(snapshot.has("hall_version_warning"), "hall must reserve the version-conflict slot")
	assert_eq(str(snapshot.get("hall_version_warning", "")), "")


func test_map_commands_expose_save_run_and_drive_feedback() -> void:
	var controller := _new_controller()
	var commands: Dictionary = controller._build_commands("Map")
	assert_true(commands.has("save_run"), "map screen must receive the save_run entry (R1.5)")
	commands["save_run"].call()
	assert_eq(controller.last_feedback, SAVE_FEEDBACK, "map 存档 button path must produce the save toast text")


func test_shop_snapshot_flags_unaffordable_offers_for_emergency() -> void:
	var controller := _new_controller()
	controller.state.stone = 999999
	var rich: Dictionary = controller._snapshot_for("Shop")
	for o in rich.get("offers", []):
		assert_false(bool(o.get("will_emergency_pay", false)), "affordable offers must not flag emergency pay")
	controller.state.stone = 0
	var broke: Dictionary = controller._snapshot_for("Shop")
	var saw_stone_priced := false
	for o in broke.get("offers", []):
		if bool(o.get("curse_warning", false)):
			continue
		var price_text := str(o.get("price", ""))
		var stone_cost := 0
		if price_text.ends_with(" 元石"):
			stone_cost = int(price_text.trim_suffix(" 元石"))
		if stone_cost > 0:
			saw_stone_priced = true
		assert_eq(bool(o.get("will_emergency_pay", false)), stone_cost > 0,
				"emergency flag must match unaffordable stone-priced offers only")
	assert_true(saw_stone_priced, "catalog must expose at least one stone-priced offer for the gate")


func test_shop_emergency_offer_opens_dialog_and_affordable_buys_directly() -> void:
	var bought: Array = []
	var commands := {
		"buy": func(id = ""): bought.append(str(id)),
		"block": func(_a = ""): pass,
		"use_service": func(_a = ""): pass,
		"leave": func(): pass,
	}

	# Case A: stones = 0 → a non-cursed stone-priced offer is emergency-flagged.
	var broke_controller := _new_controller()
	broke_controller.state.stone = 0
	var broke_snapshot: Dictionary = broke_controller._snapshot_for("Shop")
	var emergency_offer := {}
	for o in broke_snapshot.get("offers", []):
		if not bool(o.get("curse_warning", false)) and bool(o.get("will_emergency_pay", false)):
			emergency_offer = o
			break
	assert_false(emergency_offer.is_empty(), "catalog must contain a non-cursed emergency-flagged offer")
	if emergency_offer.is_empty():
		return
	var expected_id := str(emergency_offer.get("id", ""))
	# Mount with ONLY the target offer so exactly one 购买此蛊 button exists.
	broke_snapshot["offers"] = [emergency_offer]
	broke_snapshot["services"] = []
	var broke_host := _mount_screen("res://ui/screens/shop_screen.gd", {"state": broke_snapshot, "commands": commands})
	for i in 3:
		await get_tree().process_frame
	assert_true(_press_button(broke_host, "购买此蛊", 0), "emergency offer buy button must exist")
	for i in 3:
		await get_tree().process_frame
	# Dialog-specific copy (「元石不足」 only appears in the dialog note, never in the standing note).
	assert_true(_host_has_text(broke_host, "⚠ 应急支付") and _host_has_text(broke_host, "元石不足"),
			"unaffordable plain offer must open the emergency dialog")
	assert_false(bought.has(expected_id), "no command before confirmation")
	assert_true(_press_button(broke_host, "确认支付"), "emergency dialog confirm button must exist")
	for i in 3:
		await get_tree().process_frame
	assert_true(bought.has(expected_id), "confirm must fire buy for the emergency offer")

	# Case B: stones huge → the same class of offer buys directly without any dialog.
	var rich_controller := _new_controller()
	rich_controller.state.stone = 999999
	var rich_snapshot: Dictionary = rich_controller._snapshot_for("Shop")
	var affordable_offer := {}
	for ro in rich_snapshot.get("offers", []):
		if not bool(ro.get("curse_warning", false)) and not bool(ro.get("will_emergency_pay", false)):
			affordable_offer = ro
			break
	assert_false(affordable_offer.is_empty(), "rich run must expose a plain affordable offer")
	if affordable_offer.is_empty():
		return
	var affordable_id := str(affordable_offer.get("id", ""))
	rich_snapshot["offers"] = [affordable_offer]
	rich_snapshot["services"] = []
	var rich_host := _mount_screen("res://ui/screens/shop_screen.gd", {"state": rich_snapshot, "commands": commands})
	for i in 3:
		await get_tree().process_frame
	assert_true(_press_button(rich_host, "购买此蛊", 0), "affordable buy button must exist")
	for i in 3:
		await get_tree().process_frame
	assert_true(bought.has(affordable_id), "affordable plain offer must buy directly")
	# The dialog TITLE is unique; 「元石不足」 alone also matches the standing R6.7 note.
	assert_false(_host_has_text(rich_host, "⚠ 应急支付"), "no emergency dialog for affordable offers")
