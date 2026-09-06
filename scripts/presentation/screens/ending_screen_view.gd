class_name EndingScreenView
extends MarginContainer
## 统一结算模块（Godot 官方 .tscn 节点树版，替代 ui/screens/ending_screen.guitkx）。
##
## 由 ending_type 驱动；复盘顺序固定（结局类型 · 路线 · 重大决策 · 关键得失 ·
## 资源结余 · 本局记录 · 解锁手记 · 后续），缺失的整节隐藏。
## 无读档按钮（§16.6）：只有「返回大厅」与「查看图鉴」。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuChipScene := preload("res://scenes/ui/widgets/gu_resource_chip.tscn")

const TYPE_NAMES := {
	"success": "成功", "death": "死亡", "gu_fall": "蛊化坠落",
	"risky": "险成", "retreat": "中途遁走", "true_ending": "真结局",
}

@onready var _top_bar: PanelContainer = $primary_decision_surface/TopBar
@onready var _title_label: Label = $primary_decision_surface/TitleBlock/TitleBox/TitleLabel
@onready var _type_label: Label = $primary_decision_surface/TitleBlock/TitleBox/TypeLabel
@onready var _type_panel: PanelContainer = $primary_decision_surface/TypePanel
@onready var _cause_panel: PanelContainer = $primary_decision_surface/DeathCausePanel
@onready var _route_panel: PanelContainer = $primary_decision_surface/RoutePanel
@onready var _decision_panel: PanelContainer = $primary_decision_surface/DecisionPanel
@onready var _gains_panel: PanelContainer = $primary_decision_surface/GainsPanel
@onready var _balance_panel: PanelContainer = $primary_decision_surface/BalancePanel
@onready var _record_panel: PanelContainer = $primary_decision_surface/RecordPanel
@onready var _unlock_panel: PanelContainer = $primary_decision_surface/UnlockPanel
@onready var _aftermath_panel: PanelContainer = $primary_decision_surface/AftermathPanel
@onready var _to_hall_button: Button = $primary_decision_surface/ActionBlock/ActionRow/ToHallButton
@onready var _to_codex_button: Button = $primary_decision_surface/ActionBlock/ActionRow/ToCodexButton

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
## mount_snapshot 可能早于 _ready()，未就绪时只收数据，_ready() 里补刷新。
var _ready_done := false


func _ready() -> void:
	_ready_done = true
	_apply_ending_atmosphere()
	MasterTheme.apply_button(_to_hall_button, "primary")
	MasterTheme.apply_button(_to_codex_button, "archive")
	_to_hall_button.pressed.connect(func(): _fire("to_hall"))
	_to_codex_button.pressed.connect(func(): _fire("to_codex"))
	_title_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	if not _snapshot.is_empty():
		_refresh()


## 结算屏氛围层：浅色命簿纸面 + 淡青茅山背景 + 暗角。
## 结局是命簿最终章，用浅色纸面风格（与地图屏一致），而非洞窟暗色舞台。
## 背景层加到 EndingScreen 本身（z_index=-1），不影响 primary_decision_surface 的 VBox 布局。
func _apply_ending_atmosphere() -> void:
	var paper := ColorRect.new()
	paper.color = GuStyle.PAPER_BG
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.z_index = -1
	paper.anchor_right = 1.0
	paper.anchor_bottom = 1.0
	add_child(paper)

	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/wenzhen/hall/qing-mao-mountain.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = GuStyle.MAP_BACKDROP_DIM
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -1
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	add_child(backdrop)

	var vignette_grad := Gradient.new()
	vignette_grad.set_color(0, Color(0, 0, 0, 0))
	vignette_grad.set_color(1, Color(0, 0, 0, 0.12))
	var vignette_tex := GradientTexture2D.new()
	vignette_tex.gradient = vignette_grad
	vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	vignette_tex.width = 512
	vignette_tex.height = 512
	var vignette := TextureRect.new()
	vignette.texture = vignette_tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = 10
	vignette.anchor_right = 1.0
	vignette.anchor_bottom = 1.0
	add_child(vignette)


