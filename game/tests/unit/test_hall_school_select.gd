extends GutTest


# 流派选择屏（择道）回归 —— 2026-09-11 用户报：
# 「只能默认力道选择，点击其他按钮都没有反应；需要 20 个流派都可正常点击，
#   选择后进入游戏获得的也是对应流派的初始蛊」。
#
# 实测根因：`select_school` 命令**写字段是对的**（`_selected_school` 确实变），
# 但**不触发重绘**；流派卡片是自建 Panel（选中态靠快照重建，无自绘状态），
# 于屏上完全看不出变化 → 玩家感知为「点了没反应 / 只有力道能用」。
# 因此本套的关键断言落在**界面**（卡片的「已选」标记归属），而不只是字段。
#
# 另锁：未知 id 拒绝；切流派不冲掉已勾选开局加成；新局 starter 蛊随所选流派。

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const RunCommandBuilderScript = preload("res://scripts/presentation/run_command_builder.gd")


func _controller() -> Node:
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	controller.catalog = ContentCatalog.load_all()
	controller._show_title()
	return controller


func _commands(controller: Node) -> Dictionary:
	return RunCommandBuilderScript.for_screen("Title", controller)


## 仅取仍在树上的子节点：重绘会 queue_free 旧卡片，而它们在帧末才真正释放。
func _live_children(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	for child in node.get_children():
		if not child.is_queued_for_deletion():
			out.append(child)
	return out


func _find_master(controller: Node) -> Node:
	var host: Node = controller.get_node_or_null("RUIHost")
	if host == null:
		return null
	for child in host.get_children():
		if str(child.name).begins_with("Wenzhen"):
			return child
	return null


func _school_grid(controller: Node) -> Node:
	var master := _find_master(controller)
	if master == null:
		return null
	return master.get_node_or_null("SchoolsView/SchoolGrid")


## 卡片内第一个 Label 即流派名（_school_card 的构建顺序：name → order → summary → starter）。
func _card_school_name(card: Node) -> String:
	for node in _labels(card):
		return node.text
	return ""


func _labels(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is Label:
			out.append(child)
		out.append_array(_labels(child))
	return out


## 屏上带「已选」印章的卡片所代表的流派名（无则空串）。
func _checked_school_name(controller: Node) -> String:
	var grid := _school_grid(controller)
	for card in _live_children(grid):
		for label in _labels(card):
			if str(label.text) == "已选":
				return _card_school_name(card)
	return ""


## 卡片唯一的点击层（_school_card 末尾铺满的 flat Button）。
func _click_button(card: Node) -> Button:
	for node in _buttons(card):
		return node
	return null


func _buttons(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is Button:
			out.append(child)
		out.append_array(_buttons(child))
	return out


func test_school_grid_exposes_all_twenty_schools() -> void:
	var controller = _controller()
	var catalog_schools: Dictionary = controller.catalog.get("schools", {})
	assert_eq(catalog_schools.size(), 20, "目录应含 20 个流派")
	var schools: Array = controller._snapshot_for("Title").get("available_schools", [])
	assert_eq(schools.size(), 20, "快照暴露全部 20 个流派（卡片网格据它构建）")
	for entry_value in schools:
		var entry: Dictionary = entry_value
		assert_ne(str(entry.get("id", "")), "", "每个流派都有 id")
		assert_ne(str(entry.get("name", "")), "", "每个流派都有中文名")
	controller.queue_free()


func test_every_school_card_is_clickable_and_wired() -> void:
	var controller = _controller()
	controller._show_hall_subview("schools")
	await get_tree().process_frame
	var grid := _school_grid(controller)
	assert_true(grid != null, "流派网格已挂载")
	var cards := _live_children(grid)
	assert_eq(cards.size(), 20, "网格有 20 张卡片")
	for card_value in cards:
		var card: Node = card_value
		var click := _click_button(card)
		assert_true(click != null, "卡片 %s 有点击层" % _card_school_name(card))
		if click != null:
			assert_gt(click.pressed.get_connections().size(), 0,
				"卡片 %s 的点击层已接线（否则是可点无反应的死按钮）" % _card_school_name(card))
	controller.queue_free()


func test_clicking_a_card_selects_that_school_and_repaints() -> void:
	var controller = _controller()
	controller._show_hall_subview("schools")
	await get_tree().process_frame
	assert_eq(_checked_school_name(controller), "力道", "默认选中力道")
	# 点第 1 张卡（血道）的覆盖按钮 —— 走与真实点击同一条路径（pressed 信号）。
	var grid := _school_grid(controller)
	var first_card: Node = _live_children(grid)[0]
	var click := _click_button(first_card)
	click.pressed.emit()
	assert_eq(controller._selected_school, "blood", "点击后选中血道")
	await get_tree().process_frame
	assert_eq(_checked_school_name(controller), "血道",
		"界面重绘：已选印章移到血道卡（旧实现只写字段不重绘，此断言红）")
	controller.queue_free()


func test_select_school_rejects_unknown_id() -> void:
	var controller = _controller()
	var before: String = controller._selected_school
	var commands := _commands(controller)
	commands["select_school"].call("not_a_real_school")
	assert_eq(controller._selected_school, before, "未知流派 id 不改变当前选择")
	controller.queue_free()


func test_select_school_keeps_toggled_opening_buffs() -> void:
	var controller = _controller()
	controller._show_hall_subview("schools")
	var commands := _commands(controller)
	var buffs: Array = controller._snapshot_for("Title").get("available_buffs", [])
	assert_gt(buffs.size(), 0, "目录至少有一个开局加成")
	var bid := str((buffs[0] as Dictionary).get("id", "")) if buffs[0] is Dictionary else str(buffs[0])
	commands["toggle_buff"].call(bid)
	commands["select_school"].call("water")
	var snapshot: Dictionary = controller._snapshot_for("Title")
	assert_true(Array(snapshot.get("selected_buffs", [])).has(bid), "切换流派不冲掉已勾选的开局加成")
	assert_true(Array(controller._selected_buffs).has(bid), "controller 侧勾选保留")
	controller.queue_free()


func test_selected_school_drives_run_starter_gu() -> void:
	var controller = _controller()
	var schools: Dictionary = controller.catalog.get("schools", {})
	var blood_starters: Array = schools["blood"].get("starter_gu_ids", [])
	var soul_starters: Array = schools["soul"].get("starter_gu_ids", [])
	assert_gt(blood_starters.size(), 0, "血道有 starter 定义")
	assert_gt(soul_starters.size(), 0, "魂道有 starter 定义")
	var commands := _commands(controller)
	commands["select_school"].call("blood")
	commands["new_run"].call()
	assert_eq(controller.current_view_name(), "Map", "开局进入地图")
	assert_eq(controller.state.school, "blood", "新局采用所选流派")
	for gid in blood_starters:
		assert_true(controller.state.refined_gu_ids.has(str(gid)),
			"开局获得血道初始蛊 %s" % str(gid))
	for gid in soul_starters:
		assert_false(controller.state.refined_gu_ids.has(str(gid)),
			"不含未选流派的初始蛊 %s" % str(gid))
	controller.queue_free()
