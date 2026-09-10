class_name GuTallFanHandView
extends Control

## 竖向长卡片的底部横向扇形手牌（Tall-Card Bottom Fan Hand）——2026-09-10。
##
## 适用形态：卡面改成长条（高 > 宽，默认 110×154），手牌区仍在屏幕底部横向扇形展开。
## 卡变窄后 `step` 会自动变小，同屏容量按比例上升（110 宽 + 45% 重叠 → 1280 可放 20+ 张）。
##
## 责任边界：
##   · 只负责「摆放 + 悬停/拖拽的表现」；出牌与否由宿主命令面裁决（只发信号）。
##   · **不用 Container 装卡**：扇形要给每张卡自由改 position/rotation/scale，
##     HBox/VBox 下一帧会把位置改回去。卡一律是普通 Control 子节点。
##   · 命中检测走宿主注入的 target_provider（UI 用 Control 矩形判定即可；Area2D 属于
##     2D 物理世界，和 UI 混用还要做坐标换算，没必要）。
##
## 横向扇形数学（详见 _update_hand_layout 注释）：
##   t        = (index − center) / max(center, 1)        # −1 最左 → +1 最右
##   t_eased  = sign(t) × |t|^T_EASE                     # 非线性缓动：两端倾角增长更缓
##   step     = clamp(可用宽 / (n−1), 卡宽 × (1−最大重叠率), 卡宽 × 1.02)
##   x        = base_x + step × index + 让位量
##   rotation = MAX_ANGLE × t_eased                      # 竖长卡容易"倾倒难看"，故角度小
##   arc_y    = (1 − t_eased²) × ARC_LIFT                # 中间最高，两端落回基线
##   scale    = 1 − PERSPECTIVE_DROP × |t|               # 中间 1.0，边缘 0.9，做纵深
##   z_index  = index                                    # 右侧压左侧

signal card_chosen(card_id: String, target_id: String)
## 悬停变化：""=离开全部卡。
signal hover_changed(card_id: String)
## 取消请求（右键 / Esc，**且当前没有进行中的手势**）。
## 组件不知道自己取消的是什么——「已武装一张指向卡但还没选目标」是**宿主**的状态，
## 所以这里只转发意图，由宿主决定退回哪一步。拖拽/瞄准中的取消不走这里：
## 那个由组件自己的状态机吞掉，否则一次右键会取消两次（并拆掉刚建的影卡）。
signal cancel_requested
## 拖拽命中检测结果：""=当前没有指向任何合法目标。
##
## 宿主侧接线契约（2026-09-10 用户裁定：组件只发信号，高亮由宿主施加）：
##   · 组件**不做**任何敌人高亮——它不知道敌人卡是谁，也不该知道。
##   · 宿主把本信号接到自家已有的放置高亮开关上即可。战斗屏现成入口是
##     `BattleScreenView._set_drop_hot(enemy_id)`，它内部走
##     `GuEnemyActorView.set_drop_highlight(on)`（玉绿描边 + 立绘提亮，与选中态同一套视觉语言）。
##   最小接线：
##     hand.aim_target_changed.connect(_set_drop_hot)
##   · 信号语义（由 `_set_aim_target` 单点保证）：**只在目标真的变化时发**，
##     同帧重复命中同一目标不会重复触发；收线/取消/换目标一律先发一次 ""，
##     宿主因此不需要自己维护"上一目标"。
signal aim_target_changed(target_id: String)

const DRAG_START_THRESHOLD_PX := 6.0
const DRAG_CAST_DISTANCE_PX := 64.0
## 影卡抓取点（相对卡尺寸的归一化坐标）：光标落在卡面下方 72% 处，卡体浮在指上。
const DRAG_PROXY_GRAB := Vector2(0.5, 0.72)
## 瞄准起点兜底偏移：拿不到卡体矩形时退到鼠标上方这么多，**绝不返回鼠标位**——
## 起点==终点会让贝塞尔退化成零长度，`draw_polyline` 什么都画不出来（线"消失"）。
const AIM_ORIGIN_FALLBACK_Y := 120.0
const DRAG_PROXY_SCALE := 1.4
const TWEEN_TIME := 0.16
const REBOUND_TIME := 0.22
## 卡面字号与效果行截断阈值。竖长卡宽 110：
##   · 字号 11 时每行约容 10 个汉字；
##   · 卡高 154 富余很多（四行只用掉约 60px），所以效果行**允许折成两行**再截断，
##     不然「对单体造成 6 点伤害」会被切成「对单体造成 6…」这种半截话。
## 超出仍会被 `clip_text` **静默切掉**（不报错），所以阈值必须显式给。
const FACE_FONT_SIZE := 11
const FACE_EFFECT_MAX_CHARS := 18

