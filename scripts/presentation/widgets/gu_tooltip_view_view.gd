class_name GuTooltipViewView
extends PanelContainer
## 统一 tooltip 模板（Godot 官方 .tscn 节点树版，替代 ui/widgets/gu_tooltip_view.guitkx）。
## 固定格式：品质 / 效果 / 联动 / 代价 / 不可用 / 诅咒警示；缺段隐藏、顺序恒定。
## 底色 PAPER 卷轴 + 深字 INK；朱砂只保留给诅咒警示与不可用行，不与正文混用。

@onready var _title_label: Label = $TipMargin/TipBody/TitleRow/TitleLabel
@onready var _quality_label: Label = $TipMargin/TipBody/TitleRow/QualityLabel
@onready var _effect_label: Label = $TipMargin/TipBody/EffectLabel
@onready var _synergy_label: Label = $TipMargin/TipBody/SynergyLabel
@onready var _cost_label: Label = $TipMargin/TipBody/CostLabel
@onready var _block_label: Label = $TipMargin/TipBody/BlockLabel
@onready var _curse_label: Label = $TipMargin/TipBody/CurseLabel
@onready var _detail_button: Button = $TipMargin/TipBody/DetailButton


func _ready() -> void:
	_refresh_style()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_quality_label.add_theme_font_size_override("font_size", 12)
	for label in [_effect_label, _synergy_label, _cost_label, _block_label, _curse_label]:
		label.add_theme_font_size_override("font_size", 14)
	_effect_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_synergy_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_cost_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_block_label.add_theme_color_override("font_color", GuStyle.CINNABAR)
	_curse_label.add_theme_color_override("font_color", GuStyle.CINNABAR)
	_detail_button.add_theme_font_size_override("font_size", 14)
	_detail_button.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	hide_all()


## 写入各段文案并刷新显隐。空段一律隐藏，顺序恒定不变。
func setup(title: String = "", quality: String = "", effect: String = "",
		synergy: String = "", cost: String = "", block_reason: String = "",
		curse_warning: bool = false, on_detail: Callable = Callable()) -> void:
	_title_label.text = title
	_title_label.visible = title != ""
	_quality_label.text = quality
	_quality_label.visible = quality != ""
	_quality_label.add_theme_color_override("font_color", GuStyle.quality_color(quality))

	# 空段不仅隐藏，text 也必须清空：原 .guitkx 是条件渲染（根本不建节点），
	# 若这里只设 visible=false 而留着「代价：」这类前缀，按文本查找的断言会误命中。
	_effect_label.text = _seg("效果：", effect)
	_effect_label.visible = effect != ""
	_synergy_label.text = _seg("联动：", synergy)
	_synergy_label.visible = synergy != ""
	_cost_label.text = _seg("代价：", cost)
	_cost_label.visible = cost != ""
	_block_label.text = _seg("不可用：", block_reason)
	_block_label.visible = block_reason != ""
	_curse_label.text = _seg("诅咒警示：", effect if curse_warning else "")
	_curse_label.visible = curse_warning and effect != ""

	_detail_button.visible = on_detail.is_valid()
	if on_detail.is_valid():
		_disconnect_detail()
		_detail_button.pressed.connect(on_detail)


## 段文案：值为空时整段返回空串（等价于条件渲染）。
func _seg(prefix: String, value: String) -> String:
	return (prefix + value) if value != "" else ""


func hide_all() -> void:
	for label in [_title_label, _quality_label, _effect_label, _synergy_label,
			_cost_label, _block_label, _curse_label]:
		label.visible = false
	_detail_button.visible = false


func _disconnect_detail() -> void:
	for conn in _detail_button.pressed.get_connections():
		if conn.signal.get_name() == "pressed":
			_detail_button.pressed.disconnect(conn.callable)


func _refresh_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_BG
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	box.border_color = GuStyle.PAPER_DEEP
	add_theme_stylebox_override("panel", box)
