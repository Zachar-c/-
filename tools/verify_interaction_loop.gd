extends SceneTree
## Interactive-loop audit v2: reach every screen possible headless,
## enumerate BaseButton nodes, report:
##  - dead buttons: clickable (visible+enabled) with zero pressed connections
##  - audio coverage: whether the button went through MasterTheme.apply_button
##    (detected via font_hover_color override), i.e. ui_click is wired.
##  - occlusion: whether the control that actually receives the click at the button's
##    center is neither the button nor one of its ancestors. Buttons whose rect is
##    covered by a transparent full-width layout container look "greyed and dead" while
##    still passing the connection check — that failure mode shipped twice
##    (battle right column ops dock covered first by HandStage, then by HandMargin),
##    so it is audited here.
## Never emits pressed; inspection only.

const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")

## 已知未修的既有遮挡：**逐条留档，不判红**，但必须继续出现在报告里（`occluded_known`）。
## 这类问题本批不修，因为每一条都要产品决策，不是单纯加 IGNORE 能了结的：
##   · Rest 决策面板上沿伸进顶栏带 —— 是**布局**问题（面板该往下让），改 mouse_filter 会让
##     面板主体也失去"吃掉点在纸面上的点击"的语义。
##   · Shop 黑市封蜡 —— `shop_screen.tscn` 有**孤儿节点**：`SealMargin` 的 parent 指向
##     `Root/ShopStage/SealPanelContainer`，而该节点只在 `StageContent/TitleRow` 下声明过一次，
##     于是引擎把 `SealMargin` 按整屏尺寸挂上去，压住购买/离开按钮。属坏场景，需决定该节点的归处。
##   · Settings 内容全部不可点 —— `BackRow` 是 `MarginContainer` 的直接子节点，被容器**拉伸成整屏**
##     （Container 会接管子节点的 pos/size，tscn 里写的 anchors/offset 对它是无效的）。
## 键 = "<屏>|<遮挡物节点名>"；**新增**的遮挡一律判红。
const KNOWN_OCCLUDED := {
}


func _collect_buttons(root_node: Node) -> Array:
	var out: Array = []
	# _walk 是 DFS 先序 = CanvasItem 的绘制/命中顺序（父在子前、兄弟按序、后者压前者）。
	# 遮挡判定直接复用同一份顺序，不另造一套遍历。
	var order := _walk(root_node)
	for node in order:
		if node is BaseButton:
			var b: BaseButton = node
			var conns := b.pressed.get_connections()
			# `toggled` 是 BaseButton 的另一条合法接线（CheckButton / CheckBox 的语义信号）：
			# 只数 `pressed` 会把"勾选即生效"的开关误报成死按钮（2026-09-11 大厅加成行 3 例）。
			var toggle_conns := b.toggled.get_connections()
			var total_conns := conns.size() + toggle_conns.size()
			out.append({
				"path": str(b.get_path()),
				"text": str(b.text if "text" in b else ""),
				"connected": total_conns > 0,
				"conn_count": total_conns,
				"visible": b.is_visible_in_tree(),
				"disabled": b.disabled,
				"themed": b.has_theme_color_override("font_hover_color"),
				"occluded_by": _occluder_for(b, root_node),
				"path_last": str(b.name),
			})
	return out


