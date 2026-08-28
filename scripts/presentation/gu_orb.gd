class_name GuOrb
extends Control


const SIZE := 34.0
const CENTER := 17.0
const RING := 13.0
const INK := GuStyle.INK_PRIMARY
const INK_RING := GuStyle.INK_SOFT

const GU_COLORS := {
	"small_light_gu": Color("cfe9e2"),
	"moonlight_gu": Color("cdd6c9"),
	"moon_glow_gu": Color("e6d3a0"),
	"phantom_moon_gu": Color("9fb8d8"),
	"moon_shadow_gu": Color("8a7fb0"),
	"stone_shell_gu": Color("9aa0a3"),
	"trail_eye_gu": Color("7fb06a"),
	"thorn_whip_gu": Color("6b8f4f"),
	"blood_moss_gu": Color("b0554a"),
	"mist_step_gu": Color("b8cdd4"),
	"venom_thread_gu": Color("7ba84f"),
	"shadow_veil_gu": Color("6f5f8f"),
	"pulse_drum_gu": Color("b06a4a"),
}


var gu_id := "":
	set(value):
		gu_id = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var accent: Color = GU_COLORS.get(gu_id, Color("a9b8b5"))
	draw_circle(Vector2(CENTER, CENTER), RING + 1.5, INK)
	draw_circle(Vector2(CENTER, CENTER), RING, INK_RING)
	draw_circle(Vector2(CENTER, CENTER), 8.0, Color(accent.r, accent.g, accent.b, 0.25))
	draw_circle(Vector2(CENTER, CENTER), 6.0, accent)
	draw_circle(Vector2(CENTER - 2.2, CENTER - 2.2), 2.0, Color(1, 1, 1, 0.5))
