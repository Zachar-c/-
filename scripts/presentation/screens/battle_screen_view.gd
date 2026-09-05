class_name BattleScreenView
extends MarginContainer

## 战斗屏（Godot 官方 .tscn 节点树版，替代 ui/screens/battle_screen.guitkx）。
##
## 战斗状态是只读快照；**交互态是本屏唯一的本地状态**（mode / card / target_id /
## confirming / expanded_enemies）。转 .tscn 后这些从 RUITK 的 useState
## 变成脚本成员变量——比整树重渲染更好管，也更好调试。
##
## 出牌判定顺序（与原实现一致，不要改）：
##   1. target_type == "single_enemy"  → 进入选目标，等玩家点敌人
##   2. known_risk or dangerous        → 弹确认，确认后才下发
##   3. 其余                            → 直接下发

const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuEnemyActorScene := preload("res://scenes/ui/widgets/gu_enemy_actor.tscn")

const MAX_VISIBLE_ENEMIES := 3

@onready var _top_bar = $Root/battle_hud/TopBar
@onready var _player_panel = $Root/battle_field/PlayerPanel
@onready var _enemy_panel = $Root/battle_field/EnemyPanel
@onready var _inventory = $Root/battle_field/Inventory
@onready var _feedback_toast = $Root/FeedbackToast
@onready var _hint_host: VBoxContainer = $Root/HintHost
@onready var _primordial_label: Label = $Root/battle_hand/HandMetaRow/PrimordialLabel
@onready var _piles_label: Label = $Root/battle_hand/HandMetaRow/PilesLabel
@onready var _hand = $Root/battle_hand/Hand
@onready var _kill_host: VBoxContainer = $Root/battle_hand/KillHost
@onready var _ops_row: HBoxContainer = $Root/battle_hand/OpsRow
@onready var _mode_host: VBoxContainer = $Root/ModeHost
@onready var _confirm_dialog = $Root/ConfirmDialog
@onready var _tooltip_host: PanelContainer = $Root/battle_hand_tooltip_host
@onready var _tooltip_title: Label = $Root/battle_hand_tooltip_host/TooltipMargin/TooltipBody/hand_tooltip_title
@onready var _tooltip_view = $Root/battle_hand_tooltip_host/TooltipMargin/TooltipBody/TooltipView

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}

# —— 本地交互态 ——
var _mode := "idle"
var _active_card: Dictionary = {}
var _hovered_card: Dictionary = {}
var _card_id := ""
var _target_id := ""
var _confirming := false
var _expanded_enemies := false
# 拖拽命中用：enemy_id -> 敌方卡 Control（_refresh_enemies 每次重建）。
var _enemy_actors: Dictionary = {}
var _submitted_card_keys: Dictionary = {}
var _last_hand_version := -1

var _ready_done := false


func _ready() -> void:
	_ready_done = true
	_apply_tooltip_style()
	_refresh()


## run_controller 的挂载入口（与各屏同签名）。
func mount_snapshot(snapshot: Dictionary, commands: Dictionary) -> void:
	# 防重复提交缓存只在快照版本（领域 event_log 推进）变化时清理；
	# 相同版本的重挂载（刷新/重渲染）不得解除已建立的卡/目标去重保护。
	var new_hand_version := int(snapshot.get("hand_version", -1))
	if new_hand_version != _last_hand_version:
		_submitted_card_keys.clear()
		_last_hand_version = new_hand_version
	_snapshot = snapshot
	_commands = commands
	if _ready_done:
		_refresh()


# ——————————————————————————————— 交互 ———————————————————————————————

func _play_card(card: Dictionary) -> void:
	if str(card.get("target_type", "none")) == "single_enemy":
		_set_mode("target_select", card)
	elif _is_dangerous_card(card):
		_active_card = card
		_card_id = str(card.get("id", ""))
		_target_id = ""
		_confirming = true
		_mode = "dragging"
		_refresh()
	else:
		_submit_card(card, "")


