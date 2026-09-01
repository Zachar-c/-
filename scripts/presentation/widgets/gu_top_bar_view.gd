class_name GuTopBarView
extends PanelContainer
## 局内全局顶栏（Godot 官方 .tscn 节点树版，替代 ui/widgets/gu_top_bar.guitkx）。
##
## 只读展示 snapshot 的资源 / 契约 / 异变 / 三死线；唯一交互出口是点危险死线查看死因。
## 种类固定的元素（4 种资源 chip、3 条死线）预置在节点树里靠 visible 控制，
## 数量不定的元素（契约 / 异变徽章）才走代码生成。
## 颜色与字号一律取自 GuStyle，不在 .tscn 里硬编码色值。

const RESOURCE_KINDS := ["yuanstone", "shouyuan", "hunpo", "material"]
const DEATH_KINDS := ["shouyuan", "hunpo", "backlash"]
const DEATH_NAMES := {"shouyuan": "寿元", "hunpo": "魂魄", "backlash": "反噬"}

const BLOOD_BAR := GuStyle.TINT_BLOOD

## chip 内图标尺寸（对齐 GuIconView.SIZE_SMALL，不引用其类型以免加载时序问题）。
const CHIP_ICON_PX := 16

# 显式路径而非 % unique-name：子场景实例化后 owner 链不指向自身根，
# % 查找会失败（实测 Godot 4.7.2）。显式路径同时让节点树结构一目了然。
@onready var _layer_label: Label = $BarMargin/BarRow/LayerLabel
@onready var _chip_host: HBoxContainer = $BarMargin/BarRow/ChipHost
@onready var _meta_host: HBoxContainer = $BarMargin/BarRow/MetaHost
@onready var _death_title: Label = $BarMargin/BarRow/DeathHost/DeathTitle
@onready var _death_host: VBoxContainer = $BarMargin/BarRow/DeathHost
@onready var _menu_button: Button = $BarMargin/BarRow/MenuButton

var _chips: Dictionary = {}
var _death_rows: Dictionary = {}

var _on_view: Callable = Callable()
var _on_menu: Callable = Callable()

var _resources: Dictionary = {}
var _contracts: Array = []
var _anomalies: Array = []
var _death_lines: Dictionary = {}


func _ready() -> void:
	for kind in RESOURCE_KINDS:
		var chip: PanelContainer = _chip_host.get_node_or_null("Chip" + kind.capitalize().replace(" ", ""))
		if chip != null:
			_chips[kind] = chip
			_apply_chip_style(chip)
	for kind in DEATH_KINDS:
		var row: Button = _death_host.get_node_or_null("Death" + kind.capitalize())
		if row != null:
			_death_rows[kind] = row
			row.pressed.connect(_on_death_row_pressed.bind(kind))
	_apply_bar_style()
	_menu_button.pressed.connect(_on_menu_pressed)
	_refresh_all()


## 供宿主（各屏 view）调用：写入快照数据并刷新。
func set_data(resources: Dictionary, contracts: Array, anomalies: Array,
		death_lines: Dictionary, layer: int = -1) -> void:
	_resources = resources
	_contracts = contracts
	_anomalies = anomalies
	_death_lines = death_lines
	_layer_label.visible = layer >= 0
	if layer >= 0:
		_layer_label.text = "第 %d 转" % layer
	_refresh_all()


## 死线点击出口：cause_id 回传宿主去开死因浮层。
## 必须重刷死线行：行的 disabled 取决于 _on_view 是否有效，而 set_data() 通常
## 在宿主接上本回调**之前**就跑过了，不补刷会让危险行一直点不动。
func set_on_view(callable: Callable) -> void:
	_on_view = callable
	_refresh_death_lines()


func set_on_menu(callable: Callable) -> void:
	_on_menu = callable
	_menu_button.visible = callable.is_valid()


func _refresh_all() -> void:
	_refresh_chips()
	_refresh_meta()
	_refresh_death_lines()


