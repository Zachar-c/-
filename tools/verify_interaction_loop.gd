extends SceneTree
## Interactive-loop audit v2: reach every screen possible headless,
## enumerate BaseButton nodes, report:
##  - dead buttons: clickable (visible+enabled) with zero pressed connections
##  - audio coverage: whether the button went through MasterTheme.apply_button
##    (detected via font_hover_color override), i.e. ui_click is wired.
## Never emits pressed; inspection only.

const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")


func _collect_buttons(root_node: Node) -> Array:
	var out: Array = []
	for node in _walk(root_node):
		if node is BaseButton:
			var b: BaseButton = node
			var conns := b.pressed.get_connections()
			out.append({
				"path": str(b.get_path()),
				"text": str(b.text if "text" in b else ""),
				"connected": conns.size() > 0,
				"conn_count": conns.size(),
				"visible": b.is_visible_in_tree(),
				"disabled": b.disabled,
				"themed": b.has_theme_color_override("font_hover_color"),
			})
	return out


func _walk(root: Node) -> Array:
	var acc: Array = [root]
	for child in root.get_children():
		acc.append_array(_walk(child))
	return acc


func _report(label: String, controller: Node) -> void:
	var host: Node = controller.get_node_or_null("RUIHost")
	if host == null:
		print("AUDIT[%s] NO_HOST" % label)
		return
	var master: Node = null
	for child in host.get_children():
		if str(child.name).begins_with("Wenzhen"):
			master = child
			break
	if master == null and host.get_child_count() > 0:
		master = host.get_child(0)
	if master == null:
		print("AUDIT[%s] NO_MASTER children=%d" % [label, host.get_child_count()])
		return
	var btns := _collect_buttons(master)
	var dead: Array = []
	var no_sfx: Array = []
	for b in btns:
		if b["visible"] and not b["disabled"] and not b["connected"]:
			dead.append("%s(%s)" % [b["path"], b["text"]])
		# Audio coverage: MasterTheme.apply_button wires ui_click (themed), or
		# >=2 pressed connections = business handler + separate sfx wiring.
		if b["visible"] and not b["disabled"] and not (b["themed"] or b["conn_count"] >= 2):
			no_sfx.append("%s(%s)" % [b["path"], b["text"]])
	var clickable := 0
	for b in btns:
		if b["visible"] and not b["disabled"]:
			clickable += 1
	print("AUDIT[%s] total=%d clickable=%d dead=%s no_ui_click=%s" % [label, btns.size(), clickable, str(dead), str(no_sfx)])


func _travel(controller: Node, want_type: String) -> String:
	for node_value in controller.visible_route_nodes(3):
		var node: Dictionary = node_value
		if str(node.get("type", "")) == want_type:
			var nid := str(node.get("id", ""))
			var r: Dictionary = controller.submit_command({"type": "travel", "node_id": nid})
			if bool(r.get("ok", false)):
				return nid
	return ""


func _initialize() -> void:
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	await process_frame
	_report("Hall", controller)
	controller.start_new_run(20260909, "", [])
	await process_frame
	await process_frame
	_report("Map", controller)
	# battle
	if _travel(controller, "combat") != "":
		await process_frame
		await process_frame
		_report("Battle", controller)
		controller.submit_command({"type": "leave_encounter"})
		await process_frame
		await process_frame
	# rest
	if _travel(controller, "rest") != "":
		await process_frame
		await process_frame
		_report("Rest", controller)
		controller.submit_command({"type": "rest", "mode": "skip"})
		await process_frame
		await process_frame
	# shop
	if _travel(controller, "shop") != "":
		await process_frame
		await process_frame
		_report("Shop", controller)
		controller.submit_command({"type": "leave_encounter"})
		await process_frame
		await process_frame
	# refine
	if _travel(controller, "refinement") != "":
		await process_frame
		await process_frame
		_report("Refine", controller)
		controller.submit_command({"type": "leave_encounter"})
		await process_frame
		await process_frame
	# encounter via inheritance (anchor-guaranteed)
	if _travel(controller, "inheritance") != "":
		await process_frame
		await process_frame
		_report("Encounter", controller)
		controller.submit_command({"type": "leave_encounter"})
		await process_frame
		await process_frame
	# settings / kill overlays
	controller._show_settings()
	await process_frame
	_report("Settings", controller)
	controller.back_from_overlay()
	await process_frame
	controller._show_kill()
	await process_frame
	_report("Kill", controller)
	controller.back_from_overlay()
	await process_frame
	print("AUDIT_DONE")
	quit(0)
