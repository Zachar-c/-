class_name ScreenTransition
extends ColorRect
## 全屏转场遮蔽层（main.tscn 常驻，挂在 TransitionLayer 下）。
##
## 与 RunController._play_screen_fade() 的分工：
##   _play_screen_fade 只对 RUIHost 做 0.14s 淡入（同屏命令重渲染不闪），盖不到背景纸和调试面板。
##   本层盖住整屏，用于需要暂时遮住全部 UI 的场合（进出战斗、结局、跨场景）。
## 默认全透明 + mouse_filter IGNORE，未调用时完全不参与渲染与输入。

const FADE_SECONDS := 0.22

var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0, 0, 0, 0)


## 淡入黑幕（0 -> 1）。instant=true 时直接置满，不播动画。
func cover(instant := false) -> void:
	_kill_tween()
	if instant:
		color.a = 1.0
		return
	_tween = create_tween()
	_tween.tween_property(self, "color:a", 1.0, FADE_SECONDS)


## 淡出黑幕（1 -> 0），恢复可交互。
func reveal(instant := false) -> void:
	_kill_tween()
	if instant:
		color.a = 0.0
		return
	_tween = create_tween()
	_tween.tween_property(self, "color:a", 0.0, FADE_SECONDS)


## 一次性全遮再揭开，用于需要"断一下"的转场。
func blink() -> void:
	cover()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "color:a", 1.0, FADE_SECONDS)
	_tween.tween_property(self, "color:a", 0.0, FADE_SECONDS)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
