class_name SettingsScreenView
extends Control
## 设置屏（线框稿 v2 高精度对齐：面板 left112/top186/w1130/h420，
## 声音滑块 / 分隔线 / 当前分辨率提示 / 右侧导航，逐项对齐）。
## 分辨率选项与静音走代码生成；保存/读档经 commands 出口。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GameVersionScript := preload("res://scripts/domain/game_version.gd")

## 分辨率档位（与 scripts/domain/app_settings.gd 的 RESOLUTIONS 对齐）。
const RESOLUTIONS: Array[Dictionary] = [
	{"label": "全屏", "mode": "fullscreen"},
	{"label": "1920×1080 · 窗口", "mode": "window"},
	{"label": "1600×900 · 窗口", "mode": "window"},
	{"label": "1280×720 · 窗口", "mode": "window"},
]
const TRACK_LEFT := 110.0
const TRACK_WIDTH := 440.0
const THUMB_OFF := 6.0

@onready var _top_bar: PanelContainer = $TopBar
@onready var _paper: ColorRect = $SettingsPaper
@onready var _vtitle: Label = $VTitle
@onready var _redline: ColorRect = $RedLine
@onready var _sub_label: Label = $SubLabel
@onready var _seal_box: PanelContainer = $SealPanelContainer
@onready var _stage: PanelContainer = $SettingsStage
@onready var _volume_label: Label = $SettingsStage/Content/VolumeLabel
@onready var _mute_button: Button = $SettingsStage/Content/MuteButton
@onready var _fill: ColorRect = $SettingsStage/Content/Fill
@onready var _thumb: PanelContainer = $SettingsStage/Content/Thumb
@onready var _resolution_row: HBoxContainer = $SettingsStage/Content/ResolutionRow
@onready var _current_hint: Label = $SettingsStage/Content/CurrentHint
@onready var _save_button: Button = $SettingsStage/Content/SaveRow/SaveButton
@onready var _load_button: Button = $SettingsStage/Content/SaveRow/LoadButton
@onready var _nav_journal: Button = $Nav/NavJournal
@onready var _nav_codex: Button = $Nav/NavCodex
@onready var _nav_settings: Button = $Nav/NavSettings
@onready var _nav_quit: Button = $Nav/NavQuit
@onready var _back_button: Button = $SettingsStage/Content/BackRow/BackButton
@onready var _version_label: Label = $VersionLabel

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
	_back_button.pressed.connect(func(): _fire("back"))
	_mute_button.pressed.connect(_toggle_mute)
	_save_button.pressed.connect(func(): _fire("save"))
	_load_button.pressed.connect(func(): _fire("load"))
	_nav_quit.pressed.connect(func(): _fire("back"))
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
	# 快照驱动的本地展示态：音量 0 ⇒ 静音；分辨率高亮跟随偏好。
	_muted = int(_snapshot.get("master_volume", 100)) <= 0
	_version_label.text = str(_snapshot.get("version_label", GameVersionScript.display()))
	_resolution_index = int(_snapshot.get("resolution_index", 3))
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
	_vtitle.text = _vertical_title(str(_snapshot.get("title", "设置")))
	_sub_label.text = str(_snapshot.get("subtitle", "声色之调 · 存于机匣"))


func _refresh_sound() -> void:
	var volume := int(_snapshot.get("master_volume", 100))
	_volume_label.text = "0" if _muted else str(volume)
	_mute_button.text = "取消静音" if _muted else "静音"
	# 音量滑块：fill 宽 = 音量百分比；thumb 跟随右端。
	var fill_w := TRACK_WIDTH * clampf(float(volume) / 100.0, 0.0, 1.0)
	_fill.offset_right = TRACK_LEFT + fill_w
	_thumb.offset_left = TRACK_LEFT + fill_w - THUMB_OFF
	_thumb.offset_right = TRACK_LEFT + fill_w - THUMB_OFF + 16.0
	_apply_opt_style(_mute_button, _muted)


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
		_apply_opt_style(children[i], on)
	var label := str(RESOLUTIONS[_resolution_index]["label"])
	var hint := "当前 %s" % label
	if label == "1280×720 · 窗口":
		hint += "（与基准 1:1）"
	_current_hint.text = hint