func _select_enemy(enemy_id: String) -> void:
	if _mode != "target_select":
		return
	var valid: Array = _active_card.get("valid_target_ids", [])
	if not valid.has(enemy_id):
		return
	if _is_dangerous_card(_active_card):
		_target_id = enemy_id
		_confirming = true
		_refresh()
	else:
		_submit_card(_active_card, enemy_id)


func _submit_card(card: Dictionary, target_id: String) -> void:
	var card_id := str(card.get("id", ""))
	var request_key := card_id + ":" + target_id
	if _submitted_card_keys.has(request_key):
		return
	_submitted_card_keys[request_key] = true
	if _commands.has("play_card"):
		_commands["play_card"].call(card_id, target_id)
	_active_card = card
	_card_id = card_id
	_target_id = target_id
	_confirming = false
	_mode = "play_success"
	_refresh()


func _is_dangerous_card(card: Dictionary) -> bool:
	if card.get("dangerous", false) == true:
		return true
	var known_risk = card.get("known_risk", [])
	if known_risk is Array:
		return not known_risk.is_empty()
	return str(known_risk) != ""


func _known_risk_text(card: Dictionary) -> String:
	var known_risk = card.get("known_risk", [])
	if known_risk is Array:
		var lines: Array[String] = []
		for line in known_risk:
			var text := str(line)
			if text != "":
				lines.append(text)
		return "；".join(lines)
	return str(known_risk)


func _set_mode(next_mode: String, card: Dictionary = {}) -> void:
	var c: Dictionary = card if not card.is_empty() else _active_card
	_mode = next_mode
	_active_card = c
	_card_id = str(c.get("id", ""))
	_target_id = ""
	_confirming = false
	_refresh()


## 取消 / 关闭浮层：保留 expanded_enemies，其余归位。
func _reset_interaction() -> void:
	_mode = "idle"
	_active_card = {}
	_hovered_card = {}
	_card_id = ""
	_target_id = ""
	_confirming = false
	_refresh()


func _on_card_hover(card: Dictionary) -> void:
	# Hover is presentation-only. Rebuilding the hand here replaces the Button
	# under the pointer before its click arrives; it also used to overwrite the
	# card already armed for a single-target selection.
	if _mode != "idle" or _confirming:
		return
	_hovered_card = card
	_refresh_tooltip()


# ——————————————————————————————— 渲染 ———————————————————————————————

func _refresh() -> void:
	if not _ready_done:
		return
	var state := _snapshot
	_refresh_top_bar(state)
	_refresh_player(state)
	_refresh_enemies(state)
	_inventory.setup(state.get("inventory", {}))
	_refresh_hand(state)
	_refresh_ops(state)
	_refresh_kill_moves(state)
	_refresh_hints(state)
	_refresh_feedback(state)
	_refresh_mode_label()
	_refresh_confirm()
	_refresh_tooltip()


func _refresh_top_bar(state: Dictionary) -> void:
	_top_bar.set_data(
			state.get("resources", {}),
			state.get("contracts", []),
		state.get("anomalies", []),
		state.get("death_lines", {}),
		int(state.get("layer", -1)))


