extends GutTest

## GuTallFanHandView 的瞄准目标广播协议（2026-09-10）。
##
## 用户裁定：**组件只发 `aim_target_changed`，敌人高亮由宿主施加**
## （战斗屏现成入口 `BattleScreenView._set_drop_hot` → `GuEnemyActorView.set_drop_highlight`）。
## 本文件把这个"接线协议"钉成回归钉子，用**真实敌人卡组件**验证，而不是打桩：
##
##   1. 只在目标真变化时发（同目标不重复发）——宿主靠这个前提做前目标复位；
##   2. 目标变更时：前一目标关、新目标开，任何时刻至多一张亮；
##   3. 收线/松手/取消：先发 ""，所有高亮归零；
##   4. 松手命中：既提交 `play_card(card_id, target_id)`，也把高亮清干净（不留残亮）。

const FanHandView := preload("res://scripts/presentation/widgets/gu_tall_fan_hand_view.gd")
const EnemyActorScene := preload("res://scenes/ui/widgets/gu_enemy_actor.tscn")

const VIEWPORT_SIZE := Vector2i(1280, 720)
const HAND_ORIGIN := Vector2(0, 470)
const HAND_SIZE := Vector2(1280, 190)
const ENEMY_A := Rect2(700, 100, 208, 306)
const ENEMY_B := Rect2(960, 100, 208, 306)

var _hosts: Array = []
var _emitted: Array = []
var _actors: Dictionary = {}
var _lit := ""


func after_each() -> void:
	_emitted.clear()
	_actors.clear()
	_lit = ""
	for host in _hosts:
		if host != null and is_instance_valid(host):
			host.free()
	_hosts.clear()


## 命中检测命中 A、B 与空白三种情况；并记录每次广播。
func test_aim_target_broadcast_is_change_based_and_drives_highlight() -> void:
	var rig := await _mount_rig()
	var hand = rig["hand"]
	var vp: SubViewport = rig["viewport"]
	var targeted := _card_center(hand, 2)

	# 按下指向卡 → 位移超阈值进入瞄准态（此时还没指向任何目标）。
	_viewport_mouse_motion(vp, targeted)
	_viewport_mouse_button(vp, targeted, true)
	_viewport_mouse_motion(vp, targeted + Vector2(0, -60))
	await _settle(2)
	assert_eq(_emitted, [], "进入瞄准但未指向目标时不得广播")

	# 拖到敌人 A：广播 A，A 亮、B 不亮。
	_viewport_mouse_motion(vp, ENEMY_A.get_center())
	await _settle(2)
	assert_eq(_emitted, ["e_a"], "首次指向合法目标必须广播其 id")
	assert_true(_drop_highlight("e_a"), "被指向的敌人必须点亮")
	assert_false(_drop_highlight("e_b"), "未被指向的敌人不得点亮")

	# 同一目标连续停留：不得重复广播（宿主据此免于维护去重）。
	_viewport_mouse_motion(vp, ENEMY_A.get_center() + Vector2(6, 6))
	await _settle(2)
	assert_eq(_emitted, ["e_a"], "目标未变化时不得重复广播")

	# 拖到空白：广播 ""，A 熄灭。
	_viewport_mouse_motion(vp, Vector2(640, 60))
	await _settle(2)
	assert_eq(_emitted, ["e_a", ""], "离开所有目标必须广播空 id")
	assert_false(_drop_highlight("e_a"), "离开目标后必须熄灭")

	# 从空白直接拖到 B：只发 B（中间不产生多余的空广播）。
	_viewport_mouse_motion(vp, ENEMY_B.get_center())
	await _settle(2)
	assert_eq(_emitted, ["e_a", "", "e_b"], "换目标只在切换时广播")
	assert_true(_drop_highlight("e_b"), "新目标必须点亮")
	assert_false(_drop_highlight("e_a"), "旧目标不得残留高亮")

	# 松手命中 B：提交 play_card，并把高亮归零。
	var chosen: Array = rig["chosen"]
	_viewport_mouse_button(vp, ENEMY_B.get_center(), false)
	await _settle(3)
	assert_eq(_emitted, ["e_a", "", "e_b", ""], "松手后必须广播空 id 收尾")
	assert_eq(chosen, [["gu.gu_003", "e_b"]], "松手命中敌人必须按该目标提交")
	assert_false(_drop_highlight("e_a"), "结算后 A 不得残留高亮")
	assert_false(_drop_highlight("e_b"), "结算后 B 不得残留高亮")


