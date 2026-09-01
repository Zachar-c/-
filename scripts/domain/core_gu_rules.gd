class_name CoreGuRules
extends RefCounted


# Spec-v4 phase-2 (T7.1): core gu confirmation (§1.1), depth markup (§1.1)
# and distribution-only pool tilt (§1.2). Pure static, deterministic.
# The tilt is a candidate-distribution suggestion - it never authorizes any
# direct number, and every GuBalance output stays untouched (test-pinned).


const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")

const DEPTH_COMMON := "common_core"
const DEPTH_HUB := "hub_core"

# P0.1 layer-semantics ruling: the authoritative layer is nodes.json /
# RunState.stage ("one".."five"); current_node_layer has no production
# writer and is never consulted by the confirmation gate. "First-layer
# midpoint" is implemented as in-layer progress: the run has traversed at
# least FIRST_LAYER_MIDPOINT_NODES valid nodes (route_progress), which also
# covers every later stage - the first layer can never lock the core out.
const FIRST_LAYER_MIDPOINT_NODES := 4


# §1.1: one core per run; the gate opens at the first-layer midpoint. The
# player may delay freely - the only cost is less tilt duration; there is no
# default-core path anywhere (confirm is an explicit player action).
static func can_confirm(state, instance_id: String, catalog: Dictionary) -> Dictionary:
	var existing := _existing_core(state)
	if not existing.is_empty():
		return {"ok": false, "reason": "core_already_confirmed", "detail": existing}
	if (state.route_progress as Array).size() < FIRST_LAYER_MIDPOINT_NODES:
		return {"ok": false, "reason": "too_early_first_layer"}
	if not (state.gu_instances as Dictionary).has(str(instance_id)):
		return {"ok": false, "reason": "instance_missing"}
	return {"ok": true, "reason": ""}


# Explicit player confirmation: writes the core facts (layer / depth / event
# marker) into the instance's core_state and returns the event for the
# command surface to append (T9.2). Never automatic.
static func confirm(state, instance_id: String, catalog: Dictionary) -> Dictionary:
	var pre := can_confirm(state, instance_id, catalog)
	if not bool(pre["ok"]):
		return {"ok": false, "reason": pre["reason"], "updated_instance": {}, "event": {}}
	var instance: Dictionary = (state.gu_instances[str(instance_id)] as Dictionary).duplicate(true)
	var definition: Dictionary = catalog.get("gu_by_id", {}).get(
			str(instance.get("definition_id", "")), {})
	var depth := core_depth(definition, catalog)
	instance["core_state"] = {
		"confirmed_layer": str(state.stage),
		"depth": depth,
		"confirmed_at_event": "core_" + str(instance_id),
	}
	return {
		"ok": true,
		"reason": "",
		"updated_instance": instance,
		"event": {
			"action": "core_confirmed",
			"instance_id": str(instance_id),
			"definition_id": str(instance.get("definition_id", "")),
			"core_state": instance["core_state"].duplicate(true),
			"reason": "player_confirmed",
		},
	}


# §1.1 depth markup: common cores carry the unified benefits; a hub core
# additionally declares hand-authored branch recipes / exclusive refining
# evidence in gu.json (schema-guarded) and that evidence is enumerable.
# The markup never denies ordinary gu their core eligibility.
static func core_depth(definition: Dictionary, _catalog: Dictionary) -> String:
	if str(definition.get("core_depth", "")) == "hub":
		return DEPTH_HUB
	return DEPTH_COMMON


static func hub_evidence(definition: Dictionary, catalog: Dictionary) -> Dictionary:
	var branch_recipes: Array = []
	for recipe_id in definition.get("branch_recipes", []):
		if catalog.get("refinement_by_id", {}).has(str(recipe_id)):
			branch_recipes.append(str(recipe_id))
	return {"branch_recipes": branch_recipes, "exclusive_refine": str(definition.get("exclusive_refine", ""))}


# §1.2 pool tilt: raise the candidate weight of gu that share the core's dao
# tags or main role inside each school pool. The output is a pure suggestion
# (pool -> boosted candidate ids) for the pool manager - it guarantees
# nothing, drops nothing, and adds no base numbers anywhere.
static func tilt_pool(pools: Dictionary, core: Dictionary, catalog: Dictionary) -> Dictionary:
	var definition: Dictionary = catalog.get("gu_by_id", {}).get(
			str(core.get("definition_id", "")), {})
	var core_tags: Array = definition.get("tags", [])
	var core_role := str(definition.get("role", ""))
	var suggestions := {}
	for pool_id_value in pools:
		var pool_id := str(pool_id_value)
		var boosted: Array = []
		for gu_id_value in pools[pool_id_value]:
			var gu_id := str(gu_id_value)
			var candidate: Dictionary = catalog.get("gu_by_id", {}).get(gu_id, {})
			var shares_tag := false
			for tag in candidate.get("tags", []):
				if core_tags.has(str(tag)):
					shares_tag = true
					break
			if shares_tag or str(candidate.get("role", "")) == core_role:
				boosted.append(gu_id)
		if not boosted.is_empty():
			suggestions[pool_id] = boosted
	return {"suggestions": suggestions}


