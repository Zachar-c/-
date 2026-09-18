extends SceneTree

## 诊断探针：行动值耗尽后，右栏操作按钮（结束回合/炼蛊/撤退）为何"看着置灰、点不动"。
##
## 思路：不猜渲染层，直接把**全量状态摊开**——按钮自身的 disabled/visible/modulate/矩形、
## 父链的 modulate、**手牌容器链的矩形**（内边距只作用于子节点，不改容器自身矩形）、
## 以及按 Godot 真实算法算出的**最上层命中者**。
##
## ⚠️ 判定"能不能点到"必须复刻引擎的命中算法（`Viewport::_gui_find_control_at_pos`）：
##   **子节点逆序**深度优先；先递归子树，再判自身；`MOUSE_FILTER_IGNORE` 自身不作为命中，
##   但**不影响其子树被继续检查**。凡是「本节点矩形含该点且 filter != IGNORE」就会截获事件。
##   早先版本用"DFS 先序 + 找第一个 STOP"近似，漏掉了这一层，给出过假阴性。
##
## 用法（无头即可，不需要真实窗口）：
##   tools\godot.ps1 --headless --path . -s tools/dbg_ops_grey.gd

const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")
const OPS_TEXTS := ["结束回合", "炼蛊", "撤退"]
## 手牌区那串容器——它们全是默认 STOP 的布局容器，最容易整条盖住右栏。
const HAND_CHAIN := ["HandStage", "HandMargin", "battle_hand", "HandArea", "Hand"]
const MAX_PLAYS := 16

var _screen: Node = null


func _initialize() -> void:
	_run()


func _run() -> void:
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	await process_frame
	controller.start_new_run(20260910, "", [])
	await process_frame
	await process_frame
	if not _goto_combat(controller):
		print("[OPS] 未能进入战斗节点，诊断中止")
		quit(1)
		return
	await process_frame
	await process_frame
	_dump(controller, "行动未消耗")

	var played := 0
	for _i in MAX_PLAYS:
		if not _play_one(controller):
			break
		played += 1
		await process_frame
		await process_frame
	print("[OPS] 共出牌 %d 次" % played)
	# 出牌会触发 _refresh() 重建右栏按钮，等布局稳定再量。
	await process_frame
	await process_frame
	_dump(controller, "行动已耗尽")
	quit(0)


func _goto_combat(controller: Node) -> bool:
	for node_value in controller.visible_route_nodes(3):
		var node: Dictionary = node_value
		if str(node.get("type", "")) == "combat":
			var nid := str(node.get("id", ""))
			var r: Dictionary = controller.submit_command({"type": "travel", "node_id": nid})
			return bool(r.get("ok", false))
	return false


## 出一张当前可执行的牌；没有可出的就返回 false。
func _play_one(controller: Node) -> bool:
	var screen := _find_screen(controller)
	if screen == null:
		return false
	var hand: Array = screen.get("_snapshot").get("hand", [])
	var commands: Dictionary = screen.get("_commands")
	for card_value in hand:
		if not (card_value is Dictionary):
			continue
		var card: Dictionary = card_value
		if not bool(card.get("executable", true)):
			continue
		var target := ""
		var valid: Array = card.get("valid_target_ids", [])
		if str(card.get("target_type", "none")) == "single_enemy":
			if valid.is_empty():
				continue
			target = str(valid[0])
		if commands.has("play_card"):
			commands["play_card"].call(str(card.get("id", "")), target)
			return true
	return false


func _find_screen(controller: Node) -> Node:
	var host: Node = controller.get_node_or_null("RUIHost")
	if host == null:
		return null
	for child in host.get_children():
		var found := _find_by_name_prefix(child, "Wenzhen")
		if found != null:
			return found
	return host.get_child(0) if host.get_child_count() > 0 else null


func _find_by_name_prefix(node: Node, prefix: String) -> Node:
	if str(node.name).begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _find_by_name_prefix(child, prefix)
		if found != null:
			return found
	return null


