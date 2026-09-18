class_name GuToastView
extends CenterContainer

## 轻量提示条（规格 §8 D4 / §4.5 L4 不拦截）。
##
## 纯展示组件：显隐由宿主控制，本组件**不起计时器**。
## 消隐由控制器侧清空 last_feedback 驱动（见 run_controller._on_feedback_timer_timeout）。

@onready var _panel: PanelContainer = $ToastPanel
@onready var _label: Label = $ToastPanel/ToastMargin/ToastLabel

## tone: "info" 普通信息 / "warn" 警示。
## 旧 .guitkx 实现里两个 tone 都走 ANOMALY_YELLOW（三元两边写成了同一个值），
## 这里按 UI_RULES §2 的语义修正：warn 才是「异常/凶险」，info 只是普通信息。
func setup(text: String, tone: String = "info") -> void:
	var color := GuStyle.ANOMALY_YELLOW if tone == "warn" else GuStyle.INK_SOFT
	_label.text = text
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", color)
	_apply_panel_style(color)
	# 不拦截点击：提示条浮在内容之上但不该吃掉操作。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = text != ""


func _apply_panel_style(border: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED
	box.border_color = border
	box.set_border_width_all(GuStyle.HAIRLINE)
	box.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", box)
