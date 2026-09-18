extends SceneTree

## Rest screen headless regression gate (1280x720 layout budget):
##   1. LeaveRow (leave + pinned skip entry) must stay inside the visible window;
##   2. the trailing skip card in the choice grid must become visible after
##      scrolling the primary decision surface to the bottom (no soft lock);
##   3. the pinned skip entry must open the confirm dialog (no dead button).
## Usage:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/verify_rest_headless.gd

const RestScene := "res://scenes/ui/screens/rest_screen.tscn"
const SnapshotBuilder := preload("res://scripts/presentation/run_snapshot_builder.gd")

var _fails: Array[String] = []


func _initialize() -> void:
	var snapshot: Dictionary = SnapshotBuilder.rest(_stub())
	var cmds := {
		"choose": func(_cid: Variant) -> void: pass,
		"mode_action": func(_cid: Variant) -> void: pass,
		"leave": func() -> void: pass,
		"close": func() -> void: pass,
	}
	# Headless root is a fixed 64x64 window; a 1280x720 SubViewport reproduces
	# the real project viewport so layout rects and engine GUI picking are
	# measured in true window coordinates.
	var view := SubViewport.new()
	view.size = Vector2(1280, 720)
	root.add_child(view)
	var screen: Control = (load(RestScene) as PackedScene).instantiate()
	view.add_child(screen)
	screen.mount_snapshot(snapshot, cmds)
	for _frame in 4:
		await process_frame

	var win := Rect2(0, 0, 1280, 720)
	_check("snapshot carries 7 choices incl skip+wash", _choices_ok(snapshot))

	# 1. LeaveRow must be visible without scrolling.
	var leave_btn: Button = screen.get_node_or_null("Root/RestStage/StageContent/LeaveRow/LeaveButton")
	_check_rect("LeaveButton inside window", leave_btn, win)
	var skip_entry := _find_button_by_text(screen, "跳过 · 放弃收益")
	_check_rect("pinned skip entry inside window", skip_entry, win)

	# 2. Grid skip card reachable via the choice scroll.
	var scroll := _find_scroll(screen)
	_check("choice ScrollContainer exists", scroll != null)
	if scroll != null:
		# The scroll viewport must own real height (ContentHost expand chain);
		# a 0-height viewport would clip every card into unclickability.
		_check("scroll viewport has height", scroll.size.y >= 150.0)
		# First choice row must be engine-pickable without scrolling.
		var heal_card := _find_button_under_panel(screen, "调息回血")
		if heal_card != null:
			var heal_picked := _engine_pick(view, heal_card.get_global_rect().get_center())
			if heal_picked != heal_card:
				await process_frame
				heal_picked = view.gui_get_hovered_control()
			_check("engine picks first choice card without scrolling", heal_picked == heal_card)
		scroll.scroll_vertical = 100000
		await process_frame
		await process_frame
		var skip_card := _find_button_under_panel(screen, "放弃收益并离开")
		_check_rect("grid skip card visible after scroll", skip_card, win)
		if skip_card != null:
			var picked := _engine_pick(view, skip_card.get_global_rect().get_center())
			if picked != skip_card:
				await process_frame
				picked = view.gui_get_hovered_control()
			_check("engine picks the skip card at its center", picked == skip_card)

	# 3. Pinned skip entry opens the confirm dialog.
	if skip_entry != null and not skip_entry.disabled:
		skip_entry.pressed.emit()
		await process_frame
		var dialog: Control = screen.get_node_or_null("Root/ConfirmDialog")
		_check("skip entry opens confirm dialog", dialog != null and dialog.visible)

	if _fails.is_empty():
		print("REST HEADLESS OK")
		quit(0)
	else:
		for f in _fails:
			print("REST FAIL: " + f)
		quit(1)


func _choices_ok(snapshot: Dictionary) -> bool:
	var ids: Array[String] = []
	for c in snapshot.get("choices", []):
		if c is Dictionary:
			ids.append(str(c.get("id", "")))
	return ids.has("skip") and ids.has("wash") and ids.size() == 7


func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails.append(what)


func _check_rect(what: String, ctrl: Control, win: Rect2) -> void:
	if ctrl == null:
		_fails.append(what + " (node missing)")
		return
	if not win.intersects(ctrl.get_global_rect()):
		_fails.append("%s global_rect=%s window=%s" % [what, ctrl.get_global_rect(), win])


func _find_button_by_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button_by_text(child, text)
		if found != null:
			return found
	return null


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var found := _find_scroll(child)
		if found != null:
			return found
	return null


## Real engine GUI picking inside the subviewport at the given position.
func _engine_pick(view: SubViewport, pos: Vector2) -> Control:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	view.push_input(motion)
	return view.gui_get_hovered_control()


## The confirm button of the choice card whose panel title matches.
func _find_button_under_panel(node: Node, panel_title: String) -> Button:
	if node is GuPanelView and (node as GuPanelView).get_node_or_null(
			"PanelMargin/PanelBody/TitleRow/TitleLabel") != null \
			and _panel_title(node) == panel_title:
		return _find_button_by_text(node, "选择")
	for child in node.get_children():
		var found := _find_button_under_panel(child, panel_title)
		if found != null:
			return found
	return null


func _panel_title(panel: Node) -> String:
	var label: Label = panel.get_node("PanelMargin/PanelBody/TitleRow/TitleLabel")
	return label.text


func _stub() -> RefCounted:
	var stub := _Stub.new()
	stub.state = RunState.new_run(101)
	stub.state.current_node_id = "rest_seclusion_probe"
	stub.current_node = {"id": "rest_seclusion_probe", "type": "seclusion"}
	stub.catalog = ContentCatalog.load_all()
	return stub


class _Stub:
	extends RefCounted
	var state: RunState
	var current_node: Dictionary
	var catalog: Dictionary
	var current_session: Dictionary = {}
	var current_battle: Dictionary = {}
