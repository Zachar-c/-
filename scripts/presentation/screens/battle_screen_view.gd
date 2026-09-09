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

const GameVersionScript := preload("res://scripts/domain/game_version.gd")
const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuEnemyActorScene := preload("res://scenes/ui/widgets/gu_enemy_actor.tscn")
const PlayerPortrait := preload("res://assets/wenzhen/hall/first-life-character.png")

const MAX_VISIBLE_ENEMIES := 3

@onready var _paper: ColorRect = $BattlePaper
@onready var _top_bar = $Root/battle_hud/TopBar
@onready var _battle_stage: PanelContainer = $Root/BattleStage
@onready var _player_panel = $Root/BattleStage/battle_field/PlayerPanel
@onready var _enemy_panel = $Root/BattleStage/battle_field/EnemyPanel
@onready var _inventory = $Root/BattleStage/battle_field/Inventory
@onready var _feedback_toast = $Root/FeedbackToast
@onready var _hint_host: VBoxContainer = $Root/BattleStage/battle_field/HintHost
@onready var _hand_stage: PanelContainer = $Root/HandStage
@onready var _primordial_label: Label = $Root/HandStage/HandMargin/battle_hand/LeftMeta/PrimordialRow/PrimordialLabel
@onready var _piles_label: Label = $Root/HandStage/HandMargin/battle_hand/LeftMeta/PilesRow/PilesLabel
@onready var _hand = $Root/HandStage/HandMargin/battle_hand/HandArea/CenterWrap/Hand
@onready var _build_ver: Label = $Root/HandStage/BuildVer
@onready var _kill_host: HBoxContainer = $Root/BattleStage/battle_field/BattleInfo/KillRow
@onready var _ops_row: VBoxContainer = $Root/BattleStage/battle_field/OpsDock/OpsRow
@onready var _mode_host: VBoxContainer = $Root/BattleStage/battle_field/ModeHost
@onready var _confirm_dialog = $Root/ConfirmDialog
@onready var _tooltip_host: PanelContainer = $Root/battle_hand_tooltip_host
@onready var _tooltip_title: Label = $Root/battle_hand_tooltip_host/TooltipMargin/TooltipBody/hand_tooltip_title
@onready var _tooltip_view = $Root/battle_hand_tooltip_host/TooltipMargin/TooltipBody/TooltipView
@onready var _seal_overlay: Control = $Root/SealOverlay
@onready var _seal_box: PanelContainer = $Root/SealOverlay/SealCenter/SealBox
@onready var _seal_label: Label = $Root/SealOverlay/SealCenter/SealBox/SealMargin/SealLabel
@onready var _ink_overlay: Control = $Root/InkOverlay
@onready var _ink_blob: PanelContainer = $Root/InkOverlay/InkCenter/InkBlob

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
# 动效触发用：记录上一帧敌人 alive 状态和状态名集合，检测死亡/状态施加。
var _prev_enemy_alive: Dictionary = {}
# V-F-03 受击反馈用：记录上一帧玩家/敌人 hp，降低时触发红闪+微震+音效。
var _prev_player_hp := -1
var _prev_enemy_hp: Dictionary = {}
var _prev_enemy_statuses: Dictionary = {}
# 拖拽命中用：enemy_id -> 敌方卡 Control（_refresh_enemies 每次重建）。
var _enemy_actors: Dictionary = {}
# 拖拽候选：左键在可执行手牌卡上按下时记录，全局左键抬起时命中敌方卡。
var _drag_candidate_card: Dictionary = {}
var _submitted_card_keys: Dictionary = {}
var _last_hand_version := -1

var _ready_done := false


func _ready() -> void:
	_ready_done = true
	# 第四批：战斗屏同步基准——浅米纸底 + 网点（原暗色舞台设计已由基准统一取代）
	_paper.color = GuStyle.PAPER_HALL
	_apply_stage_style()
	_apply_hand_stage_style()
	_apply_seal_style()
	_apply_ink_style()
	_apply_tooltip_style()
	_build_ver.text = GameVersionScript.display()
	# 设置入口收敛到顶栏状态栏 icon（独立「设置」文字按钮已移除）。
	_top_bar.set_on_settings(func():
		if _commands.has("open_settings"):
			_commands["open_settings"].call())
	_refresh()


