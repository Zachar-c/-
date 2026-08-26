class_name UiTheme
extends RefCounted


# Dependency-free palette + small factory helpers shared by all presentation
# scripts. This file never touches RunState or any domain logic; it only knows
# the 蛊真人 grim-dark palette, rarity colors, and how to spin up themed nodes.

const THEME := preload("res://assets/theme/gu_theme.tres")

const GOLD := Color("e7c883")
const JADE := Color("b8d5cc")
const BG := Color("241c16")
const BG_DEEP := Color("1a1410")
const DANGER := Color("ff5a4d")
const CURSE := Color("c0152f")
const CONTRACT := Color("5a8bd6")
const DDA := Color("ffcc55")
const DDA_YELLOW := Color("ffcc55")
const DDA_RED := Color("ff7766")

const RARITY_COLORS := {
	"common": Color("b8d5cc"),
	"rare": Color("5a8bd6"),
	"epic": Color("9f7fd6"),
	"legendary": Color("e7c883"),
}

const CURSE_GLYPH := "⚠"
const CONTRACT_GLYPH := "契"
const DDA_GLYPH := "异"


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(str(rarity), JADE)


static func contract_color() -> Color:
	return CONTRACT


static func curse_color() -> Color:
	return CURSE


static func dda_color() -> Color:
	return DDA


static func _panel_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = JADE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = THEME
	p.add_theme_stylebox_override("panel", _panel_stylebox())
	return p


static func button(text: String, enabled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.theme = THEME
	return b


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.theme = THEME
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
