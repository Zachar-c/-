class_name SettingsScreenView
extends MarginContainer
## 设置屏（线框稿 v2：声音 / 显示 / 存档 三栏）。
## 分辨率选项与静音走代码生成；保存/读档经 commands 出口。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")

## 分辨率档位（与 scripts/domain/app_settings.gd 的 RESOLUTIONS 对齐）。
const RESOLUTIONS: Array[Dictionary] = [
	{"label": "全屏", "mode": "fullscreen"},
	{"label": "1920×1080 · 窗口", "mode": "window"},
	{"label": "1600×900 · 窗口", "mode": "window"},
	{"label": "1280×720 · 窗口", "mode": "window"},
]

@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _paper: ColorRect = $SettingsPaper
@onready var _stage: PanelContainer = $Root/SettingsStage
@onready var _seal_box: PanelContainer = $Root/HeaderRow/SealPanelContainer
@onready var _title_label: Label = $Root/HeaderRow/TitleLabel
@onready var _title_rule: ColorRect = $Root/HeaderRow/TitleRule
@onready var _sub_label: Label = $Root/HeaderRow/SubLabel
@onready var _volume_label: Label = $Root/SettingsStage/StageContent/SoundRow/VolumeLabel
@onready var _mute_button: Button = $Root/SettingsStage/StageContent/SoundRow/MuteButton
@onready var _resolution_row: HBoxContainer = $Root/SettingsStage/StageContent/ResolutionRow
@onready var _save_button: Button = $Root/SettingsStage/StageContent/SaveRow/SaveButton
@onready var _load_button: Button = $Root/SettingsStage/StageContent/SaveRow/LoadButton

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
var _ready_done := false
## 本地展示态（只改展示，持久化经 commands）。
var _muted := false
var _resolution_index := 3


func _ready() -> void:
	_ready_done = true
	_apply_base_fonts()
	_apply_stage_style()
	_build_resolutions()
	_mute_button.pressed.connect(_toggle_mute)
	_save_button.pressed.connect(func(): _fire("save"))
	_load_button.pressed.connect(func(): _fire("load"))
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
	_refresh_sound()
	_refresh_resolutions()


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
	_title_label.text = _vertical_title(str(_snapshot.get("title", "设置")))
	_sub_label.text = str(_snapshot.get("subtitle", "声色之调 · 存于机匣"))


func _refresh_sound() -> void:
	var volume := int(_snapshot.get("master_volume", 100))
	_volume_label.text = "0" if _muted else str(volume)
	_mute_button.text = "取消静音" if _muted else "静音"
	MasterTheme.apply_button(_mute_button, "danger" if _muted else "action")


func _toggle_mute() -> void:
	_muted = not _muted
	_refresh_sound()
	_fire("toggle_mute")


func _build_resolutions() -> void:
	for child in _resolution_row.get_children():
		_resolution_row.remove_child(child)
		child.queue_free()
	for i in RESOLUTIONS.size():
		var r := RESOLUTIONS[i]
		var btn := Button.new()
		btn.text = str(r["label"])
		btn.pressed.connect(func():
			_resolution_index = i
			_refresh_resolutions()
			_fire("set_resolution", i))
		_resolution_row.add_child(btn)


func _refresh_resolutions() -> void:
	var children := _resolution_row.get_children()
	for i in children.size():
		if not (children[i] is Button):
			continue
		var on := i == _resolution_index
		MasterTheme.apply_button(children[i], "danger" if on else "action")


func _fire(key: String, arg = null) -> void:
	if not _commands.has(key):
		return
	if arg == null:
		_commands[key].call()
	else:
		_commands[key].call(arg)


func _vertical_title(flat: String) -> String:
	if flat == "":
		return ""
	var lines: Array[String] = []
	for ch in flat:
		lines.append(str(ch))
	return "\n".join(lines)


func _apply_base_fonts() -> void:
	_title_label.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_title_rule.color = Color("82463e")
	_title_rule.custom_minimum_size = Vector2(2, 0)
	_sub_label.add_theme_color_override("font_color", GuStyle.NOTE_TEXT)
	_volume_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_paper.color = GuStyle.PAPER_HALL
	GuStyle.apply_seal(_seal_box, 3.0)
	MasterTheme.apply_button(_save_button, "action")
	MasterTheme.apply_button(_load_button, "action")


func _apply_stage_style() -> void:
	var stage_box := StyleBoxFlat.new()
	stage_box.bg_color = Color(0, 0, 0, 0)
	stage_box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	_stage.add_theme_stylebox_override("panel", stage_box)
