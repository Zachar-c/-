class_name RewardScreenView
extends MarginContainer
## 战利品确认屏（Godot 官方 .tscn 节点树版，替代 ui/screens/reward_screen.guitkx）。
##
## 普通路线的战利品已由 settle_victory 自动入账，本屏是确认展示；
## 独立 M0 路线在这里提供真实的三选一奖励按钮，选择前不能离开。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuCardScene := preload("res://scenes/ui/widgets/gu_card.tscn")

@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _paper: ColorRect = $RewardPaper
@onready var _seal_box: PanelContainer = $Root/HeaderRow/SealPanelContainer
@onready var _title_label: Label = $Root/HeaderRow/TitleLabel
@onready var _subtitle_label: Label = $Root/HeaderRow/SubtitleLabel
@onready var _title_rule: ColorRect = $Root/HeaderRow/TitleRule
@onready var _section_title: Label = $Root/primary_decision_surface/SectionTitle
@onready var _reward_row: HBoxContainer = $Root/primary_decision_surface/RewardRow
@onready var _pool_fallback_label: Label = $Root/NoteRow/PoolFallbackLabel
@onready var _pity_label: Label = $Root/NoteRow/PityLabel
@onready var _continue_button: Button = $Root/ContinueButton
# Playable Core Loop Phase 3：本场产出 → 构筑目标进度（只读，无交互）。
@onready var _progress_box: VBoxContainer = $Root/primary_decision_surface/BuildProgressBox
@onready var _progress_title: Label = $Root/primary_decision_surface/BuildProgressBox/BuildProgressTitle
@onready var _progress_lines: Label = $Root/primary_decision_surface/BuildProgressBox/BuildProgressLines
@onready var _progress_status: Label = $Root/primary_decision_surface/BuildProgressBox/BuildProgressStatus
@onready var _progress_next: Label = $Root/primary_decision_surface/BuildProgressBox/BuildProgressNext

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
## mount_snapshot 可能早于 _ready()，未就绪时只收数据，_ready() 里补刷新。
var _ready_done := false


func _ready() -> void:
	_ready_done = true
	_apply_base_fonts()
	_continue_button.pressed.connect(func(): _fire("close"))
	if not _snapshot.is_empty():
		_refresh()


## run_controller 的挂载入口（与各 master 场景同签名）。
func mount_snapshot(snapshot: Dictionary, commands: Dictionary) -> void:
	_snapshot = snapshot
	_commands = commands
	if _ready_done:
		_refresh()


func _refresh() -> void:
	_refresh_top_bar()
	_refresh_header()
	_refresh_rewards()
	_refresh_build_progress()
	_refresh_notes()


## Playable Core Loop Phase 3：本场战利品推进了当前构筑目标的什么。
## 无可执行目标或无战斗入账时整块隐藏（不留空壳）。
func _refresh_build_progress() -> void:
	var progress: Dictionary = _snapshot.get("build_progress", {})
	var available := bool(progress.get("available", false))
	_progress_box.visible = available
	if not available:
		_progress_title.text = ""
		_progress_lines.text = ""
		_progress_status.text = ""
		_progress_next.text = ""
		return
	_progress_title.text = "构筑进度 · " + str(progress.get("title", ""))
	var lines: Array[String] = []
	for row_value in progress.get("lines", []):
		var row: Dictionary = row_value
		var gained := int(row.get("gained", 0))
		var mark := "✓" if bool(row.get("complete", false)) else "·"
		var gain_text := "（本场 +%d）" % gained if gained > 0 else ""
		lines.append("%s %s %d/%d%s" % [mark, str(row.get("name", "")),
				int(row.get("owned_after", 0)), int(row.get("required", 0)), gain_text])
	var stone_gained := int(progress.get("stone_gained", 0))
	var stone_after := int(progress.get("stone_after", 0))
	var stone_required := int(progress.get("stone_required", 0))
	lines.append("%s 元石 %d/%d%s" % [
			"✓" if stone_after >= stone_required else "·",
			stone_after, stone_required,
			"（本场 +%d）" % stone_gained if stone_gained > 0 else ""])
	_progress_lines.text = "\n".join(lines)
	if bool(progress.get("became_ready", false)):
		_progress_status.text = "状态：本场已满足全部条件 —— 可以执行了。"
		_progress_status.add_theme_color_override("font_color", GuStyle.CINNABAR)
	elif bool(progress.get("ready_after", false)):
		_progress_status.text = "状态：已满足全部条件。"
		_progress_status.add_theme_color_override("font_color", GuStyle.CINNABAR)
	else:
		_progress_status.text = "状态：尚未满足条件。"
		_progress_status.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_progress_next.text = str(progress.get("next_step_text", ""))