# —— 扇形参数（**竖长卡的调参重点**）——
## 单侧最大倾角：竖长卡重心高，角度一大边缘卡就像"倒下的多米诺"。
## 横向卡可以给 8~10°，竖长卡建议 5~7°。
const MAX_ANGLE_DEG := 6.0
## t 的非线性缓动指数：>1 时两端倾角增长更慢（0.5/1.0 处的卡更"立"），
## 既不牺牲扇形辨识度，又不让最外侧卡歪得难看。
const T_EASE := 1.35
## 弧高：中间卡比两端低这么多（y 向下为正，所以"低"= 更靠屏幕下沿）。
##
## ⚠️ 这个值决定手牌区**向上溢出多少**，是换竖长卡后唯一能撑爆布局的量：
## 手牌盒只预留 `卡高`（见 _sync_min_size），弧高部分靠卡自己向上溢出，
## 而溢出发生在**最左/最右**两张卡上——那是水平方向唯一没有控件占用的位置
## （`ModeHost` 居中 448..832、`OpsDock` 靠右 1090+）。调大它会让端卡顶到
## 战场区最靠下的内容，实测口径见 tools/verify_card_shape_budget.gd。
const ARC_LIFT := 22.0
## 横向自适应压缩的下限比例（= 1 − 最大重叠率）。卡越窄这个值越关键：
## 0.45 → 最多重叠 55%，再小卡片就只剩一条缝，认不出是哪张。
const MIN_STEP_RATIO := 0.45
## 边缘卡透视缩放幅度：1.0 → 0.9。
const PERSPECTIVE_DROP := 0.10
## 两端卡旋转后，顶角会向外偏出布局矩形；留出这段内缩量，免得最外侧卡被屏幕边缘切掉。
## 近似值 = 卡高 × sin(最大倾角) ÷ 2（探针实测：6°/154 高时偏出约 8~9px）。
const EDGE_OVERHANG_INSET := 10.0
## 悬停：上浮 / 放大 / 抬到最高层的 z。
## ⚠️ HOVER_LIFT 受**上方控件**硬约束：手牌区顶边 508 时，`ModeHost`（模式按钮区）底边在 507。
## 实测（tools/verify_card_shape_budget.gd）：卡顶边 550，抬升量 = HOVER_LIFT + 卡高×0.15。
## 取 42 时卡顶到 485 → **撞进 ModeHost 22px**；取 18 时到 509 → 让开。
## 这个数不能单看组件自身调大——它是"组件参数 + 卡高"两笔叠加出来的。
const HOVER_LIFT := 18.0
const HOVER_SCALE := 1.15
const HOVER_Z := 100
## 悬停时左右邻居让位：按距离衰减到第 3 张。
const HOVER_FANOUT := 24.0
const FANOUT_REACH := 3.0
## 拖拽态：脱离布局、姿态归正、放大 1.2、抬到最高。
const DRAG_SCALE := 1.2
const DRAG_Z := 1000
## 未悬停卡压暗程度。用 darkened() 而不是写 Color 小数：新体系禁止硬编码色值
## （UI_RULES §2，test_ui_rules_guard 会扫 scripts/presentation/）。
const DIM_DARKEN := 0.22

var card_size := Vector2(110, 154)
var on_chosen: Callable = Callable()
var target_provider: Callable = Callable()

var _cards: Array[Control] = []
## 原始 card_id → 卡体（见 card_rect 的节点名清洗说明）。
var _cards_by_id: Dictionary = {}
var _data: Array = []
var _hovered_index := -1
## 槽位让位量（沿 X，正=向右），_refresh_hover_shift 写、布局函数读。
var _hover_shift: PackedFloat32Array = PackedFloat32Array()
var _tweens: Dictionary = {}

# —— 拖拽 / 瞄准态 ——
var _candidate_index := -1
var _press_pos := Vector2.ZERO
var _drag_index := -1
var _dragging := false
var _aiming := false
var _drag_proxy: Control = null
## 影卡是否已处于「可出牌」态（朱砂描边），用于避免每帧重建 StyleBox。
var _proxy_ready := false
var _aim: Control = null
var _aim_target := ""
var _submitted := {}

var _cards_host: Control
var _aim_layer: CanvasLayer
var _scaffold_ready := false
var _resize_hooked := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ensure_scaffold()
	_hook_resize()


func setup(cards: Array, chosen: Callable = Callable(),
		hovered: Callable = Callable()) -> void:
	_ensure_scaffold()
	_hook_resize()
	_data = cards
	on_chosen = chosen
	if hovered.is_valid() and not hover_changed.is_connected(hovered):
		hover_changed.connect(hovered)
	for child in _cards_host.get_children():
		_cards_host.remove_child(child)
		child.queue_free()
	_cards.clear()
	_cards_by_id.clear()
	for card in cards:
		if not (card is Dictionary):
			continue
		var node := _build_card(card)
		_cards_host.add_child(node)
		_cards.append(node)
		# 按**原始 id** 登记：宿主用 card_rect/set_card_dimmed 查它是为了绕开
		# "节点名已被引擎清洗"这个坑（见 card_rect 注释）。
		_cards_by_id[str((card as Dictionary).get("id", ""))] = node
	_hovered_index = -1
	_submitted.clear()
	# 重建手牌时若正处于瞄准态，目标 id 可能已失效（敌人换了）→ 必须先清零广播，
	# 否则宿主会把上一局的目标 id 当成有效目标继续点亮。
	_set_aim_target("")
	_refresh_hover_shift()
	_update_hand_layout()


## 宿主注入命中检测：入参鼠标全局位，返回目标 id（""=无目标）。
func set_target_provider(provider: Callable) -> void:
	target_provider = provider


## 换卡面尺寸（竖长卡的宽度直接决定同屏容量）后必须重排。
func set_card_size(next: Vector2) -> void:
	card_size = next
	for card in _cards:
		card.custom_minimum_size = card_size
		card.size = card_size
		card.pivot_offset = _pivot()
	_sync_min_size()
	_update_hand_layout()


## 卡体全局矩形（宿主用它锚解释栏、推瞄准线起点）；找不到返回空 Rect2。
##
## ⚠️ 按**原始 id** 走映射表，不按节点名反查：真实蛊卡 id 形如 `gu.gu_001`，含点，
## 节点名会被清洗成 `gu_gu_001`，按名反查必然 null 且**静默失败**（2026-09-10 真机
## 冒烟就是栽在这里：瞄准线起点退化成一个点 → 整条线不画）。
func card_rect(card_id: String) -> Rect2:
	var node := _node_for(card_id)
	if node != null:
		return node.get_global_rect()
	return Rect2()


