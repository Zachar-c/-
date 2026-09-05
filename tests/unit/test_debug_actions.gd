extends "res://addons/gut/test.gd"


# DBG1 §16.22 developer debug actions: domain gate (allowed flag + config
# switch), reward-path gu gain into cave_aperture, clamped resource writes
# honoring the ascended cave essence_max, route jump whose arrival flag lets
# reachable_nodes expand successors, open-session abandonment, read-only
# query/dump, and a full audit trail (accepted ops and rejections alike carry
# source="debug" under the log-only "_debug" key; live state stays untouched).


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const DebugActionsScript = preload("res://scripts/domain/debug_actions.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")


func enabled_catalog() -> Dictionary:
	var cat := ContentCatalogScript.load_all()
	cat["debug"] = {"enabled": true}
	return cat


func disabled_catalog() -> Dictionary:
	var cat := ContentCatalogScript.load_all()
	cat["debug"] = {"enabled": false}
	return cat


func make_route() -> Array:
	return [
		{"id": "trailhead", "type": "combat"},
		{"id": "ridge_caravan", "type": "market"},
		{"id": "beast_swarm_pass", "type": "combat"},
	]


# Rejections must append exactly one light audit entry and leave every live
# state field identical to the pre-call state (only event_log grows).
func assert_state_untouched_except_audit(next: RunState, before: RunState) -> void:
	assert_eq(int(next.event_log.size()), int(before.event_log.size()) + 1,
			"exactly one light audit entry rides a rejection")
	var baseline := before.to_save_data()
	var data := next.to_save_data()
	for field in data:
		if field == "event_log":
			continue
		assert_eq_deep(data[field], baseline[field])


func test_disallowed_gate_rejects_with_a_single_audit_trace() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var applied := DebugActionsScript.apply(state, cat, {"op": "dump_snapshot"}, false)
	assert_false(bool(applied["ok"]), "allowed=false must reject")
	assert_eq(str(applied["result"]["reason"]), "debug_disabled")
	assert_eq(str(applied["feeds"][0]["text_key"]), "debug_disabled")
	assert_state_untouched_except_audit(applied["state"], state)
	var entry: Dictionary = applied["state"].event_log[applied["state"].event_log.size() - 1]
	assert_eq(str(entry["action"]), "debug_rejected")
	assert_eq(str(entry["reason"]), "debug_disabled")


func test_disabled_config_rejects_even_when_allowed() -> void:
	var cat := disabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var applied := DebugActionsScript.apply(state, cat, {"op": "dump_snapshot"}, true)
	assert_false(bool(applied["ok"]), "disabled config must reject")
	assert_eq(str(applied["result"]["reason"]), "debug_disabled")
	assert_eq(int(applied["state"].event_log.size()), int(state.event_log.size()) + 1)


func test_unknown_op_is_rejected() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var applied := DebugActionsScript.apply(state, cat, {"op": "grant_legendary"}, true)
	assert_false(bool(applied["ok"]), "whitelist must reject unknown ops")
	assert_eq(str(applied["result"]["reason"]), "unknown_debug_op")
	assert_eq(int(applied["state"].event_log.size()), int(state.event_log.size()) + 1)


func test_add_gu_success_follows_reward_semantics_into_cave_aperture() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var action := {"op": "add_gu", "definition_id": "force_gu"}
	var applied := DebugActionsScript.apply(state, cat, action, true)
	assert_true(bool(applied["ok"]), "known gu must be added")
	var next: RunState = applied["state"]
	assert_eq(int(next.event_log.size()), int(state.event_log.size()) + 1)
	assert_eq(int(next.cave_aperture["stored_gu_instance_ids"].size()),
			int(state.cave_aperture["stored_gu_instance_ids"].size()) + 1,
			"cave aperture must hold one more instance")
	var instance: Dictionary = next.gu_instances[str(applied["result"]["instance_id"])]
	assert_eq(str(instance["definition_id"]), "force_gu")
	assert_eq(str(instance["state"]), "refined", "reward semantics refine the instance")
	assert_true(next.refined_gu_ids.has("force_gu"), "legacy projection synced")
	var entry: Dictionary = next.event_log[next.event_log.size() - 1]
	assert_eq(str(entry["action"]), "debug_add_gu")
	assert_eq(str(entry["source"]), "debug")
	assert_eq(str(entry["reason"]), "debug_console")
	assert_true(entry["targets"].has("force_gu"))
	assert_eq_deep(entry["after"]["_debug"], action)