## 线稿 v2 选项按钮：透明底 + 细边框 + 墨字；选中态浅纸底。
func _apply_opt_style(btn: Button, on: bool) -> void:
	btn.flat = false
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_font_override("font", GuStyle.BODY_FONT)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	if on:
		# 与旧硬编码 #f6f3e9 同值，只改走 GuStyle token（UI_RULES §2）。
		var on_tint := GuStyle.NODE_REACH_BG
		on_tint.a = 0.6
		box.bg_color = on_tint
		box.border_color = Color("9a978c")
		btn.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	else:
		box.bg_color = Color(0, 0, 0, 0)
		box.border_color = Color("aaa89f")
		btn.add_theme_color_override("font_color", GuStyle.NAV_TEXT)
	btn.add_theme_stylebox_override("normal", box)
	var hover := box.duplicate()
	hover.border_color = Color("9c332d")
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_hover_color", GuStyle.CINNABAR)
	btn.add_theme_color_override("font_pressed_color", GuStyle.CINNABAR)
	btn.add_theme_color_override("font_focus_color", GuStyle.NAV_TEXT)


func _fire(key: String, arg = null) -> void:
	if not _commands.has(key):
		return
	if arg == null:
		_commands[key].call()
	else:
		_commands[key].call(arg)


func _apply_menu_style(btn: Button) -> void:
	if btn == null:
		return
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_font_override("font", GuStyle.BODY_FONT)
	btn.add_theme_color_override("font_color", GuStyle.NAV_TEXT)
	btn.add_theme_color_override("font_hover_color", GuStyle.CINNABAR)
	btn.add_theme_color_override("font_pressed_color", GuStyle.CINNABAR)
	btn.add_theme_color_override("font_focus_color", GuStyle.NAV_TEXT)
	btn.add_theme_color_override("font_disabled_color", GuStyle.INK_MUTED)


func _vertical_title(flat: String) -> String:
	if flat == "":
		return ""
	var lines: Array[String] = []
	for ch in flat:
		lines.append(str(ch))
	return "\n".join(lines)


func _apply_base_fonts() -> void:
	_vtitle.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_vtitle.add_theme_font_size_override("font_size", 26)
	_vtitle.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_redline.color = Color("82463e")
	_sub_label.add_theme_font_override("font", GuStyle.BODY_FONT)
	_sub_label.add_theme_font_size_override("font_size", 12)
	_sub_label.add_theme_color_override("font_color", GuStyle.NOTE_TEXT)
	_volume_label.add_theme_font_override("font", GuStyle.BODY_FONT)
	_volume_label.add_theme_font_size_override("font_size", 15)
	_volume_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_version_label.add_theme_font_size_override("font_size", 11)
	_version_label.add_theme_color_override("font_color", GuStyle.VER_TEXT)
	_paper.color = GuStyle.PAPER_HALL
	GuStyle.apply_seal(_seal_box, 3.0)
	# 右侧导航：手记/图鉴尚未接入独立路由（图鉴=蛊方收藏册待 D1b 落地，
	# 手记=事件日志待规划），为避免"可点无反应"，一律 disabled 置灰；
	# 设置=当前页标识亦 disabled。退出即返回。接入路由后移除 disabled。
	for btn in [_nav_journal, _nav_codex, _nav_quit]:
		_apply_menu_style(btn)
	_nav_journal.disabled = true
	_nav_codex.disabled = true
	_nav_settings.disabled = true
	_nav_settings.flat = true
	_nav_settings.add_theme_font_size_override("font_size", 14)
	_nav_settings.add_theme_font_override("font", GuStyle.BODY_FONT)
	_nav_settings.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_apply_menu_style(_back_button)
	_apply_opt_style(_save_button, false)
	_apply_opt_style(_load_button, false)


func _apply_stage_style() -> void:
	var stage_box := StyleBoxFlat.new()
	var stage_tint := GuStyle.NODE_REACH_BG
	stage_tint.a = 0.55
	stage_box.bg_color = stage_tint
	stage_box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	stage_box.border_width_left = 1
	stage_box.border_width_top = 1
	stage_box.border_width_right = 1
	stage_box.border_width_bottom = 1
	stage_box.border_color = Color("aaa89f")
	_stage.add_theme_stylebox_override("panel", stage_box)
	var thumb_box := StyleBoxFlat.new()
	thumb_box.bg_color = Color("e5e2d7")
	thumb_box.border_width_left = 1
	thumb_box.border_width_top = 1
	thumb_box.border_width_right = 1
	thumb_box.border_width_bottom = 1
	thumb_box.border_color = Color("9a978c")
	_thumb.add_theme_stylebox_override("panel", thumb_box)