func _refresh_top_bar() -> void:
	if not _top_bar.has_method("set_data"):
		return
	_top_bar.set_data(
		_snapshot.get("resources", {}),
		_snapshot.get("contracts", []),
		_snapshot.get("anomalies", []),
		_snapshot.get("death_lines", {}),
		int(_snapshot.get("layer", -1)))


func _refresh_header() -> void:
	var m0_mode := bool(_snapshot.get("m0_mode", false))
	_title_label.text = _vertical_title("战后抉择" if m0_mode else str(_snapshot.get("title", "战利品")))
	_subtitle_label.text = "三选一 · 选择会改变本局构筑" if m0_mode else "战利品已入账 · 本屏为确认展示"
	_section_title.text = "本场奖励" if m0_mode else "本场所得"


func _refresh_rewards() -> void:
	_clear_children(_reward_row)
	if bool(_snapshot.get("m0_mode", false)):
		_refresh_m0_choices()
		return
	var rewards: Array = _snapshot.get("rewards", [])
	for r in rewards:
		if not (r is Dictionary):
			continue
		_build_reward_card(r)
	if rewards.is_empty():
		var empty := _label_of("（本次无战利品）", GuStyle.INK_SOFT, 14)
		_reward_row.add_child(empty)


func _refresh_m0_choices() -> void:
	var choices: Array = _snapshot.get("choice_rewards", [])
	var selected := bool(_snapshot.get("choice_selected", false))
	for option_value in choices:
		if not (option_value is Dictionary):
			continue
		var option: Dictionary = option_value
		var option_id := str(option.get("id", ""))
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 104)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s\n\n%s" % [str(option.get("title", "")), str(option.get("description", ""))]
		button.tooltip_text = str(option.get("description", ""))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		MasterTheme.apply_button(button, "action", "large")
		button.custom_minimum_size = Vector2(220, 104)
		button.disabled = selected
		button.pressed.connect(_on_m0_choice_pressed.bind(option_id))
		_reward_row.add_child(button)
	if choices.is_empty():
		_reward_row.add_child(_label_of("（当前没有可用奖励）", GuStyle.INK_SOFT, 14))


func _on_m0_choice_pressed(option_id: String) -> void:
	_fire("choose_reward", option_id)


func _build_reward_card(r: Dictionary) -> void:
	var cursed := bool(r.get("curse_warning", false))
	var card := GuCardScene.instantiate()
	# 先入树再配内容：GuCardView.content_host 是 @onready，add_child 触发 _ready() 后才有值。
	_reward_row.add_child(card)
	card.setup(str(r.get("name", "")), str(r.get("quality", "")), cursed, cursed, false, "",
			false, false, false, "idle", str(r.get("effect", "")))

	var kind := str(r.get("kind", ""))
	if kind != "":
		card.content_host.add_child(_label_of(kind, GuStyle.INK_SOFT, 12))
	var cost := str(r.get("cost", ""))
	if cost != "":
		card.content_host.add_child(_label_of(cost, GuStyle.ANOMALY_YELLOW, 13))


func _refresh_notes() -> void:
	# 空即隐藏：原 .guitkx 无条件渲染空 Label（白占一行），这里顺手收敛。
	var fallback := str(_snapshot.get("pool_fallback_note", ""))
	_pool_fallback_label.text = fallback
	_pool_fallback_label.visible = fallback != ""
	var pity := str(_snapshot.get("pity_note", ""))
	_pity_label.text = pity
	_pity_label.visible = pity != ""
	var m0_mode := bool(_snapshot.get("m0_mode", false))
	var choice_selected := bool(_snapshot.get("choice_selected", false))
	_continue_button.disabled = m0_mode and not choice_selected
	_continue_button.text = "继续旅程" if not m0_mode or choice_selected else "请选择一项奖励"


func _fire(key: String, arg = null) -> void:
	if not _commands.has(key):
		return
	if arg == null:
		_commands[key].call()
	else:
		_commands[key].call(arg)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _label_of(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_base_fonts() -> void:
	# 基准风格：竖排墨色标题 + 红线 + 印章 + 双色描边主按钮
	_title_label.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_title_rule.color = Color("82463e")
	_title_rule.custom_minimum_size = Vector2(2, 0)
	_paper.color = GuStyle.PAPER_HALL
	GuStyle.apply_seal(_seal_box, 3.0)
	$Root/HeaderRow/SubtitleLabel.add_theme_color_override("font_color", GuStyle.NOTE_TEXT)
	$Root/primary_decision_surface/SectionTitle.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_pool_fallback_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_pity_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	MasterTheme.apply_primary_outline(_continue_button, 20)


## 竖排：每字一行（Godot Label 无 writing-mode，用换行模拟）。
func _vertical_title(flat: String) -> String:
	if flat == "":
		return ""
	var lines: Array[String] = []
	for ch in flat:
		lines.append(str(ch))
	return "\n".join(lines)