## 拖拽期间压暗源卡（视觉反馈：卡已「离手」）；结束/取消时恢复。
func set_card_dimmed(card_id: String, dimmed: bool) -> void:
	var node := _node_for(card_id)
	if node != null:
		node.modulate.a = 0.45 if dimmed else 1.0


## 悬停卡视觉上沿相对布局矩形抬高了多少（宿主用它把解释栏让开卡沿）。
## 两笔叠加：显式上浮 HOVER_LIFT + 绕底边放大导致的"向上长高"。
## 供宿主调用而不是让宿主去读组件常量——跨类引用别家 const 在换组件时会直接断。
func hover_lift_px() -> float:
	return HOVER_LIFT + card_size.y * (HOVER_SCALE - 1.0)


func _node_for(card_id: String) -> Control:
	# 用 `=` 而非 `:=`：Dictionary.get 返回 Variant，`:=` 会被
	# "类型推断自 Variant" 的警告判红（项目把该警告当错误）。
	var node = _cards_by_id.get(card_id)
	if node is Control and is_instance_valid(node):
		return node as Control
	return null


# ————————————————————————— 骨架 —————————————————————————

## 惰性搭骨架：宿主可能在节点入树前就调 setup()（mount_snapshot 常早于 _ready），
## 等 _ready 才建子容器会把手牌吞掉。
func _ensure_scaffold() -> void:
	if _scaffold_ready:
		return
	_scaffold_ready = true
	_cards_host = Control.new()
	_cards_host.name = "Cards"
	_cards_host.mouse_filter = Control.MOUSE_FILTER_PASS
	_cards_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cards_host)
	# 瞄准线独立 CanvasLayer：保证压在本屏所有 UI 之上（layer 90，低于转场遮罩 100），
	# 且随本屏一起释放。挂 viewport 根的话，将来有 UI 进更高 layer 就会被盖住。
	_aim_layer = CanvasLayer.new()
	_aim_layer.name = "AimLayer"
	_aim_layer.layer = 90
	add_child(_aim_layer)
	_sync_min_size()


## 手牌盒的最小高度 = **卡高**（不含弧高）。
##
## 宿主的手牌区是 `size_flags_vertical = 0`（按内容撑）的容器，所以这个最小高度
## 直接决定整块手牌区占多少竖直空间。刻意**不**把 ARC_LIFT 加进来：弧高靠两端卡
## 向上溢出实现，否则手牌区会多长高 22px，把战场区最靠下的 ModeHost 顶掉
## （实测换竖长卡后那条缝隙只剩 1px）。
## 宽度交给容器的 `size_flags_horizontal = 3`，这里不给最小值——扇形是靠实际宽度算步进的。
func _sync_min_size() -> void:
	custom_minimum_size = Vector2(0.0, card_size.y)


func _hook_resize() -> void:
	if _resize_hooked:
		return
	_resize_hooked = true
	resized.connect(func(): call_deferred("_update_hand_layout"))


## 影卡挂在**视口根**（要盖住整屏、不受本屏布局影响），不随组件释放 → 这里手工回收。
## 回弹中的影卡同样要清，否则退屏后会留在下一屏上当鬼影。
func _exit_tree() -> void:
	if _drag_proxy != null and is_instance_valid(_drag_proxy):
		_drag_proxy.queue_free()
	_drag_proxy = null
	if _aim != null and is_instance_valid(_aim):
		_aim.queue_free()
	_aim = null


# ————————————————————————— 卡体 —————————————————————————

## ⚠️ pivot_offset 必须 = (size.x/2, size.y)：**底边中点**。
## 不设（或设为 0）的话卡会以左上角为轴心旋转，整排扇形会以各自的左上角为圆心散开，
## 表现为"扇形断裂错位"。设在底边中点后：旋转/缩放都围绕卡的下沿中轴，
## 整排的下沿始终贴在基线上，缩放的也是"向上长高"而不是向四周膨胀。
func _pivot() -> Vector2:
	return Vector2(card_size.x * 0.5, card_size.y)


## 卡体：**外层 Control 承担变形**（position / rotation / scale / pivot / z），
## 内层 Button 承担交互（hover / 点击）。两层分工的原因：
##   · 变形放在外层，Button 就能保持 AABB 命中与自己的 hover 态样式；
##   · 节点名与生产组件同构（`card_box_<清洗 id>` / `card_body_<清洗 id>`），
##     既有测试按这两个名字定位，换组件因此不必改测试。
## 卡面**只能**是 Button 自己的多行 text：既有测试断言"手牌区内不得存在含卡名/品质/费用的
## 独立 Label"（详情归宿主 tooltip），所以不要往卡上挂角标 Label。
func _build_card(card: Dictionary) -> Control:
	var card_id := str(card.get("id", ""))
	var node_name := _node_name(card_id)
	var box := Control.new()
	box.name = "card_box_" + node_name
	box.custom_minimum_size = card_size
	box.size = card_size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.pivot_offset = _pivot()

	var btn := Button.new()
	btn.name = "card_body_" + node_name
	btn.text = _face_text(card)
	btn.clip_text = true
	# 中文按字断行（WORD_SMART 对无空格的中文会整段不折），效果行因此能占两行。
	btn.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 卡体必须 STOP：否则 hover/点击都收不到（IGNORE 会变成"看得见点不到"）。
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if not bool(card.get("executable", true)):
		btn.modulate = Color(1, 1, 1, 0.55)
	btn.add_theme_font_override("font", GuStyle.BODY_FONT)
	btn.add_theme_font_size_override("font_size", FACE_FONT_SIZE)
	btn.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	btn.add_theme_stylebox_override("normal", _card_box(false))
	btn.add_theme_stylebox_override("hover", _card_box(true))
	btn.add_theme_stylebox_override("pressed", _card_box(false))
	# 交互闭环契约：每个可点元素必须有**视觉 + 听觉**双重反应。悬停视觉由 hover 样式块
	# 承担（玉绿描边 + 抬亮纸底），听觉这里显式接一次 ui_click —— 本组件刻意不调
	# `MasterTheme.apply_button`（它会写死卡角色尺寸 120×110，并自装 hover 缩放补间，
	# 与扇形自己的 scale 补间抢同一属性），所以没有 theme 代劳的那次接线。
	# font_hover_color 与主题的 card 角色保持同一语言（hover 文字转朱砂）。
	btn.add_theme_color_override("font_hover_color", GuStyle.CINNABAR)
	btn.pressed.connect(func(): _sfx("ui_click"))
	box.add_child(btn)

	var index := _cards.size()
	btn.mouse_entered.connect(func(): _on_card_entered(index))
	btn.mouse_exited.connect(func(): call_deferred("_confirm_hover_exit", index))
	btn.button_down.connect(func(): _on_card_down(index))
	btn.pressed.connect(func():
		# 不可执行的卡**仍要可悬停**（玩家得看得到 block_reason），但**绝不提交**：
		# 提交与否归宿主裁决，组件只保证"禁用卡不会发出出牌请求"。
		if _drag_index < 0 and bool(card.get("executable", true)) and on_chosen.is_valid():
			on_chosen.call(card_id, ""))
	btn.gui_input.connect(func(event):
		var is_cancel: bool = (
				(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT
						and event.pressed)
			or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed))
		if is_cancel and _drag_index < 0 and _candidate_index < 0:
			cancel_requested.emit())
	return box


