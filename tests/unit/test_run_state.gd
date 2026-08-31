extends GutTest


func test_new_run_records_aptitude_capacity_and_next_feeding() -> void:
	var state := RunState.new_run(101)
	assert_eq(state.aptitude, "bing")
	assert_eq(state.essence_capacity, 20)
	assert_eq(state.estimate_feeding(ContentCatalog.load_all()), 1)


func test_append_event_returns_new_state_without_changing_old_state() -> void:
	var before := RunState.new_run(101)
	var after := before.append_event(EventFactory.resource_changed(
		"stone", 12, 9, "buy_information", "market"
	))
	assert_eq(before.stone, 12)
	assert_eq(before.event_log.size(), 1)
	assert_eq(after.stone, 9)
	assert_eq(after.event_log.size(), 2)
	assert_eq(after.event_log.back()["reason"], "buy_information")
	assert_eq(after.event_log.back()["id"], "event_0001")


func test_save_data_preserves_event_log_order() -> void:
	var state := RunState.new_run(101)
	var after := state.append_event(EventFactory.resource_changed(
		"essence", 3, 2, "scout", "trail"
	))
	var save_data := after.to_save_data()
	assert_eq(save_data["seed"], 101)
	assert_eq(save_data["event_log"].size(), 2)
	assert_eq(save_data["event_log"][0]["id"], "event_0000")
	assert_eq(save_data["event_log"][1]["id"], "event_0001")
