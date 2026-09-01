extends Control
## 地图路径连线层：只画节点之间的连线，不持有任何拓扑状态。
##
## 几何由 MapScreenView 算好后整体喂进来（from/to/hot），本层只负责 _draw。
## hot（已选分支）走朱砂 2px，其余走发丝线 1px。

var _segments: Array = []


func set_segments(segments: Array) -> void:
	_segments = segments
	queue_redraw()


func _draw() -> void:
	for segment in _segments:
		var hot := bool(segment.get("hot", false))
		var color := GuStyle.CINNABAR if hot else GuStyle.HAIRLINE_COLOR
		var width := 2.0 if hot else 1.0
		draw_line(segment["from"], segment["to"], color, width, true)