func _refresh_chips() -> void:
	for kind in RESOURCE_KINDS:
		var chip: PanelContainer = _chips.get(kind)
		if chip == null:
			continue
		var has_kind: bool = _resources.has(kind)
		chip.visible = has_kind
		if not has_kind:
			continue
		var canonical := GuStyle.resource_normalize(kind)
		var label: Label = chip.get_node("ChipMargin/ChipBox/Label")
		label.text = "%s: %d%s" % [
			GuStyle.resource_label(canonical),
			int(_resources[kind]),
			GuStyle.resource_suffix(canonical),
		]
		var tone := GuStyle.resource_color(canonical)
		label.add_theme_color_override("font_color", tone)
		# chip 底是 INK_PRIMARY 深色，图标必须染资源色才看得见（图标本体是白描边）。
		# 刻意用 Node + duck typing，不标 GuIconView 类型：class_name 的全局注册
		# 有时序，标类型会让本脚本在 gu_icon_view.gd 注册前加载失败。
		var icon: Node = chip.get_node("ChipMargin/ChipBox/Icon")
		if icon != null and icon.has_method("setup"):
			icon.setup(kind, tone, CHIP_ICON_PX)


func _refresh_meta() -> void:
	for child in _meta_host.get_children():
		child.queue_free()
	for c in _contracts:
		_meta_host.add_child(_meta_badge("契约·%s" % c, GuStyle.CONTRACT_BLUE,
				GuStyle.TINT_CONTRACT))
	for a in _anomalies:
		var label_text := str(a.get("label", a)) if a is Dictionary else str(a)
		_meta_host.add_child(_meta_badge("异变·%s" % label_text, GuStyle.ANOMALY_YELLOW,
				GuStyle.TINT_ANOMALY))


func _refresh_death_lines() -> void:
	var any := false
	for kind in DEATH_KINDS:
		var row: Button = _death_rows.get(kind)
		if row == null:
			continue
		if not _death_lines.has(kind):
			row.visible = false
			continue
		var d: Dictionary = _death_lines[kind]
		var remaining := int(d.get("value", d.get("remaining", 0)))
		var threshold := int(d.get("threshold", d.get("max", 0)))
		var danger := bool(d.get("danger", remaining >= threshold))
		row.visible = true
		any = true
		row.text = ("☠ %s %d/%d" if danger else "· %s %d/%d") % [
			str(d.get("name", DEATH_NAMES.get(kind, kind))), remaining, threshold]
		row.set_meta("cause_id", str(d.get("cause_id", "")))
		row.disabled = not (danger and _on_view.is_valid())
		row.flat = not danger
		row.add_theme_font_size_override("font_size", 15 if danger else 13)
		row.add_theme_color_override("font_color", GuStyle.CINNABAR if danger else GuStyle.INK_SOFT)
		row.add_theme_color_override("font_disabled_color", GuStyle.CINNABAR if danger else GuStyle.INK_SOFT)
		# 危险行无论可否点击都要保持血锈底：Godot 在 disabled 时改走 disabled
		# stylebox，只设 normal 会让「无 on_view 宿主」的危险行掉回默认灰底。
		if danger:
			row.add_theme_stylebox_override("normal", _blood_box())
			row.add_theme_stylebox_override("disabled", _blood_box())
			row.add_theme_stylebox_override("hover", _blood_box())
		else:
			row.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	_death_title.visible = any


func _on_death_row_pressed(kind: String) -> void:
	if not _on_view.is_valid():
		return
	var row: Button = _death_rows.get(kind)
	if row == null:
		return
	_on_view.call(str(row.get_meta("cause_id", "")))


func _on_menu_pressed() -> void:
	if _on_menu.is_valid():
		_on_menu.call()


func _meta_badge(text: String, font_color: Color, bg: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", box)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", font_color)
	margin.add_child(label)
	panel.add_child(margin)
	return panel


func _apply_bar_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_BG
	box.border_color = GuStyle.HAIRLINE_COLOR
	box.set_border_width_all(GuStyle.HAIRLINE)
	add_theme_stylebox_override("panel", box)
	custom_minimum_size = Vector2(0, GuStyle.TOP_BAR_HEIGHT)


func _apply_chip_style(chip: PanelContainer) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.INK_PRIMARY
	box.border_color = GuStyle.PAPER_BG
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("panel", box)


func _blood_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BLOOD_BAR
	box.set_corner_radius_all(4)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box
