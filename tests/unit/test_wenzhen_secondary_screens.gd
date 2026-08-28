extends GutTest


const SECONDARY_SCREENS := [
	"res://ui/screens/encounter_screen.guitkx",
	"res://ui/screens/shop_screen.guitkx",
	"res://ui/screens/npc_screen.guitkx",
	"res://ui/screens/rest_screen.guitkx",
	"res://ui/screens/refine_screen.guitkx",
	"res://ui/screens/reward_screen.guitkx",
	"res://ui/screens/ending_screen.guitkx",
]


func test_secondary_screens_keep_one_decision_surface_and_no_nested_cards() -> void:
	for screen_path in SECONDARY_SCREENS:
		var source := FileAccess.get_file_as_string(screen_path)
		assert_eq(_count(source, "<GuTopBar"), 1, screen_path + " must keep one persistent top bar")
		assert_eq(_count(source, 'name="primary_decision_surface"'), 1,
				screen_path + " must expose one primary decision surface")
		assert_false(source.contains('<GuPanel title="蛊虫 / 货物">') or source.contains('<GuPanel title="奖励选项">'),
				screen_path + " must not wrap repeatable item cards in another framed decision panel")


func _count(source: String, needle: String) -> int:
	return source.count(needle)
