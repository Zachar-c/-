class_name DebugActions
extends RefCounted


# DBG1 §16.22: developer console domain. Every op reuses formal validation
# paths (deck capacity gate, reward-semantics gu gain) and leaves a unified
# audit event with source="debug" carrying the raw action under the log-only
# "_debug" key. Rejections are equally traceable: every reject path appends
# one light debug_rejected audit entry (after holds only the "_debug" info,
# reason carries the rejection code) without touching any live state field.
# Release builds never reach this module: RunController only mounts it behind
# OS.is_debug_build(), and the allowed flag is a second domain-level guard so
# tests can exercise the rejection path.


const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")

const OPS := ["add_gu", "set_resources", "jump_to_node", "query_loot_state", "dump_snapshot", "grant_recipe"]


# Returns the resolver-style shape {ok/result/state/feeds}. `route` is the
# presentation-owned map route; jump_to_node needs it to verify that the
# target node exists on this run's generated map.
static func apply(
	state: RunState,
	catalog: Dictionary,
	action: Dictionary,
	allowed: bool,
	route: Array = []
) -> Dictionary:
	if not allowed or not bool(catalog.get("debug", {}).get("enabled", false)):
		return _rejected(state, action, "debug_disabled")
	var op := str(action.get("op", ""))
	if not OPS.has(op):
		return _rejected(state, action, "unknown_debug_op")
	match op:
		"add_gu":
			return _add_gu(state, catalog, action)
		"set_resources":
			return _set_resources(state, action)
		"jump_to_node":
			return _jump_to_node(state, action, route)
		"grant_recipe":
			return _grant_recipe(state, catalog, action)
		_:
			return _read_only(state, action)


