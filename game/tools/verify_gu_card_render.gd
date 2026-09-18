extends SceneTree

## GuCardView 卡面重构 + 全息闪箔/裸眼视差 渲染探针（2026-09-11）。
##
## 把 GuCardView 挂进 1280×720 的 SubViewport，铺宣纸底，四稀有度 + 咒/锁态各一张，
## 落图到 .preview/gu_card_<state>.png，供肉眼级检查：
##   cards_idle       — 五张卡静置：标题毛笔体/右上费用徽章/深灰标签/画框/描述关键词高亮/投影
##   cards_hover_foil — 传说卡悬停：闪箔带 + 悬停辉光 + 视差偏移（tilt 注入，确定值）
##
## 闪箔/辉光不走 _set_hover（那会触发 _process 用真实鼠标覆写 tilt），
## 直接注入 uniform，保证截图确定性：tilt=(0.45,-0.55)、anim_time=3.0。
##
## 用法（需真实窗口，不能 --headless）：
##   tools\godot.ps1 --path . -s tools/verify_gu_card_render.gd

const GuCardScene := preload("res://scenes/ui/widgets/gu_card.tscn")

const OUT_DIR := "res://.preview"
const VIEWPORT_SIZE := Vector2i(1280, 720)

var _failed := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = VIEWPORT_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var paper := ColorRect.new()
	paper.name = "paper"
	paper.color = GuStyle.PAPER_BG
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(paper)

	# ⚠️ 卡片必须入树一帧后才能 setup（@onready 依赖 _ready）。
	await _settle(1)

	var row := HBoxContainer.new()
	row.name = "row"
	row.add_theme_constant_override("separation", 14)
	row.position = Vector2(40, 120)
	row.size = Vector2(1200, 480)
	vp.add_child(row)

	var defs := [
		{"title": "月光蛊", "quality": "传说", "cost": "3",
			"desc": "消耗2真元·吸取3气血，月华护体"},
		{"title": "蚀骨蛊", "quality": "史诗", "curse": true, "cost": "2",
			"desc": "1转·损耗1寿元，对敌施加中毒"},
		{"title": "血牙蛊", "quality": "稀有", "cost": "2",
			"desc": "1转·恢复2气血，撕咬造成流血"},
		{"title": "石甲蛊", "quality": "普通", "sealed": true, "cost": "1", "desc": ""},
		{"title": "凝气蛊", "quality": "普通", "cost": "1",
			"desc": "强化自身2层真元"},
	]
	var cards: Array = []
	for d in defs:
		var card: Control = GuCardScene.instantiate()
		card.custom_minimum_size = Vector2(216, 300)
		row.add_child(card)
		card.setup(str(d.get("title", "")), str(d.get("quality", "")),
				bool(d.get("curse", false)), bool(d.get("curse", false)),
				bool(d.get("sealed", false)), str(d.get("cost", "")),
				false, false, false, "idle", str(d.get("desc", "")))
		cards.append(card)

	await _settle(3)
	await _capture(vp, "cards_idle")

	# 悬停态：传说卡注入 tilt + 辉光 + 流光相位（确定性，不依赖真实鼠标）。
	var legendary: Control = cards[0]
	legendary.call("_set_tilt", Vector2(0.45, -0.55))
	var glow_mat: ShaderMaterial = (legendary.get("_glow_overlay") as ColorRect).material
	glow_mat.set_shader_parameter("on", 1.0)
	var foil_mat: ShaderMaterial = (legendary.get("_shimmer_overlay") as ColorRect).material
	foil_mat.set_shader_parameter("anim_time", 3.0)
	legendary.z_index = 10
	# 诊断：确认 uniform 真的注入 + 覆盖层尺寸同步到位。
	print("[CARD] foil intensity=%s rect_half=%s tilt=%s anim=%s" % [
		str(foil_mat.get_shader_parameter("intensity")),
		str(foil_mat.get_shader_parameter("rect_half")),
		str(foil_mat.get_shader_parameter("tilt")),
		str(foil_mat.get_shader_parameter("anim_time"))])
	print("[CARD] overlay sizes shimmer=%s glow=%s card=%s" % [
		str((legendary.get("_shimmer_overlay") as ColorRect).size),
		str((legendary.get("_glow_overlay") as ColorRect).size),
		str(legendary.size)])
	await _settle(4)
	await _capture(vp, "cards_hover_foil")

	# 特写：单独一张传说卡放大渲染，检查闪箔带 / 辉光 / 视差是否可见。
	var solo := SubViewport.new()
	solo.size = Vector2i(480, 640)
	solo.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(solo)
	var spaper := ColorRect.new()
	spaper.color = GuStyle.PAPER_BG
	spaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	solo.add_child(spaper)
	await _settle(1)
	var big: Control = GuCardScene.instantiate()
	big.custom_minimum_size = Vector2(320, 440)
	big.position = Vector2(80, 100)
	solo.add_child(big)
	big.setup("月光蛊", "传说", false, false, false, "3",
			false, false, false, "idle", "消耗2真元·吸取3气血，月华护体")
	await _settle(3)
	big.call("_set_tilt", Vector2(0.45, -0.55))
	var bglow: ShaderMaterial = (big.get("_glow_overlay") as ColorRect).material
	bglow.set_shader_parameter("on", 1.0)
	var bfoil: ShaderMaterial = (big.get("_shimmer_overlay") as ColorRect).material
	bfoil.set_shader_parameter("anim_time", 3.0)
	await _settle(4)
	await _capture(solo, "card_foil_closeup")

	print("[CARD] FAILED=%d" % _failed)
	quit(1 if _failed > 0 else 0)


func _capture(vp: SubViewport, state: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	if tex == null:
		print("[CARD] FAIL no render target for %s" % state)
		_failed += 1
		return
	var img := tex.get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var out := ProjectSettings.globalize_path(OUT_DIR) + "/gu_card_" + state + ".png"
	img.save_png(out)
	print("[CARD] SAVED %s %dx%d" % [out, img.get_width(), img.get_height()])


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame
