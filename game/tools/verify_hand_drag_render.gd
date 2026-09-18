extends SceneTree

## 手牌交互多态渲染探针（2026-09-10）：把 battle_screen.tscn 挂进 1280×720 的
## **SubViewport**，喂合成快照后逐个驱动、逐个落图到 .preview/hand_<state>.png，
## 供与参考实机截图做肉眼级比对：
##   hover     — 鼠标悬停手牌：悬停卡抬升 + 解释栏锚在卡上方
##   drag_near — 无指向卡拖出 >6px 但不足出牌距离：影卡墨框「未就绪」态
##   drag_free — 无指向卡拖出 >64px：影卡朱砂「可出牌」态，跟随鼠标
##   aim_free  — 指向卡拖动、未命中敌人：墨色弧形箭
##   aim_hot   — 指向卡拖动、命中敌人：朱砂弧形箭 + 敌人放置高亮
##
## 为什么用 SubViewport 而不是根窗口 + warp_mouse：
##   根窗口下 Input.parse_input_event 的 MouseMotion 不更新 gui.last_mouse_pos；
##   push_input 到根窗口又要自己换算 final_transform（本机 DPI 缩放下不是单位阵）；
##   warp_mouse 是否产生真实移动事件取决于窗口管理器，跨状态还会残留按键状态。
##   SubViewport.push_input 与单测走同一条 GUI 管线，确定性最好。
##
## 用法（需真实窗口，不能 --headless）：
##   tools\godot.ps1 --path . -s tools/verify_hand_drag_render.gd [-- --only=hover,drag_free]

const BattleScene := "res://scenes/ui/screens/battle_screen.tscn"
const OUT_DIR := "res://.preview"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const STATES := ["hover", "drag_near", "drag_free", "aim_free", "aim_hot"]

var _failed := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var wanted := _requested_states()
	print("[PROBE] viewport=%s states=%s" % [str(VIEWPORT_SIZE), str(STATES if wanted.is_empty() else wanted)])
	for state in STATES:
		if not wanted.is_empty() and not wanted.has(state):
			continue
		await _capture_state(state)
	print("[PROBE] FAILED=%d" % _failed)
	quit(1 if _failed > 0 else 0)


func _capture_state(state: String) -> void:
	var vp := SubViewport.new()
	vp.size = VIEWPORT_SIZE
	vp.gui_disable_input = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var battle: Control = (load(BattleScene) as PackedScene).instantiate()
	vp.add_child(battle)
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.mount_snapshot(_snapshot(), _commands())
	await _settle(5)
	var ok := await _drive(vp, battle, state)
	await _capture_png(vp, state)
	print("[PROBE] %s ok=%s" % [state, str(ok)])
	if not ok:
		_failed += 1
	vp.queue_free()
	await _settle(2)


func _drive(vp: SubViewport, battle: Control, state: String) -> bool:
	var target_card := _find(battle, "card_body_c0")   # 月光蛊：single_enemy
	var plain_card := _find(battle, "card_body_c1")    # 石皮蛊：none
	var enemy := _find(battle, "enemy_actor_e0")
	if target_card == null or plain_card == null or enemy == null:
		print("[PROBE] FAIL node missing target=%s plain=%s enemy=%s" % [
			str(target_card), str(plain_card), str(enemy)])
		return false

	match state:
		"hover":
			(plain_card as Button).mouse_entered.emit()
			await _settle(4)
			var tip := _find(battle, "battle_hand_tooltip_host")
			_dump_hover_geometry(plain_card, tip)
			return tip is Control and (tip as Control).visible
		"drag_near":
			# 超过阈值但不足 DRAG_CAST_DISTANCE_PX(64)：影卡应为墨框「未就绪」态。
			var from_near: Vector2 = (plain_card as Control).get_global_rect().get_center()
			await _press_drag(vp, battle, from_near, from_near + Vector2(0, -40))
			return _viewport_child(battle, "battle_drag_proxy") != null
		"drag_free":
			var from: Vector2 = (plain_card as Control).get_global_rect().get_center()
			await _press_drag(vp, battle, from, from + Vector2(0, -170))
			return _viewport_child(battle, "battle_drag_proxy") != null
		"aim_free":
			var from2: Vector2 = (target_card as Control).get_global_rect().get_center()
			await _press_drag(vp, battle, from2, from2 + Vector2(300, -120))
			return _viewport_child(battle, "battle_aim_line") != null
		"aim_hot":
			var from3: Vector2 = (target_card as Control).get_global_rect().get_center()
			var to3: Vector2 = (enemy as Control).get_global_rect().get_center()
			await _press_drag(vp, battle, from3, to3)
			return _viewport_child(battle, "battle_aim_line") != null
	return false


## 输入驱动：按下 → 移动（跨阈值触发拖拽/瞄准）→ 停住供截图（**不抬起**）。
func _press_drag(vp: SubViewport, battle: Control, from: Vector2, to: Vector2) -> void:
	_motion(vp, from)
	await _settle(1)
	_btn(vp, from, true)
	await _settle(1)
	_motion(vp, from.lerp(to, 0.35))
	await _settle(1)
	_motion(vp, to)
	await _settle(3)
	# 手势内部态现在归手牌组件（宿主那套已删）——从组件上读，字段名同义。
	print("[PROBE]   drag: mouse=%s press=%s drag=%s aim=%s proxy=%s aimline=%s" % [
		str(battle.get_global_mouse_position()),
		str(_hand_of(battle).get("_press_pos")),
		str(_hand_of(battle).get("_dragging")),
		str(_hand_of(battle).get("_aiming")),
		str(_hand_of(battle).get("_drag_proxy")),
		str(_hand_of(battle).get("_aim"))])


