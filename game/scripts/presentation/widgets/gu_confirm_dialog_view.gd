class_name GuConfirmDialogView
extends PanelContainer
## 统一确认弹窗（Godot 官方 .tscn 节点树版，替代 ui/widgets/gu_confirm_dialog.guitkx）。
## 顶部朱砂警示条 + 后果预览；危险色锁死，不做柔和化。
## 宿主通过 open(...) 传入文案与回调，通过 close() 收起；自身不持有任何领域状态。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")

@onready var _title_label: Label = $DialogBody/WarnBar/WarnMargin/TitleLabel
@onready var _message_label: Label = $DialogBody/BodyMargin/BodyBox/MessageLabel
@onready var _note_label: Label = $DialogBody/BodyMargin/BodyBox/NoteLabel
@onready var _cancel_button: Button = $DialogBody/BodyMargin/BodyBox/ButtonRow/CancelButton
@onready var _confirm_button: Button = $DialogBody/BodyMargin/BodyBox/ButtonRow/ConfirmButton

var _on_confirm: Callable = Callable()
var _on_cancel: Callable = Callable()


func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.border_color = GuStyle.CINNABAR
	add_theme_stylebox_override("panel", box)

	var warn_box := StyleBoxFlat.new()
	warn_box.bg_color = GuStyle.TINT_BLOOD_DEEP
	$DialogBody/WarnBar.add_theme_stylebox_override("panel", warn_box)
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.85, 1))
	_message_label.add_theme_font_size_override("font_size", 16)
	_message_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_note_label.add_theme_font_size_override("font_size", 14)
	_note_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)

	MasterTheme.apply_button(_cancel_button, "cancel")
	MasterTheme.apply_button(_confirm_button, "danger", "large")
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)


## 打开弹窗：写入文案与回调并显示。取消标签为空时隐藏取消按钮（不可逆场景）。
func open(message: String, on_confirm: Callable, on_cancel: Callable,
		title: String = "⚠ 确认", warning_note: String = "",
		confirm_label: String = "确认", cancel_label: String = "取消") -> void:
	_title_label.text = title
	_message_label.text = message
	_note_label.text = warning_note
	_note_label.visible = warning_note != ""
	_confirm_button.text = confirm_label
	_cancel_button.text = cancel_label
	_cancel_button.visible = cancel_label != ""
	_on_confirm = on_confirm
	_on_cancel = on_cancel
	visible = true


## 关闭弹窗。
##
## 必须把文本一并清空，不能只 visible=false：弹窗是预置在节点树里的常驻节点，
## 隐藏后文本仍留在树中，会被「按文本查找」的断言和逻辑误命中（RUI 时期是条件
## 渲染、隐藏时根本不存在节点，所以没这问题）。见 UI_RULES §5 空值不渲染。
func close() -> void:
	visible = false
	_title_label.text = ""
	_message_label.text = ""
	_note_label.text = ""
	_on_confirm = Callable()
	_on_cancel = Callable()


func _on_confirm_pressed() -> void:
	var cb := _on_confirm
	close()
	if cb.is_valid():
		cb.call()


func _on_cancel_pressed() -> void:
	var cb := _on_cancel
	close()
	if cb.is_valid():
		cb.call()
