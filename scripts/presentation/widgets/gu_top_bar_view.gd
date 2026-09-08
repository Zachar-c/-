class_name GuTopBarView
extends PanelContainer
## 局内全局顶栏（杀戮尖塔风格：无框状态 + 右侧icon入口）。
##
## 左侧：气血 / 寿命 / 魂魄 / 原石（图标 + 当前/最大，无框包裹）
## 右侧：背包 / 设置（icon按钮，点击进入对应页面）
## 颜色与字号一律取自 GuStyle，不在 .tscn 里硬编码色值。

const STATUS_KINDS := ["qi", "shou", "hun", "yuan"]
const STATUS_ICON_KEYS := {
	"qi": "health",
	"shou": "shouyuan",
	"hun": "hunpo",
	"yuan": "yuanstone",
}
const STATUS_LABELS := {
	"qi": "气血",
	"shou": "寿命",
	"hun": "魂魄",
	"yuan": "原石",
}

## 图标尺寸（使用GuIconView常量，避免魔法数字）。
const ICON_PX := 16

@onready var _status_host: HBoxContainer = $BarMargin/BarRow/StatusHost
@onready var _action_host: HBoxContainer = $BarMargin/BarRow/ActionHost
@onready var _bag_button: Button = $BarMargin/BarRow/ActionHost/BagButton
@onready var _bag_icon: Node = $BarMargin/BarRow/ActionHost/BagButton/BagIcon
@onready var _settings_button: Button = $BarMargin/BarRow/ActionHost/SettingsButton
@onready var _settings_icon: Node = $BarMargin/BarRow/ActionHost/SettingsButton/SettingsIcon

var _status_nodes: Dictionary = {}
var _on_bag: Callable = Callable()
var _on_settings: Callable = Callable()

var _resources: Dictionary = {}
var _player: Dictionary = {}
var _death_lines: Dictionary = {}


func _ready() -> void:
	for kind in STATUS_KINDS:
		var status_box: HBoxContainer = _status_host.get_node_or_null(kind.capitalize() + "Status")
		if status_box != null:
			_status_nodes[kind] = {
				"box": status_box,
				"icon": status_box.get_node_or_null(kind.capitalize() + "Icon"),
				"label": status_box.get_node_or_null(kind.capitalize() + "Label"),
			}
	_apply_bar_style()
	_apply_action_buttons()
	_bag_button.pressed.connect(_on_bag_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_refresh_all()


## 供宿主（各屏 view）调用：写入快照数据并刷新。
## player参数用于获取气血（hp/max_hp），其他资源从resources获取。
func set_data(resources: Dictionary, contracts: Array, anomalies: Array,
		death_lines: Dictionary, layer: int = -1, player: Dictionary = {}) -> void:
	_resources = resources
	_player = player
	_death_lines = death_lines
	_refresh_all()


## 兼容既有屏幕挂载入口。
func set_on_view(_callable: Callable) -> void:
	pass


func set_on_menu(callable: Callable) -> void:
	# 兼容旧接口：menu 回调映射到 settings
	_on_settings = callable


func set_on_bag(callable: Callable) -> void:
	_on_bag = callable


func set_on_settings(callable: Callable) -> void:
	_on_settings = callable


func _refresh_all() -> void:
	_refresh_status()


func _refresh_status() -> void:
	for kind in STATUS_KINDS:
		var nodes: Dictionary = _status_nodes.get(kind)
		if nodes.is_empty():
			continue
		var value: int = 0
		var max_value: int = 0
		var has_data: bool = false
		var danger: bool = false
		var danger_detail := ""
		var resource_key := ""

		if kind == "qi":
			# 气血从player对象获取
			if _player.has("hp"):
				value = int(_player["hp"])
				max_value = int(_player.get("max_hp", 0))
				has_data = true
				var health_line: Dictionary = _death_lines.get("health", {})
				danger = bool(health_line.get("danger", false))
				danger_detail = str(health_line.get("detail", ""))
		else:
			# 寿命/魂魄/原石从resources获取
			resource_key = str(STATUS_ICON_KEYS.get(kind, ""))
			if _resources.has(resource_key):
				value = int(_resources[resource_key])
				has_data = true
				var line: Dictionary = _death_lines.get(resource_key, {})
				danger = bool(line.get("danger", false))
				danger_detail = str(line.get("detail", ""))

		var box: HBoxContainer = nodes["box"]
		box.visible = has_data
		if not has_data:
			continue

		var label: Label = nodes["label"]
		if max_value > 0:
			label.text = "%d/%d" % [value, max_value]
		else:
			label.text = "%d" % value

		# 危险反馈：数值转朱砂红 + hover tooltip 显示精准死因（沿用旧顶栏
		# chip.tooltip_text 契约——危险必须可感知原因，不允许静默）。
		var tone := GuStyle.CINNABAR if danger else GuStyle.INK_PRIMARY
		label.add_theme_color_override("font_color", tone)
		box.tooltip_text = danger_detail if danger else ""

		var icon: Node = nodes["icon"]
		if icon != null and icon.has_method("setup"):
			icon.setup(STATUS_ICON_KEYS[kind], tone, ICON_PX)


func _on_bag_pressed() -> void:
	if _on_bag.is_valid():
		_on_bag.call()


func _on_settings_pressed() -> void:
	if _on_settings.is_valid():
		_on_settings.call()


func _apply_bar_style() -> void:
	# 大屏基准：顶栏透明，纸面+网点由各屏根 Backdrop 提供，无框直接浮于纸面。
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Color(0, 0, 0, 0)
	box.set_border_width_all(0)
	add_theme_stylebox_override("panel", box)
	custom_minimum_size = Vector2(0, 56)


func _apply_action_buttons() -> void:
	# 背包按钮：透明背景 + 卷轴icon（古风储物意象）
	var bag_style := StyleBoxFlat.new()
	bag_style.bg_color = Color(0, 0, 0, 0)
	bag_style.set_corner_radius_all(4)
	_bag_button.add_theme_stylebox_override("normal", bag_style)
	_bag_button.add_theme_stylebox_override("hover", bag_style)
	_bag_button.add_theme_stylebox_override("pressed", bag_style)
	if _bag_icon != null and _bag_icon.has_method("setup"):
		_bag_icon.setup("scroll", GuStyle.INK_PRIMARY, ICON_PX)

	# 设置按钮：透明背景 + 齿轮icon
	var settings_style := StyleBoxFlat.new()
	settings_style.bg_color = Color(0, 0, 0, 0)
	settings_style.set_corner_radius_all(4)
	_settings_button.add_theme_stylebox_override("normal", settings_style)
	_settings_button.add_theme_stylebox_override("hover", settings_style)
	_settings_button.add_theme_stylebox_override("pressed", settings_style)
	if _settings_icon != null and _settings_icon.has_method("setup"):
		_settings_icon.setup("settings", GuStyle.INK_PRIMARY, ICON_PX)