## 手牌组件（手势与覆盖件的拥有者）。
func _hand_of(battle: Node) -> Node:
	return battle.get("_hand")


## 悬停态几何体检：先把矩形都打出来，再谈"好不好看"。
func _dump_hover_geometry(plain_card: Node, tip: Node) -> void:
	print("[PROBE]   card_rect=%s scale=%s" % [
		str((plain_card as Control).get_global_rect()), str((plain_card as Control).scale)])
	if not (tip is Control):
		return
	print("[PROBE]   tip_rect=%s" % str((tip as Control).get_global_rect()))
	for wanted in ["hand_tooltip_title", "TooltipView", "TipBody", "TitleRow",
			"QualityLabel", "EffectLabel", "CostLabel"]:
		var n := _find(tip, wanted)
		if n is Control:
			print("[PROBE]     %s rect=%s vis=%s" % [wanted,
				str((n as Control).get_global_rect()), str((n as Control).visible)])


func _capture_png(vp: SubViewport, state: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	if tex == null:
		print("[PROBE] FAIL no render target for %s" % state)
		_failed += 1
		return
	var img := tex.get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var out := ProjectSettings.globalize_path(OUT_DIR) + "/hand_" + state + ".png"
	img.save_png(out)
	print("[PROBE] SAVED %s %dx%d" % [out, img.get_width(), img.get_height()])


func _snapshot() -> Dictionary:
	return {
		"resources": {"shouyuan": 41, "hunpo": 7, "yuanstone": 12},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
		"layer": 3,
		"player": {"name": "问真", "hp": 94, "max_hp": 120, "shield": 12,
			"thoughts": 8, "primordial": 4},
		"actions": {"left": 8, "max": 12},
		"enemies": [
			{"id": "e0", "name": "毒瘴蛛", "hp": 23, "max_hp": 50, "shield": 0, "alive": true,
				"intent": {"type": "charge", "value": 3, "speed": 0, "detail": "蓄势待发"},
				"statuses": [{"name": "中毒", "stacks": 2}, {"name": "蓄力", "stacks": 1}]},
			{"id": "e1", "name": "石皮蝎", "hp": 66, "max_hp": 75, "shield": 0, "alive": true,
				"intent": {"type": "attack", "value": 8, "speed": 1, "detail": "猛击"},
				"statuses": [{"name": "石皮", "stacks": 3}]},
		],
		"hand": [
			{"id": "c0", "name": "月光蛊", "school_id": "light", "school_label": "光道", "quality": "一阶",
				"effect": "对敌造成 6 点伤害", "synergy": "月蛊同场时伤害 +2",
				"cost": "2", "cost_ex": "念头 2", "executable": true,
				"target_type": "single_enemy", "valid_target_ids": ["e0", "e1"],
				"dangerous": false, "known_risk": [], "block_reason": ""},
			{"id": "c1", "name": "石皮蛊", "school_id": "earth", "school_label": "土道", "quality": "一阶",
				"effect": "获得 10 点护盾", "synergy": "",
				"cost": "1", "cost_ex": "念头 1", "executable": true,
				"target_type": "none", "dangerous": false, "known_risk": [],
				"block_reason": ""},
			{"id": "c2", "name": "燃寿蛊", "school_id": "blood", "school_label": "血道", "quality": "二阶",
				"effect": "对敌造成 12 点伤害", "synergy": "",
				"cost": "3", "cost_ex": "念头 3", "executable": true,
				"target_type": "single_enemy", "valid_target_ids": ["e0"],
				"dangerous": true, "known_risk": ["寿元 -1"], "block_reason": ""},
		],
		"kill_moves": [
			{"name": "月噬", "sequence_display": "光·月 Ⅱ", "cost": "6",
				"executable": true, "block_reason": ""},
		],
		"inventory": {},
		"flee_available": true,
		"first_battle": false,
		"feedback": "",
		"dda_boss_hint": "",
	}


func _commands() -> Dictionary:
	return {
		"play_card": Callable(self, "_noop"),
		"end_turn": Callable(self, "_noop"),
		"refine": Callable(self, "_noop"),
		"flee": Callable(self, "_noop"),
	}


func _requested_states() -> Array:
	var wanted: Array = []
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if str(arg).begins_with("--only="):
			for part in str(arg).substr("--only=".length()).split(","):
				wanted.append(str(part).strip_edges())
	return wanted


## 递归扫视口子树：瞄准线挂在屏内 AimLayer(CanvasLayer) 下，影卡挂在视口根下。
func _viewport_child(battle: Node, prefix: String) -> Node:
	var vp := battle.get_viewport()
	if vp == null:
		return null
	for child in vp.get_children():
		var found := _find_by_prefix(child, prefix)
		if found != null:
			return found
	return null


func _find_by_prefix(node: Node, prefix: String) -> Node:
	if str(node.name).begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _find_by_prefix(child, prefix)
		if found != null:
			return found
	return null


func _motion(vp: SubViewport, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = Vector2.ZERO
	vp.push_input(event)


func _btn(vp: SubViewport, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	vp.push_input(event)


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


func _noop(_arg: Variant = null) -> void:
	pass
