extends GutTest


const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")


func test_saved_reply_is_replayed_without_gateway_call() -> void:
	var state := RunState.new_run(101)
	var route := MapGenerator.build(101, true)
	var replies := [{
		"intent": "trade",
		"confidence": 0.9,
		"conditions": ["ledger_evidence"],
		"text": "管事收下账册证据，为你打开一条有人照看的路。",
		"needs_clarification": false,
	}]
	var saved := SaveRepository.serialize_run(state, route, replies)
	var gateway := CountingGateway.new()
	var loaded := SaveRepository.load_run_from_data(saved)
	assert_eq(loaded["replies"][0]["text"], "管事收下账册证据，为你打开一条有人照看的路。")
	assert_eq(gateway.calls, 0)


func test_save_round_trip_preserves_active_encounter_session() -> void:
	var state := RunState.new_run(101)
	state.health = 4
	state.encounter_session = {"node_id": "neutral_wanderer", "completed": false}
	state.encounter_results = [ResultFeedScript.entry("deceive", "contact_deceive_success", {"stone": 2}, [])]
	var saved := SaveRepository.serialize_run(state, MapGenerator.build(101, true), [])
	var loaded := SaveRepository.load_run_from_data(saved)

	assert_eq(loaded["state"].health, 4)
	assert_eq(loaded["state"].encounter_session["node_id"], "neutral_wanderer")
	assert_eq(loaded["state"].encounter_results[0]["text_key"], "contact_deceive_success")


func test_load_rejects_save_with_non_contiguous_event_ids() -> void:
	var state := RunState.new_run(101)
	var saved := SaveRepository.serialize_run(state, MapGenerator.build(101, true), [])
	saved["state"]["event_log"][0]["id"] = "event_0002"

	_assert_rejected(SaveRepository.load_run_from_data(saved), "invalid_event_log")


func test_load_rejects_save_with_tampered_state_checksum() -> void:
	var state := RunState.new_run(101)
	var saved := SaveRepository.serialize_run(state, MapGenerator.build(101, true), [])
	saved["state"]["seed"] = int(saved["state"]["seed"]) + 1

	_assert_rejected(SaveRepository.load_run_from_data(saved), "checksum_mismatch")


func test_load_rejects_save_without_checksum() -> void:
	var state := RunState.new_run(101)
	var saved := SaveRepository.serialize_run(state, MapGenerator.build(101, true), [])
	saved.erase("_checksum")

	_assert_rejected(SaveRepository.load_run_from_data(saved), "checksum_missing")


# Spec-v4 T1.1: rejected loads now carry {"ok": false, "reason": kind,
# "message": ...} and never a "state" key. This pins the refusal contract.
func _assert_rejected(loaded: Dictionary, expected_kind: String) -> void:
	assert_false(loaded.has("state"), "rejected loads must not carry state")
	assert_false(bool(loaded.get("ok", true)), "rejected loads must carry ok=false")
	assert_eq(str(loaded.get("reason", "")), expected_kind)


class CountingGateway extends DialogueGateway:
	var calls := 0

	func respond(_context: Dictionary) -> Dictionary:
		calls += 1
		return {}
