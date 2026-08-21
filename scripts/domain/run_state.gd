class_name RunState
extends RefCounted


var seed: int = 0
var stage: String = "one"
var cultivation: int = 1
var essence: int = 3
var injury: int = 0
var lifespan_debt: int = 0
var stone: int = 12
var gu_ids: Array[String] = []
var equipped_gu_ids: Array[String] = []
var inheritance_ids: Array[String] = []
var body_imprints: Array[String] = []
var clues: Array[String] = []
var relations: Dictionary = {}
var pursuit: int = 0
var ascension: Dictionary = {}
var known_facts: Array[String] = []
var current_node_id: String = "awakening"
var event_log: Array[Dictionary] = []


static func new_run(run_seed: int) -> RunState:
	var state := RunState.new()
	state.seed = run_seed
	state.gu_ids = ["small_light_gu"]
	state.equipped_gu_ids = ["small_light_gu"]
	state.event_log = [state._initial_event()]
	return state


func append_event(event: Dictionary) -> RunState:
	var next := _copy()
	var entry := _normalized_event(event, next.event_log.size())
	next._apply_after(entry["after"])
	next.event_log.append(entry)
	return next


func to_save_data() -> Dictionary:
	return {
		"seed": seed,
		"stage": stage,
		"cultivation": cultivation,
		"essence": essence,
		"injury": injury,
		"lifespan_debt": lifespan_debt,
		"stone": stone,
		"gu_ids": gu_ids.duplicate(),
		"equipped_gu_ids": equipped_gu_ids.duplicate(),
		"inheritance_ids": inheritance_ids.duplicate(),
		"body_imprints": body_imprints.duplicate(),
		"clues": clues.duplicate(),
		"relations": relations.duplicate(true),
		"pursuit": pursuit,
		"ascension": ascension.duplicate(true),
		"known_facts": known_facts.duplicate(),
		"current_node_id": current_node_id,
		"event_log": event_log.duplicate(true),
	}


func _initial_event() -> Dictionary:
	return {
		"id": "event_0000",
		"stage": stage,
		"time": 0,
		"node_id": current_node_id,
		"action": "run_started",
		"before": {},
		"after": {
			"stone": stone,
			"essence": essence,
			"gu_ids": gu_ids.duplicate(),
			"equipped_gu_ids": equipped_gu_ids.duplicate(),
		},
		"reason": "new_run",
		"source": "run_state",
		"targets": [],
	}


func _copy() -> RunState:
	var copy := RunState.new()
	copy.seed = seed
	copy.stage = stage
	copy.cultivation = cultivation
	copy.essence = essence
	copy.injury = injury
	copy.lifespan_debt = lifespan_debt
	copy.stone = stone
	copy.gu_ids = gu_ids.duplicate()
	copy.equipped_gu_ids = equipped_gu_ids.duplicate()
	copy.inheritance_ids = inheritance_ids.duplicate()
	copy.body_imprints = body_imprints.duplicate()
	copy.clues = clues.duplicate()
	copy.relations = relations.duplicate(true)
	copy.pursuit = pursuit
	copy.ascension = ascension.duplicate(true)
	copy.known_facts = known_facts.duplicate()
	copy.current_node_id = current_node_id
	copy.event_log = event_log.duplicate(true)
	return copy


func _normalized_event(event: Dictionary, index: int) -> Dictionary:
	return {
		"id": "event_%04d" % index,
		"stage": event.get("stage", stage),
		"time": event.get("time", index),
		"node_id": event.get("node_id", current_node_id),
		"action": event.get("action", "state_change"),
		"before": event.get("before", {}).duplicate(true),
		"after": event.get("after", {}).duplicate(true),
		"reason": event.get("reason", ""),
		"source": event.get("source", current_node_id),
		"targets": event.get("targets", []).duplicate(true),
	}


func _apply_after(after: Dictionary) -> void:
	for key in after:
		if key in [
			"stage", "cultivation", "essence", "injury", "lifespan_debt", "stone",
			"gu_ids", "equipped_gu_ids", "inheritance_ids", "body_imprints", "clues",
			"relations", "pursuit", "ascension", "known_facts", "current_node_id",
		]:
			set(key, _copy_value(after[key]))


func _copy_value(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
