class_name RefineScreenView
extends MarginContainer
## 炼蛊 / 合成屏（Godot 官方 .tscn 节点树版，替代 ui/screens/refine_screen.guitkx）。
##
## 三通道 Tab（定向 / 组合 / 盲盒）是**屏内展示状态**，切换只改本地过滤、不发命令
## （2026-08-28 验收批已移除 set_channel 等幽灵命令）。
## 合成执行前走二次确认，完整预览产物 / 失败率 / 躁动 / 诅咒继承。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuPanelScene := preload("res://scenes/ui/widgets/gu_panel.tscn")
const PlayerPortrait := preload("res://assets/wenzhen/hall/first-life-character.png")

@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _refine_stage: PanelContainer = $Root/RefineStage
@onready var _title_label: Label = $Root/RefineStage/StageContent/HeaderRow/TitleLabel
@onready var _tab_row: HBoxContainer = $Root/RefineStage/StageContent/HeaderRow/TabRow
@onready var _slot_label: Label = $Root/RefineStage/StageContent/primary_decision_surface/MainColumn/SlotStatusLabel
@onready var _recipe_panel: PanelContainer = $Root/RefineStage/StageContent/primary_decision_surface/MainColumn/RecipePanel
@onready var _streak_label: Label = $Root/RefineStage/StageContent/primary_decision_surface/MainColumn/StreakNoteLabel
@onready var _dismantle_panel: PanelContainer = $Root/RefineStage/StageContent/primary_decision_surface/SideColumn/DismantlePanel
@onready var _leave_button: Button = $Root/RefineStage/StageContent/primary_decision_surface/SideColumn/LeaveButton
@onready var _confirm_dialog: PanelContainer = $Root/ConfirmDialog

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
## mount_snapshot 可能早于 _ready()，未就绪时只收数据，_ready() 里补刷新。
var _ready_done := false
## 当前通道（fixed / combo / blind）：纯展示状态，不改领域。
var _channel := "fixed"
## 待确认合成的配方 id；空串表示无。
var _confirm_recipe := ""


func _ready() -> void:
	_ready_done = true
	_apply_base_fonts()
	_apply_stage_style()
	_recipe_panel.setup("配方 / 预览", true, true)
	_dismantle_panel.setup("拆解化材", false, false)
	_leave_button.pressed.connect(func(): _fire("leave"))
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
	_refresh_tabs()
	_refresh_recipes()
	_refresh_dismantle()
	_refresh_confirm_dialog()


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
	_title_label.text = str(_snapshot.get("title", "炼蛊台"))
	var slot_ok := bool(_snapshot.get("slot_ok", false))
	_slot_label.text = ("空位校验：已就绪" if slot_ok
			else "空位校验：蛊囊已满，需先移除或拆解一只蛊")
	_slot_label.add_theme_color_override("font_color",
			GuStyle.JADE if slot_ok else GuStyle.CINNABAR)
	_streak_label.text = str(_snapshot.get("streak_note", ""))


## 通道 Tab 只改本地过滤，不发命令。
func _refresh_tabs() -> void:
	_clear_children(_tab_row)
	for ch in _snapshot.get("channels", []):
		if not (ch is Dictionary):
			continue
		var cid := str(ch.get("id", ""))
		var tab := Button.new()
		tab.text = str(ch.get("label", ""))
		MasterTheme.apply_button(tab, "danger" if cid == _channel else "action")
		tab.pressed.connect(func():
			_channel = cid
			_refresh_tabs()
			_refresh_recipes())
		_tab_row.add_child(tab)


func _refresh_recipes() -> void:
	var list := _ensure_scroll_list(_recipe_panel, "RecipeScroll")
	_clear_children(list)
	if _channel == "free_pair":
		_build_pair_panel(list)
		return
	var blind_note := str(_snapshot.get("blind_note", ""))
	var slot_ok := bool(_snapshot.get("slot_ok", false))
	var shown := 0
	for r in _snapshot.get("recipes", []):
		if not (r is Dictionary):
			continue
		# 通道过滤：配方自带 channel 标签，与当前 Tab 一致才显示。
		if str(r.get("channel", "fixed")) != _channel:
			continue
		shown += 1
		_build_recipe_card(list, r, slot_ok, blind_note)
	if shown == 0:
		list.add_child(_label_of("（无可用配方）", GuStyle.INK_SOFT, 14))


