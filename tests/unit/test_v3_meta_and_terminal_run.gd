extends GutTest


const META_PROGRESS_PATH := "res://scripts/domain/meta_progress.gd"


func test_meta_progress_records_only_codex_and_death_statistics() -> void:
	var meta_script: Script = load(META_PROGRESS_PATH)
	if meta_script == null:
		fail_test("MetaProgress script should exist")
		return
	var run := RunState.new_run(101)
	run.stone = 99
	var meta = meta_script.new()
	var next = meta.record_run_end(run, "dead")
	var saved: Dictionary = next.to_save_data()

	assert_false(saved.has("stone"))
	assert_false(saved.has("gu_instances"))
	assert_eq(saved["gu_codex_ids"], ["small_light_gu"])
	assert_eq(saved["statistics"]["deaths"], 1)


func test_meta_empty_factory_and_terminal_state_are_explicit() -> void:
	var meta_script: Script = load(META_PROGRESS_PATH)
	var meta = meta_script.new_empty()
	var run := RunState.new_run(101)
	run.terminal_state = "dead"

	assert_eq(meta.to_save_data()["statistics"]["deaths"], 0)
	assert_true(run.is_terminal())

func test_meta_save_uses_a_separate_global_only_payload() -> void:
	var meta_script: Script = load(META_PROGRESS_PATH)
	var meta = meta_script.new_empty()
	var saved: Dictionary = SaveRepository.serialize_meta(meta)
	var loaded = SaveRepository.load_meta_from_data(saved)

	assert_false(saved.has("state"))
	assert_false(saved.has("route"))
	assert_eq(loaded.to_save_data(), meta.to_save_data())