## 叙事层：以大厅屏为基准——纸面 + 网点背景由根 Backdrop（BattlePaper + BattleDots）提供，
## 舞台本身完全透明，让纸面网点透出全屏；敌人/玩家纸卡墨框浮于其上，命簿语言统一。

func _apply_stage_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_border_width_all(0)
	box.set_corner_radius_all(0)
	_battle_stage.add_theme_stylebox_override("panel", box)


## 规则层：手牌区透明，纸面+网点由根 Backdrop 提供，与大厅/地图一致。
func _apply_hand_stage_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_border_width_all(0)
	box.set_corner_radius_all(0)
	_hand_stage.add_theme_stylebox_override("panel", box)


## 概念层：朱砂盖印样式。用于危险确认、不可逆裁定。短、功能性，完成后归于安静。
func _apply_seal_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.CINNABAR
	box.border_color = GuStyle.INK_PRIMARY
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	_seal_box.add_theme_stylebox_override("panel", box)
	_seal_label.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_seal_label.add_theme_color_override("font_color", GuStyle.PAPER_BG)


## 朱砂盖印动效：从上方盖下，缩放回落 + 旋转回正 + 淡入，停留后淡出。
func play_cinnabar_seal(text: String = "裁定") -> void:
	# 第18批：接入朱砂盖印音效
	AudioManager.play_sfx("concept_seal_stamp")
	_seal_label.text = text
	_seal_overlay.visible = true
	_seal_overlay.modulate = Color(1, 1, 1, 0)
	_seal_box.scale = Vector2(1.5, 1.5)
	_seal_box.rotation = deg_to_rad(-12)

	var tween := create_tween()
	tween.set_parallel(true)
	# 盖下：缩放回落 + 旋转回正 + 淡入
	tween.tween_property(_seal_box, "scale", Vector2(1, 1), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_seal_box, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_seal_overlay, "modulate:a", 1.0, 0.12)
	# 停留
	tween.tween_interval(0.28)
	# 淡出
	tween.tween_property(_seal_overlay, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func(): _seal_overlay.visible = false)


## 概念层：墨迹扩散样式。用于状态落定、新记录揭示。黑色墨团从中心扩散后消散。
func _apply_ink_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.INK_PRIMARY
	box.set_border_width_all(0)
	box.set_corner_radius_all(8)
	_ink_blob.add_theme_stylebox_override("panel", box)


## 墨迹扩散动效：黑色墨团从中心缩放扩散，半透明淡入后缓慢消散。
## 用于出牌成功、状态落定等时刻，符合设计文档「墨迹扩散=状态落定」语义。
func play_ink_spread() -> void:
	# 第18批：接入墨迹扩散音效
	AudioManager.play_sfx("concept_ink_spread")
	_ink_overlay.visible = true
	_ink_overlay.modulate = Color(1, 1, 1, 0)
	_ink_blob.scale = Vector2(0.2, 0.2)

	var tween := create_tween()
	tween.set_parallel(true)
	# 扩散：缩放放大 + 淡入
	tween.tween_property(_ink_blob, "scale", Vector2(1.8, 1.8), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ink_overlay, "modulate:a", 0.25, 0.25)
	# 消散：缓慢淡出
	tween.tween_interval(0.15)
	tween.tween_property(_ink_overlay, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _ink_overlay.visible = false)


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
	# 第18批：接入出牌音效
	AudioManager.play_sfx("battle_card_play")
	# 概念层：出牌成功触发墨迹扩散（状态落定）
	play_ink_spread()
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
	# 杀戮尖塔风格：隐藏舞台中的背包面板，顶栏右侧已有背包入口按钮，主舞台只保留立绘
	_inventory.visible = false
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
		int(state.get("layer", -1)),
		state.get("player", {}))  # 传递player数据，用于显示气血（hp/max_hp）


