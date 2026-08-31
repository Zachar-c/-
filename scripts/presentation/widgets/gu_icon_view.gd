class_name GuIconView
extends TextureRect

## 问眞极简单色图标。
##
## 图标为**白色描边**的 SVG，靠 modulate 乘法染成 token 色——这是刻意设计：
## CanvasItem.modulate 是乘法，黑色 * 任何色 = 黑色，染不上色；白色 * 目标色 = 目标色。
## 因此 GuIcon 必须始终显式给 color，缺省也走 INK_PRIMARY，绝不能放任默认白（白在纸面上不可见）。
##
## 素材来源：assets/wenzhen/icons/*.svg，本项目程序化自绘（线性描边，24 viewBox，4x 导入 = 96px）。
## 将来若要换成 game-icons.net（CC BY 3.0）素材，只需改 ICON_PATHS 的映射并保持白色描边约定；
## 注意 CC BY 是**署名强需求**，换素材时必须在游戏内「关于」界面署名，光放许可证文件不够。

const ICON_DIR := "res://assets/wenzhen/icons/"

## 图标注册表：语义名 → 文件名。新增图标只改这张表 + 丢一个 SVG 进目录。
const ICON_PATHS := {
	# 资源
	"yuanstone": "ic_yuanstone",
	"shouyuan": "ic_shouyuan",
	"hunpo": "ic_hunpo",
	"material": "ic_material",
	# 战斗
	"health": "ic_health",
	"attack": "ic_attack",
	"shield": "ic_shield",
	"dodge": "ic_dodge",
	# 蛊虫
	"insect": "ic_insect",
	"poison": "ic_poison",
	"bone": "ic_bone",
	"flame": "ic_flame",
	# 状态
	"curse": "ic_curse",
	"seal": "ic_seal",
	"warning": "ic_warning",
	"danger": "ic_danger",
	"death": "ic_death",
	# 界面
	"close": "ic_close",
	"check": "ic_check",
	"settings": "ic_settings",
	"scroll": "ic_scroll",
	"codex": "ic_codex",
	"map": "ic_map",
}

## 语义默认色：凶险类自动走 CINNABAR，肯定类走 JADE，其余 INK_PRIMARY。
## 与 GuStyle 的语义色板保持一致，禁止在此硬编码色值。
const SEMANTIC_COLORS := {
	"curse": "cinnabar",
	"danger": "cinnabar",
	"death": "cinnabar",
	"poison": "cinnabar",
	"warning": "anomaly",
	"check": "jade",
	"shield": "contract",
}

## 尺寸档位（与 UI_RULES 的间距档位对齐，避免在调用点写魔法数字）。
const SIZE_SMALL := 16
const SIZE_BODY := 20
const SIZE_BLOCK := 24

var _icon_name := ""

## 设置图标。px 用 SIZE_* 常量；color 省略时走语义默认色。
## 未知图标名不会崩，只是隐藏自己并 push_warning——UI 不应因为缺素材就打断流程。
func setup(icon_name: String, color: Color = Color(0, 0, 0, 0), px: int = SIZE_BODY) -> void:
	_icon_name = icon_name
	if not ICON_PATHS.has(icon_name):
		push_warning("GuIcon 未知图标名: %s" % icon_name)
		visible = false
		texture = null
		return
	var file: String = ICON_PATHS[icon_name]
	var tex := load(ICON_DIR + file + ".svg") as Texture2D
	if tex == null:
		push_warning("GuIcon 图标文件缺失: %s" % file)
		visible = false
		texture = null
		return
	texture = tex
	custom_minimum_size = Vector2(px, px)
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visible = true
	modulate = _resolve_color(icon_name, color)


func _resolve_color(icon_name: String, explicit: Color) -> Color:
	# Color(0,0,0,0) 作为「未指定」哨兵：合法 token 色都是不透明的。
	if explicit.a > 0.0:
		return explicit
	var key := str(SEMANTIC_COLORS.get(icon_name, ""))
	match key:
		"cinnabar":
			return GuStyle.CINNABAR
		"anomaly":
			return GuStyle.ANOMALY_YELLOW
		"jade":
			return GuStyle.JADE
		"contract":
			return GuStyle.CONTRACT_BLUE
		_:
			return GuStyle.INK_PRIMARY


static func has(icon_name: String) -> bool:
	return ICON_PATHS.has(icon_name)


static func names() -> Array:
	return ICON_PATHS.keys()