static func _existing_core(state) -> String:
	for instance_id in (state.gu_instances as Dictionary):
		var instance: Dictionary = state.gu_instances[str(instance_id)]
		if not (instance.get("core_state", {}) as Dictionary).is_empty():
			return str(instance_id)
	return ""


# ---- §1.3 core replacement ------------------------------------------------

const REPLACE_HARD_LIMIT := 1
const CORE_MOD_SOURCE := "core_exclusive"


# §1.3: a stage two/three major node guarantees one replacement-token option,
# racing the node's own strengthening (the command surface presents the two
# as an exclusive choice). Random encounters may come early through the seeded
# pool manager - this entry is the data-driven grant gate: once any
# replacement already happened, the guarantee becomes a peer reward instead
# of a useless token (the hard cap is never bypassed).
static func grant_replacement_token(state, node: Dictionary, _rng_free_source) -> Dictionary:
	var token: Dictionary = node.get("core_replacement_token", {})
	if token.is_empty():
		return {"ok": false, "reason": "no_token_on_node"}
	if int(state.node_flags.get("core_replace_count", 0)) >= REPLACE_HARD_LIMIT:
		return {"ok": false, "reason": "guarantee_replaced_with_peer_reward"}
	return {"ok": true, "reason": "", "token": "core_replacement_token"}


# §1.3 preflight (same source as execution, §17.3): the per-run success hard
# cap, instance existence, and the structured, publicly visible cost sources.
static func can_replace(state, old_instance_id: String, new_instance_id: String, cost: Dictionary, catalog: Dictionary) -> Dictionary:
	if int(state.node_flags.get("core_replace_count", 0)) >= REPLACE_HARD_LIMIT:
		return {"ok": false, "reason": "replace_limit_reached", "cost_sources": []}
	if not (state.gu_instances as Dictionary).has(str(old_instance_id)) \
			or not (state.gu_instances as Dictionary).has(str(new_instance_id)):
		return {"ok": false, "reason": "instance_missing", "cost_sources": []}
	return {"ok": true, "reason": "", "cost_sources": _structured_cost(cost)}


# §1.3: swap the core. The old gu keeps rank, refine state and identity; only
# its core facts and the core-exclusive modifications are removed. The new
# core starts from the current state - no route, no mods, no consumed
# resources; its core_state is a fresh confirmation. Returns the updated
# instances and the immutable event for the command surface.
static func replace_core(state, old_instance_id: String, new_instance_id: String, cost: Dictionary, catalog: Dictionary) -> Dictionary:
	var pre := can_replace(state, old_instance_id, new_instance_id, cost, catalog)
	if not bool(pre["ok"]):
		return {"ok": false, "reason": pre["reason"], "instances": {}, "event": {}}
	var old: Dictionary = (state.gu_instances[str(old_instance_id)] as Dictionary).duplicate(true)
	var new_core: Dictionary = (state.gu_instances[str(new_instance_id)] as Dictionary).duplicate(true)
	old["core_state"] = {}
	var kept_mods: Array = []
	for mod_value in old.get("modifications", []):
		var mod: Dictionary = mod_value
		if str(mod.get("source", "")) != CORE_MOD_SOURCE:
			kept_mods.append(mod.duplicate(true))
	old["modifications"] = kept_mods
	var depth := core_depth(
			catalog.get("gu_by_id", {}).get(str(new_core.get("definition_id", "")), {}), catalog)
	new_core["core_state"] = {
		"confirmed_layer": int(state.current_node_layer),
		"depth": depth,
		"confirmed_at_event": "core_" + str(new_instance_id),
	}
	var replace_count := int(state.node_flags.get("core_replace_count", 0)) + 1
	return {
		"ok": true,
		"reason": "",
		"instances": {str(old_instance_id): old, str(new_instance_id): new_core},
		"replace_count": replace_count,
		"event": {
			"action": "core_replaced",
			"old_instance_id": str(old_instance_id),
			"new_instance_id": str(new_instance_id),
			"old_definition_id": str(old.get("definition_id", "")),
			"new_definition_id": str(new_core.get("definition_id", "")),
			"cost_sources": pre["cost_sources"],
			"replace_count": replace_count,
			"reason": "player_confirmed",
		},
	}


static func _structured_cost(cost: Dictionary) -> Array:
	var sources: Array = []
	for kind in ["certificate", "stones", "materials", "lifespan", "soul", "taboo"]:
		var amount: Variant = cost.get(kind, 0)
		if amount is int or amount is float or amount is String:
			if float(amount) > 0.0 or kind == "taboo":
				sources.append({"kind": kind, "amount": amount})
	return sources
