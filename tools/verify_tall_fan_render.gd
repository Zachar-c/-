extends SceneTree

## 竖长卡横向扇形手牌 渲染探针（2026-09-10）。
##
## 把 GuTallFanHandView 挂进 1280×720 的 SubViewport，喂 18 张竖长卡（110×154），
## 驱动并落图到 .preview/tall_fan_<state>.png，供肉眼级检查：
##   fan_idle        — 18 张全展开，检查步进/重叠/倾角/边缘透视缩放/是否越界
##   fan_hover       — 悬停中间一张：上浮放大回正 + 左右邻居让位 + 其余压暗
##   aim_free        — 攻击指向卡拖到空白：半透明虚线弧箭（朱砂），敌人高亮必须全灭
##   aim_control_hot — 控制指向卡拖到敌人：实线加粗弧箭（青灰）+ 目标玉绿高亮
##   aim_hot         — 攻击指向卡拖到敌人：实线加粗弧箭（朱砂）+ 目标玉绿高亮
##
## 敌人侧用**真实 GuEnemyActorView**（不是探针自画的色块），高亮走生产入口
## `set_drop_highlight()`，接线方式即宿主侧 `aim_target_changed → _set_drop_hot`。
## 每态都断言"亮着的敌人卡至多 1 张"，防残亮。
##
## 用法（需真实窗口，不能 --headless）：
##   tools\godot.ps1 --path . -s tools/verify_tall_fan_render.gd

const TallFan := preload("res://scripts/presentation/widgets/gu_tall_fan_hand_view.gd")
## 敌人卡场景**不能 const preload**：preload 会在主脚本编译期就把整条依赖链
## （含 wenzhen_master_theme.gd → autoload `AudioManager`）一起编译，而 `-s` 主脚本
## 编译时 autoload 尚未注册，会报「Identifier not found: AudioManager」。
## 惰性 load 发生在 autoload 就绪之后，规避该顺序问题。
const ENEMY_ACTOR_PATH := "res://scenes/ui/widgets/gu_enemy_actor.tscn"

const OUT_DIR := "res://.preview"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const HAND_RECT := Rect2(0, 530, 1280, 190)
const CARD_SIZE := Vector2(126, 176)
const CARD_COUNT := 18
const STATES := ["fan_idle", "fan_hover", "aim_free", "aim_control_hot", "aim_hot"]

var _failed := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	for state in STATES:
		await _capture_state(state)
	print("[TALL] FAILED=%d" % _failed)
	quit(1 if _failed > 0 else 0)


func _capture_state(state: String) -> void:
	var vp := SubViewport.new()
	vp.size = VIEWPORT_SIZE
	vp.gui_disable_input = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var stage := Control.new()
	stage.name = "stage"
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(stage)

	# ⚠️ 挂敌人卡前必须等一帧：在 `-s` 主脚本的 `_initialize()` 阶段，`add_child`
	# **不会同步触发 `_ready`**（SceneTree 还没开始跑帧），于是组件里的 `@onready`
	# 全为 null，`setup()` 会在第一行赋值处静默失败——敌人卡变成"有脚本但没内容"的
	# 空壳，而 `set_drop_highlight` 仍可调用，把问题整个藏住。
	await _settle(1)
	var enemies := _mount_enemies(stage)
	var hand = TallFan.new()
	hand.name = "tall_fan_hand"
	hand.card_size = CARD_SIZE
	hand.position = HAND_RECT.position
	hand.size = HAND_RECT.size
	stage.add_child(hand)
	hand.setup(_cards(), Callable(self, "_on_chosen"), Callable(self, "_on_hover"))
	hand.set_target_provider(func(pos: Vector2) -> String:
		for enemy in enemies:
			if (enemy as Control).get_global_rect().has_point(pos):
				return str(enemy.get_meta("enemy_id", ""))
		return "")
	# 接线：组件只发信号，高亮由宿主施加（用户裁定 2026-09-10）。
	hand.aim_target_changed.connect(func(target_id): _apply_drop_highlight(enemies, target_id))
	# 等布局补间**真的跑完**再驱动交互：只等固定帧数在快帧率下会拿到半途坐标，
	# 命中点就会算在卡片还没到位的位置上（本探针踩过）。
	await _wait_settled(hand)

	var ok := await _drive(vp, hand, enemies, state)
	await _capture(vp, state)
	print("[TALL] %s ok=%s" % [state, str(ok)])
	if not ok:
		_failed += 1
	vp.queue_free()
	await _settle(2)


