class_name CoreGuRules
extends RefCounted


# Spec-v4 phase-2 (T7.1): core gu confirmation (§1.1), depth markup (§1.1)
# and distribution-only pool tilt (§1.2). Pure static, deterministic.
# The tilt is a candidate-distribution suggestion - it never authorizes any
# direct number, and every GuBalance output stays untouched (test-pinned).


const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")

const DEPTH_COMMON := "common_core"
const DEPTH_HUB := "hub_core"


# §1.1: one core per run; the gate opens at the first-layer midpoint. The
# midpoint verdict: the run must have entered layer 1 (the first layer's
# opening stretch is over); within layer 0 confirmation stays refused.
# The player may delay freely - the only cost is less tilt duration; there is
# no default-core path anywhere (confirm is an explicit player action).
static func can_confirm(state, instance_id: String, catalog: Dictionary) -> Dictionary:
	var existing := _existing_core(state)
	if not existing.is_empty():
		return {"ok": false, "reason": "core_already_confirmed", "detail": existing}
	if int(state.current_node_layer) < 1:
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
		"confirmed_layer": int(state.current_node_layer),
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