## D1b 古方知识模型：自由配对面板——选主/辅蛊，产物按知识状态揭示（？？？/实名）。
func _build_pair_panel(list: Node) -> void:
	var candidates: Array = _snapshot.get("pair_candidates", [])
	var main_id := str(_snapshot.get("pair_main", ""))
	var partner_id := str(_snapshot.get("pair_partner", ""))
	var preview: Dictionary = _snapshot.get("pair_preview", {})

	var note := _label_of("任何两只同转已炼化蛊都可入炉；产物由这一对决定，同对永远同果。" +
			"持古方者当场可见产物，未持者见「？？？」，首炼自动授予古方。", GuStyle.INK_SOFT, 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)

	list.add_child(_label_of("主蛊位（其流派与转数决定产物域）", GuStyle.INK_HALL, 14))
	for c in candidates:
		if not (c is Dictionary):
			continue
		var cid := str(c.get("id", ""))
		var btn := Button.new()
		btn.text = "%s · %d转 · %s%s" % [str(c.get("name", "")), int(c.get("rank", 0)), str(c.get("school", "")), "（主）" if cid == main_id else ""]
		MasterTheme.apply_button(btn, "danger" if cid == main_id else "action")
		btn.pressed.connect(func(): _fire("select_pair_main", cid))
		list.add_child(btn)
	list.add_child(_label_of("辅蛊位", GuStyle.INK_HALL, 14))
	for c in candidates:
		if not (c is Dictionary):
			continue
		var cid2 := str(c.get("id", ""))
		var btn2 := Button.new()
		btn2.text = "%s · %d转 · %s%s" % [str(c.get("name", "")), int(c.get("rank", 0)), str(c.get("school", "")), "（辅）" if cid2 == partner_id else ""]
		MasterTheme.apply_button(btn2, "danger" if cid2 == partner_id else "action")
		btn2.pressed.connect(func(): _fire("select_pair_partner", cid2))
		list.add_child(btn2)

	list.add_child(_label_of("预检", GuStyle.INK_HALL, 14))
	if not bool(preview.get("ok", false)) and str(preview.get("reason", "")) != "":
		list.add_child(_label_of(str(preview.get("reason", "")), GuStyle.CINNABAR, 13))
	else:
		var known := bool(preview.get("output_known", false))
		var output_line := ""
		if known:
			output_line = "产物：%s（古方在手，效果见图鉴）" % DisplayText.gu(str(preview.get("output_id", "")))
		else:
			output_line = "产物：？？？（首炼自动获得古方）"
		list.add_child(_label_of("产物域：" + str(preview.get("domain", "")), GuStyle.INK_HALL, 13))
		list.add_child(_label_of(output_line, GuStyle.ANOMALY_YELLOW if known else GuStyle.INK_SOFT, 14))
		list.add_child(_label_of("成功率 %d%% · 元石 %d 枚" % [int(preview.get("success_pct", 0)), int(preview.get("stone_cost", 0))], GuStyle.INK_HALL, 13))
		list.add_child(_label_of("失败：主蛊受伤（休整可愈），元石照耗。", GuStyle.CINNABAR, 12))
	var go := Button.new()
	go.text = "确认炼蛊"
	go.disabled = not (bool(preview.get("ok", false)) and bool(preview.get("executable", false)))
	MasterTheme.apply_button(go, "danger")
	go.pressed.connect(func(): _fire("refine_free_pair"))
	list.add_child(go)


func _build_recipe_card(list: Node, r: Dictionary, slot_ok: bool, blind_note: String) -> void:
	var rid := str(r.get("id", ""))
	var rcurse := str(r.get("curse", ""))
	var rbacklash := str(r.get("backlash", ""))
	var runlocked := bool(r.get("unlocked", true))
	var is_danger: bool = rcurse != "" or rbacklash != "无躁动"

	var panel := GuPanelScene.instantiate()
	list.add_child(panel)
	panel.setup(str(r.get("name", "")), true, false)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.content_host.add_child(box)
	var output_row := HBoxContainer.new()
	output_row.add_theme_constant_override("separation", 4)
	var output_icon := GuIconView.new()
	output_icon.setup("yuanstone", GuStyle.ANOMALY_YELLOW, GuIconView.SIZE_SMALL)
	output_row.add_child(output_icon)
	output_row.add_child(_label_of("产物：" + str(r.get("output", "")), GuStyle.ANOMALY_YELLOW, 15))
	box.add_child(output_row)
	box.add_child(_label_of(str(r.get("fail_chance", "")), GuStyle.ANOMALY_YELLOW, 13))
	box.add_child(_label_of(rbacklash, GuStyle.ANOMALY_YELLOW, 13))
	var rank_note := str(r.get("rank_note", ""))
	if rank_note != "":
		box.add_child(_label_of(rank_note, GuStyle.INK_SOFT, 12))
	if rcurse != "":
		box.add_child(_label_of(rcurse, GuStyle.CINNABAR, 13))
	if _channel == "blind" and blind_note != "":
		box.add_child(_label_of(blind_note, GuStyle.INK_SOFT, 12))

	var refine_btn := Button.new()
	refine_btn.text = "确认炼蛊"
	refine_btn.disabled = not slot_ok or not runlocked
	MasterTheme.apply_button(refine_btn, "danger" if is_danger else "action")
	refine_btn.pressed.connect(func():
		_confirm_recipe = rid
		_refresh_confirm_dialog())
	panel.content_host.add_child(refine_btn)


