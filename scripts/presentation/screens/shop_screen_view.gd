class_name ShopScreenView
extends MarginContainer
## 黑市 / 商店屏（Godot 官方 .tscn 节点树版，替代 ui/screens/shop_screen.guitkx）。
##
## 静态骨架（顶栏、标题行、两列决策区、服务面板、离开按钮、浮层）预置在节点树里；
## 数量不定的内容（货架卡、服务行、目标候选项）走代码生成。
## 本地交互状态只有两个：待确认的危险交易 offer id、正在选目标的服务 id。
## 只读快照，所有写操作经 commands 出口；本类绝不修改领域状态。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuCardScene := preload("res://scenes/ui/widgets/gu_card.tscn")
const PlayerPortrait := preload("res://assets/wenzhen/hall/first-life-character.png")
## NPC商人立绘：异常自然志图鉴风格，运行时加载绕过资源导入系统。
var NpcMerchantPortrait: Texture2D = null


func _load_npc_texture(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)

@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _feedback_label: Label = $Root/FeedbackLabel
@onready var _shop_stage: PanelContainer = $Root/ShopStage
@onready var _title_label: Label = $Root/ShopStage/StageContent/TitleRow/TitleLabel
@onready var _inflation_label: Label = $Root/ShopStage/StageContent/TitleRow/InflationLabel
@onready var _npc_label: Label = $Root/ShopStage/StageContent/TitleRow/NpcLabel
@onready var _stance_label: Label = $Root/ShopStage/StageContent/TitleRow/StanceLabel
@onready var _offer_list: VBoxContainer = $Root/ShopStage/StageContent/PrimarySurface/OfferColumn/OfferScroll/OfferList
@onready var _emergency_label: Label = $Root/ShopStage/StageContent/PrimarySurface/OfferColumn/EmergencyLabel
@onready var _pool_fallback_label: Label = $Root/ShopStage/StageContent/PrimarySurface/OfferColumn/PoolFallbackLabel
@onready var _service_list: VBoxContainer = $Root/ShopStage/StageContent/PrimarySurface/ServiceColumn/ServicePanel/ServicePanelMargin/ServicePanelBox/ServiceScroll/ServiceList
@onready var _leave_button: Button = $Root/ShopStage/StageContent/PrimarySurface/ServiceColumn/LeaveButton
@onready var _target_panel: PanelContainer = $Root/TargetPanel
@onready var _target_title: Label = $Root/TargetPanel/TargetMargin/TargetBox/TargetTitle
@onready var _target_list: VBoxContainer = $Root/TargetPanel/TargetMargin/TargetBox/TargetScroll/TargetList
@onready var _confirm_dialog: PanelContainer = $Root/ConfirmDialog

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
## mount_snapshot 可能早于 _ready()（脚本化挂载、-s 模式等），
## 未就绪时只收数据，等 _ready() 补一次刷新，避免踩空 @onready 绑定。
var _ready_done := false
## 待确认的危险交易（寿元代付 / 应急支付）货架 id；空串表示无。
var _confirm_offer := ""
## 正在等待指定目标的服务 id；空串表示无。
var _active_service := ""


func _ready() -> void:
	_ready_done = true
	_apply_base_fonts()
	_apply_stage_style()
	_leave_button.pressed.connect(func(): _fire("leave"))
	if not _snapshot.is_empty():
		_refresh()


## 加载NPC商人立绘：运行时加载绕过资源导入系统，失败时回退到玩家立绘。
func _load_npc_merchant_portrait() -> Texture2D:
	var path := "res://assets/wenzhen/npc/npc_merchant.png"
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


## run_controller 的挂载入口（与各 master 场景同签名）。
func mount_snapshot(snapshot: Dictionary, commands: Dictionary) -> void:
	_snapshot = snapshot
	_commands = commands
	if _ready_done:
		_refresh()


# ---------------------------------------------------------------------------
# 刷新
# ---------------------------------------------------------------------------