func _drive(vp: SubViewport, hand, enemies: Array, state: String) -> bool:
	match state:
		"fan_idle":
			_dump(hand, "idle")
			var first = hand.get("_cards")[0]
			var last = hand.get("_cards")[CARD_COUNT - 1]
			# 不越界：整排（含卡宽）必须落在手牌区矩形内。
			var left: float = (first as Control).position.x
			var right: float = (last as Control).position.x + CARD_SIZE.x
			print("[TALL]   span=[%.0f, %.0f] hand_w=%.0f" % [left, right, hand.size.x])
			return left >= -1.0 and right <= hand.size.x + 1.0
		"fan_hover":
			var middle = hand.get("_cards")[CARD_COUNT / 2]
			var probe := (middle as Control).get_global_rect().position \
					+ Vector2(CARD_SIZE.x * 0.25, CARD_SIZE.y * 0.5)
			_motion(vp, probe)
			_probe_hit(hand, probe)
			await _wait_settled(hand)
			_dump(hand, "hover")
			return int(hand.get("_hovered_index")) == CARD_COUNT / 2
		"aim_free":
			await _press_drag(vp, hand.get("_cards")[CARD_COUNT / 2] as Control,
					Vector2(300, 300))
			_aim_dump(hand)
			# 未指向目标：高亮必须全灭（"无目标还亮着一张"是最容易漏的残亮 bug）。
			print("[TALL]   highlight=%s" % _highlight_state(enemies))
			return _aim_points(hand) > 8 and not bool(hand.get("_aim").call("is_hot")) \
					and _lit_count(enemies) == 0
		"aim_control_hot":
			await _press_drag(vp, hand.get("_cards")[6] as Control,
					(enemies[0] as Control).get_global_rect().get_center())
			_aim_dump(hand)
			print("[TALL]   highlight=%s" % _highlight_state(enemies))
			var line = hand.get("_aim")
			return _aim_points(hand) > 8 and bool(line.call("is_hot")) \
					and line.call("color") == GuStyle.CONTRACT_BLUE \
					and _lit_count(enemies) == 1 \
					and bool((enemies[0] as Control).get("_drop_highlight"))
		"aim_hot":
			await _press_drag(vp, hand.get("_cards")[CARD_COUNT / 2] as Control,
					(enemies[1] as Control).get_global_rect().get_center())
			_aim_dump(hand)
			print("[TALL]   highlight=%s" % _highlight_state(enemies))
			var line2 = hand.get("_aim")
			return _aim_points(hand) > 8 and bool(line2.call("is_hot")) \
					and line2.call("color") == GuStyle.CINNABAR \
					and _lit_count(enemies) == 1 \
					and bool((enemies[1] as Control).get("_drop_highlight"))
	return false


## 亮着的敌人卡数量：任何时刻至多 1（"只亮新目标、旧目标必熄"）。
func _lit_count(enemies: Array) -> int:
	var count := 0
	for enemy in enemies:
		if bool((enemy as Control).get("_drop_highlight")):
			count += 1
	return count


## 悬停命中点：扇形里第 i 张卡的**可见条**（右侧被 i+1 压住，取左侧那条）。
## 命中诊断：列出所有"矩形包含该点"的卡及其 z，看 GUI 选中的是不是最上那张。
func _probe_hit(hand, point: Vector2) -> void:
	var hits: Array = []
	var cards = hand.get("_cards")
	for i in cards.size():
		var rect: Rect2 = (cards[i] as Control).get_global_rect()
		if rect.has_point(point):
			hits.append("%d(z=%d,rot=%.2f)" % [i, int((cards[i] as Control).z_index),
					rad_to_deg((cards[i] as Control).rotation)])
	print("[TALL]   probe=%s contained_by=%s" % [str(point.round()), str(hits)])


func _visible_point(card: Control, index: int, hand) -> Vector2:
	var origin := card.get_global_transform().origin
	return origin + Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y * 0.4)


func _press_drag(vp: SubViewport, card: Control, to: Vector2) -> void:
	var from := card.get_global_transform().origin + Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y * 0.5)
	_motion(vp, from)
	await _settle(1)
	_btn(vp, from, true)
	await _settle(1)
	_motion(vp, from.lerp(to, 0.4))
	await _settle(1)
	_motion(vp, to)
	await _settle(4)


func _aim_points(hand) -> int:
	var line = hand.get("_aim")
	if line == null:
		return 0
	var points: PackedVector2Array = line.call("points")
	return points.size()


func _aim_dump(hand) -> void:
	var line = hand.get("_aim")
	if line == null:
		print("[TALL]   aim=null")
		return
	var points: PackedVector2Array = line.call("points")
	print("[TALL]   aim points=%d hot=%s color=%s first=%s last=%s" % [points.size(),
			str(line.call("is_hot")), str(line.call("color")),
			str(points[0]), str(points[points.size() - 1])])


func _dump(hand, label: String) -> void:
	var cards = hand.get("_cards")
	print("[TALL]   %s state: hovered=%s size=%s card_size=%s step=%.1f" % [label,
			str(hand.get("_hovered_index")), str(hand.size), str(hand.card_size),
			hand.call("_layout_step", cards.size())])
	for i in [0, CARD_COUNT / 2, CARD_COUNT - 1]:
		var card = cards[i]
		print("[TALL]   %s card[%d] pos=%s rot=%.2f scale=%.3f z=%d dim=%.2f" % [label, i,
				str((card as Control).position.round()), rad_to_deg((card as Control).rotation),
				(card as Control).scale.x, int((card as Control).z_index),
				(card as Control).modulate.r])


