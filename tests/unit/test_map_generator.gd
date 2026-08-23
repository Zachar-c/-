extends GutTest


func test_first_run_contains_required_anchor_nodes() -> void:
	var route := MapGenerator.build(101, true)
	var ids := route.map(func(node: Dictionary): return node["id"])
	assert_eq(route.size(), 15)
	assert_true(ids.has("ridge_caravan"))
	assert_true(ids.has("blood_moss_grove"))
	assert_true(ids.has("ridge_black_market"))
	assert_true(ids.has("echo_cave"))
	assert_eq(ids.back(), "stage_one_ledger")


func test_same_seed_builds_same_non_first_route() -> void:
	assert_eq(MapGenerator.build(202, false), MapGenerator.build(202, false))
	assert_false(MapGenerator.build(202, false).is_empty())


func test_generated_route_does_not_repeat_required_contest() -> void:
	for seed in range(1, 40):
		var route := MapGenerator.build(seed, false)
		var contest_count := route.filter(func(node: Dictionary): return node["id"] == "earth_vein_contest").size()
		assert_eq(contest_count, 1, "seed %s repeats earth vein contest" % seed)


func test_first_run_only_reveals_current_and_next_node() -> void:
	var route := MapGenerator.build(101, true)
	assert_true(route[0]["visible"])
	assert_true(route[1]["visible"])
	assert_false(route[2]["visible"])