## V-F-03 第19批：受击反馈——目标红闪 + 战斗舞台微震 + 音效。
## 纯表现层（hp diff 驱动），不触碰领域状态；scale 动画不影响布局。
func _play_hit_feedback(target: Control, strong := false) -> void:
	if target != null and is_instance_valid(target):
		var t := target.create_tween()
		t.tween_property(target, "modulate", GuStyle.HIT_FLASH, 0.05)
		t.tween_property(target, "modulate", Color.WHITE, 0.25)
	if _battle_stage != null and is_instance_valid(_battle_stage):
		var s := _battle_stage.create_tween()
		s.tween_property(_battle_stage, "scale", Vector2(1.006, 1.006), 0.04)
		s.tween_property(_battle_stage, "scale", Vector2.ONE, 0.12)
	AudioManager.play_sfx("battle_hit", 1.0 if strong else 0.7)


func _refresh_player(state: Dictionary) -> void:
	var player: Dictionary = state.get("player", {})
	var actions: Dictionary = state.get("actions", {})
	# 杀戮尖塔风格：无标题、完全透明背景，立绘为主体
	_player_panel.setup("", true, true, true)
	_make_panel_fully_transparent(_player_panel)
	var host: Node = _player_panel.content_host
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(host as VBoxContainer).alignment = BoxContainer.ALIGNMENT_END
	for c in host.get_children():
		c.queue_free()

	var box := VBoxContainer.new()
	box.name = "player_actor"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", GuStyle.SPACE_3)
	host.add_child(box)

	# 玩家立绘（左下角小立绘：线框稿 v2 104×148，窗口 1280×720 与画布 1:1）
	var portrait := TextureRect.new()
	portrait.name = "player_portrait"
	portrait.texture = PlayerPortrait
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(0, 148)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.modulate = Color(1, 1, 1, 1)
	box.add_child(portrait)

	# 玩家名（快照有 name 才显示，不编造）
	var pname := str(player.get("name", ""))
	if pname != "":
		var nm := Label.new()
		nm.name = "player_name"
		nm.text = pname
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_override("font", GuStyle.TITLE_FONT)
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
		box.add_child(nm)

	var hp = StatBarScene().instantiate()
	hp.name = "hp"
	box.add_child(hp)
	var health_line: Dictionary = state.get("death_lines", {}).get("health", {})
	hp.setup("生命", int(player.get("hp", 0)), maxi(1, int(player.get("max_hp", 1))),
			GuStyle.JADE, int(player.get("shield", 0)), Callable(),
			bool(health_line.get("danger", false)), str(health_line.get("detail", "")))
	# V-F-03 第19批：玩家受击反馈（hp 下降→红闪+微震+音效），首次挂载不触发。
	var cur_hp := int(player.get("hp", 0))
	if _prev_player_hp >= 0 and cur_hp < _prev_player_hp:
		_play_hit_feedback(_player_panel, false)
	_prev_player_hp = cur_hp

	# 杀戮尖塔风格：真元和行动点已在左侧LeftMeta显示，玩家区域只保留立绘+血量条，更简洁


