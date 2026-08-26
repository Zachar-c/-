extends GutTest


# Task L1: event log slimming and long-run scaling guards.
# Covers R1 (shallow log sharing between states), R2 ("_"-prefixed info keys
# bypass state application and save validation while riding serialization),
# R4 (5000-append loose time budget) and the R5 legacy v2 save regression.


const APPEND_COUNT := 5000
const BUDGET_MS := 3000


func test_append_5000_events_stays_under_loose_budget() -> void:
	var state := RunState.new_run(101)
	var start_ms := Time.get_ticks_msec()
	for index in APPEND_COUNT:
		state = state.append_event(EventFactory.resource_changed(
			"stone", 12, 9, "scaling_probe_%d" % index, "market"
		))
	var elapsed_ms := Time.get_ticks_msec() - start_ms
	assert_eq(state.event_log.size(), APPEND_COUNT + 1)
	assert_lt(elapsed_ms, BUDGET_MS)


func test_appended_states_share_log_entries_and_old_state_stays_frozen() -> void:
	var first := RunState.new_run(101)
	var second := first.append_event(EventFactory.resource_changed(
		"stone", 12, 9, "share_probe", "market"
	))
	assert_eq(first.event_log.size(), 1)
	assert_eq(second.event_log.size(), 2)
	assert_true(is_same(second.event_log[0], first.event_log[0]))
	var third := second.append_event(EventFactory.resource_changed(
		"stone", 9, 7, "share_probe", "market"
	))
	assert_true(is_same(third.event_log[0], first.event_log[0]))
	assert_true(is_same(third.event_log[1], second.event_log[1]))
	assert_eq(first.event_log.size(), 1)
	assert_eq(second.event_log.size(), 2)
	assert_eq(third.event_log.size(), 3)


func test_underscore_info_keys_bypass_state_application() -> void:
	var state := RunState.new_run(101)
	var next := state.append_event({
		"stage": "one",
		"time": 1,
		"node_id": "market",
		"action": "state_change",
		"before": {"stone": 12},
		"after": {"stone": 5, "_debug_note": "attribution-only"},
		"reason": "underscore_probe",
		"source": "test",
		"targets": [],
	})
	assert_eq(int(next.stone), 5)
	assert_null(next.get("_debug_note"))
	var recorded: Dictionary = next.event_log.back()
	assert_true(recorded["after"].has("_debug_note"))


func test_underscore_info_keys_pass_save_validation_and_serialization() -> void:
	var state := RunState.new_run(101)
	var next := state.append_event({
		"stage": "one",
		"time": 1,
		"node_id": "market",
		"action": "state_change",
		"before": {},
		"after": {"essence": 2, "_debug_note": "attribution-only"},
		"reason": "underscore_probe",
		"source": "test",
		"targets": [],
	})
	var payload := SaveRepository.serialize_run(next, [], [])
	assert_true(JSON.stringify(payload).contains("_debug_note"))
	var loaded := SaveRepository.load_run_from_data(payload)
	assert_false(loaded.is_empty())
	assert_eq(
		str(loaded["state"].event_log.back()["after"]["_debug_note"]),
		"attribution-only"
	)


func test_legacy_v2_save_with_heavy_before_snapshot_still_loads() -> void:
	var state := RunState.new_run(101)
	var legacy_before := {
		"cultivator": state.cultivator.duplicate(true),
		"cave_aperture": state.cave_aperture.duplicate(true),
		"gu_instances": state.gu_instances.duplicate(true),
		"encounter_session": {"node_id": "market", "completed": true},
		"encounter_results": [{"type": "encounter", "text_key": "contact_fight_started"}],
		"materials": {"feed_points": 3},
	}
	var payload := SaveRepository.serialize_run(state, [], [])
	payload["state"]["event_log"].append({
		"id": "event_0001",
		"stage": "one",
		"time": 1,
		"node_id": "market",
		"action": "curse_gained",
		"before": legacy_before,
		"after": {"cultivator": state.cultivator.duplicate(true)},
		"reason": "backlash_curse_gained",
		"source": "legacy_writer",
		"targets": ["gu_erosion"],
	})
	payload["_checksum"] = SaveRepository._state_checksum(payload["state"])
	var loaded := SaveRepository.load_run_from_data(payload)
	assert_false(loaded.is_empty())
	assert_eq(str(loaded["state"].event_log[1]["action"]), "curse_gained")
