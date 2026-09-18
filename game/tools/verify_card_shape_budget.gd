extends SceneTree

## 卡形改造的**布局预算实测**探针（2026-09-10）。
##
## 换卡形（168×74 横向 → 110×154 竖长）最硬的约束不是代码，是**高度从哪来**：
## battle_screen 的 Root 是 VBoxContainer，BattleStage(size_flags=3, 吃剩余) +
## HandStage(size_flags=0, 按内容) 同处一个纵向流里，手牌区每长高 1px 就直接从
## 战场区扣 1px。所以本探针做一件事：把同一棵树量两遍。
##
##   pass A —— **现役形态**（竖长卡 110×154，真实挂载，不改任何东西）
##   pass B —— 旧形态（168×74，运行时改卡体 min_size 模拟）——只作对照数字
##
## 判定一律打在 pass A 上：这才是真机上会跑的那一份。
##
## 然后逐项对比 battle_hud / BattleStage / 敌人卡 / HandStage / 手牌 的矩形，
## 并判定：敌人卡是否被压到低于自身最小高（会裁剪）、手牌是否出屏。
##
## 用法（需真实窗口，不能 --headless）：
##   tools\godot.ps1 --path . -s tools/verify_card_shape_budget.gd

const BattleScene := "res://scenes/ui/screens/battle_screen.tscn"
const VIEWPORT_SIZE := Vector2i(1280, 720)
## 现役卡形（GuTallFanHandView 默认）。改它的话这里也要跟着改。
## 2026-09-11 战斗视觉重构：110×154 → 126×176。
const CURRENT_CARD := Vector2(126, 176)
## 旧卡形，仅用于对照打印"换形前后差多少"。
const LEGACY_CARD := Vector2(168, 74)
## 敌人卡尺寸（gu_enemy_actor.tscn / battle_screen_view，2026-09-11 视觉重构 236×352）。
const ENEMY_CARD_MIN := Vector2(236, 352)

## 参与对比的节点路径（相对 BattleScreen）。
const PROBES := {
	"hud": "Root/battle_hud",
	"stage": "Root/BattleStage",
	"field": "Root/BattleStage/battle_field",
	"enemy_panel": "Root/BattleStage/battle_field/EnemyPanel",
	"hand_stage": "Root/HandStage",
	"hand_box": "Root/HandStage/HandMargin/battle_hand",
	"hand": "Root/HandStage/HandMargin/battle_hand/HandArea/Hand",
}

var _failed := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := await _measure("A_current", Vector2.ZERO)
	var b := await _measure("B_legacy", LEGACY_CARD)
	_report(a, b)
	print("[BUDGET] FAILED=%d" % _failed)
	quit(1 if _failed > 0 else 0)


## 挂一棵全新的战斗屏，可选地把卡体改成目标尺寸，然后量所有关注节点的矩形。
func _measure(label: String, card_size: Vector2) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = VIEWPORT_SIZE
	vp.gui_disable_input = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var battle: Control = (load(BattleScene) as PackedScene).instantiate()
	vp.add_child(battle)
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.mount_snapshot(_snapshot(), _commands())
	await _settle(6)
	if card_size != Vector2.ZERO:
		_resize_cards(battle, card_size)
		await _settle(6)
	var rects := {}
	for key in PROBES:
		var node := battle.get_node_or_null(str(PROBES[key]))
		rects[key] = (node as Control).get_global_rect() if node is Control else Rect2()
	# ⚠️ 不能按 `card_box_<id>` 反查：真实卡 id 含点（gu.gu_001），Godot 节点名会把它
	# 清洗成下划线。这里按前缀取第一张，与 id 形状无关。
	var cards := battle.find_children("card_box_*", "", true, false)
	rects["first_card"] = (cards[0] as Control).get_global_rect() if not cards.is_empty() else Rect2()
	# 战场区里内容真正的底边：用来判断那 80px 是"吃掉了空白余量"还是"顶到了内容"。
	# ⚠️ 注意 battle_field 的子节点是**绝对定位**（不随面板高度重排），所以不能拿
	# BattleStage 的底边当判据——真正的风险是手牌区顶边撞上战场最靠下的控件。
	rects["field_bottom"] = _content_bottom(battle.get_node_or_null("Root/BattleStage"))
	rects["lowest_in_field"] = _lowest_child(battle.get_node_or_null("Root/BattleStage/battle_field"))
	rects["field_children"] = _describe_children(
			battle.get_node_or_null("Root/BattleStage/battle_field"))
	# 手牌**卡带**（所有卡的外接矩形）与战场控件的相交检测。不能拿 HandStage 整块去比：
	# 它是通栏面板，右侧本来就被 OpsDock 压着（靠 HandMargin.right=210 让位），
	# 那种相交是设计使然；真正会出事的是"卡"撞上战场控件。
	rects["card_band"] = _union_rect(cards)
	rects["battle_controls"] = _collect_controls(battle.get_node_or_null("Root/BattleStage"))
	print("[BUDGET] %-10s %s" % [label, _fmt(rects)])
	vp.queue_free()
	await _settle(2)
	return rects