## run_controller 的挂载入口（与各 master 场景同签名）。
func mount_snapshot(snapshot: Dictionary, commands: Dictionary) -> void:
	_snapshot = snapshot
	_commands = commands
	if _ready_done:
		_refresh()


func _refresh() -> void:
	_refresh_top_bar()
	_refresh_title()
	_refresh_type()
	_refresh_death_cause()
	_refresh_route()
	_refresh_decisions()
	_refresh_gains()
	_refresh_balance()
	_refresh_record()
	_refresh_unlocks()
	_refresh_aftermath()


func _refresh_top_bar() -> void:
	if not _top_bar.has_method("set_data"):
		return
	_top_bar.set_data(
		_snapshot.get("resources", {}),
		_snapshot.get("contracts", []),
		_snapshot.get("anomalies", []),
		_snapshot.get("death_lines", {}),
		int(_snapshot.get("layer", -1)))


func _refresh_title() -> void:
	var ending_type := str(_snapshot.get("ending_type", ""))
	var type_label := str(TYPE_NAMES.get(ending_type, "未知结局"))
	_title_label.text = str(_snapshot.get("title", "—"))
	_type_label.text = "结局类型 · " + type_label
	_type_label.add_theme_color_override("font_color", _type_color(ending_type))


func _refresh_type() -> void:
	var ending_type := str(_snapshot.get("ending_type", ""))
	var type_label := str(TYPE_NAMES.get(ending_type, "未知结局"))
	_type_panel.setup("一 · 结局类型", false, false)
	var host := _content(_type_panel)
	_clear_children(host)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 8)
	host.add_child(badge_row)
	badge_row.add_child(_badge(type_label, _type_color(ending_type), GuStyle.PAPER_DEEP))
	var death_cause_short := str(_snapshot.get("death_cause_short", ""))
	if ending_type == "death" and death_cause_short != "":
		badge_row.add_child(_badge("死因 · " + death_cause_short,
				GuStyle.CINNABAR, GuStyle.TINT_BLOOD))
	var achievement := str(_snapshot.get("achievement", ""))
	if achievement != "":
		host.add_child(_label_of("达成：" + achievement, GuStyle.INK_PRIMARY, 14))
	var max_rank := int(_snapshot.get("max_rank", 0))
	if max_rank > 0:
		host.add_child(_label_of("最高转数：%d 转" % max_rank, GuStyle.INK_SOFT, 13))


func _refresh_death_cause() -> void:
	var is_death: bool = str(_snapshot.get("ending_type", "")) == "death"
	_cause_panel.visible = is_death
	if not is_death:
		return
	_cause_panel.setup("精准死因", false, false)
	var host := _content(_cause_panel)
	_clear_children(host)
	host.add_child(_label_of(str(_snapshot.get("death_cause", "")), GuStyle.CINNABAR, 16))


func _refresh_route() -> void:
	var route_summary: Array = _snapshot.get("route_summary", [])
	_route_panel.visible = not route_summary.is_empty()
	if route_summary.is_empty():
		return
	_route_panel.setup("二 · 路线", false, false)
	var host := _content(_route_panel)
	_clear_children(host)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	host.add_child(row)
	for layer_info in route_summary:
		if not (layer_info is Dictionary):
			continue
		var layer_text := "第%d层 %s" % [
				int(layer_info.get("layer", 0)), "·".join(layer_info.get("types", []))]
		var color: Color = GuStyle.RARITY_EPIC if bool(layer_info.get("boss", false)) else GuStyle.INK_SOFT
		row.add_child(_label_of(layer_text, color, 14))


func _refresh_decisions() -> void:
	_decision_panel.setup("三 · 重大决策", false, false)
	var host := _content(_decision_panel)
	_clear_children(host)
	var key_decisions: Array = _snapshot.get("key_decisions", [])
	for d in key_decisions:
		host.add_child(_label_of("· " + str(d), GuStyle.INK_PRIMARY, 15))
	if key_decisions.is_empty():
		host.add_child(_label_of("（无重大抉择记录）", GuStyle.INK_SOFT, 14))


