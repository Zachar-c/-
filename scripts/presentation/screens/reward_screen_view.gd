class_name RewardScreenView
extends MarginContainer
## 战利品确认屏（Godot 官方 .tscn 节点树版，替代 ui/screens/reward_screen.guitkx）。
##
## 战利品已由 settle_victory 自动入账，本屏是**确认展示**而非再抽取——
## 没有任何拾取 / 替换 / 放弃按钮（那些发的是领域不存在的幽灵命令，2026-08-28 已移除）。
## 静态骨架预置在节点树里，战利品卡走代码生成。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuCardScene := preload("res://scenes/ui/widgets/gu_card.tscn")

@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _paper: ColorRect = $RewardPaper
@onready var _seal_box: PanelContainer = $Root/HeaderRow/SealPanelContainer
@onready var _title_label: Label = $Root/HeaderRow/TitleLabel
@onready var _title_rule: ColorRect = $Root/HeaderRow/TitleRule
@onready var _reward_row: HBoxContainer = $Root/primary_decision_surface/RewardRow
@onready var _pool_fallback_label: Label = $Root/NoteRow/PoolFallbackLabel
@onready var _pity_label: Label = $Root/NoteRow/PityLabel
@onready var _continue_button: Button = $Root/ContinueButton

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
	_refresh_notes()


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
	_title_label.text = _vertical_title(str(_snapshot.get("title", "战利品")))


func _refresh_rewards() -> void:
	_clear_children(_reward_row)
	var rewards: Array = _snapshot.get("rewards", [])
	for r in rewards:
		if not (r is Dictionary):
			continue
		_build_reward_card(r)
	if rewards.is_empty():
		var empty := _label_of("（本次无战利品）", GuStyle.INK_SOFT, 14)
		_reward_row.add_child(empty)


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
