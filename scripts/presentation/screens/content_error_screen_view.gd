class_name ContentErrorScreenView
extends MarginContainer

const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")

## 内容配置无法加载时的兜底屏。
##
## 这一屏是「内容都没加载成功」时唯一能显示的东西，所以它必须**零依赖**：
## 不引用 catalog、不引用 DisplayText、不依赖任何可能同样损坏的数据表，
## 只用 GuStyle 的常量与纯节点树。加任何间接依赖都会让它在最需要的时候一起挂掉。

@onready var _title: Label = $Center/Body/TitleLabel
@onready var _hint: Label = $Center/Body/HintLabel
@onready var _error_host: VBoxContainer = $Center/Body/ErrorHost
@onready var _quit: Button = $Center/Body/QuitButton

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}

var _ready_done := false


func _ready() -> void:
	_ready_done = true
	_apply_fonts()
	_quit.pressed.connect(func():
		if _commands.has("quit"):
			_commands["quit"].call())
	_refresh()


## run_controller 的挂载入口（与各屏同签名）。
func mount_snapshot(snapshot: Dictionary, commands: Dictionary) -> void:
	_snapshot = snapshot
	_commands = commands
	if _ready_done:
		_refresh()


func _refresh() -> void:
	if not _ready_done:
		return
	var errors: Array = _snapshot.get("errors", [])
	_title.text = str(_snapshot.get("title", "内容配置无法加载"))
	_hint.text = "请修复数据文件后重新启动。错误数：%d" % int(_snapshot.get("error_count", errors.size()))

	for c in _error_host.get_children():
		_error_host.remove_child(c)
		c.free()
	for e in errors:
		var l := Label.new()
		l.text = "· " + str(e)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", GuStyle.CINNABAR)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_error_host.add_child(l)

	_quit.visible = _commands.has("quit")


func _apply_fonts() -> void:
	_title.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_title.add_theme_color_override("font_color", GuStyle.CINNABAR)
	_hint.add_theme_font_override("font", GuStyle.BODY_FONT)
	_hint.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	MasterTheme.apply_button(_quit, "action")
