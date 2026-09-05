extends GutTest

## A1（architecture-refactor-master-plan §3 A1，重做版）：main 路径 Battle 视图
## 挂载 wenzhen battle master 后，既有的「拖拽蛊卡到敌人释放出蛊」交互必须可用——
## 拖拽命中以目标出牌的命令（play_card 带 target_id），数据仍走 RunSnapshotBuilder
## 快照、命令仍走 submit_command。旧屏 battle_screen.tscn 不得回到路由表。
##
## 头less 用 SubViewport 合成真实鼠标手势做回归门；真实窗口键鼠走查单独执行
## （AGENTS AI 契约）。本文件只测主路径挂载 + RUI 战斗屏的拖拽契约。


const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")

const BATTLE_MASTER := "res://scenes/ui_masters/wenzhen_battle_master.tscn"
const OLD_BATTLE_SCREEN := "res://scenes/ui/screens/battle_screen.tscn"

var _disposables: Array = []


func after_each() -> void:
	for d in _disposables:
		if d != null and is_instance_valid(d):
			d.queue_free()
	_disposables.clear()


func test_route_table_pins_battle_to_wenzhen_master() -> void:
	var paths: Dictionary = RUN_CONTROLLER.MASTER_SCENE_PATHS
	assert_eq(str(paths.get("Battle", "")), BATTLE_MASTER,
			"Battle view must mount the wenzhen battle master on the main route")
	assert_ne(str(paths.get("Battle", "")), OLD_BATTLE_SCREEN,
			"old battle_screen.tscn must not stay on the main route")


func test_main_path_battle_mounts_master_and_renders_real_snapshot() -> void:
	var vp := _viewport()
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	vp.add_child(controller)
	controller.start_new_run(101)
	await _settle()
	assert_eq(controller.current_view_name(), "Map")
	controller.current_node = {
		"id": "a1_combat_probe", "type": "combat", "layer": 1,
		"enemy_kind": "ridge_hound", "layer_boss": 0,
	}
	controller._start_battle()
	await _settle()
	assert_eq(controller.current_view_name(), "Battle")
	var inst := controller._master_instance
	assert_not_null(inst, "main path must instantiate a master for the Battle view")
	if inst == null:
		return
	assert_eq(inst.scene_file_path, BATTLE_MASTER,
			"Battle view instance must come from the wenzhen battle master")
	var host := inst.get_node_or_null("BattleScreen")
	assert_not_null(host, "wenzhen battle master must own the BattleScreen RUI host")
	if host != null:
		assert_true(host.get_child_count() > 0, "battle master must render real controls from the snapshot")
	assert_true(_has_text_under(inst, "敌方"), "battle master must render the enemy panel")
	assert_true(_has_text_under(inst, "结束回合"), "battle master must render battle ops")
	# 命令面仍从 RunCommandBuilder 提供 play_card（带 target 参数）。
	var battle_commands: Dictionary = controller._build_commands("Battle")
	assert_true(battle_commands.has("play_card"),
			"battle command surface must expose play_card through the controller")


func test_drag_card_onto_enemy_submits_with_that_target() -> void:
	var played: Array = []
	var vp := _viewport()
	var master := _mount_master(vp, func(card_id, target_id): played.append([card_id, target_id]))
	await _settle()
	var card_btn := _named(master, "card_body_c1") as Control
	var enemy_actor := _named(master, "enemy_actor_e0") as Control
	assert_not_null(card_btn, "hand card body button must exist in the RUI tree")
	assert_not_null(enemy_actor, "enemy actor container must exist in the RUI tree")
	if card_btn == null or enemy_actor == null:
		return
	var from: Vector2 = card_btn.get_global_rect().get_center()
	var to: Vector2 = enemy_actor.get_global_rect().get_center()
	_motion(vp, from)
	_press(vp, from)
	_motion(vp, to)
	_release(vp, to)
	await _settle()
	assert_eq(played, [["c1", "e0"]],
			"drag release over an enemy must play the card on that target")


func test_drag_release_off_enemies_does_not_submit() -> void:
	var played: Array = []
	var vp := _viewport()
	var master := _mount_master(vp, func(card_id, target_id): played.append([card_id, target_id]))
	await _settle()
	var card_btn := _named(master, "card_body_c1") as Control
	assert_not_null(card_btn)
	if card_btn == null:
		return
	var from: Vector2 = card_btn.get_global_rect().get_center()
	var to: Vector2 = from + Vector2(0, -90)
	_motion(vp, from)
	_press(vp, from)
	_motion(vp, to)
	_release(vp, to)
	await _settle()
	assert_true(played.is_empty(),
			"drag release off any enemy must not submit a command")