## 按钮能否真正收到点击：按引擎的真实 GUI 命中算法求出"最上层命中者"，
## 再看按钮是否落在它的**祖先链**上（命中者 == 按钮，或命中者是按钮的祖先 →
## 事件会沿祖先链传上来，按钮收得到）。否则事件被命中者截获 → 按钮点不到。
##
## 早先版本写成"DFS 先序 + 只找 STOP + 最先一个"，两处都错，给出过假阴性：
##   1. **PASS 同样截获**。PASS 的语义是"自己也收，并继续传给**父节点**"，
##      它**不会**穿给身后被压住的兄弟节点；只有 IGNORE 才让路。
##      （曾误以为 PASS 会穿透，于是只检查 STOP，漏掉了 HandMargin。）
##   2. 顺序不是"先序找第一个"，而是引擎的 `Viewport::_gui_find_control_at_pos`：
##      **子节点逆序**（后声明=绘制在上）深度优先，先递归子树、子树无命中再判自身。
##
## 报告里带上命中者的类名/矩形，能直接看出"它凭什么盖住"，不必回来复跑探针。
## 返回 {} 表示可达；否则 {"name": 遮挡物节点名, "desc": 详情}。
func _occluder_for(button: BaseButton, root_node: Node) -> Dictionary:
	if not button.is_visible_in_tree():
		return {}
	var hit := _find_control_at_pos(root_node, button.get_global_rect().get_center())
	if hit == null:
		return {}
	var cursor: Node = hit
	while cursor != null:
		if cursor == button:
			return {}
		cursor = cursor.get_parent()
	var c := hit as Control
	var r: Rect2 = c.get_global_rect()
	return {
		"name": str(c.name),
		"desc": "%s(%s mf=%d rect=%d,%d %dx%d)" % [str(c.name), c.get_class(), c.mouse_filter,
				int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)],
	}


## 复刻 `Viewport::_gui_find_control_at_pos`：返回该点上会被 GUI 命中的最上层控件。
func _find_control_at_pos(node: Node, point: Vector2) -> Node:
	for i in range(node.get_child_count() - 1, -1, -1):
		var child: Node = node.get_child(i)
		if not (child is CanvasItem):
			continue
		if not (child as CanvasItem).is_visible_in_tree():
			continue
		var sub := _find_control_at_pos(child, point)
		if sub != null:
			return sub
		if child is Control:
			var c := child as Control
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
					and c.get_global_rect().has_point(point):
				return c
	return null


func _walk(root: Node) -> Array:
	var acc: Array = [root]
	for child in root.get_children():
		acc.append_array(_walk(child))
	return acc


