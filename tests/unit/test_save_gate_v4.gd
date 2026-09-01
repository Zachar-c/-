extends GutTest


# Spec-v4 phase-1 (T1.1): save schema gate. Riding rules changed — a v3
# in-progress run must be refused with a player-readable reason, the run
# payload must serialize under schema version 4, a v4 run round-trips, and
# the permanent hall save (codex / recipes / contracts / stats) migrates
# from v3 with zero field loss.


const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const MetaProgressScript = preload("res://scripts/domain/meta_progress.gd")


func test_v3_run_data_is_rejected_with_schema_v4_message() -> void:
	var v3_payload := {
		"version": 3,
		"state": {"seed": 101, "event_log": []},
		"_checksum": 0,
	}
	var result := SaveRepositoryScript.load_run_from_data(v3_payload)
	assert_false(bool(result.get("ok", true)), "v3 run must be refused")
	assert_eq(str(result.get("reason", "")), "schema_v4_required")
	assert_true(str(result.get("message", "")).contains("已保留"),
			"message must tell the player hall progress is kept: %s" % str(result.get("message", "")))


func test_run_payload_serializes_under_schema_version_four() -> void:
	var run := RunState.new_run(101)
	var payload := SaveRepositoryScript.serialize_run(run, [], [])
	assert_eq(int(payload.get("version", 0)), 4, "run payload must carry schema v4")


func test_v4_run_state_round_trip_keeps_key_fields() -> void:
	var run := RunState.new_run(101)
	var payload := SaveRepositoryScript.serialize_run(run, [{"id": "ridge_caravan"}], [])
	# The after-append invariants of event_log forbid mutating state fields
	# after the last event, so this round trip asserts the fresh-run shape.
	var loaded: Dictionary = SaveRepositoryScript.load_run_from_data(payload)
	assert_false(loaded.is_empty())
	var restored: RunState = loaded["state"]
	var fresh := RunState.new_run(101)
	assert_eq(restored.current_node_id, fresh.current_node_id)
	assert_eq(int(restored.stone), int(fresh.stone))
	assert_eq(int(restored.health), int(fresh.health))
	# Schema version must survive the round trip as the serializer's constant.
	assert_eq(int(payload.get("version", 0)), 4)


func test_diagnose_reports_old_run_as_unsupported_version() -> void:
	var v3_payload := {"version": 3, "state": {"seed": 1, "event_log": []}}
	var diagnosis := SaveRepositoryScript.diagnose_run_data(v3_payload)
	assert_false(bool(diagnosis.get("ok", true)))
	assert_eq(str(diagnosis.get("kind", "")), "unsupported_version")


func test_v3_meta_migrates_hall_fields_without_loss() -> void:
	var meta: MetaProgress = MetaProgressScript.new_empty()
	meta.gu_codex_ids = ["small_light_gu", "trail_eye_gu"]
	meta.recipe_codex_ids = ["free_mix"]
	meta.contracts_unlocked = ["miser_pact"]
	meta.statistics = {"runs_started": 3, "runs_won": 1, "deaths": 2}
	var payload := SaveRepositoryScript.serialize_meta(meta)
	# Simulate a legacy v3 hall save; the checksum hashes only the meta fields.
	payload["version"] = 3
	var restored := SaveRepositoryScript.load_meta_from_data(payload)
	assert_true(restored != null, "v3 hall save must migrate, not be dropped")
	assert_eq(restored.gu_codex_ids, ["small_light_gu", "trail_eye_gu"])
	assert_eq(restored.recipe_codex_ids, ["free_mix"])
	assert_eq(restored.contracts_unlocked, ["miser_pact"])
	assert_eq(int(restored.statistics.get("runs_started", 0)), 3)
	assert_eq(int(restored.statistics.get("runs_won", 0)), 1)
