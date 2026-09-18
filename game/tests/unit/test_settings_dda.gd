extends "res://addons/gut/test.gd"


# A6 settings DDA toggle (R14.6⑧): the hall settings surface exposes a
# toggle_dda command that flips the meta-level boolean and persists via
# save round-trip. The snapshot builder must surface the current value.


const RunCommandBuilderScript := preload("res://scripts/presentation/run_command_builder.gd")
const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")
const MetaProgressScript := preload("res://scripts/domain/meta_progress.gd")
const SaveRepositoryScript := preload("res://scripts/domain/save_repository.gd")
const RunSnapshotBuilderScript := preload("res://scripts/presentation/run_snapshot_builder.gd")


func test_title_command_surface_exposes_toggle_dda() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	var commands := RunCommandBuilderScript.for_screen("Title", controller)
	assert_true(commands.has("toggle_dda"), "Title must expose a toggle_dda command")


func test_toggle_dda_flips_the_meta_boolean() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	var meta = MetaProgressScript.new_empty()
	assert_true(meta.dda_state_adaptive_enabled, "default should be ON")
	controller.meta = meta
	controller.toggle_dda()
	assert_false(meta.dda_state_adaptive_enabled, "toggle_dda should flip to OFF")
	controller.toggle_dda()
	assert_true(meta.dda_state_adaptive_enabled, "toggle_dda should flip back to ON")


func test_toggle_dda_persists_through_serialization_round_trip() -> void:
	var meta = MetaProgressScript.new_empty()
	meta.dda_state_adaptive_enabled = false
	var data := SaveRepositoryScript.serialize_meta(meta)
	var loaded = SaveRepositoryScript.load_meta_from_data(data)
	assert_false(loaded.dda_state_adaptive_enabled, "serialized OFF should survive round-trip")


func test_hall_snapshot_surfaces_dda_state() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	var meta = MetaProgressScript.new_empty()
	meta.dda_state_adaptive_enabled = false
	controller.meta = meta
	var snapshot := RunSnapshotBuilderScript.hall(controller)
	assert_false(snapshot.get("dda_state_adaptive_enabled", true),
		"hall snapshot must reflect DDA OFF")


func test_toggle_dda_no_op_when_meta_is_null() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.meta = null
	controller.toggle_dda()  # should not crash
	assert_null(controller.meta, "meta should remain null")