## 数据 id → 节点名后缀。**显式清洗**而不是依赖引擎的隐式行为：
## Godot 节点名不允许 `. : @ / %`，会自行替换，但那是引擎实现细节；
## 命名方与查找方用同一条规则（`id.replace(".", "_")`）才不会漂移。
static func _node_name(card_id: String) -> String:
	return card_id.replace(".", "_")


## 卡面多行文案：名称 / 道阶 / 效果 / 费用。与生产手牌同构（含字段回退顺序），
## 只是截断阈值按竖长卡的窄宽度（110）重算：字号 11 时每行约容 10 字，
## 取 8 字留内边距——超了会被 clip_text 静默切掉，所以必须显式截断。
func _face_text(card: Dictionary) -> String:
	var name := str(card.get("name", "蛊虫"))
	var quality := str(card.get("quality", "普通"))
	var school := str(card.get("school_label", ""))
	# cost 已是展示文案（如「念头 1」）；cost_ex 仅在数据自带时优先。
	var cost := str(card.get("cost_ex", ""))
	if cost.is_empty():
		cost = str(card.get("cost", ""))
	# 卡面只放一短行效果；括号注记与长尾留给宿主 tooltip。
	var effect := str(card.get("effect", ""))
	var paren := effect.find("（")
	if paren >= 0:
		effect = effect.substr(0, paren)
	if effect.length() > FACE_EFFECT_MAX_CHARS:
		effect = effect.substr(0, FACE_EFFECT_MAX_CHARS) + "…"
	var lines: Array[String] = [name]
	lines.append("%s · %s" % [school, quality] if not school.is_empty() else quality)
	if not effect.is_empty():
		lines.append(effect)
	if not cost.is_empty():
		lines.append("◆ %s" % cost)
	return "\n".join(lines)