func test_add_gu_rejects_unknown_definition() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var applied := DebugActionsScript.apply(
			state, cat, {"op": "add_gu", "definition_id": "not_a_gu"}, true)
	assert_false(bool(applied["ok"]))
	assert_eq(str(applied["result"]["reason"]), "unknown_gu")
	assert_state_untouched_except_audit(applied["state"], state)


func test_rejection_leaves_a_light_audit_trail() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var action := {"op": "add_gu", "definition_id": "not_a_gu"}
	var applied := DebugActionsScript.apply(state, cat, action, true)
	assert_false(bool(applied["ok"]))
	assert_state_untouched_except_audit(applied["state"], state)
	var entry: Dictionary = applied["state"].event_log[applied["state"].event_log.size() - 1]
	assert_eq(str(entry["action"]), "debug_rejected", "rejections share one audit action")
	assert_eq(str(entry["reason"]), "unknown_gu", "rejection code rides the reason field")
	assert_eq(str(entry["source"]), "debug")
	assert_true(entry["after"].has("_debug"), "audit payload rides the _ key")
	assert_eq(int((entry["after"] as Dictionary).keys().size()), 1,
			"after holds nothing but the log-only _ key")
	assert_eq_deep(entry["after"]["_debug"], action)
	assert_eq(int((entry["targets"] as Array).size()), 0)


func test_set_resources_clamps_every_value_into_legal_bounds() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var applied := DebugActionsScript.apply(state, cat,
			{"op": "set_resources", "essence": 99, "stones": -5, "health": 0, "soul": 99}, true)
	assert_true(bool(applied["ok"]), "clamped write must succeed")
	var next: RunState = applied["state"]
	assert_eq(int(next.essence), int(next.essence_capacity), "essence clamps to capacity")
	assert_eq(int(next.stone), 0, "stones never go negative")
	assert_eq(int(next.health), 1, "health floor is 1: no silent death")
	assert_eq(int(next.cultivator.get("soul", -1)), int(next.cultivator.get("soul_max", -1)),
			"soul clamps to soul_max")
	var again := DebugActionsScript.apply(next, cat, {"op": "set_resources", "health": -7}, true)
	assert_eq(int(again["state"].health), 1, "negative health also clamps to the floor")
	var entry: Dictionary = applied["state"].event_log[applied["state"].event_log.size() - 1]
	assert_eq(int(entry["after"]["health"]), 1, "event after carries the clamped values")
	assert_eq(int(entry["after"]["stone"]), 0)


func test_set_resources_respects_ascended_cave_essence_max() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	state.cave_aperture["essence_max"] = 6
	var applied := DebugActionsScript.apply(
			state, cat, {"op": "set_resources", "essence": 6}, true)
	assert_true(bool(applied["ok"]))
	assert_eq(int(applied["state"].essence), 6,
			"ascended cave cap allows six without truncating to the legacy scalar")
	assert_eq(int(applied["result"]["essence"]), 6)
	var over := DebugActionsScript.apply(
			applied["state"], cat, {"op": "set_resources", "essence": 99}, true)
	assert_eq(int(over["state"].essence), 6, "clamp still bounds at the cave essence_max")


func test_set_resources_subset_only_touches_given_fields() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var baseline := state.to_save_data()
	var applied := DebugActionsScript.apply(state, cat, {"op": "set_resources", "stones": 7}, true)
	assert_true(bool(applied["ok"]))
	var after: Dictionary = applied["state"].to_save_data()
	assert_eq(int(after["stone"]), 7)
	assert_eq(int(after["essence"]), int(baseline["essence"]), "untouched essence")
	assert_eq(int(after["health"]), int(baseline["health"]), "untouched health")
	assert_eq_deep(after["cultivator"], baseline["cultivator"])
	assert_eq(int(after["event_log"].size()), int(baseline["event_log"].size()) + 1)


func test_jump_to_node_requires_a_known_route_node_and_route_context() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var no_route := DebugActionsScript.apply(
			state, cat, {"op": "jump_to_node", "node_id": "ridge_caravan"}, true)
	assert_false(bool(no_route["ok"]), "jump without route context must refuse")
	assert_eq(str(no_route["result"]["reason"]), "missing_route_context")
	assert_state_untouched_except_audit(no_route["state"], state)
	var applied := DebugActionsScript.apply(
			state, cat, {"op": "jump_to_node", "node_id": "nowhere"}, true, make_route())
	assert_false(bool(applied["ok"]))
	assert_eq(str(applied["result"]["reason"]), "unknown_route_node")
	assert_state_untouched_except_audit(applied["state"], state)