func _dump(controller: Node, label: String) -> void:
	var screen := _find_screen(controller)
	print("[OPS] ================== %s ==================" % label)
	if screen == null:
		print("[OPS] 找不到战斗屏")
		return
	var snap: Dictionary = screen.get("_snapshot")
	print("[OPS] 快照 actions=%s" % str(snap.get("actions", {})))
	var hand: Array = snap.get("hand", [])
	var executable := 0
	for card_value in hand:
		if card_value is Dictionary and bool((card_value as Dictionary).get("executable", true)):
			executable += 1
	print("[OPS] 手牌 %d 张，其中可执行 %d 张" % [hand.size(), executable])
	# 手牌容器链：矩形是否整条横跨屏幕（内边距不改容器自身矩形）。
	print("[OPS] --- 手牌容器链（mouse_filter：0=STOP 1=PASS 2=IGNORE）---")
	for wanted in HAND_CHAIN:
		var node := _find_by_name(screen, wanted)
		if not (node is Control):
			print("[OPS]   %-12s 不存在" % wanted)
			continue
		var c := node as Control
		print("[OPS]   %-12s mf=%d visible=%s rect=%s" % [wanted, c.mouse_filter,
				str(c.is_visible_in_tree()), _rect_str(c.get_global_rect())])
	# 每个操作按钮：自身状态 + 父链 modulate + 命中者。
	for wanted in OPS_TEXTS:
		var btn := _find_button_by_text(screen, wanted)
		if btn == null:
			print("[OPS] 「%s」**不存在**" % wanted)
			continue
		var center: Vector2 = btn.get_global_rect().get_center()
		print("[OPS] 「%s」visible=%s disabled=%s mf=%d rect=%s 中心=%s" % [
			wanted, str(btn.is_visible_in_tree()), str(btn.disabled), btn.mouse_filter,
			_rect_str(btn.get_global_rect()), str(center.round())])
		print("[OPS]    父链 modulate=%s" % str(_parent_modulate_chain(btn)))
		print("[OPS]    最上层命中=%s" % _top_hit_desc(screen, center))
		print("[OPS]    含该点的已绘制控件=%s" % str(_containing_chain(screen, center)))
	# 覆盖层状态
	for overlay_name in ["SealOverlay", "InkOverlay", "FeedbackToast", "ConfirmDialog"]:
		var overlay := _find_by_name(screen, overlay_name)
		if overlay is Control:
			print("[OPS] 覆盖层 %s visible=%s rect=%s" % [overlay_name,
					str((overlay as Control).is_visible_in_tree()),
					_rect_str((overlay as Control).get_global_rect())])


func _rect_str(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]


func _find_button_by_text(node: Node, text: String) -> Button:
	if node is Button and str((node as Button).text) == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button_by_text(child, text)
		if found != null:
			return found
	return null


func _find_by_name(node: Node, wanted: String) -> Node:
	if str(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_by_name(child, wanted)
		if found != null:
			return found
	return null


## 从自身往上的 modulate 连乘——父节点压暗会连带子节点一起变灰。
func _parent_modulate_chain(node: Node) -> String:
	var parts: Array[String] = []
	var cursor := node.get_parent()
	while cursor is CanvasItem:
		var c := cursor as CanvasItem
		if c.modulate != Color(1, 1, 1, 1):
			parts.append("%s=%s" % [c.name, str(c.modulate)])
		cursor = cursor.get_parent()
	return "、".join(parts) if not parts.is_empty() else "（父链全为 1）"


## Godot 真实命中算法的最上层结果（含 IGNORE 语义与逆序）。
func _top_hit_desc(root_node: Node, point: Vector2) -> String:
	var hit := _find_control_at_pos(root_node, point)
	if hit == null:
		return "（无控件命中：事件会落到视口）"
	return "%s(%s) mf=%d rect=%s" % [hit.name, hit.get_class(), hit.mouse_filter,
			_rect_str((hit as Control).get_global_rect())]


func _find_control_at_pos(node: Node, point: Vector2) -> Node:
	# 逆序：后声明的子节点绘制在上层，先被命中。
	for i in range(node.get_child_count() - 1, -1, -1):
		var child: Node = node.get_child(i)
		if not (child is CanvasItem):
			continue
		var ci := child as CanvasItem
		if not ci.is_visible_in_tree():
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


## 所有"矩形含该点且可见"的 Control，按绘制先后列出（末位=最上层）。
func _containing_chain(node: Node, point: Vector2) -> Array[String]:
	var acc: Array[String] = []
	_collect_containing(node, point, acc)
	return acc


func _collect_containing(node: Node, point: Vector2, acc: Array[String]) -> void:
	for child in node.get_children():
		if child is Control:
			var c := child as Control
			if c.is_visible_in_tree() and c.get_global_rect().has_point(point):
				acc.append("%s(mf=%d)" % [c.name, c.mouse_filter])
		_collect_containing(child, point, acc)
