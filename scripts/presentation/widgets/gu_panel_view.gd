class_name GuPanelView
extends PanelContainer
## 内容边界容器（Godot 官方 .tscn 节点树版，替代 ui/widgets/gu_panel.guitkx）。
## 冷峻旧宣纸命簿风格：发丝线边界 + 朱砂标题装饰线 + 柔和阴影 + 留白呼吸感。
## 外部内容一律加进 content_host。
## transparent_bg=true 时使用半透明纸面背景，让暗色舞台透出来（战斗/休整/交易屏用）。

@onready var _title_label: Label = $PanelMargin/PanelBody/TitleRow/TitleLabel
@onready var _title_row: HBoxContainer = $PanelMargin/PanelBody/TitleRow
@onready var content_host: VBoxContainer = $PanelMargin/PanelBody/ContentHost

var _transparent_bg: bool = false
var _cinnabar_rule: ColorRect = null
var _title_divider: ColorRect = null


func _ready() -> void:
	_title_label.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_title_label.add_theme_font_size_override("font_size", GuStyle.FONT_H3)
	_title_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_apply_title_decoration()
	_refresh_style()


## 一次性写入面板标题并刷新。title 为空时隐藏标题行。
## transparent_bg=true 时面板背景半透明，用于暗色舞台场景（战斗/休整/交易/炼蛊/遭遇）。
func setup(title: String = "", expand_h: bool = false, expand_v: bool = false,
		transparent_bg: bool = false) -> void:
	_title_label.text = title
	_title_row.visible = title != ""
	if _title_divider != null:
		_title_divider.visible = title != ""
	if expand_h:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_v:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transparent_bg = transparent_bg
	_refresh_style()


## 标题栏装饰：左侧朱砂短竖线 + 标题与内容区分隔发丝线。
## 营造命簿批注感，提升设计层次。
func _apply_title_decoration() -> void:
	if _title_row == null:
		return
	# 左侧朱砂装饰线
	_cinnabar_rule = ColorRect.new()
	_cinnabar_rule.name = "CinnabarRule"
	_cinnabar_rule.color = GuStyle.CINNABAR
	_cinnabar_rule.custom_minimum_size = Vector2(GuStyle.CINNABAR_RULE_WIDTH, GuStyle.CINNABAR_RULE_HEIGHT)
	_cinnabar_rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title_row.add_child(_cinnabar_rule)
	_title_row.move_child(_cinnabar_rule, 0)
	# 标题与内容区分隔发丝线
	_title_divider = ColorRect.new()
	_title_divider.name = "TitleDivider"
	_title_divider.color = GuStyle.TITLE_DIVIDER_COLOR
	_title_divider.custom_minimum_size = Vector2(0, GuStyle.TITLE_DIVIDER_WIDTH)
	_title_divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_body := _title_row.get_parent()
	if panel_body != null:
		panel_body.add_child(_title_divider)
		panel_body.move_child(_title_divider, _title_row.get_index() + 1)


func _refresh_style() -> void:
	var box := StyleBoxFlat.new()
	if _transparent_bg:
		# 暗色舞台场景：半透明纸面背景，让舞台底色与青茅山背景透出来
		box.bg_color = Color(GuStyle.PAPER_BG.r, GuStyle.PAPER_BG.g, GuStyle.PAPER_BG.b, 0.70)
	else:
		box.bg_color = GuStyle.PAPER_BG
	box.set_border_width_all(GuStyle.HAIRLINE)
	box.border_color = GuStyle.HAIRLINE_COLOR
	box.set_corner_radius_all(GuStyle.RADIUS_LARGE)
	# 冷峻旧宣纸风格阴影：低透明度、柔和偏移，不搞厚重投影
	box.shadow_color = GuStyle.SHADOW_MEDIUM_COLOR
	box.shadow_size = GuStyle.SHADOW_MEDIUM_SIZE
	box.shadow_offset = GuStyle.SHADOW_MEDIUM_OFFSET
	add_theme_stylebox_override("panel", box)