func _refresh_gains() -> void:
	_gains_panel.setup("四 · 关键得失", false, false)
	var host := _content(_gains_panel)
	_clear_children(host)
	var gains_row := HBoxContainer.new()
	gains_row.add_theme_constant_override("separation", 4)
	var gains_icon := GuIconView.new()
	gains_icon.setup("gi_coin", GuStyle.INK_PRIMARY, GuIconView.SIZE_SMALL)
	gains_row.add_child(gains_icon)
	gains_row.add_child(_label_of(str(_snapshot.get("gains_losses", "—")), GuStyle.INK_PRIMARY, 15))
	host.add_child(gains_row)


func _refresh_balance() -> void:
	_balance_panel.setup("五 · 资源结余", false, false)
	var host := _content(_balance_panel)
	_clear_children(host)
	var balance: Dictionary = _snapshot.get("resource_balance", {})
	if balance.is_empty():
		host.add_child(_label_of("（资源已随本局清空）", GuStyle.INK_SOFT, 14))
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		host.add_child(row)
		for k in balance.keys():
			var chip := GuChipScene.instantiate()
			row.add_child(chip)
			chip.setup(str(k), int(balance[k]))
	host.add_child(_label_of(
			"所有资源离局清零 · 解锁与手记留存大厅（§16.16 / R12.2）", GuStyle.INK_SOFT, 12))


func _refresh_record() -> void:
	var record: Dictionary = _snapshot.get("run_record", {})
	var rows: Array[Dictionary] = []
	var attempts := int(record.get("synthesis_attempts", 0))
	if attempts > 0:
		rows.append({"text": "战斗合成：%d 次 · 成 %d / 败 %d" % [
				attempts, int(record.get("synthesis_ok", 0)), int(record.get("synthesis_fail", 0))],
				"color": GuStyle.INK_PRIMARY})
	var shifts := int(record.get("boss_phase_shifts", 0))
	if shifts > 0:
		rows.append({"text": "Boss 阶段切换：%d 次" % shifts, "color": GuStyle.INK_PRIMARY})
	var dda := int(record.get("dda_triggers", 0))
	if dda > 0:
		rows.append({"text": "DDA 触发：%d 次" % dda, "color": GuStyle.ANOMALY_YELLOW})
	_record_panel.visible = not rows.is_empty()
	if rows.is_empty():
		return
	_record_panel.setup("六 · 本局记录", false, false)
	var host := _content(_record_panel)
	_clear_children(host)
	for r in rows:
		host.add_child(_label_of(str(r["text"]), r["color"], 15))


func _refresh_unlocks() -> void:
	_unlock_panel.setup("七 · 解锁手记", false, false)
	var host := _content(_unlock_panel)
	_clear_children(host)
	var unlocks: Array = _snapshot.get("unlocks", [])
	for u in unlocks:
		host.add_child(_label_of("★新 " + str(u), GuStyle.ANOMALY_YELLOW, 15))
	if unlocks.is_empty():
		host.add_child(_label_of("（本次无新解锁，仅作复盘）", GuStyle.INK_SOFT, 14))


func _refresh_aftermath() -> void:
	_aftermath_panel.setup("八 · 后续", false, false)
	var host := _content(_aftermath_panel)
	_clear_children(host)
	host.add_child(_label_of(str(_snapshot.get("aftermath", "—")), GuStyle.INK_SOFT, 15))


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

func _content(panel: PanelContainer) -> Node:
	return panel.content_host


func _badge(text: String, font_color: Color, bg: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", font_color)
	panel.add_child(label)
	return panel


func _fire(key: String) -> void:
	if _commands.has(key):
		_commands[key].call()


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _label_of(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _type_color(ending_type: String) -> Color:
	match ending_type:
		"success", "true_ending": return GuStyle.JADE
		"death", "gu_fall": return GuStyle.CINNABAR
		"risky": return GuStyle.ANOMALY_YELLOW
		"retreat": return GuStyle.INK_SOFT
		_: return GuStyle.INK_PRIMARY