func _refresh_dismantle() -> void:
	var host := _ensure_box(_dismantle_panel, "DismantleBody")
	_clear_children(host)
	var slots: Array = _snapshot.get("dismantle_slots", [])
	for g in slots:
		var did := str(g.get("id", "")) if g is Dictionary else str(g)
		var dname := str(g.get("name", did)) if g is Dictionary else str(g)
		var btn := Button.new()
		btn.text = "拆解 " + dname
		MasterTheme.apply_button(btn, "action")
		btn.pressed.connect(func(): _fire("dismantle", did))
		host.add_child(btn)
	if slots.is_empty():
		host.add_child(_label_of("（蛊囊中没有可拆解的蛊虫）", GuStyle.INK_SOFT, 12))
	var hint := Label.new()
	hint.text = "被拆解蛊直接消失换材料（仅炼蛊台/事件节点）"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.add_child(hint)


func _refresh_confirm_dialog() -> void:
	if _confirm_recipe == "":
		_confirm_dialog.close()
		return
	var recipe := _recipe_by_id(_confirm_recipe)
	if recipe.is_empty():
		_confirm_recipe = ""
		_confirm_dialog.close()
		return
	var parts: Array[String] = []
	for part in [str(recipe.get("fail_chance", "")),
			str(recipe.get("backlash", "")), str(recipe.get("curse", ""))]:
		if part != "":
			parts.append(part)
	_confirm_dialog.open(
		"配方：" + str(recipe.get("name", "")),
		func():
			var rid := _confirm_recipe
			_confirm_recipe = ""
			_fire("refine", rid),
		func():
			_confirm_recipe = ""
			_confirm_dialog.close(),
		"合成执行", " · ".join(parts), "确认合成", "取消")


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

func _ensure_scroll_list(panel: PanelContainer, name_hint: String) -> Node:
	var host: Node = panel.content_host
	var scroll: Node = host.get_node_or_null(name_hint)
	if scroll != null:
		return scroll.get_node("List")
	var new_scroll := ScrollContainer.new()
	new_scroll.name = name_hint
	new_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	new_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(new_scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	new_scroll.add_child(list)
	return list


func _ensure_box(panel: PanelContainer, name_hint: String) -> Node:
	var host: Node = panel.content_host
	var existing: Node = host.get_node_or_null(name_hint)
	if existing != null:
		return existing
	var box := VBoxContainer.new()
	box.name = name_hint
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	host.add_child(box)
	return box


func _fire(key: String, arg = null) -> void:
	if not _commands.has(key):
		return
	if arg == null:
		_commands[key].call()
	else:
		_commands[key].call(arg)


func _recipe_by_id(recipe_id: String) -> Dictionary:
	for r in _snapshot.get("recipes", []):
		if r is Dictionary and str(r.get("id", "")) == recipe_id:
			return r
	return {}


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


func _apply_base_fonts() -> void:
	_title_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	_streak_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	MasterTheme.apply_button(_leave_button, "action")


## 炼蛊台暗色舞台：复用交易屏/休整屏验证的三层结构。
## 青茅山背景调暗半透明 + 角色立绘炼蛊姿态 + 纸墨UI浮于其上。
func _apply_stage_style() -> void:
	var stage_box := StyleBoxFlat.new()
	stage_box.bg_color = GuStyle.STAGE_BG
	stage_box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	_refine_stage.add_theme_stylebox_override("panel", stage_box)

	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/wenzhen/hall/qing-mao-mountain.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = GuStyle.STAGE_BACKDROP_DIM
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -1
	_refine_stage.add_child(backdrop)

	var portrait := TextureRect.new()
	portrait.texture = PlayerPortrait
	portrait.custom_minimum_size = Vector2(120, 160)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = GuStyle.PORTRAIT_DIM
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.z_index = -1
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.offset_left = -140
	portrait.offset_top = 20
	portrait.offset_right = -20
	portrait.offset_bottom = -20
	_refine_stage.add_child(portrait)
