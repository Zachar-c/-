class_name CurseRegistry
extends RefCounted


# P0 backlash curse system (spec R9.x): curses are run-scoped status entries
# stored under state.cultivator.statuses[curse_id] as {"layers", "source"}.
# They persist across battles until fully removed; battles only project them.

# Stage ladder follows the canonical map stage strings; unknown stage strings
# fall back to index zero so escalation never fires on malformed saves.
const STAGE_ORDER := ["one", "two", "three", "four", "five"]
const EFFECT_KINDS := ["draw_pollution", "essence_surcharge", "slot_seal"]

# essence_surcharge lets the first two intensity points pass free (R9.2).
const SURCHARGE_FREE_ALLOWANCE := 2


static func gain_curse(state: RunState, curse_id: String, source: String) -> RunState:
	var cultivator: Dictionary = state.cultivator.duplicate(true)
	var statuses: Dictionary = cultivator.get("statuses", {}).duplicate(true)
	var entry: Dictionary = statuses.get(curse_id, {}).duplicate(true)
	entry["layers"] = int(entry.get("layers", 0)) + 1
	if str(entry.get("source", "")).is_empty():
		entry["source"] = source
	statuses[curse_id] = entry
	cultivator["statuses"] = statuses
	return state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "curse_gained",
		"before": {"cultivator": state.cultivator},
		"after": {"cultivator": cultivator},
		"reason": "backlash_curse_gained",
		"source": "curse_registry",
		"targets": [curse_id, source],
	})


static func remove_curse(state: RunState, curse_id: String) -> RunState:
	# R9.3 removal is full removal only; no partial de-layering.
	var cultivator: Dictionary = state.cultivator.duplicate(true)
	var statuses: Dictionary = cultivator.get("statuses", {}).duplicate(true)
	statuses.erase(curse_id)
	cultivator["statuses"] = statuses
	return state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "curse_removed",
		"before": {"cultivator": state.cultivator},
		"after": {"cultivator": cultivator},
		"reason": "backlash_curse_removed",
		"source": "curse_registry",
		"targets": [curse_id],
	})


static func layers_of(state: RunState, curse_id: String) -> int:
	return int(state.cultivator.get("statuses", {}).get(curse_id, {}).get("layers", 0))


static func intensity(state: RunState, curse: Dictionary) -> int:
	# R9.5: (base_intensity + escalation_per_stage * stage_index) * layers.
	var layers := layers_of(state, str(curse.get("id", "")))
	if layers <= 0:
		return 0
	var base := maxi(0, int(curse.get("base_intensity", 0)))
	var escalation := maxi(0, int(curse.get("escalation_per_stage", 0)))
	return (base + escalation * stage_index(state)) * layers


static func stage_index(state: RunState) -> int:
	return maxi(0, STAGE_ORDER.find(str(state.stage)))


# Deterministic battle projection sorted by curse id so battle setup never
# depends on dictionary iteration order.
static func project_battle_curses(state: RunState, catalog: Dictionary) -> Array[Dictionary]:
	var projections: Array[Dictionary] = []
	var ids: Array[String] = []
	for curse_id_value in state.cultivator.get("statuses", {}):
		ids.append(str(curse_id_value))
	ids.sort()
	for curse_id in ids:
		var curse: Dictionary = catalog.get("curse_by_id", {}).get(curse_id, {})
		if curse.is_empty():
			continue
		projections.append({
			"id": curse_id,
			"effect": str(curse.get("effect", "")),
			"intensity": intensity(state, curse),
			"free": int(curse.get("free_allowance", SURCHARGE_FREE_ALLOWANCE)),
		})
	return projections


static func total_intensity(projections: Array, effect: String) -> int:
	var total := 0
	for projection_value in projections:
		var projection: Dictionary = projection_value
		if str(projection.get("effect", "")) == effect:
			total += maxi(0, int(projection.get("intensity", 0)))
	return total


static func essence_surcharge(projections: Array) -> int:
	var total := 0
	for projection_value in projections:
		var projection: Dictionary = projection_value
		if str(projection.get("effect", "")) != "essence_surcharge":
			continue
		total += maxi(0, int(projection.get("intensity", 0)) - int(projection.get("free", SURCHARGE_FREE_ALLOWANCE)))
	return total


# slot_seal disables the single highest-index equipped gu (last entry of
# equipped_gu_ids); multiple seal curses still share that one slot.
static func sealed_definition_ids(state: RunState, projections: Array) -> Array[String]:
	var sealed: Array[String] = []
	if total_intensity(projections, "slot_seal") <= 0 or state.equipped_gu_ids.is_empty():
		return sealed
	sealed.append(str(state.equipped_gu_ids[state.equipped_gu_ids.size() - 1]))
	return sealed