## 运行时把每张卡的 min_size 换成候选值——模拟"同布局换卡形"，不碰任何代码。
func _resize_cards(battle: Node, size: Vector2) -> void:
	for box in battle.find_children("card_box_*", "", true, false):
		if box is Control:
			(box as Control).custom_minimum_size = size
	for body in battle.find_children("card_body_*", "", true, false):
		if body is Control:
			(body as Control).custom_minimum_size = size


func _report(a: Dictionary, b: Dictionary) -> void:
	var hand_a: Rect2 = a["hand_stage"]
	var hand_b: Rect2 = b["hand_stage"]
	var stage_a: Rect2 = a["stage"]
	var stage_b: Rect2 = b["stage"]
	var card_a: Rect2 = a["first_card"]
	var card_b: Rect2 = b["first_card"]
	print("[BUDGET] --- 高度账 ---")
	print("[BUDGET] 卡高 %d → %d (+%d)" % [
		int(card_a.size.y), int(card_b.size.y), int(card_b.size.y - card_a.size.y)])
	print("[BUDGET] HandStage %d → %d (%+d)" % [
		int(hand_a.size.y), int(hand_b.size.y), int(hand_b.size.y - hand_a.size.y)])
	print("[BUDGET] BattleStage %d → %d (%+d)" % [
		int(stage_a.size.y), int(stage_b.size.y), int(stage_b.size.y - stage_a.size.y)])
	print("[BUDGET] BattleStage 收缩量 == HandStage 增长量 → %s" % str(
		int(stage_a.size.y - stage_b.size.y) == int(hand_b.size.y - hand_a.size.y)))
	# 手牌是否被挤出屏幕：HandStage 底边超出视口即失败（判**现役** A）。
	if hand_a.end.y > float(VIEWPORT_SIZE.y) + 0.5:
		print("[BUDGET] ✗ 手牌区被挤出屏幕：底边 %.1f > %d" % [
			hand_a.end.y, VIEWPORT_SIZE.y])
		_failed += 1
	else:
		print("[BUDGET] ✓ 手牌区底边 %.1f ≤ %d，未出屏" % [hand_a.end.y, VIEWPORT_SIZE.y])
	# 战场区是否被压到装不下敌人卡：EnemyPanel 高 < 敌人卡最小高即会被裁剪。
	var field_a: Rect2 = a["field"]
	var enemy_a: Rect2 = a["enemy_panel"]
	if enemy_a.size.y < ENEMY_CARD_MIN.y - 0.5:
		print("[BUDGET] ✗ 敌人卡 %.1f < 最小高 %.0f，立绘/意图会被裁剪" % [
			enemy_a.size.y, ENEMY_CARD_MIN.y])
		_failed += 1
	else:
		print("[BUDGET] ✓ 敌人卡 %.1f ≥ 最小高 %.0f，未裁剪（战场区 %.1f）" % [
			enemy_a.size.y, ENEMY_CARD_MIN.y, field_a.size.y])
	# 手牌横向容量：必须用**实测的手牌容器宽**，不能拿窗口宽减个估值——
	# HandMargin 左右各留边（右 210 是给右下 OpsDock 让位的），拿满宽会把容量算高。
	var usable: float = (a["hand_box"] as Rect2).size.x
	print("[BUDGET] 手牌容器实测宽 %.0f" % usable)
	print("[BUDGET] 扇形容量（步进下限=卡宽×0.45）：现役 %d 宽 → %.1f 张 ／ 旧 %d 宽 → %.1f 张" % [
		int(CURRENT_CARD.x), 1.0 + (usable - CURRENT_CARD.x) / (CURRENT_CARD.x * 0.45),
		int(LEGACY_CARD.x), 1.0 + (usable - LEGACY_CARD.x) / (LEGACY_CARD.x * 0.45)])
	# 卡带是否与战场控件相交：这才是换卡形真正要过的门。
	var band_a: Rect2 = a["card_band"]
	var band_b: Rect2 = b["card_band"]
	var hits_a := _collisions(a["battle_controls"], band_a)
	var hits_b := _collisions(b["battle_controls"], band_b)
	print("[BUDGET] --- 卡带 vs 战场控件 ---")
	print("[BUDGET] 现役卡带 %s ／ 旧形态卡带 %s" % [_rect_str(band_a), _rect_str(band_b)])
	print("[BUDGET] 现役碰撞 %s ／ 旧形态碰撞 %s" % [hits_a, hits_b])
	if not hits_a.is_empty():
		print("[BUDGET] ✗ 现役卡带撞上战场控件：%s" % str(hits_a))
		_failed += 1
	if band_a.end.x > float(VIEWPORT_SIZE.x) + 0.5 or band_a.position.x < -0.5:
		print("[BUDGET] ✗ 现役卡带出屏：x %.1f..%.1f" % [band_a.position.x, band_a.end.x])
		_failed += 1
	if band_a.end.y > float(VIEWPORT_SIZE.y) + 0.5:
		print("[BUDGET] ✗ 现役卡带下沉出屏：y 底边 %.1f" % band_a.end.y)
		_failed += 1
	if hits_a.is_empty() and band_a.end.x <= float(VIEWPORT_SIZE.x) + 0.5 \
			and band_a.position.x >= -0.5 and band_a.end.y <= float(VIEWPORT_SIZE.y) + 0.5:
		print("[BUDGET] ✓ 现役卡带在屏内且与战场控件无交叠")
	print("[BUDGET] stage 子节点：%s" % str(b["field_children"]))