func test_jump_closes_open_session_then_arrives_in_one_debug_event() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	state.encounter_session = {
		"node_id": "trailhead", "kind": "combat", "phase": "active",
		"completed": false, "completion_reason": "", "flags": {},
	}
	state.encounter_results.append({"action": "probe"})
	var action := {"op": "jump_to_node", "node_id": "beast_swarm_pass"}
	var applied := DebugActionsScript.apply(state, cat, action, true, make_route())
	assert_true(bool(applied["ok"]))
	var next: RunState = applied["state"]
	assert_eq(int(next.event_log.size()), int(state.event_log.size()) + 1,
			"closure and arrival ride a single unified debug event")
	assert_eq(str(next.current_node_id), "beast_swarm_pass", "arrival state reached")
	assert_true(next.node_flags.has("trailhead"), "open-session origin must be closed out")
	assert_eq(str(next.node_flags["trailhead"]), "debug_abandoned")
	assert_eq_deep(next.encounter_session, {})
	assert_eq(int(next.encounter_results.size()), 0, "stale session results cleared")
	var entry: Dictionary = next.event_log[next.event_log.size() - 1]
	assert_eq(str(entry["action"]), "debug_jump_to_node")
	assert_eq(str(entry["source"]), "debug")
	assert_eq_deep(entry["after"]["_debug"], action)


func test_jump_marks_target_arrival_so_reachability_expands() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var route: Array[Dictionary] = MapGeneratorScript.build(2026, true)
	# 节点收窄后 first_run 骨架无 refinement_hollow；跳转到骨架中段战斗
	# iron_hide_ambush，其后继 ridge_black_market 验证可达性展开。
	var action := {"op": "jump_to_node", "node_id": "iron_hide_ambush"}
	var applied := DebugActionsScript.apply(state, cat, action, true, route)
	assert_true(bool(applied["ok"]))
	var next: RunState = applied["state"]
	assert_eq(str(next.node_flags.get("iron_hide_ambush", "")), "debug_arrived",
			"arrival mirrors _complete_node's bare-id visited-marker semantics")
	var reachable := MapGeneratorScript.reachable_nodes(route, next)
	var ids := []
	for node_value in reachable:
		ids.append(str((node_value as Dictionary).get("id", "")))
	assert_false(reachable.is_empty(),
			"jumped-to origin must expand successors instead of soft-locking the map")
	assert_true(ids.has("ridge_black_market"),
			"successors follow the route's own next_ids")


func test_query_and_dump_are_read_only_but_still_leave_audit_events() -> void:
	var cat := enabled_catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	state.loot_pity = 2
	state.material_pity = 1
	state.synthesis_fail_streak = 1
	var baseline := state.to_save_data()
	var queried := DebugActionsScript.apply(state, cat, {"op": "query_loot_state"}, true)
	assert_true(bool(queried["ok"]))
	assert_eq_deep(queried["result"]["pity"],
			{"loot_pity": 2, "material_pity": 1, "synthesis_fail_streak": 1})
	assert_eq_deep(queried["result"]["excluded"], [])
	var dumped := DebugActionsScript.apply(queried["state"], cat, {"op": "dump_snapshot"}, true)
	assert_true(bool(dumped["ok"]))
	var snap: Dictionary = dumped["result"]["snapshot"]
	assert_eq(int(snap["event_log"].size()), int(baseline["event_log"].size()) + 1,
			"snapshot carries only the query audit event beyond baseline")
	for field in snap:
		if field == "event_log":
			continue
		assert_eq_deep(snap[field], baseline[field])
	var final_data: Dictionary = dumped["state"].to_save_data()
	for field in final_data:
		if field == "event_log":
			continue
		assert_eq_deep(final_data[field], baseline[field])
	assert_eq(int(final_data["event_log"].size()), int(baseline["event_log"].size()) + 2)
	for index in range(int(baseline["event_log"].size()), final_data["event_log"].size()):
		var entry: Dictionary = final_data["event_log"][index]
		assert_eq(str(entry["source"]), "debug")
		assert_true(entry["after"].has("_debug"), "audit payload rides the _ key")
