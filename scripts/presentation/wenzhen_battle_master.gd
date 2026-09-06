class_name WenzhenBattleMaster
extends Control


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const SCREEN = "res://ui/screens/battle_screen.gd"
const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuStyle = preload("res://scripts/presentation/gu_style.gd")

var _rui_root: RuitkRoot
var _host: Control


func _ready() -> void:
	_apply_static_theme()
	_apply_stage_background()
	_host = Control.new()
	_host.name = "BattleScreen"
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	_rui_root = RuiRoot.create(_host, VLib.fc(VLib.comp(SCREEN, "render"), {"state": {}, "commands": {}}))


## 战斗屏暗色舞台背景：青茅山背景+雾气+萤火，营造南疆志怪氛围。
## 背景层在_host之前添加，渲染在guitkx UI之下，不影响交互。
func _apply_stage_background() -> void:
	# 暗色舞台底色
	var stage_bg := ColorRect.new()
	stage_bg.color = GuStyle.STAGE_BG
	stage_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_bg.z_index = -10
	add_child(stage_bg)

	# 青茅山背景层（调暗半透明）
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/wenzhen/hall/qing-mao-mountain.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = GuStyle.STAGE_BACKDROP_DIM
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -9
	add_child(backdrop)

	# 暗角层
	var vignette_grad := Gradient.new()
	vignette_grad.set_color(0, Color(0, 0, 0, 0))
	vignette_grad.set_color(1, GuStyle.STAGE_VIGNETTE)
	var vignette_tex := GradientTexture2D.new()
	vignette_tex.gradient = vignette_grad
	vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	vignette_tex.width = 512
	vignette_tex.height = 512
	var vignette := TextureRect.new()
	vignette.texture = vignette_tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = -8
	add_child(vignette)

	# 雾气层
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
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.z_index = -7
	add_child(fog)
	var fog_tween := create_tween()
	fog_tween.set_loops()
	fog_tween.tween_property(fog, "modulate:a", 0.15, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fog_tween.tween_property(fog, "scale", Vector2(1.05, 1.02), 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fog_tween.tween_property(fog, "modulate:a", 0.08, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fog_tween.tween_property(fog, "scale", Vector2(1.0, 1.0), 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 萤火层
	for i in range(6):
		var firefly := ColorRect.new()
		firefly.color = GuStyle.FIREFLY_COLOR
		firefly.size = Vector2(3, 3)
		firefly.mouse_filter = Control.MOUSE_FILTER_IGNORE
		firefly.z_index = -6
		var sx := randf_range(100.0, 800.0)
		var sy := randf_range(100.0, 400.0)
		firefly.position = Vector2(sx, sy)
		add_child(firefly)
		var ft := create_tween()
		ft.set_loops()
		var bd := randf_range(2.0, 4.0)
		var dx := randf_range(-30.0, 30.0)
		var dy := randf_range(-20.0, 20.0)
		ft.tween_property(firefly, "color:a", 0.8, bd).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ft.tween_property(firefly, "position", Vector2(sx + dx, sy + dy), bd).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ft.tween_property(firefly, "color:a", 0.1, bd).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ft.tween_property(firefly, "position", Vector2(sx, sy), bd).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_static_theme() -> void:
	for node_name in ["RefineButton", "FleeButton", "EndTurnButton"]:
		var node := get_node_or_null("BattleHandZone/TurnActions/" + node_name)
		if node is Button:
			var role := "action"
			if node_name == "FleeButton":
				role = "cancel"
			elif node_name == "EndTurnButton":
				role = "danger"
			MasterTheme.apply_button(node, role)


func mount_snapshot(snapshot: Dictionary, commands: Dictionary) -> void:
	if _rui_root == null:
		return
	_rui_root.set_root(VLib.fc(VLib.comp(SCREEN, "render"), {"state": snapshot, "commands": commands}))