func _refresh_enemies(state: Dictionary) -> void:
	var enemies: Array = state.get("enemies", [])
	var visible_enemies: Array = enemies
	var remainder: Array = []
	if not _expanded_enemies and enemies.size() > MAX_VISIBLE_ENEMIES:
		visible_enemies = enemies.slice(0, MAX_VISIBLE_ENEMIES)
		remainder = enemies.slice(MAX_VISIBLE_ENEMIES)

	# 杀戮尖塔风格：无标题、完全透明背景，立绘为主体
	_enemy_panel.setup("", true, true, true)
	_make_panel_fully_transparent(_enemy_panel)
	var host: Node = _enemy_panel.content_host
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(host as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	for c in host.get_children():
		c.queue_free()

	var group := HBoxContainer.new()
	group.name = "enemy_group"
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 26)
	host.add_child(group)

	var valid_targets: Array = _active_card.get("valid_target_ids", [])
	_enemy_actors.clear()
	for e in visible_enemies:
		if not (e is Dictionary):
			continue
		var enemy_id := str(e.get("id", ""))
		var actor = GuEnemyActorScene.instantiate()
		# 线框稿 v2：敌人卡 208×306（1280×720 窗口与画布 1:1）
		actor.custom_minimum_size = Vector2(208, 306)
		# build 函数一律先 add_child：@onready 要等入树后才有值。
		group.add_child(actor)
		_enemy_actors[enemy_id] = actor
		actor.setup(e, _target_id == enemy_id,
				_mode == "target_select" and valid_targets.has(enemy_id),
				_select_enemy)
		# V-F-03 第19批：敌人受击反馈（hp 下降）。
		var ehp := int(e.get("hp", 0))
		if _prev_enemy_hp.has(enemy_id) and ehp < int(_prev_enemy_hp[enemy_id]):
			_play_hit_feedback(actor, false)
		_prev_enemy_hp[enemy_id] = ehp

	if not remainder.is_empty():
		var more := Button.new()
		more.name = "enemy_remainder"
		more.text = "余敌 %d" % remainder.size()
		MasterTheme.apply_button(more, "action")
		more.pressed.connect(func():
			_expanded_enemies = true
			_refresh())
		group.add_child(more)

	# 动效触发：检测敌人死亡（alive true→false）和状态施加（新状态名出现）。
	# 死亡触发墨迹扩散（生命消散），状态施加触发墨迹扩散（蛊毒落定）。
	var death_triggered := false
	var status_triggered := false
	for e in visible_enemies:
		if not (e is Dictionary):
			continue
		var eid := str(e.get("id", ""))
		var alive: bool = e.get("alive", true)
		var prev_alive: bool = _prev_enemy_alive.get(eid, true)
		if prev_alive and not alive:
			death_triggered = true
		# 状态施加检测：当前有但上一帧没有的状态名
		var cur_statuses: Array = e.get("statuses", [])
		var prev_set: Dictionary = _prev_enemy_statuses.get(eid, {})
		for s in cur_statuses:
			if s is Dictionary:
				var sname := str(s.get("name", ""))
				if sname != "" and not prev_set.has(sname):
					status_triggered = true
	# 更新跟踪状态
	_prev_enemy_alive.clear()
	_prev_enemy_statuses.clear()
	for e in visible_enemies:
		if not (e is Dictionary):
			continue
		var eid := str(e.get("id", ""))
		_prev_enemy_alive[eid] = e.get("alive", true)
		var sset := {}
		for s in e.get("statuses", []):
			if s is Dictionary:
				sset[str(s.get("name", ""))] = true
		_prev_enemy_statuses[eid] = sset
	# 触发动效+音效（死亡优先，状态施加次之，不重复触发）
	if death_triggered:
		play_ink_spread()
		AudioManager.play_sfx("battle_death")
	elif status_triggered:
		play_ink_spread()
		AudioManager.play_sfx("battle_status_apply")


func _refresh_hand(state: Dictionary) -> void:
	var player: Dictionary = state.get("player", {})
	var actions: Dictionary = state.get("actions", {})
	_primordial_label.text = "真元 %d" % int(player.get("primordial", 0))
	_primordial_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	# V1 无牌库/弃牌堆；此槽位显示行动点预算（念头移右栏按钮下方，与线框稿 v2 一致）。
	_piles_label.text = "行动 %d/%d" % [
			int(actions.get("left", 0)), int(actions.get("max", 0))]
	# 行动预算是玩家必读资源：浅色纸面主题下用墨色保证对比度。
	_piles_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	# 开源图标：真元用宝石图标，行动点用拳头图标，动态创建一次后复用。
	# 真元图标添加到PrimordialRow（真元行）
	var primordial_row: HBoxContainer = _primordial_label.get_parent() as HBoxContainer
	if primordial_row != null:
		if primordial_row.get_node_or_null("primordial_icon") == null:
			var p_icon := GuIconView.new()
			p_icon.name = "primordial_icon"
			p_icon.setup("yuanstone", GuStyle.ANOMALY_YELLOW, GuIconView.SIZE_BODY)
			p_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			primordial_row.add_child(p_icon)
			primordial_row.move_child(p_icon, 0)
	# 行动点图标添加到PilesRow（行动点行）
	var piles_row: HBoxContainer = _piles_label.get_parent() as HBoxContainer
	if piles_row != null:
		if piles_row.get_node_or_null("piles_icon") == null:
			var a_icon := GuIconView.new()
			a_icon.name = "piles_icon"
			a_icon.setup("gi_fist", GuStyle.INK_PRIMARY, GuIconView.SIZE_SMALL)
			a_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piles_row.add_child(a_icon)
			piles_row.move_child(a_icon, 0)

	# Gubattle_hand 接 6 参（press / hover / cancel / drag_start）。拖拽命中走
	# 全局 _input 抬起拦截（_on_card_drop），不依赖按钮捕获的 release 事件；
	# 按住期间不重建手牌，避免销毁正在接收输入的按钮。
	_hand.setup(state.get("hand", []), _interaction_dict(),
			_play_card, _on_card_hover, _reset_interaction, _on_card_drag_start)


## 拖拽候选：左键在可执行手牌卡上按下时记录，不触发任何刷新。
func _on_card_drag_start(card: Dictionary) -> void:
	_drag_candidate_card = card


## 全局左键抬起：候选非空时用画布全局鼠标位命中敌方卡，命中即按该目标出牌
## （危险卡进确认流）。未命中敌方卡时不清当前输入，让普通点击照常武装。
func _input(event: InputEvent) -> void:
	if _drag_candidate_card.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var card: Dictionary = _drag_candidate_card
		_drag_candidate_card = {}
		var mouse := get_global_mouse_position()
		var enemy_id := _enemy_at(mouse)
		if enemy_id != "":
			_play_card(card)
			_select_enemy(enemy_id)
			get_viewport().set_input_as_handled()


## 拖拽命中：全局鼠标位命中的存活敌方卡 id；未命中返回空串。
func _enemy_at(global_pos: Vector2) -> String:
	for enemy_id in _enemy_actors:
		var actor := _enemy_actors[enemy_id] as Control
		if actor != null and actor.is_visible_in_tree() and actor.get_global_rect().has_point(global_pos):
			return str(enemy_id)
	return ""


func _refresh_ops(state: Dictionary) -> void:
	for c in _ops_row.get_children():
		c.queue_free()
	# 线框稿 v2：三按钮一律纸面 action 角色（浅底≈透明，墨字），结束回合为大号主按钮，右列竖排
	var end_btn := _op_button("结束回合", func():
		if _commands.has("end_turn"):
			_commands["end_turn"].call())
	MasterTheme.apply_button(end_btn, "action")
	end_btn.custom_minimum_size = Vector2(150, 52)
	end_btn.add_theme_font_override("font", GuStyle.TITLE_FONT)
	end_btn.add_theme_font_size_override("font_size", 18)
	_ops_row.add_child(end_btn)
	if _commands.has("refine"):
		var refine_btn := _op_button("炼蛊", func(): _commands["refine"].call())
		refine_btn.add_theme_font_override("font", GuStyle.TITLE_FONT)
		refine_btn.add_theme_font_size_override("font_size", 15)
		_ops_row.add_child(refine_btn)
	if _commands.has("flee") and bool(state.get("flee_available", true)):
		var flee_btn := _op_button("撤退", func(): _commands["flee"].call())
		flee_btn.add_theme_font_override("font", GuStyle.TITLE_FONT)
		flee_btn.add_theme_font_size_override("font_size", 15)
		_ops_row.add_child(flee_btn)
	# 念头预算：右栏按钮下方小注（线框稿 v2：右栏念头 8/12）
	var note := Label.new()
	note.name = "thought_note"
	note.text = "念头 %d/%d" % [int(state.get("player", {}).get("thoughts", 0)),
			int(state.get("actions", {}).get("max", 0))]
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 9)
	note.add_theme_color_override("font_color", GuStyle.INK_MAP_FAINT)
	note.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_ops_row.add_child(note)


func _op_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	MasterTheme.apply_button(b, "action")
	b.pressed.connect(on_press)
	return b


## 杀招区（线框稿 v2：舞台中右 3 格纸卡；空位显示「未研习」）。
func _refresh_kill_moves(state: Dictionary) -> void:
	for c in _kill_host.get_children():
		c.queue_free()
	var moves: Array = state.get("kill_moves", [])
	var slots: Array = []
	for km in moves:
		if km is Dictionary:
			slots.append(km)
	# 最多 3 格；不足补空位
	var idx := 0
	while idx < 3:
		if idx < slots.size():
			var km: Dictionary = slots[idx]
			_kill_host.add_child(_kill_slot(
					str(km.get("name", "杀招")),
					str(km.get("sequence_display", "")),
					str(km.get("cost", "")),
					bool(km.get("executable", false)),
					str(km.get("block_reason", ""))))
		else:
			_kill_host.add_child(_kill_slot_empty())
		idx += 1


