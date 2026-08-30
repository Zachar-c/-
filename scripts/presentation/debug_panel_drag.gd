class_name DebugPanelDrag
extends Control

# 调试面板拖拽宿主：仅顶部标题栏可拖拽，防止误拖内部控件。

const HEADER_HEIGHT := 36.0

var _dragging := false
var _drag_offset := Vector2()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var in_header: bool = event.position.y < HEADER_HEIGHT
			_dragging = event.pressed and in_header
			if _dragging:
				_drag_offset = get_global_mouse_position() - global_position
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
