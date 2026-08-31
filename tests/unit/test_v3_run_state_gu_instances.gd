extends GutTest


func test_new_run_serializes_bing_cultivator_and_unbounded_aperture() -> void:
	var run := RunState.new_run(101)
	var saved := run.to_save_data()

	assert_true(saved.has("cultivator"))
	assert_eq(saved["cultivator"]["aptitude"], "bing")
	assert_eq(saved["cave_aperture"]["essence_max"], 20)
	assert_eq(saved["cave_aperture"]["essence_regen_per_turn"], 4)
	assert_false(saved["cave_aperture"].has("gu_capacity"))
	assert_false(saved["cave_aperture"].has("gu_slot_limit"))


func test_refined_instance_projection_keeps_legacy_ids_compatible() -> void:
	var run := RunState.new_run(101)
	run.gu_instances["gu_002"] = {
		"instance_id": "gu_002",
		"definition_id": "stone_shell_gu",
		"state": "refined",
	}
	run.cave_aperture["stored_gu_instance_ids"].append("gu_002")

	run.sync_legacy_gu_projections()

	assert_eq(run.refined_gu_ids, ["small_light_gu", "stone_shell_gu"])
	assert_eq(run.refined_instances().size(), 2)

func test_save_round_trip_preserves_structured_run_state() -> void:
	var run := RunState.new_run(101)
	run.cultivator["soul"] = 3
	run.cave_aperture["essence"] = 2
	var saved := SaveRepository.serialize_run(run, [], [])
	var loaded := SaveRepository.load_run_from_data(saved)

	assert_eq(loaded["state"].cultivator["soul"], 3)
	assert_eq(loaded["state"].cave_aperture["essence"], 2)
	assert_true(loaded["state"].gu_instances.has("gu_001"))