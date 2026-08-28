class_name ResourceIcon
extends Control


const SIZE := 34.0
const CENTER := 17.0
const RING := 13.0
const INK := GuStyle.INK_PRIMARY
const INK_RING := GuStyle.INK_SOFT

const ACCENTS := {
	"stone": Color("5f9d8a"),
	"essence": Color("7fd0c0"),
	"lifespan": Color("d9b56a"),
	"soul": Color("7fa5d8"),
	"injury": Color("c0523e"),
	"material": Color("8aa85c"),
	"intel": Color("c9a35a"),
	"relic": Color("9a7fb5"),
}


var kind := "stone":
	set(value):
		kind = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_circle(Vector2(CENTER, CENTER), RING + 1.5, INK)
	draw_circle(Vector2(CENTER, CENTER), RING, INK_RING)
	var accent: Color = ACCENTS.get(kind, Color.WHITE)
	_draw_glyph(accent)


func _draw_glyph(accent: Color) -> void:
	match kind:
		"stone":
			draw_circle(Vector2(CENTER, CENTER), 6.5, accent)
			draw_circle(Vector2(CENTER - 2.2, CENTER - 2.2), 1.8, Color(1, 1, 1, 0.55))
		"essence":
			draw_circle(Vector2(CENTER, CENTER), 5.5, accent)
			draw_circle(Vector2(CENTER, CENTER), 2.2, Color(1, 1, 1, 0.8))
		"lifespan":
			draw_rect(Rect2(CENTER - 1.5, CENTER - 2.0, 3.0, 7.0), accent)
			draw_circle(Vector2(CENTER, CENTER - 3.5), 3.0, Color("f0c26a"))
			draw_rect(Rect2(CENTER - 5.5, CENTER + 5.0, 11.0, 1.8), accent)
		"soul":
			draw_circle(Vector2(CENTER, CENTER + 2.5), 5.0, accent)
			draw_circle(Vector2(CENTER, CENTER - 3.5), 3.2, accent)
			draw_circle(Vector2(CENTER, CENTER + 1.5), 1.6, Color(1, 1, 1, 0.5))
		"injury":
			var points := PackedVector2Array([
				Vector2(CENTER - 6.5, CENTER - 6.5),
				Vector2(CENTER + 6.5, CENTER - 6.5),
				Vector2(CENTER + 6.5, CENTER + 6.5),
				Vector2(CENTER - 6.5, CENTER + 6.5),
			])
			draw_colored_polygon(points, accent)
			draw_line(Vector2(CENTER - 4.5, CENTER + 5.0), Vector2(CENTER - 1.5, CENTER), Color(0, 0, 0, 0.4), 1.6)
			draw_line(Vector2(CENTER - 1.5, CENTER), Vector2(CENTER + 2.5, CENTER - 3.5), Color(0, 0, 0, 0.4), 1.6)
		"material":
			var pouch := PackedVector2Array([
				Vector2(CENTER - 5.5, CENTER + 5.0),
				Vector2(CENTER, CENTER - 5.5),
				Vector2(CENTER + 5.5, CENTER + 5.0),
			])
			draw_colored_polygon(pouch, accent)
			draw_circle(Vector2(CENTER, CENTER - 5.5), 1.6, accent)
		"intel":
			draw_rect(Rect2(CENTER - 6.5, CENTER - 4.5, 13.0, 9.0), accent)
			draw_line(Vector2(CENTER - 4.5, CENTER - 1.5), Vector2(CENTER + 4.5, CENTER - 1.5), INK, 1.4)
			draw_line(Vector2(CENTER - 4.5, CENTER + 1.5), Vector2(CENTER + 4.5, CENTER + 1.5), INK, 1.4)
		"relic":
			var gem := PackedVector2Array([
				Vector2(CENTER, CENTER - 7.0),
				Vector2(CENTER + 5.5, CENTER),
				Vector2(CENTER, CENTER + 7.0),
				Vector2(CENTER - 5.5, CENTER),
			])
			draw_colored_polygon(gem, accent)
			draw_circle(Vector2(CENTER, CENTER), 2.2, Color(1, 1, 1, 0.45))
