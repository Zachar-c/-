extends GutTest


# Task C1-min §16.13 part 2: hall-side persistence (ending-bound unlocks,
# display-only hall material bonus ledger), meta save round-trip tolerance
# for old saves, controller wiring for opening swears and snapshot exposure.


const META_SAVE_PATH := "user://nanjiang_smoke_meta.json"

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()
	# Hermetic meta: ending-bound contract unlocks recorded by other suites
	# (integration ending flows) must not leak into these swearing assertions.
	var meta_path := ProjectSettings.globalize_path(META_SAVE_PATH)
	if FileAccess.file_exists(META_SAVE_PATH):
		DirAccess.remove_absolute(meta_path)


func _run_with(ids: Array) -> RunState:
	var run := RunState.new_run(101)
	var typed: Array[String] = []
	for id in ids:
		typed.append(str(id))
	run.contracts = typed
	return run


func _any_contains(values: Array, needle: String) -> bool:
	for value in values:
		if str(value).contains(needle):
			return true
	return false


func _by_id(rows: Array, id: String) -> Dictionary:
	for value in rows:
		if value is Dictionary and str(value.get("id", "")) == id:
			return value
	return {}


func _any_locked(rows: Array) -> bool:
	for value in rows:
		if value is Dictionary and bool(value.get("locked", false)):
			return true
	return false


func test_record_run_end_unlocks_ending_bound_contract_on_matching_etype() -> void:
	var meta := MetaProgress.new_empty()
	meta = meta.record_run_end(_run_with(["ascetic_path"]), "risky", catalog, "risky")
	assert_true(meta.contracts_unlocked.has("ascetic_path"))
	assert_eq(int(meta.hall_material_bonus_accrued), 50)

	var wrong_etype := MetaProgress.new_empty()
	wrong_etype = wrong_etype.record_run_end(_run_with(["ascetic_path"]), "dead", catalog, "death")
	assert_eq(wrong_etype.contracts_unlocked, [])
	assert_eq(int(wrong_etype.hall_material_bonus_accrued), 0)

	var no_etype := MetaProgress.new_empty()
	no_etype = no_etype.record_run_end(_run_with(["ascetic_path"]), "dead", catalog)
	assert_eq(no_etype.contracts_unlocked, [])


func test_hall_material_bonus_accrues_only_on_won_or_risky_runs() -> void:
	var won := MetaProgress.new_empty()
	won = won.record_run_end(_run_with(["ascetic_path"]), "won", catalog, "success")
	assert_eq(int(won.hall_material_bonus_accrued), 50)

	var dead := MetaProgress.new_empty()
	dead = dead.record_run_end(_run_with(["ascetic_path"]), "dead", catalog, "death")
	assert_eq(int(dead.hall_material_bonus_accrued), 0)

	var without_contract := MetaProgress.new_empty()
	without_contract = without_contract.record_run_end(_run_with([]), "won", catalog, "success")
	assert_eq(int(without_contract.hall_material_bonus_accrued), 0)

	var stacked := MetaProgress.new_empty()
	stacked = stacked.record_run_end(_run_with(["ascetic_path"]), "won", catalog, "success")
	stacked = stacked.record_run_end(_run_with(["ascetic_path"]), "risky", catalog, "risky")
	assert_eq(int(stacked.hall_material_bonus_accrued), 100)


func test_unlocked_contracts_combine_always_and_ending_unlocks() -> void:
	var fresh := MetaProgress.new_empty()
	assert_eq(fresh.unlocked_contracts(catalog), ["blood_pact", "miser_pact", "essence_tide", "enemy_vitality_trial"])

	var veteran := MetaProgress.new_empty()
	var unlocked: Array[String] = ["ascetic_path"]
	veteran.contracts_unlocked = unlocked
	assert_eq(veteran.unlocked_contracts(catalog),
			["blood_pact", "miser_pact", "essence_tide", "ascetic_path", "enemy_vitality_trial"])



func test_meta_save_round_trip_carries_new_fields_and_defaults_old_saves() -> void:
	var meta := MetaProgress.new_empty()
	var unlocked: Array[String] = ["ascetic_path"]
	meta.contracts_unlocked = unlocked
	meta.hall_material_bonus_accrued = 150
	var loaded = SaveRepository.load_meta_from_data(SaveRepository.serialize_meta(meta))
	assert_not_null(loaded)
	assert_eq(loaded.contracts_unlocked, ["ascetic_path"])
	assert_eq(int(loaded.hall_material_bonus_accrued), 150)

	var legacy_data := {
		"gu_codex_ids": [],
		"recipe_codex_ids": [],
		"relic_codex_ids": [],
		"inheritance_codex_ids": [],
		"unlocked_content_ids": [],
		"unlocked_random_outcomes": {},
		"statistics": {"runs_started": 1, "runs_won": 0, "deaths": 0},
	}
	var legacy_payload := {
		"version": SaveRepository.SAVE_VERSION,
		"meta": legacy_data,
		"_checksum": SaveRepository._checksum_value(legacy_data),
	}
	var legacy = SaveRepository.load_meta_from_data(legacy_payload)
	assert_not_null(legacy)
	assert_eq(legacy.contracts_unlocked, [])
	assert_eq(int(legacy.hall_material_bonus_accrued), 0)


func test_controller_start_new_run_swears_allowed_and_reports_rejections() -> void:
	var controller: RunController = autofree(load("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	await get_tree().process_frame

	controller.start_new_run(101, "force", ["blood_pact"])
	assert_eq(controller.state.contracts, ["blood_pact"])

	controller.start_new_run(102, "", ["ascetic_path"])
	assert_eq(controller.state.contracts, [])
	assert_true(controller.last_feedback.contains("contract_locked"), controller.last_feedback)

	controller.start_new_run(103, "", [])
	assert_eq(controller.state.contracts, [])


func test_snapshots_expose_available_and_sworn_contracts() -> void:
	var controller: RunController = autofree(load("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(104, "force", ["blood_pact"])

	var hall: Dictionary = RunSnapshotBuilder.hall(controller)
	var listed: Array = hall["contracts"]
	assert_eq(listed.size(), 5)
	# 结构化契约行（§15/§16.13）：id/name/desc/locked/selected，勾选态镜像控制器。
	assert_true(_any_contains(listed, "血契"), str(listed))
	assert_true(_any_contains(listed, "+30%"), str(listed))
	assert_true(_any_contains(listed, "未解锁") == false or _any_locked(listed), str(listed))
	var blood := _by_id(listed, "blood_pact")
	assert_true(not blood.is_empty() and bool(blood.get("selected", false)), str(listed))
	var ascetic := _by_id(listed, "ascetic_path")
	assert_true(bool(ascetic.get("locked", true)), str(listed))

	var map_snapshot: Dictionary = controller._snapshot_for("Map")
	assert_eq(map_snapshot["contracts"], ["血契"])