func _card_box(highlighted: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED if highlighted else GuStyle.PAPER_BG
	box.border_color = GuStyle.JADE if highlighted else GuStyle.HAIRLINE_COLOR
	box.set_border_width_all(2 if highlighted else GuStyle.HAIRLINE)
	box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	box.shadow_color = GuStyle.SHADOW_LARGE_COLOR if highlighted else GuStyle.SHADOW_SMALL_COLOR
	box.shadow_size = GuStyle.SHADOW_LARGE_SIZE if highlighted else GuStyle.SHADOW_SMALL_SIZE
	box.shadow_offset = GuStyle.SHADOW_LARGE_OFFSET if highlighted else GuStyle.SHADOW_SMALL_OFFSET
	return box


# ————————————————————— 横向扇形布局（核心算法） ——————————————————————

## 扇形自适应布局：一次算出**整排**的 position / rotation / scale / z_index，逐张补间。
##
## 为什么悬停时也整排重算：扇形的角度、弧高、步长、让位互相耦合，只动一张会让相邻卡
## 与它错位；整排重算后所有卡都走同一套公式，过渡才连贯，"防遮挡让位"也天然可叠加。
func _update_hand_layout() -> void:
	var count := _cards.size()
	if count == 0:
		return
	var card_w := card_size.x
	var step := _layout_step(count)
	var span := step * float(count - 1)
	# 水平居中，并保证整排不越界：step 已被夹在 [卡宽×0.45, 卡宽×1.02]，
	# 因此 span ≤ 可用宽，base_x ≥ 0 恒成立；再内缩 EDGE_OVERHANG_INSET 兜住
	# 两端卡旋转/缩放后顶角向外偏出的那几像素。
	var base_x := EDGE_OVERHANG_INSET + (_usable_width() - span - card_w) * 0.5
	var center := float(count - 1) * 0.5
	for i in count:
		var t := (float(i) - center) / maxf(center, 1.0)        # −1 最左 → +1 最右
		# 非线性缓动：t 的绝对值开 T_EASE 次方。竖长卡倾斜代价大（卡越高越像倒下），
		# 缓动后 0.5 处的卡只转到 MAX_ANGLE×0.38 而不是 ×0.5，整排更"立"。
		var t_eased: float = signf(t) * pow(absf(t), T_EASE)
		var rotation := 0.0 if i == _hovered_index else deg_to_rad(MAX_ANGLE_DEG * t_eased)
		var arc_y := (1.0 - t_eased * t_eased) * ARC_LIFT
		# 透视缩放：中间 1.0，边缘 1−PERSPECTIVE_DROP（竖长卡靠缩小 + 弧高做纵深，
		# 而不是靠加大倾角——倾角一大会露怯）。
		var scale := Vector2.ONE * (1.0 - PERSPECTIVE_DROP * absf(t))
		# 减 ARC_LIFT 把坐标系对齐到「中间卡顶边 = 手牌盒顶边」：手牌盒因此只需预留
		# **卡高**，弧高由两端卡向上溢出，而不是让整块手牌区再长高 22px——
		# 那 22px 会顶掉战场区最靠下的 ModeHost（实测该缝隙只剩 1px，见
		# tools/verify_card_shape_budget.gd）。溢出的两端卡在水平方向是空的
		# （ModeHost 居中 448..832、OpsDock 靠右 1090+），所以看不见碰撞。
		var position := Vector2(base_x + step * float(i) + _hover_shift[i], arc_y - ARC_LIFT)
		if i == _hovered_index:
			# 悬停：上浮 + 放大 + 回正（回正后卡面完全可读，且不再压住邻居的斜边）。
			position.y -= HOVER_LIFT
			scale = Vector2.ONE * HOVER_SCALE
		if i == _drag_index and (_dragging or _aiming):
			# 拖拽：脱离整排扇形，姿态归正 + 放大 1.2 + 抬到最高层。
			rotation = 0.0
			scale = Vector2.ONE * DRAG_SCALE
		# z_index：右侧压左侧（与真实扇形一致）；悬停/拖拽临时抬到最上。
		var z := i
		if i == _hovered_index:
			z = HOVER_Z
		if i == _drag_index:
			z = DRAG_Z
		_cards[i].z_index = z
		# ⚠️ 位置/旋转/缩放/**亮度**必须走同一段补间：
		# 若另开一段只补 modulate，_tween_of 会把刚建好的位移补间 kill 掉，
		# 表现为卡牌停在半路（2026-09-10 探针实测：悬停后整排位置全部半途冻结）。
		_tween_card(_cards[i], position, rotation, scale, _dim_target(i))
	_sync_stack_order()


## 单张卡的水平步进（**横向负边距重叠**的核心，也是容量的直接决定项）：
##   可用宽够 → 摊开（上限留 2% 缝隙，免得卡之间出现怪缝）；
##   不够 → 压成负边距重叠，最多压到卡宽的 MIN_STEP_RATIO。
## 卡宽从 168 改到 110 后，同样的屏宽能多放 (168/110 − 1) ≈ 53% 的卡；
## 而 step 下限同步变小（110×0.45 = 49.5），所以重叠区也等比收窄，不会"挤成一坨"。
func _layout_step(count: int) -> float:
	if count <= 1:
		return 0.0
	var room := maxf(1.0, _usable_width() - card_size.x)
	var fit := room / float(count - 1)
	return clampf(fit, card_size.x * MIN_STEP_RATIO, card_size.x * 1.02)


## 摆卡可占的横向总宽（**含卡本身**）：两侧各留出 EDGE_OVERHANG_INSET，兜住两端卡
## 旋转+缩减后顶角向外偏出的那几像素（否则最外侧卡会被屏幕边缘切掉）。
## 注意步进要用的是"扣掉一张卡宽"之后的剩余空间，两者别混（混了会整排溢出一张卡宽）。
func _usable_width() -> float:
	return maxf(1.0, size.x - EDGE_OVERHANG_INSET * 2.0)


## 悬停让位：悬停卡左侧的往左让、右侧的往右让，按距离衰减到第 3 张。
## 只改"让位量"，位置仍由 _update_hand_layout 统一算，避免两处各写一套坐标。
func _refresh_hover_shift() -> void:
	_hover_shift.resize(_cards.size())
	_hover_shift.fill(0.0)
	if _hovered_index < 0:
		return
	for i in _cards.size():
		var distance := absi(i - _hovered_index)
		if distance == 0 or float(distance) > FANOUT_REACH:
			continue
		var falloff := 1.0 - float(distance) / (FANOUT_REACH + 1.0)
		_hover_shift[i] = signf(float(i - _hovered_index)) * HOVER_FANOUT * falloff


## 未悬停卡压暗（RGB 变暗，不用 alpha：扇形本来就重叠，半透明会互相透出）。
## 只在"确实有卡被悬停"时压暗；无悬停则全部恢复满亮。
func _dim_target(index: int) -> Color:
	if _hovered_index < 0 or index == _hovered_index:
		return Color(1, 1, 1, 1)
	return Color(1, 1, 1, 1).darkened(DIM_DARKEN)


## 单卡补间：position / rotation / scale 全走 tween_property（不生硬跳变）。
## ⚠️ 同一张卡的旧 tween 必须先 kill：快速滑动鼠标时，新旧两段 tween 会同时写
## 同一属性，表现为卡牌来回抽搐。这是本组件最容易踩的一条。
func _tween_card(card: Control, target_pos: Vector2, target_rot: float,
		target_scale: Vector2, target_modulate: Color) -> void:
	var tween := _tween_of(card)
	tween.tween_property(card, "position", target_pos, TWEEN_TIME)
	tween.tween_property(card, "rotation", target_rot, TWEEN_TIME)
	tween.tween_property(card, "scale", target_scale, TWEEN_TIME)
	tween.tween_property(card, "modulate", target_modulate, TWEEN_TIME)


func _tween_of(card: Control) -> Tween:
	var running := _tweens.get(card) as Tween
	if running != null and running.is_valid():
		running.kill()
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	_tweens[card] = tween
	return tween


## 绘制层级（z_index）与命中层级（子节点顺序）必须一致。
## ⚠️ 实测：Godot 4.7 的 GUI 命中**不看 z_index，只看子节点顺序**（从后往前找）。
## 所以"悬停时把 z_index 抬到 100"只解决画在最上面，不解决点得到——
## 必须同时 move_child，否则出现"看着在最上层、鼠标却穿透到下层卡"。
func _sync_stack_order() -> void:
	if _cards.size() < 2:
		return
	var ordered := _cards.duplicate()
	ordered.sort_custom(func(a: Control, b: Control) -> bool: return a.z_index < b.z_index)
	for i in ordered.size():
		if _cards_host.get_child(i) != ordered[i]:
			_cards_host.move_child(ordered[i], i)


# ————————————————————————— 悬停交互 —————————————————————————

func _on_card_entered(index: int) -> void:
	if _dragging or _aiming or _hovered_index == index:
		return
	_hovered_index = index
	_refresh_hover_shift()
	_update_hand_layout()
	hover_changed.emit(_id_at(index))


## 离开：**延后一帧**确认。从 A 滑到 B 时 Godot 先发 A.exit 再发 B.enter，
## 立即复位会让整排闪一下（收回去又展开）。
func _confirm_hover_exit(index: int) -> void:
	if _hovered_index != index:
		return
	_hovered_index = -1
	_refresh_hover_shift()
	_update_hand_layout()
	hover_changed.emit("")


func _id_at(index: int) -> String:
	if index < 0 or index >= _data.size():
		return ""
	return str((_data[index] as Dictionary).get("id", ""))


## 音效走运行时查找而不是直接引用 AudioManager 单例：
## 组件因此不依赖 autoload（探针/单测里也能独立跑），缺失时静默降级。
func _sfx(sound: String) -> void:
	var bus := get_node_or_null("/root/AudioManager")
	if bus != null and bus.has_method("play_sfx"):
		bus.call("play_sfx", sound)


func _card_at(index: int) -> Dictionary:
	if index < 0 or index >= _data.size():
		return {}
	return _data[index]


func _is_targeted(card: Dictionary) -> bool:
	return str(card.get("target_type", "none")) == "single_enemy"


# ————————————————————— 拖拽状态机 + 瞄准线 —————————————————————

## 状态迁移（唯一入口，全部在这里收口）：
##   idle ──button_down──► candidate
##   candidate ──位移 ≥ 阈值──► dragging（无指向卡）/ aiming（指向卡）
##   dragging/aiming ──松开──► 命中目标：出牌；未命中：回弹 / 收线
##   dragging/aiming ──右键 | Esc──► 取消
func _on_card_down(index: int) -> void:
	if not bool(_card_at(index).get("executable", true)):
		return
	_candidate_index = index
	_press_pos = get_global_mouse_position()


func _input(event: InputEvent) -> void:
	if _candidate_index < 0:
		return
	if event is InputEventMouseMotion:
		if not _dragging and not _aiming \
				and _press_pos.distance_to(get_global_mouse_position()) >= DRAG_START_THRESHOLD_PX:
			_begin_drag(_candidate_index)
		return
	var index := _candidate_index
	var was_active := _dragging or _aiming
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_candidate_index = -1
		var mouse := get_global_mouse_position()
		if _aiming:
			var target := _hit_target(mouse)
			_end_drag(target != "")
			if target != "":
				_submit(index, target)
		else:
			var cast := _dragging and _press_pos.distance_to(mouse) >= DRAG_CAST_DISTANCE_PX
			_end_drag(cast)
			if cast:
				_submit(index, "")
		# 真拖拽过的手势，抬起一律吞掉：否则 GUI 会把"回弹/取消"再当成一次落在按钮内的
		# 点击发出 pressed，同一次松手出两张牌。
		if was_active:
			get_viewport().set_input_as_handled()
		return
	var is_cancel: bool = was_active and (
			(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT
					and event.pressed)
			or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE))
	if is_cancel:
		_candidate_index = -1
		_end_drag(false)
		get_viewport().set_input_as_handled()


