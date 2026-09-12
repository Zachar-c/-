extends SceneTree

## 真实对局瞄准线验证（2026-09-10）：跑真实 RunController 到第一场普通战斗，
## 用真实鼠标事件按下指向性手牌并拖拽，**拖拽途中**截图，最后松手到敌人上并断言
## 领域层真的按该目标出牌（血量/护盾下降）。
##
## 与 verify_hand_drag_render.gd 的分工：
##   那个探针验"呈现是否对"（合成快照 + SubViewport）；
##   这个验"在真实对局里这条线到底出不出来、出牌流程是否打通"（真窗口 + 真输入）。
##
## 用法（需真实窗口，不能 --headless）：
##   tools\godot.ps1 --path . -s tools/verify_aim_line_real_run.gd

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ACTION_PREVIEW_SERVICE = preload("res://scripts/domain/action_preview_service.gd")
const BATTLE_COMMAND_FACADE = preload("res://scripts/domain/battle_command_facade.gd")

const OUT_DIR := "res://.preview"
const SEEDS := [1, 3, 7, 13, 101]
const MAX_DRIVE_STEPS := 60

var _failed := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var controller: RunController = RunControllerScript.new()
	root.add_child(controller)
	await _settle(3)

	var opened := false
	for seed in SEEDS:
		controller.start_new_run(seed)
		await _settle(5)
		if await _drive_to_battle(controller):
			print("[AIM] battle open on seed=%d" % seed)
			opened = true
			break
	if not opened:
		print("[AIM] FAIL no seed reached an ordinary battle")
		_quit(1)
		return

	var battle = controller._master_instance
	var screen := _find_battle_screen(battle)
	if screen == null:
		print("[AIM] FAIL battle screen node not found")
		_quit(1)
		return

	var pre := controller._snapshot_for("Battle")
	var card := _aim_card(pre)
	var enemies: Array = pre.get("enemies", [])
	if card.is_empty() or enemies.is_empty():
		print("[AIM] FAIL no targeted card / enemy available")
		_quit(1)
		return

	var card_id := str(card.get("id", ""))
	var enemy_id := str(enemies[enemies.size() - 1].get("id", ""))
	# 节点名不能含 "."：Godot 会把它替换成 "_"，按 a1 探针同款口径取节点名。
	var card_node := _find(screen, "card_body_" + card_id.replace(".", "_"))
	var enemy_node := _find(screen, "enemy_actor_" + enemy_id)
	if not (card_node is Control) or not (enemy_node is Control):
		print("[AIM] FAIL nodes missing card=%s enemy=%s" % [card_id, enemy_id])
		_quit(1)
		return

	var from: Vector2 = (card_node as Control).get_global_rect().get_center()
	var to: Vector2 = (enemy_node as Control).get_global_rect().get_center()
	var free_spot := Vector2(300, 430)   # 舞台左侧空白：自由瞄准（不该命中敌人）
	print("[AIM] drag %s %s -> %s，自由点 %s" % [card_id, str(from.round()),
			str(to.round()), str(free_spot)])

	# 真实光标必须真的动起来：warp 到起点 → 按下 → 逐步 warp（每步等帧）。
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _settle(2)
	Input.warp_mouse(from)
	await _settle(3)
	_btn(from, true)
	await _settle(2)
	Input.warp_mouse(from.lerp(free_spot, 0.5))
	await _settle(2)
	Input.warp_mouse(free_spot)
	await _settle(3)

	var line_state := _line_state(screen)
	print("[AIM] free-aim line: %s" % line_state)
	_dump_line(screen)
	if not line_state.begins_with("ok"):
		_failed += 1
	await _capture("aim_real_free")

	Input.warp_mouse(to)
	await _settle(4)
	print("[AIM] hot-aim line: %s" % _line_state(screen))
	print("[AIM] hot flag=%s color=%s" % [str(_call(_aim_overlay(screen), "is_hot")),
			str(_call(_aim_overlay(screen), "color"))])
	await _capture("aim_real_hot")

	var hp_before := _enemy_total(pre, enemy_id)
	_btn(to, false)
	await _settle(8)
	var post := controller._snapshot_for("Battle")
	var hp_after := _enemy_total(post, enemy_id)
	print("[AIM] release on enemy: hp+shield %d -> %d" % [hp_before, hp_after])
	if hp_after >= hp_before:
		print("[AIM] FAIL release did not land a targeted play")
		_failed += 1
	print("[AIM] after release line=%s" % _line_state(screen))
	if _line_state(screen) != "none":
		print("[AIM] FAIL aim line must be removed after release")
		_failed += 1

	print("[AIM] FAILED=%d" % _failed)
	_quit(1 if _failed > 0 else 0)


func _find_battle_screen(battle: Node) -> Node:
	if battle == null:
		return null
	if battle.has_method("_process_aim"):
		return battle
	for child in battle.get_children():
		var found := _find_battle_screen(child)
		if found != null:
			return found
	return null


## 瞄准覆盖层现在归手牌组件所有（宿主的手势机件已删除），从组件上取。
func _aim_overlay(screen: Node) -> Node:/n/tvar hand = screen.get("_hand")
	return hand.get("_aim") if hand != null else null


