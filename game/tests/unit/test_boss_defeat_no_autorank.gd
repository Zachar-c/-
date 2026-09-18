extends GutTest


func before_each() -> void:
	pass


func test_boss_defeat_no_longer_changes_cultivation() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	state.cultivation = 2
	state.essence_capacity = 30
	state.cave_aperture["essence_max"] = 30
	var result := Resolver.apply(state, {"type": "record_layer_boss_defeated", "layer": 2}, catalog)
	assert_true(bool(result["result"]["ok"]))
	assert_eq(result["state"].cultivation, 2)
	assert_eq(result["state"].essence_capacity, 30)
	assert_eq(str(result["state"].node_flags.get("boss_defeated_L2", "")), "true")