func _refresh() -> void:
	_refresh_top_bar()
	_refresh_header()
	_refresh_offers()
	_refresh_services()
	_refresh_target_panel()
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
	var feedback := str(_snapshot.get("feedback", ""))
	_feedback_label.text = feedback
	_feedback_label.visible = feedback != ""

	_title_label.text = str(_snapshot.get("title", "黑市"))
	_inflation_label.text = str(_snapshot.get("inflation_note", ""))
	_npc_label.text = "NPC：" + str(_snapshot.get("npc_name", ""))

	var stance := str(_snapshot.get("npc_stance", "中立"))
	_stance_label.text = "立场·" + stance
	_stance_label.add_theme_color_override("font_color", _stance_color(stance))

	_emergency_label.text = str(_snapshot.get("emergency_note", ""))
	var fallback := str(_snapshot.get("pool_fallback_note", ""))
	_pool_fallback_label.text = fallback
	_pool_fallback_label.visible = fallback != ""


func _refresh_offers() -> void:
	_clear_children(_offer_list)
	var offers: Array = _snapshot.get("offers", [])
	for o in offers:
		if not (o is Dictionary):
			continue
		_build_offer_card(o)
	if offers.is_empty():
		_offer_list.add_child(_note_label("（货架空空）"))


func _refresh_services() -> void:
	_clear_children(_service_list)
	var services: Array = _snapshot.get("services", [])
	for s in services:
		if not (s is Dictionary):
			continue
		_service_list.add_child(_build_service_row(s))
	if services.is_empty():
		_service_list.add_child(_note_label("（暂无服务）"))


# ---------------------------------------------------------------------------
# 动态行构建
# ---------------------------------------------------------------------------

func _build_offer_card(o: Dictionary) -> void:
	var oid := str(o.get("id", ""))
	var oname := str(o.get("name", ""))
	var cursed := bool(o.get("curse_warning", false))
	var emergency := bool(o.get("will_emergency_pay", false))

	var card := GuCardScene.instantiate()
	# 先入树再配内容：GuCardView.content_host 是 @onready，只有 add_child 触发
	# _ready() 之后才有值，instantiate() 后立刻访问恒为 null。
	_offer_list.add_child(card)
	card.setup(oname, str(o.get("quality", "")), cursed, cursed, false, "")

	var desc := Label.new()
	desc.text = str(o.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	card.content_host.add_child(desc)

	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 4)
	var price_icon := GuIconView.new()
	price_icon.setup("gi_coin", GuStyle.INK_PRIMARY, GuIconView.SIZE_SMALL)
	price_row.add_child(price_icon)
	var price := Label.new()
	price.text = "价格：" + str(o.get("price", ""))
	price.add_theme_font_size_override("font_size", 14)
	price.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	price_row.add_child(price)
	card.content_host.add_child(price_row)

	var buy := Button.new()
	buy.text = "购买此蛊"
	MasterTheme.apply_button(buy, "danger" if cursed else "action")
	# 寿元代付与应急支付都不可逆 → 走一次确认；其余直接下单。
	buy.pressed.connect(func():
		if cursed or emergency:
			_confirm_offer = oid
			_refresh_confirm_dialog()
		else:
			_fire("buy", oid))
	card.content_host.add_child(buy)


