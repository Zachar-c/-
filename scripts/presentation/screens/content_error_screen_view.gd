class_name ContentErrorScreenView
extends MarginContainer

const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")

## 内容配置无法加载时的兜底屏（B1 线框 v1 对齐）。
##
## 这一屏是「内容都没加载成功」时唯一能显示的东西，所以它必须**零依赖**：
## 不引用 catalog、不引用 DisplayText、不依赖任何可能同样损坏的数据表，
## 只用 GuStyle 的常量与纯节点树。加任何间接依赖都会让它在最需要的时候一起挂掉。

@onready var _count_label: Label = $Root/TitleRow/TitleMeta/CountLabel
@onready var _error_host: VBoxContainer = $Root/ErrorPanel/ErrorScroll/ErrorHost
@onready var _quit: Button = $Root/FooterRow/QuitButton
@onready var _seal: Label = $Root/TopBar/Seal/SealLabel
@onready var _vtitle: Label = $Root/TitleRow/VTitle
@onready var _redline: ColorRect = $Root/TitleRow/TitleMeta/RedLine
@onready var _top_hint: Label = $Root/TopBar/TopHint

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}

var _ready_done := false


func _ready() -> void:
	_ready_done = true
	_apply_style()
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
	_count_label.text = "错误条数 %d 条" % int(_snapshot.get("error_count", errors.size()))

	for c in _error_host.get_children():
		_error_host.remove_child(c)
		c.free()
	for i in errors.size():
		var l := Label.new()
		l.text = "%d  %s" % [i + 1, str(errors[i])]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_error_host.add_child(l)

	_quit.visible = _commands.has("quit")


func _apply_style() -> void:
	_seal.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_seal.add_theme_color_override("font_color", GuStyle.CINNABAR)
	_vtitle.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_vtitle.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_vtitle.add_theme_constant_override("line_spacing", -4)
	_redline.color = GuStyle.CINNABAR
	_count_label.add_theme_font_override("font", GuStyle.BODY_FONT)
	_count_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_top_hint.add_theme_font_override("font", GuStyle.BODY_FONT)
	_top_hint.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	MasterTheme.apply_button(_quit, "action")
