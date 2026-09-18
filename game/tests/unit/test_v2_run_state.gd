extends GutTest


func test_new_v2_run_records_bing_aptitude_and_next_feeding() -> void:
	var state := RunState.new_run(101)
	assert_eq(state.aptitude, "bing")
	assert_eq(state.essence_capacity, 20)
	assert_eq(state.estimate_feeding(ContentCatalog.load_all()), 1)