func _refresh_player(state: Dictionary) -> void:
	var player: Dictionary = state.get("player", {})
	var actions: Dictionary = state.get("actions", {})
	_player_panel.setup("我方", true, false)
	var host: Node = _player_panel.content_host
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(host as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	for c in host.get_children():
		c.queue_free()

	var box := VBoxContainer.new()
	box.name = "player_actor"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", GuStyle.SPACE_3)
	host.add_child(box)

	var hp = StatBarScene().instantiate()
	box.add_child(hp)
	var health_line: Dictionary = state.get("death_lines", {}).get("health", {})
	hp.setup("生命", int(player.get("hp", 0)), maxi(1, int(player.get("max_hp", 1))),
			GuStyle.JADE, int(player.get("shield", 0)), Callable(),
			bool(health_line.get("danger", false)), str(health_line.get("detail", "")))

	var pri = StatBarScene().instantiate()
	box.add_child(pri)
	pri.setup("真元", int(player.get("primordial", 0)),
			maxi(1, int(player.get("primordial_max", 1))), GuStyle.ANOMALY_YELLOW)

	var soul := Label.new()
	soul.name = "player_actions_label"
	soul.text = "行动 %d/%d（念头 %d）" % [
			int(actions.get("left", 0)), int(actions.get("max", 0)),
			int(player.get("thoughts", 0))]
	soul.add_theme_font_size_override("font_size", 14)
	soul.add_theme_color_override("font_color", GuStyle.INK_MUTED)
	box.add_child(soul)


func _refresh_enemies(state: Dictionary) -> void:
	var enemies: Array = state.get("enemies", [])
	var visible_enemies: Array = enemies
	var remainder: Array = []
	if not _expanded_enemies and enemies.size() > MAX_VISIBLE_ENEMIES:
		visible_enemies = enemies.slice(0, MAX_VISIBLE_ENEMIES)
		remainder = enemies.slice(MAX_VISIBLE_ENEMIES)

	_enemy_panel.setup("敌方", true, false)
	var host: Node = _enemy_panel.content_host
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(host as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	for c in host.get_children():
		c.queue_free()

	var group := HBoxContainer.new()
	group.name = "enemy_group"
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", GuStyle.SPACE_3)
	host.add_child(group)

	var valid_targets: Array = _active_card.get("valid_target_ids", [])
	_enemy_actors.clear()
	for e in visible_enemies:
		if not (e is Dictionary):
			continue
		var enemy_id := str(e.get("id", ""))
		var actor = GuEnemyActorScene.instantiate()
		# 敌人卡保持稳定基线，长意图只在卡内折行，不改变横向节奏。
		actor.custom_minimum_size = Vector2(200, 150)
		# build 函数一律先 add_child：@onready 要等入树后才有值。
		group.add_child(actor)
		_enemy_actors[enemy_id] = actor
		actor.setup(e, _target_id == enemy_id,
				_mode == "target_select" and valid_targets.has(enemy_id),
				_select_enemy)

	if not remainder.is_empty():
		var more := Button.new()
		more.name = "enemy_remainder"
		more.text = "余敌 %d" % remainder.size()
		MasterTheme.apply_button(more, "action")
		more.pressed.connect(func():
			_expanded_enemies = true
			_refresh())
		group.add_child(more)


func _refresh_hand(state: Dictionary) -> void:
	var player: Dictionary = state.get("player", {})
	var actions: Dictionary = state.get("actions", {})
	_primordial_label.text = "真元 %d" % int(player.get("primordial", 0))
	_primordial_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	# V1 无牌库/弃牌堆；此槽位显示行动点（念头）预算，与玩家面板同源。
	_piles_label.text = "行动 %d/%d · 念头 %d" % [
			int(actions.get("left", 0)), int(actions.get("max", 0)),
			int(player.get("thoughts", 0))]
	# 行动预算是玩家必读资源：此行直接压在页面深色底上（同顶栏资源芯片），
	# 墨色 token 全按纸面设计会低对比，用 PAPER_BG 浅字。
	_piles_label.add_theme_color_override("font_color", GuStyle.PAPER_BG)

	# Gubattle_hand 接 6 参（press / hover / cancel / release），拖拽命中走
	# _on_card_release：抬起落点在敌方卡上即按该目标出牌（复用点击状态机，
	# 危险卡进确认流）；按住期间不重建手牌，避免销毁正在接收输入的按钮。
	_hand.setup(state.get("hand", []), _interaction_dict(),
			_play_card, _on_card_hover, _reset_interaction, _on_card_release)


## 拖拽命中：左键抬起落点命中的存活敌方卡 id；未命中返回空串。
func _on_card_release(card: Dictionary, global_pos: Vector2) -> void:
	var enemy_id := _enemy_at(global_pos)
	if enemy_id == "":
		return
	_play_card(card)
	_select_enemy(enemy_id)


func _enemy_at(global_pos: Vector2) -> String:
	for enemy_id in _enemy_actors:
		var actor := _enemy_actors[enemy_id] as Control
		if actor != null and actor.is_visible_in_tree() and actor.get_global_rect().has_point(global_pos):
			return str(enemy_id)
	return ""


func _refresh_ops(state: Dictionary) -> void:
	for c in _ops_row.get_children():
		c.queue_free()
	_ops_row.add_child(_op_button("结束回合", func():
		if _commands.has("end_turn"):
			_commands["end_turn"].call()))
	if _commands.has("refine"):
		_ops_row.add_child(_op_button("炼蛊", func(): _commands["refine"].call()))
	if _commands.has("flee") and bool(state.get("flee_available", true)):
		_ops_row.add_child(_op_button("撤退", func(): _commands["flee"].call()))


func _op_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	MasterTheme.apply_button(b, "action")
	b.pressed.connect(on_press)
	return b


func _refresh_kill_moves(state: Dictionary) -> void:
	for c in _kill_host.get_children():
		c.queue_free()
	for km in state.get("kill_moves", []):
		if not (km is Dictionary):
			continue
		var l := Label.new()
		var cost_line := str(km.get("cost", ""))
		var suffix := "" if bool(km.get("executable", false)) else "（不可用：%s）" % str(km.get("block_reason", ""))
		l.text = "杀招 · %s · %s%s" % [
				str(km.get("name", "")), str(km.get("sequence_display", "")), suffix]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color",
				GuStyle.CINNABAR if not bool(km.get("executable", false)) else GuStyle.INK_MUTED)
		_kill_host.add_child(l)
		if cost_line != "":
			var cost := Label.new()
			cost.text = "　　◆ " + cost_line
			cost.add_theme_font_size_override("font_size", 12)
			cost.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
			_kill_host.add_child(cost)


func _refresh_hints(state: Dictionary) -> void:
	for c in _hint_host.get_children():
		c.queue_free()
	if bool(state.get("first_battle", false)):
		_hint_host.add_child(_hint_label(
				"初战指引：出手次数由魂魄底蕴分档；每次行动耗 1 念头；敌人意图数值可见。",
				GuStyle.INK_SOFT))
	var boss_hint := DisplayText.dda_hint(str(state.get("dda_boss_hint", "")))
	if boss_hint != "":
		_hint_host.add_child(_hint_label(boss_hint, GuStyle.ANOMALY_YELLOW))


func _hint_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _refresh_feedback(state: Dictionary) -> void:
	var text := str(state.get("feedback", ""))
	_feedback_toast.visible = text != ""
	if text != "":
		_feedback_toast.setup(text, "warn")


## mode 用一个空 Label 的 **name** 承载（"battle_<mode>"）——test_wenzhen_card_fsm
## 就是按这个名字定位节点状态的，约定得留着。
## 但不能改 ModeHost 自己的名字：节点名是路径的一部分，改了会让 @onready 与
## 一切按路径的查找全部失效。所以改成在固定路径的 ModeHost 下动态挂子 Label。
func _refresh_mode_label() -> void:
	_clear(_mode_host)
	var l := Label.new()
	l.name = "battle_" + _mode
	l.text = ""
	_mode_host.add_child(l)


func _refresh_confirm() -> void:
	_confirm_dialog.visible = _confirming
	if not _confirming:
		_confirm_dialog.close()  # close() 会清空文本，只设 visible 会让隐藏节点残留文本
		return
	var card_name := str(_active_card.get("name", "此行动"))
	# GuConfirmDialog 的入口是 open()（不是 setup），签名见 gu_confirm_dialog_view.gd。
	_confirm_dialog.open(
			card_name + " 将执行已预览的不可逆代价。",
			func(): _submit_card(_active_card, _target_id),
		func(): _set_mode("drag_cancel", _active_card),
		"⚠ 危险行动",
			_known_risk_text(_active_card))


func _refresh_tooltip() -> void:
	var show_tip := _mode == "idle" and not _hovered_card.is_empty()
	_tooltip_host.visible = show_tip
	if not show_tip:
		return
	_tooltip_title.text = str(_hovered_card.get("name", "蛊虫"))
	# C2 2026-09-05：蛊卡 tooltip 标题追加流派标签（如「小光蛊 · 光道」）。
	var school_label := str(_hovered_card.get("school_label", ""))
	if school_label != "":
		_tooltip_title.text += " · " + school_label
	_tooltip_title.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_tooltip_view.setup("", str(_hovered_card.get("quality", "")),
			str(_hovered_card.get("effect", "")),
			str(_hovered_card.get("synergy", "")),
			str(_hovered_card.get("cost_ex", str(_hovered_card.get("cost", "")))),
		str(_hovered_card.get("block_reason", "")) if not bool(_hovered_card.get("executable", true)) else "",
		bool(_hovered_card.get("curse_warning", false)),
		_known_risk_text(_hovered_card))
	call_deferred("_position_tooltip")


func _position_tooltip() -> void:
	# 卡体节点名由 gu.<instance_id> 派生，Godot 会把 "." 规范化成 "_"，
	# 查找时需同步替换，否则 gu 卡悬停 tooltip 定位会落空。
	var card_id := str(_hovered_card.get("id", "")).replace(".", "_")
	var card_body := _hand.get_node_or_null("CardRow/card_body_" + card_id) as Control
	if card_body == null or not _tooltip_host.visible:
		return
	var minimum := _tooltip_host.get_combined_minimum_size()
	var tooltip_size := Vector2(maxf(280.0, minimum.x), minimum.y)
	var viewport_size := get_viewport_rect().size
	tooltip_size.x = minf(tooltip_size.x, viewport_size.x - 24.0)
	_tooltip_host.size = tooltip_size
	var card_rect := card_body.get_global_rect()
	var hand_rect: Rect2 = _hand.get_global_rect()
	var desired := Vector2(card_rect.position.x, hand_rect.position.y - tooltip_size.y - GuStyle.SPACE_2)
	desired.x = clampf(desired.x, GuStyle.SPACE_3, maxf(GuStyle.SPACE_3, viewport_size.x - tooltip_size.x - GuStyle.SPACE_3))
	if desired.y < GuStyle.SPACE_3:
		# 手牌上方不足时贴在手牌区内部上沿，避免跨回战场内容。
		desired.y = clampf(hand_rect.position.y + GuStyle.SPACE_2, GuStyle.SPACE_3, maxf(GuStyle.SPACE_3, viewport_size.y - tooltip_size.y - GuStyle.SPACE_3))
	_tooltip_host.global_position = desired


func _interaction_dict() -> Dictionary:
	return {
		"mode": _mode,
		"card": _active_card,
		"card_id": _card_id,
		"target_id": _target_id,
		"confirming": _confirming,
		"expanded_enemies": _expanded_enemies,
	}


func _apply_tooltip_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED
	box.border_color = GuStyle.HAIRLINE_COLOR
	box.set_border_width_all(GuStyle.HAIRLINE)
	box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	_tooltip_host.add_theme_stylebox_override("panel", box)



## 立即清空并释放子节点。
##
## ⚠️ 只能用在**不会发射信号**的容器上（目前只有 ModeHost，里面是自建的空 Label）。
## 其余容器一律用 queue_free：它们的子节点可能是正在发射 pressed 的按钮，
## 立即 free() 会在信号发射途中销毁发射者——Godot 会报
## "Object was freed while a signal is being emitted" 并有崩溃风险。
##
## 之所以给 ModeHost 破例：refresh 同一帧会被调用多次，queue_free 的延迟释放
## 会让 ModeHost 短暂出现多个子节点，按 child_count / get_child(0) 的断言会失真。
func _clear(host: Node) -> void:
	for c in host.get_children():
		host.remove_child(c)
		c.free()

## 小工具：本屏动态创建生命 / 真元条。
static func StatBarScene() -> PackedScene:
	return preload("res://scenes/ui/widgets/gu_stat_bar.tscn")