func _begin_drag(index: int) -> void:
	var had_hover := _hovered_index >= 0
	_drag_index = index
	_hovered_index = -1
	_refresh_hover_shift()
	if had_hover:
		# 手势一开始就收起解释栏：它贴在影卡/弧箭旁边会把「正在操作哪张卡」盖掉。
		# 宿主已不再自己判断手势状态（那会变成第二份状态镜像），所以必须由组件
		# 显式广播一次 ""，否则解释栏会在整个拖拽期间挂在屏幕上。
		hover_changed.emit("")
	var card := _card_at(index)
	if _is_targeted(card):
		_aiming = true
		_spawn_aim()
	else:
		_dragging = true
		_spawn_proxy(index)
		# 源卡压暗 = 「卡已离手」。瞄准态不压暗：源卡是箭的起点，压暗会看着像线断了。
		set_card_dimmed(str(card.get("id", "")), true)
	_update_hand_layout()
	_sfx("ui_click")


func _end_drag(hit: bool) -> void:
	var index := _drag_index
	var proxy := _drag_proxy
	_aiming = false
	_dragging = false
	_drag_index = -1
	_drag_proxy = null
	if _aim != null:
		_fade_out_aim()
	_set_aim_target("")
	if proxy != null and is_instance_valid(proxy):
		# 断线不回收：**未命中要回弹到源卡原位再淡出**，"松手就消失"读不出"我拖了一张卡、
		# 它退回去了"。命中则立即销毁（出牌接管视觉）。
		if hit:
			proxy.queue_free()
		else:
			_rebound(proxy, index)
	if index >= 0:
		set_card_dimmed(str(_card_at(index).get("id", "")), false)
		_refresh_hover_shift()
		_update_hand_layout()
	if not hit:
		_sfx("ui_cancel")