func test_dangerous_single_target_drag_enters_confirmation_not_submit() -> void:
	var played: Array = []
	var danger_card := {
		"id": "c2", "name": "燃寿蛊", "cost": 1, "effect": "造成伤害",
		"quality": "凡", "executable": true, "target_type": "single_enemy",
		"valid_target_ids": ["e0", "e1"], "dangerous": true, "known_risk": ["寿元 -1"],
	}
	var vp := _viewport()
	var master := _mount_master(vp, func(card_id, target_id): played.append([card_id, target_id]), danger_card)
	await _settle()
	var card_btn := _named(master, "card_body_c2") as Control
	var enemy_actor := _named(master, "enemy_actor_e0") as Control
	assert_not_null(card_btn, "dangerous hand card body must exist in the RUI tree")
	assert_not_null(enemy_actor, "enemy actor container must exist in the RUI tree")
	if card_btn == null or enemy_actor == null:
		return
	var from: Vector2 = card_btn.get_global_rect().get_center()
	var to: Vector2 = enemy_actor.get_global_rect().get_center()
	_motion(vp, from)
	_press(vp, from)
	_motion(vp, to)
	_release(vp, to)
	await _settle()
	assert_true(played.is_empty(),
			"a dangerous card must not submit before the danger confirmation")
	assert_not_null(_named(master, "battle_target_select"),
			"dangerous drag keeps the target selected and waits for confirmation")


func test_plain_click_on_single_target_card_still_arms_selection() -> void:
	var played: Array = []
	var vp := _viewport()
	var master := _mount_master(vp, func(card_id, target_id): played.append([card_id, target_id]))
	await _settle()
	var card_btn := _named(master, "card_body_c1") as Control
	assert_not_null(card_btn)
	if card_btn == null:
		return
	var at: Vector2 = card_btn.get_global_rect().get_center()
	_motion(vp, at)
	_press(vp, at)
	_release(vp, at)
	await _settle()
	# 普通点击不立即提交：单目标卡等待选敌（mode 标签 battle_target_select）。
	assert_true(played.is_empty(), "a click must not bypass enemy targeting")
	assert_not_null(_named(master, "battle_target_select"),
			"a click on a single-target card must enter target selection")


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

func _viewport(size := Vector2i(1280, 720)) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.gui_disable_input = false
	add_child(vp)
	_disposables.append(vp)
	return vp


func _mount_master(vp: SubViewport, on_play: Callable, card: Dictionary = {}) -> Node:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(host)
	_disposables.append(host)
	var master := (load(BATTLE_MASTER) as PackedScene).instantiate()
	host.add_child(master)
	_disposables.append(master)
	var state := {
		"resources": {}, "contracts": [], "anomalies": [], "death_lines": {},
		"enemies": [
			{"id": "e0", "name": "敌人0", "hp": 20, "max_hp": 20, "shield": 0, "statuses": [], "intent": {"type": "attack", "value": 4, "detail": "冲撞"}, "alive": true},
			{"id": "e1", "name": "敌人1", "hp": 20, "max_hp": 20, "shield": 0, "statuses": [], "intent": {"type": "attack", "value": 4, "detail": "冲撞"}, "alive": true},
		],
		"player": {"hp": 20, "max_hp": 20, "shield": 0, "primordial": 3, "thoughts": 4, "statuses": []},
		"hand": [card if not card.is_empty() else {"id": "c1", "name": "月光蛊", "cost": 1, "effect": "造成伤害", "quality": "凡", "executable": true, "target_type": "single_enemy", "valid_target_ids": ["e0", "e1"]}],
		"piles": {"draw": 0, "discard": 0, "exhausted": 0},
		"soul_ops": {"left": 4, "max": 4},
		"kill_moves": [], "feedback": "", "first_battle": false,
		"flee_available": true,
	}
	master.mount_snapshot(state, {"play_card": on_play})
	return master


func _settle() -> void:
	for _i in 5:
		await get_tree().process_frame


func _motion(vp: SubViewport, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	vp.push_input(event)


func _press(vp: SubViewport, position: Vector2) -> void:
	_button_event(vp, position, true)


func _release(vp: SubViewport, position: Vector2) -> void:
	_button_event(vp, position, false)


func _button_event(vp: SubViewport, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	vp.push_input(event)


func _named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _named(child, wanted)
		if found != null:
			return found
	return null


func _has_text_under(node: Node, wanted: String) -> bool:
	if node == null:
		return false
	if node is Label and str((node as Label).text).contains(wanted):
		return true
	if node is Button and str((node as Button).text).contains(wanted):
		return true
	for child in node.get_children():
		if _has_text_under(child, wanted):
			return true
	return false
