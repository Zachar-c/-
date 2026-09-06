extends GutTest

const SCAN_FILES := [
	"scripts/presentation/screens/hall_screen_view.gd",
	"scenes/ui/screens/hall_screen.tscn",
	"ui/widgets/gu_resource_chip.guitkx",
	"ui/widgets/gu_resource_chip.gd",
	"scripts/presentation/gu_orb.gd",
	"scripts/presentation/resource_icon.gd",
]
const FORBIDDEN_PALETTE_NAMES := [
	"HALL_PAPER", "HALL_INK", "HALL_SOFT", "HALL_FAINT", "HALL_RULE", "HALL_RED", "HALL_BLUE", "HALL_YELLOW",
	"MAP_PAPER", "MAP_INK", "MAP_MUTED", "MAP_RULE", "MAP_RED", "MAP_BLUE", "MAP_YELLOW",
]


func test_formal_ui_uses_gu_style_for_shared_palette() -> void:
	for path in SCAN_FILES:
		var source := FileAccess.get_file_as_string("res://" + path)
		for token in FORBIDDEN_PALETTE_NAMES:
			assert_false(source.contains(token), "%s still declares local palette %s" % [path, token])
		assert_false(source.contains("Color(\"e5e2d7\")"), "%s contains local paper color" % path)
		assert_false(source.contains("Color(\"e7e4da\")"), "%s contains local map paper color" % path)


func test_gu_and_resource_identification_palettes_remain_explicit() -> void:
	var orb := FileAccess.get_file_as_string("res://scripts/presentation/gu_orb.gd")
	var resource := FileAccess.get_file_as_string("res://scripts/presentation/resource_icon.gd")
	assert_true(orb.contains("GU_COLORS"))
	assert_true(resource.contains("ResourceVocabularyScript"))
	assert_true(resource.contains("GuStyle.resource_color"))