## 回弹：影卡补间回源卡矩形并淡出，结束再释放。
## 落点取**源卡矩形**（拿不到就退回起点附近），绝不用 (0,0)——
## 源卡矩形按原始 id 查（见 card_rect），否则带点 id 会让影卡飞向左上角。
func _rebound(proxy: Control, index: int) -> void:
	# 影卡挂在视口根（画布全局空间），所以落点必须用**全局矩形**而不是局部 position，
	# 否则会按局部坐标飞到一个毫不相干的位置。
	var to := proxy.position
	if index >= 0 and index < _cards.size():
		to = _cards[index].get_global_rect().position
	var tween := proxy.create_tween()
	tween.set_parallel(true)
	tween.tween_property(proxy, "position", to, REBOUND_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "modulate:a", 0.0, REBOUND_TIME)
	tween.chain().tween_callback(proxy.queue_free)


func _submit(index: int, target_id: String) -> void:
	var card := _card_at(index)
	var card_id := str(card.get("id", ""))
	var key := card_id + ":" + target_id
	if _submitted.has(key):
		return
	_submitted[key] = true
	if on_chosen.is_valid():
		on_chosen.call(card_id, target_id)


## 无指向卡的影卡：不透明 + 按比例重建放大（缩放 Control 会把字拉虚），
## 带墨框与投影读作"离手"。
func _spawn_proxy(index: int) -> void:
	var card := _card_at(index)
	var size := card_size * DRAG_PROXY_SCALE
	var btn := Button.new()
	btn.text = _face_text(card)
	btn.clip_text = true
	btn.custom_minimum_size = size
	btn.size = size
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_theme_font_override("font", GuStyle.BODY_FONT)
	btn.add_theme_font_size_override("font_size", int(FACE_FONT_SIZE * DRAG_PROXY_SCALE))
	btn.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	btn.add_theme_stylebox_override("normal", _lifted_box(false))
	var wrapper := Control.new()
	# 名字与生产组件一致：既有测试按 `battle_drag_proxy` 前缀在视口里找影卡。
	wrapper.name = "battle_drag_proxy"
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = DRAG_Z
	# 外层是普通 Control，不主动报尺寸的话对外的 custom_minimum_size 是 0——
	# 任何"影卡比源卡大"这类外部断言都会读到 0 而不是真实尺寸。
	wrapper.custom_minimum_size = size
	# 起始位置 = 源卡全局矩形，否则首帧会从画布左上角飞过来。
	if index >= 0 and index < _cards.size():
		wrapper.position = _cards[index].get_global_rect().position
	wrapper.add_child(btn)
	get_viewport().add_child(wrapper)
	_drag_proxy = wrapper
	_proxy_ready = false