# Mirrors LootResolver._gain_gu reward semantics: new refined instance into
# gu_instances + cave_aperture, then legacy projections resynced. Capacity is
# gated by the shared DeckCapacity projection used by every other gain path.
static func _add_gu(state: RunState, catalog: Dictionary, action: Dictionary) -> Dictionary:
	var gu_id := str(action.get("definition_id", ""))
	if not catalog.get("gu_by_id", {}).has(gu_id):
		return _rejected(state, action, "unknown_gu")
	if state.is_terminal():
		return _rejected(state, action, "terminal_run")
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var instance_id := RunState.next_gu_instance_id(instances)
	instances[instance_id] = GuInstanceScript.new_instance(gu_id, instance_id, catalog)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	stored.append(instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var next := _debug_event(state, {"gu_instances": instances, "cave_aperture": aperture}, action, [gu_id])
	next.sync_legacy_gu_projections()
	return _accepted(next, {"instance_id": instance_id, "definition_id": gu_id},
			_feed("debug_gu_added", {"gu": gu_id}))


# 蛊方图鉴调试授方（2026-08-30）：把配方 id 写入全局图鉴，供验收门禁与
# 跨局保留链路。首次获得即永久（Meta 回收链路照常生效）。
static func _grant_recipe(state: RunState, catalog: Dictionary, action: Dictionary) -> Dictionary:
	var recipe_id := str(action.get("recipe_id", ""))
	if not catalog.get("refinement_by_id", {}).has(recipe_id):
		return _rejected(state, action, "unknown_refinement_recipe")
	if state.is_terminal():
		return _rejected(state, action, "terminal_run")
	if state.global_codex_ids.has(recipe_id):
		return _rejected(state, action, "recipe_already_owned")
	var codex_after: Array[String] = state.global_codex_ids.duplicate()
	codex_after.append(recipe_id)
	var next := _debug_event(state, {"global_codex_ids": codex_after}, action, [recipe_id])
	next.global_codex_ids = codex_after
	return _accepted(next, {"recipe_id": recipe_id}, _feed("debug_recipe_granted", {"recipe": recipe_id}))


# Absolute writes clamped into legal bounds; health/soul floor at 1 so the
# console can never deal silent death. Only supplied keys are touched.
static func _set_resources(state: RunState, action: Dictionary) -> Dictionary:
	if state.is_terminal():
		return _rejected(state, action, "terminal_run")
	var after := {}
	# The live cap lives in cave_aperture.essence_max (ascension raises it past
	# the legacy essence_capacity scalar); fall back to the scalar when absent,
	# mirroring battle_command_facade's dual-read of the same pair.
	var essence_cap := int(state.cave_aperture.get("essence_max", state.essence_capacity))
	if action.has("essence"):
		after["essence"] = clampi(int(action["essence"]), 0, essence_cap)
	if action.has("stones"):
		after["stone"] = maxi(0, int(action["stones"]))
	if action.has("health"):
		after["health"] = clampi(int(action["health"]), 1, int(state.max_health))
	if action.has("soul"):
		var cultivator := state.cultivator.duplicate(true)
		cultivator["soul"] = clampi(
				int(action["soul"]),
				1,
				maxi(1, int(cultivator.get("soul_max", int(cultivator.get("soul", 1))))))
		after["cultivator"] = cultivator
	if after.is_empty():
		return _rejected(state, action, "missing_resource_fields")
	var next := _debug_event(state, after, action, [])
	var changes := {
		"essence": int(next.essence),
		"stones": int(next.stone),
		"health": int(next.health),
	}
	if after.has("cultivator"):
		changes["soul"] = int(next.cultivator.get("soul", 0))
	return _accepted(next, changes, _feed("debug_resources_set", changes))


# Arrival-only jump: the target must exist on this run's route, any open
# encounter session is closed as outcome "debug_abandoned" (recorded in
# node_flags like every completion outcome), stale session mirrors are
# cleared, and the target gets a bare-id "debug_arrived" flag mirroring
# _complete_node's visited-marker semantics so MapGenerator.reachable_nodes
# can expand its successors from the new origin. Reachability/stage gates are
# deliberately relaxed for debugging; normal travel keeps enforcing them.
static func _jump_to_node(state: RunState, action: Dictionary, route: Array) -> Dictionary:
	if state.is_terminal():
		return _rejected(state, action, "terminal_run")
	if route.is_empty():
		return _rejected(state, action, "missing_route_context")
	var target_id := str(action.get("node_id", ""))
	var known := false
	for node_value in route:
		if str((node_value as Dictionary).get("id", "")) == target_id:
			known = true
			break
	if not known:
		return _rejected(state, action, "unknown_route_node")
	var flags := state.node_flags.duplicate(true)
	if _session_open(state):
		flags[str(state.encounter_session.get("node_id", state.current_node_id))] = "debug_abandoned"
	flags[target_id] = "debug_arrived"
	var cleared_results: Array[Dictionary] = []
	var next := _debug_event(state, {
		"current_node_id": target_id,
		"encounter_session": {},
		"encounter_results": cleared_results,
		"node_flags": flags,
	}, action, [target_id])
	return _accepted(next, {"node_id": target_id}, _feed("debug_node_jumped", {"node_id": target_id}))


# Query/dump mutate nothing but their own audit events; pity keys mirror the
# real RunState field names. Pool exclusion storage does not exist yet (P1
# backlog item), so "excluded" stays an empty list by construction.
static func _read_only(state: RunState, action: Dictionary) -> Dictionary:
	var op := str(action.get("op", ""))
	var payload := {}
	var text_key := ""
	if op == "query_loot_state":
		payload = {
			"pity": {
				"loot_pity": int(state.loot_pity),
				"material_pity": int(state.material_pity),
				"synthesis_fail_streak": int(state.synthesis_fail_streak),
			},
			"excluded": [],
		}
		text_key = "debug_loot_state"
	else:
		payload = {"snapshot": state.to_save_data()}
		text_key = "debug_snapshot_dump"
	var next := _debug_event(state, {}, action, [])
	return _accepted(next, payload, _feed(text_key, {}))


static func _session_open(state: RunState) -> bool:
	return not state.encounter_session.is_empty() \
			and not bool(state.encounter_session.get("completed", true))


static func _debug_event(state: RunState, state_after: Dictionary, action: Dictionary, targets: Array) -> RunState:
	var after := state_after.duplicate(true)
	after["_debug"] = action.duplicate(true)
	return state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "debug_%s" % str(action.get("op", "")),
		"before": {},
		"after": after,
		"reason": "debug_console",
		"source": "debug",
		"targets": targets,
	})


static func _feed(text_key: String, changes: Dictionary) -> Dictionary:
	return ResultFeedScript.entry("debug", text_key, changes, [])


static func _accepted(next: RunState, result_payload: Dictionary, feed: Dictionary) -> Dictionary:
	return {"ok": true, "result": result_payload, "state": next, "feeds": [feed]}


static func _rejected(state: RunState, action: Dictionary, reason: String) -> Dictionary:
	# Rejections stay traceable too: one light audit entry whose after holds
	# only the "_debug" info (raw attempted action); the "_"-prefixed key is
	# skipped by RunState._apply_after, so live state fields never change.
	var next := state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "debug_rejected",
		"before": {},
		"after": {"_debug": action.duplicate(true)},
		"reason": reason,
		"source": "debug",
		"targets": [],
	})
	var text_key := "debug_disabled" if reason == "debug_disabled" else "debug_action_rejected"
	return {
		"ok": false,
		"result": {"reason": reason},
		"state": next,
		"feeds": [_feed(text_key, {"reason": reason})],
	}