func _mount_enemies(stage: Control) -> Array:
	# 用**真实敌人卡组件**而不是自画的 PanelContainer：
	#   ① 高亮走的是生产入口 GuEnemyActorView.set_drop_highlight（玉绿描边 + 立绘提亮），
	#      探针截图因此是真实视觉，不是探针自己画出来的近似色块；
	#   ② 组件必须在 add_child 之后才能 setup（@onready 要等入树）。
	var enemies: Array = []
	var scene: PackedScene = load(ENEMY_ACTOR_PATH)
	for i in 2:
		var actor: Control = scene.instantiate()
		actor.name = "enemy_%d" % i
		actor.set_meta("enemy_id", "e%d" % i)
		actor.position = Vector2(700 + i * 240, 120)
		actor.custom_minimum_size = Vector2(236, 352)
		actor.size = Vector2(236, 352)
		actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(actor)
		if not actor.is_node_ready():
			print("[TALL] ✗ 敌人卡尚未 _ready：@onready 未解析，setup 会静默失败")
			_failed += 1
		actor.setup({
			"id": "e%d" % i,
			"name": "石游子" if i == 0 else "岭犬",
			"hp": 12 + i * 6, "max_hp": 12 + i * 6, "shield": i,
			"statuses": [],
			"intent": {"type": "attack", "value": 6, "speed": 0, "detail": "重击"},
		})
		# 自检：脚本真的挂上了才能证明"高亮走的是生产入口"，否则只是在无脚本节点上空转。
		if not actor.has_method("set_drop_highlight"):
			print("[TALL] ✗ 敌人卡脚本未挂载，高亮断言无意义：%s" % actor.get_class())
			_failed += 1
		enemies.append(actor)
	return enemies


## 宿主侧接线：把组件的瞄准目标广播翻译成敌人卡的放置高亮。
## 与 BattleScreenView._set_drop_hot 同一套协议（先复位旧目标，再点亮新目标）。
func _apply_drop_highlight(enemies: Array, target_id: String) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var is_target := str((enemy as Control).get_meta("enemy_id", "")) == target_id
		(enemy as Control).call("set_drop_highlight", is_target)


## 读出所有敌人卡的高亮态，供断言与比对截图。
func _highlight_state(enemies: Array) -> String:
	var parts: Array[String] = []
	for enemy in enemies:
		parts.append("%s=%s" % [str((enemy as Control).get_meta("enemy_id", "")),
				str(bool((enemy as Control).get("_drop_highlight")))])
	return " ".join(parts)


func _enemy_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED
	box.border_color = GuStyle.ENEMY_CARD_BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	return box


func _cards() -> Array:
	var names := ["月光蛊", "石皮蛊", "小光蛊", "生机草", "血牙蛊", "燃寿蛊", "凝气蛊",
			"腐骨蛊", "回春蛊", "裂石蛊", "霜降蛊", "焰心蛊", "蛊影蛊", "拾魂蛊",
			"退风蛊", "镇魂蛊", "噬心蛊", "空明蛊"]
	var schools := ["光道", "土道", "光道", "木道", "血道", "血道", "气道", "骨道", "木道",
			"土道", "水道", "火道", "气道", "魂道", "风道", "魂道", "血道", "气道"]
	var effects := ["对敌造成 8 点伤害", "获得 12 点护盾", "恢复 5 点气血", "净化 1 层负面",
			"对敌造成 5 点伤害", "对敌造成 14 点伤害", "强化自身 2 层", "对敌施加中毒",
			"恢复 7 点气血", "击碎 1 点护盾", "施加霜冻", "施加灼烧", "潜行 1 回合",
			"回收 1 张蛊", "降低敌方速度", "震慑 1 层", "吸取 3 点气血", "清空自身负面"]
	var cards: Array = []
	for i in names.size():
		# 第 6 张做成「控制指向卡」（不造成伤害）用于验证青灰线；其余指向卡按攻击算。
		var targeted := i == 6 or i % 3 == 0
		cards.append({
			"id": "gu.gu_%03d" % (i + 1),
			"name": names[i],
			"school": schools[i],
			"quality": "一阶" if i % 4 != 3 else "二阶",
			"effect": effects[i],
			"cost": str(1 + i % 4),
			"kind": "control" if i == 6 else "attack",
			"executable": true,
			"target_type": "single_enemy" if targeted else "none",
		})
	return cards


func _capture(vp: SubViewport, state: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	if tex == null:
		print("[TALL] FAIL no render target for %s" % state)
		_failed += 1
		return
	var img := tex.get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var out := ProjectSettings.globalize_path(OUT_DIR) + "/tall_fan_" + state + ".png"
	img.save_png(out)
	print("[TALL] SAVED %s %dx%d" % [out, img.get_width(), img.get_height()])


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


## 等补间收敛：逐帧比较所有卡的 position，连续两帧一致即认为停稳。
func _wait_settled(hand, max_frames: int = 90) -> void:
	var tracked = hand.get("_cards")
	var previous := PackedVector2Array()
	for _i in max_frames:
		await process_frame
		var current := PackedVector2Array()
		for card in tracked:
			current.append((card as Control).position)
		if current == previous:
			return
		previous = current


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame


func _on_chosen(_card_id: String, _target_id: String) -> void:
	pass


func _on_hover(_card_id: String) -> void:
	pass
