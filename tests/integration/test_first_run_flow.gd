extends GutTest


func test_fixed_run_reaches_caravan_then_ascension_view() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	assert_eq(controller.current_view_name(), "Map")
	controller.submit_command({"type": "travel", "node_id": "caravan_missing_goods"})
	assert_eq(controller.current_view_name(), "Encounter")
	controller.force_complete_for_test()
	assert_eq(controller.current_view_name(), "Ending")
	controller.free()