## 右键取消：同样要清高亮，不能留一张亮着的敌人卡。
func test_right_click_cancel_clears_highlight_without_submitting() -> void:
	var rig := await _mount_rig()
	var hand = rig["hand"]
	var vp: SubViewport = rig["viewport"]
	var targeted := _card_center(hand, 2)

	_viewport_mouse_motion(vp, targeted)
	_viewport_mouse_button(vp, targeted, true)
	_viewport_mouse_motion(vp, targeted + Vector2(0, -60))
	await _settle(2)
	_viewport_mouse_motion(vp, ENEMY_A.get_center())
	await _settle(2)
	assert_true(_drop_highlight("e_a"), "取消前应处于点亮态（确认清零不是假阳性）")

	_viewport_right_click(vp, ENEMY_A.get_center())
	await _settle(3)
	assert_eq(_emitted, ["e_a", ""], "取消必须广播空 id")
	assert_false(_drop_highlight("e_a"), "取消后不得残留高亮")
	assert_eq(rig["chosen"], [], "取消不得提交命令")


# ————————————————————————— 接线与夹具 —————————————————————————

## 宿主侧接线：与 `BattleScreenView._set_drop_hot` 同一套协议——
## 先复位上一目标，再点亮新目标，目标是 "" 时只做复位。
## 这里刻意**照抄生产实现**而不是另写一套，测试才有意义。
func _apply_highlight(target_id: String) -> void:
	if _lit != "" and _actors.has(_lit):
		(_actors[_lit] as Control).call("set_drop_highlight", false)
	_lit = target_id
	if target_id != "" and _actors.has(target_id):
		(_actors[target_id] as Control).call("set_drop_highlight", true)


func _drop_highlight(enemy_id: String) -> bool:
	if not _actors.has(enemy_id):
		return false
	return bool((_actors[enemy_id] as Control).get("_drop_highlight"))


func _mount_rig() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = VIEWPORT_SIZE
	vp.gui_disable_input = false
	add_child(vp)
	_hosts.append(vp)

	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(stage)

	_actors.clear()
	_actors["e_a"] = _mount_enemy(stage, ENEMY_A, "石游子")
	_actors["e_b"] = _mount_enemy(stage, ENEMY_B, "岭犬")

	var hand = FanHandView.new()
	hand.position = HAND_ORIGIN
	hand.size = HAND_SIZE
	stage.add_child(hand)
	var chosen: Array = []
	hand.setup(_cards(), func(card_id, target_id): chosen.append([card_id, target_id]))
	hand.set_target_provider(func(pos: Vector2) -> String:
		if ENEMY_A.has_point(pos):
			return "e_a"
		if ENEMY_B.has_point(pos):
			return "e_b"
		return "")
	_emitted.clear()
	hand.aim_target_changed.connect(func(target_id): _emitted.append(target_id))
	hand.aim_target_changed.connect(_apply_highlight)
	await _settle(20)
	return {"viewport": vp, "hand": hand, "chosen": chosen}


func _mount_enemy(stage: Control, rect: Rect2, label: String) -> Control:
	var actor: Control = EnemyActorScene.instantiate()
	actor.position = rect.position
	actor.custom_minimum_size = rect.size
	actor.size = rect.size
	stage.add_child(actor)
	actor.setup({"id": label, "name": label, "hp": 12, "max_hp": 12, "shield": 0,
			"statuses": [], "intent": {"type": "attack", "value": 4, "detail": "冲撞"}})
	return actor


## 真实形态的卡 id（**带点**）：探针与单测若用 c0/c1 这类无点 id，
## 会漏掉"节点名清洗"这一类 bug（2026-09-10 真机冒烟踩过）。
func _cards() -> Array:
	var out: Array = []
	for i in 3:
		out.append({
			"id": "gu.gu_%03d" % (i + 1), "name": "测试蛊 %d" % (i + 1),
			"school": "月", "quality": "一阶", "effect": "造成 6 点伤害",
			"cost": "1", "executable": true, "target_type": "single_enemy", "kind": "attack",
		})
	return out


## 取第 index 张卡的**可视中心**：卡有旋转与边缘缩放，必须走 global rect 而不是位置相加。
func _card_center(hand, index: int) -> Vector2:
	var card = hand.get("_cards")[index]
	return (card as Control).get_global_rect().get_center()


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func _viewport_mouse_motion(viewport: SubViewport, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	viewport.push_input(event)


func _viewport_mouse_button(viewport: SubViewport, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	viewport.push_input(event)


func _viewport_right_click(viewport: SubViewport, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = position
	event.global_position = position
	viewport.push_input(event)
