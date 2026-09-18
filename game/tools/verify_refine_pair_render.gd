extends SceneTree

## D1b 自由配对渲染探针：挂真实 refine_screen.tscn + RunController 快照，
## 切到 free_pair 通道渲染，文本断言三层揭示（？？？/实名）与选择回显。
## headless 无渲染目标 → 文本/节点断言兜底（无白屏色彩段）。

const RefineScene := "res://scenes/ui/screens/refine_screen.tscn"
const RUN_CONTROLLER := preload("res://scripts/presentation/run_controller.gd")
const SNAPSHOT := preload("res://scripts/presentation/run_snapshot_builder.gd")


func _initialize() -> void:
	var controller: RunController = RUN_CONTROLLER.new()
	controller.start_new_run(20260907, "light", [])
	controller.state.stone = 5000
	# 取前两只洞天蛊作主/辅（light starter 均 rank1）。
	var stored: Array = controller.state.cave_aperture.get("stored_gu_instance_ids", [])
	if stored.size() < 2:
		push_error("需要至少两只洞天蛊做配对候选")
		quit(1)
		return
	var main_id := str(stored[0])
	var partner_id := str(stored[1])
	controller._selected_pair_main = main_id
	controller._selected_pair_partner = partner_id

	var scene: PackedScene = load(RefineScene)
	var view: Control = scene.instantiate()
	root.add_child(view)
	await process_frame
	var snapshot: Dictionary = SNAPSHOT.refine(controller)
	var cmds := {
		"refine": Callable(self, "_noop"),
		"dismantle": Callable(self, "_noop"),
		"select_pair_main": Callable(self, "_noop"),
		"select_pair_partner": Callable(self, "_noop"),
		"refine_free_pair": Callable(self, "_noop"),
		"leave": Callable(self, "_noop"),
	}
	view.mount_snapshot(snapshot, cmds)
	view._channel = "free_pair"
	view._refresh_recipes()
	await process_frame
	RenderingServer.force_draw()

	var unknown := {"title": false, "pair": false, "domains": false, "go": false, "needle": false, "double": false}
	_walk(view, func(n: Node) -> void:
		if n is Label:
			var t := str((n as Label).text)
			if t == "自由配对" or t.contains("自由配对"):
				unknown["title"] = true
			if t.contains("？？？"):
				unknown["needle"] = true
			if t.begins_with("产物域：") or t.contains("成功率"):
				unknown["domains"] = true
			if t.contains("（主）"):
				unknown["pair"] = true
			if t.contains("（辅）"):
				unknown["double"] = true
		if n is Button:
			var btext := str((n as Button).text)
			if btext.contains("（主）"):
				unknown["pair"] = true
			if btext.contains("（辅）"):
				unknown["double"] = true
			if btext == "确认炼蛊":
				unknown["go"] = true
	)
	print("UNKNOWN_REVEAL title=%s pair=%s domains=%s go=%s needle=%s double=%s" % [
			str(unknown["title"]), str(unknown["pair"]), str(unknown["domains"]),
			str(unknown["go"]), str(unknown["needle"]), str(unknown["double"])])
	if not bool(unknown["needle"]) or not bool(unknown["go"]) \
			or not bool(unknown["pair"]) or not bool(unknown["double"]):
		push_error("自由配对预检缺少 ？？？ 揭示、主辅回显或确认按钮")
		quit(1)
		return
	# 二层揭示：追加古方到 codex 后产物应实名。
	var output_id := str((snapshot.get("pair_preview", {}) as Dictionary).get("output_id", ""))
	if output_id.is_empty():
		push_error("快照缺少可揭示产物 id")
		quit(1)
		return
	controller.state.global_codex_ids.append(output_id)
	var known_snapshot: Dictionary = SNAPSHOT.refine(controller)
	view.mount_snapshot(known_snapshot, cmds)
	view._refresh_recipes()
	await process_frame
	var known := {"named": false}
	_walk(view, func(n: Node) -> void:
		if n is Label and str((n as Label).text).contains("古方在手"):
			known["named"] = true
	)
	print("KNOWN_REVEAL named=%s" % str(known["named"]))
	if not bool(known["named"]):
		push_error("持有古方后产物未实名揭示")
		quit(1)
		return
	print("OK RefineFreePairReveal")
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass


func _walk(node: Node, fn: Callable) -> void:
	fn.call(node)
	for child in node.get_children():
		_walk(child, fn)
