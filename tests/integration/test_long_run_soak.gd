extends GutTest


# Task L1 R4 long-run soak: a scripted >=600-node-equivalent event flow built
# from synthetic append sequences shaped like real resolver payloads (bounded
# encounter feeds, battle finishes, loot gains, curse churn). Guards: serialized
# save JSON stays under 2MB, journal build stays under 2000ms, and meta
# attribution scans the whole log without errors while parsing unlocks.

const NODE_COUNT := 640


func _stage_for(index: int) -> String:
	return ["one", "two", "three", "four", "five"][index % 5]


func _append_node_events(state: RunState, index: int) -> RunState:
	var node_id := "soak_node_%04d" % index
	var session := {
		"node_id": node_id,
		"phase": "post_battle",
		"completion_reason": "battle_victory",
	}
	var feed := {
		"type": "encounter",
		"text_key": "contact_fight_started",
		"changes": {"stone": 1},
		"facts": [],
	}
	var results: Array[Dictionary] = [feed]
	state = state.append_event({
		"stage": _stage_for(index),
		"time": state.event_log.size(),
		"node_id": node_id,
		"action": "encounter_session",
		"before": {},
		"after": {"encounter_session": session, "encounter_results": results},
		"reason": "encounter_resolved",
		"source": "soak",
		"targets": [],
	})
	state.encounter_session = session.duplicate(true)
	state.encounter_results = results.duplicate(true)
	state = state.append_event({
		"stage": _stage_for(index),
		"time": state.event_log.size(),
		"node_id": node_id,
		"action": "battle_finished",
		"before": {},
		"after": {"encounter_session": session, "encounter_results": results},
		"reason": "battle_victory",
		"source": "run_controller",
		"targets": [],
	})
	state.encounter_session = session.duplicate(true)
	state.encounter_results = results.duplicate(true)
	if index % 8 == 0:
		state = CurseRegistry.gain_curse(state, "gu_erosion", "soak")
	if index % 16 == 0:
		var materials := state.materials.duplicate(true)
		materials["feed_points"] = int(materials.get("feed_points", 0)) + 1
		state = state.append_event({
			"stage": _stage_for(index),
			"time": state.event_log.size(),
			"node_id": node_id,
			"action": "battle_loot",
			"before": {"material_pity": state.material_pity},
			"after": {"materials": materials, "material_pity": 0},
			"reason": "loot_materials_gained",
			"source": "loot_resolver",
			"targets": ["feed_points"],
		})
		state.materials = materials
		state.material_pity = 0
	if index % 32 == 0:
		state = state.append_event({
			"stage": _stage_for(index),
			"time": state.event_log.size(),
			"node_id": node_id,
			"action": "refine_gu",
			"before": {},
			"after": {},
			"reason": "refinement_succeeded",
			"source": "resolver",
			"targets": ["recipe:free_mix"],
		})
	return state


func test_long_run_soak_keeps_serialization_journal_and_meta_within_budget() -> void:
	var state := RunState.new_run(20260826)
	for index in NODE_COUNT:
		state = _append_node_events(state, index)
	assert_gt(state.event_log.size(), NODE_COUNT * 2)

	var payload := SaveRepository.serialize_run(state, [], [])
	var text := JSON.stringify(payload)
	assert_lt(text.length(), 2 * 1024 * 1024,
			"serialized run JSON stays under 2MB (got %d chars)" % text.length())
	assert_false(SaveRepository.load_run_from_data(payload).is_empty())

	var journal_start_ms := Time.get_ticks_msec()
	var entries := JournalBuilder.build(state, {})
	var journal_ms := Time.get_ticks_msec() - journal_start_ms
	assert_gt(entries.size(), 0)
	assert_lt(journal_ms, 2000,
			"journal build stays under 2000ms (got %dms)" % journal_ms)

	var ended: RefCounted = MetaProgress.new_empty().record_run_end(state, "dead")
	assert_eq(int(ended.statistics["deaths"]), 1)
	assert_true(ended.recipe_codex_ids.has("free_mix"))