## 等界面动画（封蜡 / 墨迹 / 屏间过渡）收尾再量。
## 只等固定帧数不行：无头模式帧率不受限，2 帧可能只有几毫秒，会量到"过渡遮罩还盖着全屏"
## 的瞬态状态，把每个屏都误报成整屏被遮挡。按**真实时间**等才稳。
func _settle(seconds: float = 0.8) -> void:
	await create_timer(seconds).timeout


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
	var occluded: Array = []
	var known: Array = []
	for b in btns:
		if b["visible"] and not b["disabled"] and not b["connected"]:
			dead.append("%s(%s)" % [b["path"], b["text"]])
		# Audio coverage: MasterTheme.apply_button wires ui_click (themed), or
		# >=2 pressed connections = business handler + separate sfx wiring.
		if b["visible"] and not b["disabled"] and not (b["themed"] or b["conn_count"] >= 2):
			no_sfx.append("%s(%s)" % [b["path"], b["text"]])
		# 接线齐全但**够不着**：中心点的实际命中者不是按钮也不是它的祖先 → 点了没反应。
		# 注意 PASS 也会遮挡，只有 IGNORE 才让路（见 _occluder_for 注释）。
		if b["visible"] and not b["disabled"] and not b["occluded_by"].is_empty():
			var hit_desc: String = str(b["occluded_by"]["desc"])
			var entry := "%s(%s) ← %s" % [b["path"], b["text"], hit_desc]
			if KNOWN_OCCLUDED.has("%s|%s" % [label, str(b["occluded_by"]["name"])]):
				known.append(entry)
			else:
				occluded.append(entry)
	var clickable := 0
	for b in btns:
		if b["visible"] and not b["disabled"]:
			clickable += 1
	print("AUDIT[%s] total=%d clickable=%d dead=%s no_ui_click=%s occluded=%s occluded_known=%d" % [
		label, btns.size(), clickable, str(dead), str(no_sfx), str(occluded), known.size()])


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
	await _settle()
	_report("Hall", controller)
	# 大厅子视图（A9，2026-09-11）：门原先只审 Hall 主视图，schools / contracts /
	# codex / journal 四个子视图的**动态构建按钮**（流派卡、契约项、图鉴条目、手记）
	# 完全没有自动保护——「20 个流派只有力道能选」的 bug 正落在该盲区。
	# 逐个切换各审一次；审完**复原 main**，保证后续 start_new_run 仍走主视图路径。
	# 注：hall 的 "settings" 子视图无命令入口（open_settings 走独立 Settings 屏），
	# 属不可达分支，不纳入。
	for subview in ["schools", "contracts", "codex", "journal"]:
		controller._show_hall_subview(subview)
		await process_frame
		await _settle()
		_report("Hall-%s" % str(subview).capitalize(), controller)
	controller._show_hall_subview("main")
	await process_frame
	await _settle()
	controller.start_new_run(20260909, "", [])
	await process_frame
	await _settle()
	_report("Map", controller)
	# battle
	if _travel(controller, "combat") != "":
		await process_frame
		await process_frame
		await _settle()
		_report("Battle", controller)
		controller.submit_command({"type": "leave_encounter"})
		await process_frame
		await process_frame
	# rest
	if _travel(controller, "rest") != "":
		await process_frame
		await process_frame
		await _settle()
		_report("Rest", controller)
		controller.submit_command({"type": "rest", "mode": "skip"})
		await process_frame
		await process_frame
	# shop
	if _travel(controller, "shop") != "":
		await process_frame
		await process_frame
		await _settle()
		_report("Shop", controller)
		controller.submit_command({"type": "leave_encounter"})
		await process_frame
		await process_frame
	# refine —— 生成图只产 combat/rest/shop/layer_boss 四类节点，路线里通常**没有**
	# refinement 节点；旧写法 `if _travel(...) != ""` 会让该屏被静默跳过（2026-09-11
	# 实测就只审计到 8 屏）。改为不可达时直接挂载，把覆盖钉死成恒定 9 屏。
	var refine_reachable := _travel(controller, "refinement") != ""
	if not refine_reachable:
		controller._show_refine()
	await process_frame
	await process_frame
	await _settle()
	_report("Refine", controller)
	if refine_reachable:
		controller.submit_command({"type": "leave_encounter"})
	await process_frame
	await process_frame
	# encounter via inheritance (anchor-guaranteed)
	if _travel(controller, "inheritance") != "":
		await process_frame
		await process_frame
		await _settle()
		_report("Encounter", controller)
		controller.submit_command({"type": "leave_encounter"})
		await process_frame
		await process_frame
	# settings / kill overlays
	controller._show_settings()
	await process_frame
	await _settle()
	_report("Settings", controller)
	controller.back_from_overlay()
	await process_frame
	controller._show_kill()
	await process_frame
	await _settle()
	_report("Kill", controller)
	controller.back_from_overlay()
	await process_frame
	# 内容屏（Reward / Npc / ContentError）：三个挂载方法都只走 `_set_view`，无前置状态
	# 依赖，因此可直接挂起来审计。这三屏是 B2 首发落地（2026-09-11）的，纳入门后才有
	# "改布局不制造遮挡/死按钮"的自动保护。
	controller._show_reward()
	await process_frame
	await _settle()
	_report("Reward", controller)
	controller._show_npc()
	await process_frame
	await _settle()
	_report("Npc", controller)
	controller._show_content_error()
	await process_frame
	await _settle()
	_report("ContentError", controller)
	# Ending 放最后：它会走结局流程（record_run_end），可能清空本局状态，故不放在中间。
	controller.force_complete_for_test()
	await process_frame
	await _settle()
	_report("Ending", controller)
	print("AUDIT_DONE")
	quit(0)
