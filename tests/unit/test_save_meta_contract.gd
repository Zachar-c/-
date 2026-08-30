extends GutTest


const SaveScript = preload("res://scripts/domain/save_repository.gd")
const MetaScript = preload("res://scripts/domain/meta_progress.gd")


func test_run_save_diagnosis_distinguishes_unsupported_version() -> void:
	var diagnosis: Dictionary = SaveScript.diagnose_run_data({"version": 2})
	assert_false(diagnosis.get("ok", true))
	assert_eq(diagnosis.get("kind", ""), "unsupported_version")
	assert_eq(int(diagnosis.get("version", -1)), 2)


func test_meta_save_contract_round_trips_through_single_factory() -> void:
	var meta: MetaProgress = MetaScript.new_empty()
	meta.gu_codex_ids = ["thorn_whip_gu"]
	meta.contracts_unlocked = ["hardship"]
	meta.hall_material_bonus_accrued = 7
	var restored: MetaProgress = MetaScript.from_save_data(meta.to_save_data())
	assert_eq(restored.to_save_data(), meta.to_save_data())


func test_meta_save_contract_defaults_missing_fields_and_ignores_unknown() -> void:
	var restored: MetaProgress = MetaScript.from_save_data({"unknown_field": "ignored"})
	assert_eq(restored.gu_codex_ids, [])
	assert_eq(restored.statistics.get("runs_started", -1), 0)
	assert_true(restored.dda_state_adaptive_enabled)