func _kill_slot(title: String, seq: String, cost: String, executable: bool, block_reason: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(246 / 255.0, 243 / 255.0, 233 / 255.0, 0.5)
	box.border_color = GuStyle.NODE_REACH_BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(248, 90)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	margin.add_child(body)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", GuStyle.TITLE_FONT)
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", GuStyle.INK_PRIMARY if executable else GuStyle.INK_SOFT)
	body.add_child(t)
	if seq != "":
		var s := Label.new()
		s.text = seq
		s.add_theme_font_size_override("font_size", 9)
		s.add_theme_color_override("font_color", GuStyle.INK_MUTED)
		body.add_child(s)
	if not executable and block_reason != "":
		var b := Label.new()
		b.text = "不可用：%s" % block_reason
		b.add_theme_font_size_override("font_size", 9)
		b.add_theme_color_override("font_color", GuStyle.CINNABAR)
		body.add_child(b)
	if cost != "":
		var c := Label.new()
		c.text = "念头 %s" % cost
		c.add_theme_font_size_override("font_size", 9)
		c.add_theme_color_override("font_color", GuStyle.CINNABAR)
		c.size_flags_vertical = Control.SIZE_SHRINK_END
		body.add_child(c)
	return panel


func _kill_slot_empty() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = GuStyle.NODE_FUTURE_BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(248, 90)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var l := Label.new()
	l.text = "未研习"
	l.add_theme_font_override("font", GuStyle.TITLE_FONT)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", GuStyle.INK_MAP_FAINT)
	margin.add_child(l)
	return panel


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
	# 异变徽章：DDA 异变(险象)等逐条随提示区呈现。历史快照 anomalies 曾为
	# String 标签数组（旧 UI），DDA marker_meta 演进后为 {id,label} 条目；
	# 两种形状都渲染 label 文本，id 不外泄。
	for anomaly_value in state.get("anomalies", []):
		var anomaly_label := ""
		if anomaly_value is Dictionary:
			anomaly_label = str((anomaly_value as Dictionary).get("label", ""))
		else:
			anomaly_label = str(anomaly_value)
		if anomaly_label != "":
			_hint_host.add_child(_hint_label(anomaly_label, GuStyle.ANOMALY_YELLOW))


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
			func():
				play_cinnabar_seal("裁定")
				_submit_card(_active_card, _target_id),
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
	# 蛊虫详情跟随鼠标（v0.10 校准）：tooltip 左上角偏移到光标右下 16px，
	# 越界时回弹到光标左侧/上方，保证完整可见且不遮挡卡牌操作区。
	if not _tooltip_host.visible:
		return
	var minimum := _tooltip_host.get_combined_minimum_size()
	var tooltip_size := Vector2(maxf(280.0, minimum.x), minimum.y)
	var viewport_size := get_viewport_rect().size
	tooltip_size.x = minf(tooltip_size.x, viewport_size.x - 24.0)
	_tooltip_host.size = tooltip_size
	var mouse_pos := get_viewport().get_mouse_position()
	var desired := Vector2(mouse_pos.x + GuStyle.SPACE_2, mouse_pos.y + GuStyle.SPACE_2)
	desired.x = clampf(desired.x, GuStyle.SPACE_3, maxf(GuStyle.SPACE_3, viewport_size.x - tooltip_size.x - GuStyle.SPACE_3))
	if desired.y + tooltip_size.y > viewport_size.y - GuStyle.SPACE_3:
		# 下方空间不足时翻到光标上方。
		desired.y = mouse_pos.y - tooltip_size.y - GuStyle.SPACE_2
	desired.y = clampf(desired.y, GuStyle.SPACE_3, maxf(GuStyle.SPACE_3, viewport_size.y - tooltip_size.y - GuStyle.SPACE_3))
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

## 杀戮尖塔风格：面板完全透明，只显示立绘和血量条，不显示面板背景和边框。
func _make_panel_fully_transparent(panel: PanelContainer) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Color(0, 0, 0, 0)
	box.set_border_width_all(0)
	box.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", box)