## 瞄准线状态：ok(points=N) / none
func _line_state(screen: Node) -> String:
	var line = _aim_overlay(screen)
	if line == null:
		return "none"
	var points: PackedVector2Array = line.call("points")
	return "ok(points=%d)" % points.size()


## 画不出来时，把绘制态全量摊开：可见性/矩形/层级/画布变换一个都不放过。
func _dump_line(screen: Node) -> void:
	var line = _aim_overlay(screen)
	if line == null:
		print("[DUMP] aim overlay = null")
		return
	var points: PackedVector2Array = line.call("points")
	print("[DUMP] class=%s parent=%s inside=%s" % [line.get_class(),
			str(line.get_parent().name), str(line.is_inside_tree())])
	print("[DUMP] visible=%s in_tree=%s top_level=%s z=%d" % [str(line.visible),
			str(line.is_visible_in_tree()), str(line.top_level), int(line.z_index)])
	print("[DUMP] pos=%s size=%s scale=%s modulate=%s self=%s" % [str(line.position),
			str(line.size), str(line.scale), str(line.modulate), str(line.self_modulate)])
	print("[DUMP] canvas_xform=%s screen_xform=%s" % [str(line.get_canvas_transform()),
			str(line.get_screen_transform())])
	print("[DUMP] viewport=%s size=%s" % [str(line.get_viewport().get_class()),
			str(line.get_viewport().get_visible_rect().size)])
	if points.size() > 0:
		print("[DUMP] first=%s last=%s" % [str(points[0]), str(points[points.size() - 1])])


func _call(screen: Node, property: String, method: String) -> Variant:
	var obj = screen.get(property)
	if obj == null:
		return "<null>"
	return obj.call(method)


func _aim_card(snapshot: Dictionary) -> Dictionary:
	for value in snapshot.get("hand", []):
		var card: Dictionary = value
		if bool(card.get("executable", false)) \
				and str(card.get("target_type", "none")) == "single_enemy":
			return card
	return {}


func _enemy_total(snapshot: Dictionary, enemy_id: String) -> int:
	for value in snapshot.get("enemies", []):
		var enemy: Dictionary = value
		if str(enemy.get("id", "")) == enemy_id:
			return int(enemy.get("hp", 0)) + int(enemy.get("shield", 0))
	return -1


# —— 驱动到普通战斗（与 verify_a1_drag.gd 同逻辑，只保留必要部分） ——

func _drive_to_battle(controller: RunController) -> bool:
	var steps := 0
	while steps < MAX_DRIVE_STEPS:
		steps += 1
		if controller.state == null or controller.state.is_terminal():
			return false
		if str(controller.current_view_name()) == "Battle":
			return not bool(BATTLE_COMMAND_FACADE.boss_blocks_retreat(controller.current_battle))
		var chosen := ""
		for node_value in controller.visible_route_nodes(2):
			var node: Dictionary = node_value
			if not bool(node.get("reachable", false)):
				continue
			var ntype := str(node.get("type", ""))
			if ntype in ["combat", "pursuit"]:
				chosen = str(node.get("id", ""))
				break
			if chosen == "" and ntype in ["hazard", "event", "contact", "wild_gu"]:
				chosen = str(node.get("id", ""))
		if chosen == "":
			return false
		controller.submit_command({"type": "travel", "node_id": chosen})
		await _settle(6)
		var view := str(controller.current_view_name())
		if view == "Battle":
			return not bool(BATTLE_COMMAND_FACADE.boss_blocks_retreat(controller.current_battle))
		if view == "Map":
			continue
		if view == "Ending":
			return false
		if await _pick_fight(controller):
			return true
		if str(controller.current_view_name()) != "Battle":
			controller.submit_command({"type": "leave_node"})
			await _settle(6)
	return false


func _pick_fight(controller: RunController) -> bool:
	if controller.current_node.is_empty():
		return false
	var cards: Array[Dictionary] = ACTION_PREVIEW_SERVICE.preview_actions(
			controller.state, controller.current_node, controller.catalog)
	for card in cards:
		if not bool(card.get("executable", false)):
			continue
		var command: Dictionary = card.get("command", {})
		var is_fight := str(command.get("action_id", "")) == "fight" \
				or (str(command.get("type", "")) == "resolve_contact"
						and str(command.get("approach", "")) == "fight")
		if not is_fight:
			continue
		controller.submit_command({
			"type": "action_card",
			"action_id": str(card.get("id", "")),
			"state_version": controller.state.event_log.size(),
			"node_id": str(controller.current_node.get("id", "")),
			"session_node_id": str(controller.state.encounter_session.get("node_id", "")),
		})
		await _settle(6)
		return str(controller.current_view_name()) == "Battle"
	return false


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var window := root as Window
	if window == null or window.get_texture() == null:
		print("[AIM] FAIL no render target")
		_failed += 1
		return
	var img := window.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var out := ProjectSettings.globalize_path(OUT_DIR) + "/" + name + ".png"
	img.save_png(out)
	print("[AIM] SAVED %s %dx%d" % [out, img.get_width(), img.get_height()])


func _btn(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame


func _quit(code: int) -> void:
	quit(code)