func _build_service_row(s: Dictionary) -> Node:
	var sid := str(s.get("id", ""))
	var candidates: Array = s.get("candidates", [])
	var executable := bool(s.get("executable", true))
	var remaining := int(s.get("remaining", 0))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_panel_style(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 2)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)

	var name_label := Label.new()
	name_label.text = str(s.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	text_col.add_child(name_label)

	var remain_text := "无次数上限" if remaining < 0 else "本局剩 %d 次" % remaining
	var meta_label := Label.new()
	meta_label.text = "%s · %s" % [str(s.get("price", "")), remain_text]
	meta_label.add_theme_font_size_override("font_size", 13)
	meta_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	text_col.add_child(meta_label)

	var note := str(s.get("note", ""))
	if note != "":
		var note_label := Label.new()
		note_label.text = note
		note_label.add_theme_font_size_override("font_size", 12)
		note_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
		text_col.add_child(note_label)

	var block := str(s.get("block_reason", ""))
	if block != "":
		var block_label := Label.new()
		block_label.text = "不可用 · " + block
		block_label.add_theme_font_size_override("font_size", 12)
		block_label.add_theme_color_override("font_color", GuStyle.CINNABAR)
		text_col.add_child(block_label)

	var use := Button.new()
	use.text = "使用"
	use.disabled = not executable
	MasterTheme.apply_button(use, "action")
	# 移除类服务带 candidates → 先选目标；无候选直接下发（如洗恶名）。
	use.pressed.connect(func():
		if candidates.is_empty():
			_fire2("service", sid, "")
		else:
			_active_service = sid
			_refresh_target_panel())
	row.add_child(use)
	return panel


# ---------------------------------------------------------------------------
# 浮层：服务目标选择 / 危险交易确认
# ---------------------------------------------------------------------------

func _refresh_target_panel() -> void:
	_clear_children(_target_list)
	if _active_service == "":
		_target_panel.visible = false
		return
	var service := _service_by_id(_active_service)
	if service.is_empty() or not bool(service.get("executable", true)):
		_target_panel.visible = false
		return
	_target_panel.visible = true
	_target_title.text = str(service.get("target_label", "选择目标"))
	for c in service.get("candidates", []):
		if not (c is Dictionary):
			continue
		var cid := str(c.get("id", ""))
		var cname := str(c.get("name", ""))
		var cprice := str(c.get("price", ""))
		var label := cname if cprice == "" else "%s（%s）" % [cname, cprice]
		var pick := Button.new()
		pick.text = "选定 " + label
		MasterTheme.apply_button(pick, "action")
		pick.pressed.connect(func():
			_active_service = ""
			_fire2("service", str(service.get("id", "")), cid))
		_target_list.add_child(pick)
	var cancel := Button.new()
	cancel.text = "取消"
	MasterTheme.apply_button(cancel, "cancel")
	cancel.pressed.connect(func():
		_active_service = ""
		_refresh_target_panel())
	_target_list.add_child(cancel)


func _refresh_confirm_dialog() -> void:
	if _confirm_offer == "":
		_confirm_dialog.close()
		return
	var offer := _offer_by_id(_confirm_offer)
	if offer.is_empty():
		_confirm_offer = ""
		_confirm_dialog.close()
		return
	var cursed := bool(offer.get("curse_warning", false))
	var title := "⚠ 危险交易 · 寿元代付"
	var note := "价格：" + str(offer.get("price", "")) + " · 以寿元支付，执行前请确认寿元余量"
	if not cursed and bool(offer.get("will_emergency_pay", false)):
		title = "⚠ 应急支付"
		note = str(offer.get("price", "")) + " · 元石不足，将以气血 / 寿元 / 反噬 / 销毁组件应急支付（R6.7）"
	_confirm_dialog.open(
		str(offer.get("name", "")) + "：" + str(offer.get("desc", "")),
		func():
			var oid := _confirm_offer
			_confirm_offer = ""
			_fire("buy", oid),
		func():
			_confirm_offer = ""
			_confirm_dialog.close(),
		title, note, "确认支付", "取消")


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

func _fire(key: String, arg = null) -> void:
	if not _commands.has(key):
		return
	if arg == null:
		_commands[key].call()
	else:
		_commands[key].call(arg)


func _fire2(key: String, arg1, arg2) -> void:
	if _commands.has(key):
		_commands[key].call(arg1, arg2)


func _offer_by_id(offer_id: String) -> Dictionary:
	for o in _snapshot.get("offers", []):
		if o is Dictionary and str(o.get("id", "")) == offer_id:
			return o
	return {}


func _service_by_id(service_id: String) -> Dictionary:
	for s in _snapshot.get("services", []):
		if s is Dictionary and str(s.get("id", "")) == service_id:
			return s
	return {}


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _note_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	return label


func _stance_color(stance: String) -> Color:
	match stance:
		"敌视": return GuStyle.ANOMALY_YELLOW
		"极度仇恨": return GuStyle.CINNABAR
		_: return GuStyle.JADE


func _apply_panel_style(panel: PanelContainer) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_BG
	box.border_color = GuStyle.HAIRLINE_COLOR
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", box)


func _apply_base_fonts() -> void:
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_inflation_label.add_theme_font_size_override("font_size", 13)
	_inflation_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_npc_label.add_theme_font_size_override("font_size", 15)
	_npc_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_stance_label.add_theme_font_size_override("font_size", 15)
	_feedback_label.add_theme_font_size_override("font_size", 14)
	_feedback_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_emergency_label.add_theme_font_size_override("font_size", 13)
	_emergency_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	_pool_fallback_label.add_theme_font_size_override("font_size", 13)
	_pool_fallback_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_target_title.add_theme_font_size_override("font_size", 18)
	_target_title.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_apply_panel_style(_target_panel)
	MasterTheme.apply_button(_leave_button, "action")


## 黑市暗色舞台：复用休整屏验证的三层结构（叙事层+规则层+概念层）。
## 青茅山背景调暗半透明 + 角色立绘（黑市交易姿态）+ 纸墨UI浮于其上。
func _apply_stage_style() -> void:
	# 暗色舞台底色
	var stage_box := StyleBoxFlat.new()
	stage_box.bg_color = GuStyle.STAGE_BG
	stage_box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	_shop_stage.add_theme_stylebox_override("panel", stage_box)

	# 青茅山背景层（复用战斗屏素材，调暗半透明）
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/wenzhen/hall/qing-mao-mountain.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = GuStyle.STAGE_BACKDROP_DIM
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -1
	_shop_stage.add_child(backdrop)

	# 雾气层：半透明冷灰水平渐变，模拟南疆湿冷山雾。
	var fog_grad := Gradient.new()
	fog_grad.set_color(0, GuStyle.FOG_COLOR_EDGE)
	fog_grad.set_color(0.5, GuStyle.FOG_COLOR_MID)
	fog_grad.set_color(1, GuStyle.FOG_COLOR_EDGE)
	var fog_tex := GradientTexture2D.new()
	fog_tex.gradient = fog_grad
	fog_tex.fill = GradientTexture2D.FILL_LINEAR
	fog_tex.width = 512
	fog_tex.height = 256
	var fog := TextureRect.new()
	fog.texture = fog_tex
	fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog.stretch_mode = TextureRect.STRETCH_SCALE
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.z_index = -1
	_shop_stage.add_child(fog)
	var fog_tween := create_tween()
	fog_tween.set_loops()
	fog_tween.tween_property(fog, "modulate:a", 0.15, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fog_tween.tween_property(fog, "scale", Vector2(1.05, 1.02), 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fog_tween.tween_property(fog, "modulate:a", 0.08, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fog_tween.tween_property(fog, "scale", Vector2(1.0, 1.0), 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 萤火层：4-6个暖黄色光点，随机闪烁+缓慢漂移。
	for i in range(5):
		var firefly := ColorRect.new()
		firefly.color = GuStyle.FIREFLY_COLOR
		firefly.size = Vector2(3, 3)
		firefly.mouse_filter = Control.MOUSE_FILTER_IGNORE
		firefly.z_index = -1
		var sx := randf_range(50.0, 500.0)
		var sy := randf_range(50.0, 250.0)
		firefly.position = Vector2(sx, sy)
		_shop_stage.add_child(firefly)
		var ft := create_tween()
		ft.set_loops()
		var bd := randf_range(2.5, 4.5)
		var dx := randf_range(-25.0, 25.0)
		var dy := randf_range(-15.0, 15.0)
		ft.tween_property(firefly, "color:a", 0.7, bd).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ft.tween_property(firefly, "position", Vector2(sx + dx, sy + dy), bd).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ft.tween_property(firefly, "color:a", 0.1, bd).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ft.tween_property(firefly, "position", Vector2(sx, sy), bd).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 角色立绘：黑市交易姿态，放在舞台右侧调暗半透明
	# NPC商人立绘：优先加载npc_merchant.png，失败时回退到玩家立绘
	var npc_tex := _load_npc_merchant_portrait()
	var portrait_tex: Texture2D = npc_tex if npc_tex != null else PlayerPortrait
	var portrait := TextureRect.new()
	portrait.texture = portrait_tex
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
	_shop_stage.add_child(portrait)