func _lifted_box(ready: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_BG
	box.border_color = GuStyle.CINNABAR if ready else GuStyle.INK_PRIMARY
	box.set_border_width_all(2)
	box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	box.shadow_color = GuStyle.SHADOW_LARGE_COLOR
	box.shadow_size = GuStyle.SHADOW_LARGE_SIZE
	box.shadow_offset = GuStyle.SHADOW_LARGE_OFFSET
	return box


## 每帧：拖拽影卡跟随 / 瞄准线跟随 + 命中检测。
func _process(delta: float) -> void:
	if _dragging and _drag_proxy != null and is_instance_valid(_drag_proxy):
		var mouse := get_global_mouse_position()
		var size := card_size * DRAG_PROXY_SCALE
		var target := mouse - size * DRAG_PROXY_GRAB
		var weight := 1.0 - pow(1.0 - 0.8, delta * 60.0)
		_drag_proxy.position = _drag_proxy.position.lerp(target, weight)
		_update_proxy_ready(mouse)
	elif _aiming and _aim != null and is_instance_valid(_aim):
		_update_aim()


## 影卡「可出牌」态：拖出 DRAG_CAST_DISTANCE_PX 后转朱砂描边，
## 给出「松手即出」的确定反馈。只在状态翻转时改样式，不每帧重建 StyleBox。
func _update_proxy_ready(mouse: Vector2) -> void:
	var ready := _press_pos.distance_to(mouse) >= DRAG_CAST_DISTANCE_PX
	if ready == _proxy_ready or _drag_proxy == null or not is_instance_valid(_drag_proxy):
		return
	_proxy_ready = ready
	var btn := _drag_proxy.get_child(0)
	if btn is Button:
		(btn as Button).add_theme_stylebox_override("normal", _lifted_box(ready))


func _spawn_aim() -> void:
	if _aim_layer == null:
		return
	var overlay := AimOverlay.new()
	_aim_layer.add_child(overlay)
	_aim = overlay
	# 呼吸发光：modulate.a 循环补间，增强"正在瞄准"的打击感。
	# 收线时必须 kill，否则淡出会被循环补间拽回 1.0，线永远不灭。
	var breath := create_tween().set_loops()
	breath.tween_property(overlay, "modulate:a", 0.72, 0.9).set_trans(Tween.TRANS_SINE)
	breath.tween_property(overlay, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	overlay.set_meta("breath", breath)


## 瞄准线起点取卡**顶部中心**（竖长卡的上沿就是卡头，箭从卡头射出最自然）；
## 终点跟随鼠标；命中检测交给宿主注入的 provider。
func _update_aim() -> void:
	var mouse := get_global_mouse_position()
	var origin := mouse
	if _drag_index >= 0 and _drag_index < _cards.size():
		var rect := _cards[_drag_index].get_global_rect()
		origin = Vector2(rect.get_center().x, rect.position.y)
	if origin.distance_to(mouse) < 1.0:
		# 起点与终点重合 → 曲线退化成一个点、线看不见。退到鼠标上方兜底。
		origin = mouse - Vector2(0.0, AIM_ORIGIN_FALLBACK_Y)
	_set_aim_target(_hit_target(mouse))
	# 颜色按卡牌性质：攻击=暗红（朱砂），控制/辅助=青灰（契约蓝）；
	# "锁定/未锁定"由线型与线宽表达（实线加粗 vs 半透明虚线），两轴正交。
	var attacking := str(_card_at(_drag_index).get("kind", "attack")) == "attack"
	_aim.call("set_aim", origin, mouse, _aim_target != "", attacking)


func _hit_target(global_pos: Vector2) -> String:
	if not target_provider.is_valid():
		return ""
	return str(target_provider.call(global_pos))


## 瞄准目标变化的**唯一出风口**：只有真变化才广播。
## 宿主侧 `_set_drop_hot` 依赖这个「只在变化时发」的前提去做前目标复位——
## 若这里放开去重，每帧都会重发同一目标，宿主会在同帧内反复关/开高亮，描边闪烁。
func _set_aim_target(target_id: String) -> void:
	if target_id == _aim_target:
		return
	_aim_target = target_id
	aim_target_changed.emit(target_id)


## 收线：先 kill 呼吸补间，再补间淡出后释放（"平滑消失"）。
func _fade_out_aim() -> void:
	var overlay := _aim
	_aim = null
	if overlay == null or not is_instance_valid(overlay):
		return
	var breath = overlay.get_meta("breath", null)
	if breath is Tween and (breath as Tween).is_valid():
		(breath as Tween).kill()
	var fade := create_tween()
	fade.tween_property(overlay, "modulate:a", 0.0, 0.18)
	fade.tween_callback(overlay.queue_free)


# ————————————————————— 瞄准覆盖层（内部类） —————————————————————

## 弧形箭：二次贝塞尔 + 渐细箭身（起点粗、末端收，近似水墨飞白）+ 实心箭头。
## 自由态半透明虚线，命中态实线加粗变色。
## 几何常量放内部类内：内部类不继承外部脚本作用域，裸引用外部 const 会解析失败。
class AimOverlay extends Control:
	const SAMPLES := 20
	const BODY_WIDTH := 9.0
	const HOT_BODY_WIDTH := 13.0
	const HEAD_LEN := 30.0
	const HEAD_HALF := 15.0
	const ARC_MIN := 40.0
	const ARC_MAX := 150.0
	const ARC_RATIO := 0.32
	const DASH := 14.0
	const GAP := 9.0
	const FREE_ALPHA := 0.8

	var _points := PackedVector2Array()
	var _color := GuStyle.INK_PRIMARY
	var _hot := false

	func _init() -> void:
		# 名字与生产组件保持一致（既有测试按 `battle_aim_line` 前缀在视口子树里找它）。
		name = "battle_aim_line"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 100
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func set_aim(from: Vector2, to: Vector2, hot: bool, attacking: bool) -> void:
		_hot = hot
		_color = GuStyle.CINNABAR if attacking else GuStyle.CONTRACT_BLUE
		_points = _build_curve(from, to)
		queue_redraw()

	func points() -> PackedVector2Array:
		return _points

	func is_hot() -> bool:
		return _hot

	func color() -> Color:
		return _color

	func _build_curve(from: Vector2, to: Vector2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var lift: float = clampf(from.distance_to(to) * ARC_RATIO, ARC_MIN, ARC_MAX)
		var ctrl := (from + to) * 0.5 + Vector2(0.0, -lift)
		for i in range(SAMPLES + 1):
			var t := float(i) / float(SAMPLES)
			pts.append(from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t))
		return pts

	## 逐段画：宽度从起点到末端线性收细（飞白感），自由态再按弧长切虚线。
	## Godot 没有"曲线虚线"API（draw_dashed_line 只吃直线），也画不出变宽折线，
	## 所以这里自己按段走。
	func _draw() -> void:
		if _points.size() < 2:
			return
		var width := HOT_BODY_WIDTH if _hot else BODY_WIDTH
		var alpha := 1.0 if _hot else FREE_ALPHA
		var color := Color(_color.r, _color.g, _color.b, alpha)
		draw_polyline(_points, Color(_color.r, _color.g, _color.b, alpha * 0.22), width * 1.7, true)
		var carry := 0.0
		for i in range(_points.size() - 1):
			var a: Vector2 = _points[i]
			var b: Vector2 = _points[i + 1]
			var seg := a.distance_to(b)
			if seg <= 0.0:
				continue
			var ratio := float(i) / float(_points.size() - 1)
			var w: float = lerpf(width * 1.15, width * 0.65, ratio)
			if _hot:
				draw_line(a, b, color, w, true)
			else:
				var travelled := 0.0
				while travelled < seg:
					var phase: float = fmod(carry + travelled, DASH + GAP)
					var on: bool = phase < DASH
					var room: float = (DASH - phase) if on else (DASH + GAP - phase)
					var take: float = minf(room, seg - travelled)
					if on:
						draw_line(a.lerp(b, travelled / seg), a.lerp(b, (travelled + take) / seg),
								color, w, true)
					travelled += take
			carry = fmod(carry + seg, DASH + GAP)
		var tip: Vector2 = _points[_points.size() - 1]
		var dir := (tip - _points[_points.size() - 2]).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([
			tip,
			tip - dir * HEAD_LEN + side * HEAD_HALF,
			tip - dir * HEAD_LEN - side * HEAD_HALF,
		]), color)
