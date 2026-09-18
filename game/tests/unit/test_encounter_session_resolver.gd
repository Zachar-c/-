extends GutTest


const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")


func test_start_records_an_active_session_in_the_event_log() -> void:
	var state := RunState.new_run(101)
	state.encounter_results = [ResultFeedScript.entry("old", "old_result", {}, [])]
	var result := EncounterSessionResolverScript.begin(state, {"id": "ridge_caravan", "type": "caravan"})

	assert_false(result["session"]["completed"])
	assert_eq(result["state"].encounter_session["node_id"], "ridge_caravan")
	assert_eq(result["state"].event_log.back()["action"], "encounter_session")
	assert_eq(result["state"].encounter_results.size(), 1)
	assert_eq(result["state"].encounter_results[0]["text_key"], "node_entered")


func test_deceive_stays_in_contact_and_records_visible_result() -> void:
	var state := RunState.new_run(101)
	var session := EncounterSessionResolverScript.start({"id": "neutral_wanderer", "type": "contact"})
	var result := EncounterSessionResolverScript.apply(
		state,
		session,
		{"type": "resolve_contact", "node_id": "neutral_wanderer", "approach": "deceive"},
		ContentCatalog.load_all()
	)

	assert_false(result["session"]["completed"])
	assert_eq(result["state"].stone, state.stone + 2)
	assert_true(result["state"].known_facts.has("wanderer_misdirected"))
	assert_eq(result["feed"]["text_key"], "contact_deceive_success")
	assert_eq(result["state"].encounter_session["node_id"], "neutral_wanderer")


func test_explicit_leave_is_the_only_normal_completion() -> void:
	var state := RunState.new_run(101)
	state = Resolver.apply(state, {"type": "travel", "node_id": "neutral_wanderer"}, ContentCatalog.load_all())["state"]
	var session := EncounterSessionResolverScript.start({"id": "neutral_wanderer", "type": "contact"})
	var result := EncounterSessionResolverScript.apply(
		state,
		session,
		{"type": "leave_node"},
		ContentCatalog.load_all()
	)

	assert_true(result["session"]["completed"])
	assert_eq(result["session"]["completion_reason"], "player_left")
	assert_eq(result["state"].node_flags["neutral_wanderer"], "abandoned")


func test_action_card_rejects_stale_preview_before_executing_current_command() -> void:
	var state := RunState.new_run(101)
	var node := {"id": "ridge_caravan", "type": "caravan"}
	state.current_node_id = "ridge_caravan"
	var session := EncounterSessionResolverScript.start(node)
	state.encounter_session = session.duplicate(true)
	var result := EncounterSessionResolverScript.apply(state, session, {
		"type": "action_card",
		"action_id": "caravan.buy.buy_force_blow",
		"state_version": state.event_log.size() - 1,
		"node_id": "ridge_caravan",
		"session_node_id": "ridge_caravan",
	}, ContentCatalog.load_all(), node)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "action_preview_stale")
	assert_eq(result["state"].stone, state.stone)
	assert_eq(result["result"]["actual_changes"], [])
	assert_false(result["result"]["next_available_actions"].is_empty())


func test_action_card_executes_current_domain_command_and_returns_changes_and_next_cards() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "ridge_caravan"
	var node := {"id": "ridge_caravan", "type": "caravan"}
	state.current_node_id = "ridge_caravan"
	var session := EncounterSessionResolverScript.start(node)
	state.encounter_session = session.duplicate(true)
	var result := EncounterSessionResolverScript.apply(state, session, {
		"type": "action_card",
		"action_id": "caravan.buy.buy_force_blow",
		"state_version": state.event_log.size(),
		"node_id": "ridge_caravan",
		"session_node_id": "ridge_caravan",
	}, ContentCatalog.load_all(), node)

	assert_true(result["result"]["ok"])
	assert_eq(result["state"].stone, state.stone - 5)
	assert_false(result["result"]["actual_changes"].is_empty())
	assert_false(result["result"]["next_available_actions"].is_empty())


func test_action_card_changes_use_chinese_gu_names_at_the_player_boundary() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "refinement_hollow"
	state.cultivator["soul"] = 3
	state.gu_instances["gu_201"] = {"instance_id": "gu_201", "definition_id": "small_light_gu", "state": "refined"}
	state.gu_instances["gu_202"] = {"instance_id": "gu_202", "definition_id": "moonlight_gu", "state": "refined"}
	state.cave_aperture["stored_gu_instance_ids"].append("gu_201")
	state.cave_aperture["stored_gu_instance_ids"].append("gu_202")
	state.sync_legacy_gu_projections()
	var node := {"id": "refinement_hollow", "type": "refinement"}
	state.current_node_id = "refinement_hollow"
	var session := EncounterSessionResolverScript.start(node)
	state.encounter_session = session.duplicate(true)
	var result := EncounterSessionResolverScript.apply(state, session, {
		"type": "action_card",
		"action_id": "refine.moon_ray_forged",
		"state_version": state.event_log.size(),
		"node_id": "refinement_hollow",
		"session_node_id": "refinement_hollow",
	}, ContentCatalog.load_all(), node)

	var messages: Array[String] = []
	for change in result["result"]["actual_changes"]:
		messages.append(str(change["message"]))
	var summary := " ".join(messages)
	assert_false(summary.contains("small_light_gu"))
	assert_false(summary.contains("moonlight_gu"))
	assert_true(summary.contains("小光蛊") or summary.contains("月光蛊"))