## 子树里所有 Control 的底边最大值（可视内容真正占到哪里）。
func _content_bottom(node: Node) -> float:
	if node == null:
		return 0.0
	var bottom := 0.0
	for child in node.get_children():
		if child is Control:
			bottom = maxf(bottom, (child as Control).get_global_rect().end.y)
			bottom = maxf(bottom, _content_bottom(child))
	return bottom


## 所有卡的外接矩形（卡带）。
func _union_rect(controls: Array) -> Rect2:
	var union := Rect2()
	var first := true
	for node in controls:
		if not (node is Control):
			continue
		var rect: Rect2 = (node as Control).get_global_rect()
		if rect.size == Vector2.ZERO:
			continue
		union = rect if first else union.merge(rect)
		first = false
	return union


## 收集子树里所有可见 Control 的名称与矩形（用于相交检测）。
func _collect_controls(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	for child in node.get_children():
		if child is Control and (child as Control).visible:
			var r: Rect2 = (child as Control).get_global_rect()
			if r.size != Vector2.ZERO:
				out.append({"name": str(child.name), "rect": r})
		out.append_array(_collect_controls(child))
	return out


## 找子树里底边最大的那个 Control 及其名字（用于报告"谁最靠下"）。
func _lowest_child(node: Node) -> Dictionary:
	var best := {"name": "", "bottom": 0.0}
	if node == null:
		return best
	for child in node.get_children():
		var bottom := _content_bottom(child)
		if bottom > float(best["bottom"]):
			best = {"name": str(child.name), "bottom": bottom}
	return best


func _describe_children(node: Node) -> String:
	if node == null:
		return ""
	var parts: Array[String] = []
	for child in node.get_children():
		if child is Control:
			var r: Rect2 = (child as Control).get_global_rect()
			parts.append("%s=(%d,%d %dx%d)" % [child.name, int(r.position.x),
					int(r.position.y), int(r.size.x), int(r.size.y)])
	return " ".join(parts)


## 卡带与哪些战场控件相交（返回名称数组）。
func _collisions(controls: Array, band: Rect2) -> Array:
	var hits: Array = []
	if band.size == Vector2.ZERO:
		return hits
	for item in controls:
		var rect: Rect2 = item["rect"]
		if band.intersects(rect):
			hits.append(str(item["name"]))
	return hits


func _rect_str(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [int(r.position.x), int(r.position.y),
			int(r.size.x), int(r.size.y)]


func _fmt(rects: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["hud", "stage", "enemy_panel", "hand_stage", "first_card"]:
		var r: Rect2 = rects[key]
		if r.size == Vector2.ZERO:
			continue
		parts.append("%s=(%d,%d %dx%d)" % [key, int(r.position.x), int(r.position.y),
				int(r.size.x), int(r.size.y)])
	return " ".join(parts)


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame


func _snapshot() -> Dictionary:
	return {
		"resources": {"shouyuan": 41, "hunpo": 7, "yuanstone": 12},
		"contracts": [],
		"player": {"hp": 30, "max_hp": 30, "shield": 0, "statuses": []},
		"enemies": [
			{"id": "e1", "name": "石游子", "hp": 12, "max_hp": 12, "shield": 0,
				"intent": {"type": "attack", "value": 6, "speed": 0, "detail": "重击"},
				"statuses": []},
			{"id": "e2", "name": "岭犬", "hp": 18, "max_hp": 18, "shield": 2,
				"intent": {"type": "defend", "value": 4, "speed": 1, "detail": "护身"},
				"statuses": []},
		],
		"hand": [
			{"id": "gu.gu_001", "name": "月光蛊", "school": "月", "school_label": "月道",
				"quality": "一阶", "effect": "造成 6 点伤害", "cost": "1", "cost_ex": "念头 1",
				"target_type": "single_enemy", "executable": true, "kind": "attack",
				"valid_target_ids": ["e1", "e2"]},
			{"id": "gu.gu_002", "name": "青刺蛊", "school": "木", "school_label": "木道",
				"quality": "二阶", "effect": "造成 9 点伤害并施加流血", "cost": "2",
				"cost_ex": "念头 2", "target_type": "single_enemy", "executable": true,
				"kind": "attack", "valid_target_ids": ["e1", "e2"]},
			{"id": "gu.gu_003", "name": "净心蛊", "school": "魂", "school_label": "魂道",
				"quality": "一阶", "effect": "移除一个负面状态", "cost": "1", "cost_ex": "念头 1",
				"target_type": "none", "executable": true, "kind": "control"},
			{"id": "gu.gu_004", "name": "血肉蛊", "school": "血", "school_label": "血道",
				"quality": "三阶", "effect": "回复 8 点气血，代价 3 寿元", "cost": "2",
				"cost_ex": "念头 2", "target_type": "none", "executable": false,
				"kind": "control", "block_reason": "寿元不足"},
		],
		"piles": {"draw": 12, "discard": 3, "exhaust": 0},
		"primordial": 3,
	}


func _commands() -> Dictionary:
	return {
		"play_card": Callable(self, "_noop"),
		"end_turn": Callable(self, "_noop"),
		"leave_node": Callable(self, "_noop"),
	}


func _noop(_a = null, _b = null) -> void:
	pass
