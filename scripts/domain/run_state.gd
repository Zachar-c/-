class_name RunState
extends RefCounted


const RelicHookResolverScript = preload("res://scripts/domain/relic_hook_resolver.gd")


@warning_ignore("shadowed_global_identifier")
var seed: int = 0
var stage: String = "one"
var cultivation: int = 1
var essence: int = 3
var essence_capacity: int = 4
var health: int = 6
var max_health: int = 6
var aptitude: String = "bing"
var injury: int = 0
var lifespan_debt: int = 0
var stone: int = 12
var loot_pity: int = 0
var material_pity: int = 0
var synthesis_fail_streak: int = 0
var gu_ids: Array[String] = []
var refined_gu_ids: Array[String] = []
var equipped_gu_ids: Array[String] = []
var inheritance_ids: Array[String] = []
var body_imprints: Array[String] = []
var contracts: Array[String] = []
var clues: Array[String] = []
var relations: Dictionary = {}
var pursuit: int = 0
var ascension: Dictionary = {}
var known_facts: Array[String] = []
var current_node_id: String = "awakening"
var route_progress: Array[String] = []
var node_flags: Dictionary = {}
var encounter_session: Dictionary = {}
var encounter_results: Array[Dictionary] = []
var saved_combos: Array[Dictionary] = []
var event_log: Array[Dictionary] = []

# Structured per-run state is introduced beside legacy scalars during migration.
var cultivator: Dictionary = {}
var cave_aperture: Dictionary = {}
var gu_instances: Dictionary = {}
var gu_card_overrides: Dictionary = {}
var materials: Dictionary = {}
var relic_ids: Array[String] = []
var meta_rules: Dictionary = {}
var terminal_state: String = "active"
var global_codex_ids: Array[String] = []
var school: String = ""


# Single source of truth for persisted/copied fields. Adding a field means:
# declare it above and add it here; _copy/to_save_data/load all follow.
# event_log and seed are deliberately excluded from event after-applies.
const STATE_FIELDS: Array[String] = [
	"seed", "stage", "cultivation", "essence", "essence_capacity", "health", "max_health",
	"aptitude", "injury", "lifespan_debt", "stone", "loot_pity", "material_pity", "synthesis_fail_streak",
	"gu_ids", "refined_gu_ids", "equipped_gu_ids", "inheritance_ids", "body_imprints", "contracts", "clues",
	"relations", "pursuit", "ascension", "known_facts", "current_node_id",
	"route_progress", "node_flags", "encounter_session", "encounter_results", "saved_combos", "event_log",
	"cultivator", "cave_aperture", "gu_instances", "gu_card_overrides", "materials",
	"relic_ids", "meta_rules", "global_codex_ids", "school", "terminal_state",
]


static func new_run(run_seed: int, meta: RefCounted = null) -> RunState:
	var state := RunState.new()
	state.seed = run_seed
	state.gu_ids = ["small_light_gu"]
	state.refined_gu_ids = ["small_light_gu"]
	state.equipped_gu_ids = ["small_light_gu"]
	state.cultivator = {
		"reincarnation": 1,
		"stage": 0,
		"aptitude": "bing",
		"health": 6,
		"max_health": 6,
		"lifespan": 60,
		"soul": 4,
		"soul_max": 4,
		"soul_control_limit": 2,
		"notorious": 0,
		"speed": 2,
		"force_power": 0,
		"force_imprints": [],
		"statuses": {},
	}
	state.cave_aperture = {
		"essence": 4,
		"essence_max": 4,
		"essence_regen_per_turn": 2,
		"integrity": 6,
		"integrity_max": 6,
		"stored_gu_instance_ids": ["gu_001"],
	}
	state.gu_instances = {
		"gu_001": {
			"instance_id": "gu_001",
			"definition_id": "small_light_gu",
			"state": "refined",
		}
	}
	state.gu_card_overrides = {}
	state.materials = {"feed_points": 0}
	state.relic_ids = []
	state.meta_rules = {}
	state.terminal_state = "active"
	if meta != null:
		for codex_id in meta.recipe_codex_ids + meta.gu_codex_ids:
			if not state.global_codex_ids.has(str(codex_id)):
				state.global_codex_ids.append(str(codex_id))
	state.current_node_id = "trailhead"
	state.event_log = [state._initial_event()]
	return state


func is_terminal() -> bool:
	return terminal_state != "active"


func finalize_death() -> RunState:
	# Single terminal-death transition: writes the final immutable run_ended event
	# and clears every temporary run collection. Event log is retained so
	# MetaProgress.record_run_end can still attribute the outcome.
	var cleared_aperture := cave_aperture.duplicate(true)
	cleared_aperture["stored_gu_instance_ids"] = []
	var cleared_ids: Array[String] = []
	return append_event({
		"action": "run_ended",
		"after": {
			"terminal_state": "dead",
			"gu_ids": cleared_ids,
			"refined_gu_ids": cleared_ids,
			"equipped_gu_ids": cleared_ids,
			"gu_instances": {},
			"gu_card_overrides": {},
			"materials": {},
			"relic_ids": cleared_ids,
			"cave_aperture": cleared_aperture,
			"encounter_session": {},
			"encounter_results": [],
		},
		"reason": "run_ended",
		"targets": [current_node_id],
	})


func refined_instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance_id in cave_aperture.get("stored_gu_instance_ids", []):
		var instance: Dictionary = gu_instances.get(str(instance_id), {})
		if str(instance.get("state", "")) in ["refined", "contracted", "weakened"]:
			result.append(instance.duplicate(true))
	return result


func sync_legacy_gu_projections() -> void:
	var projected_ids: Array[String] = []
	for instance in refined_instances():
		projected_ids.append(str(instance.get("definition_id", "")))
	gu_ids = projected_ids.duplicate()
	refined_gu_ids = projected_ids


static func next_gu_instance_id(instances: Dictionary) -> String:
	var highest := 0
	for key_value in instances:
		var text := str(key_value)
		if text.begins_with("gu_"):
			highest = maxi(highest, int(text.trim_prefix("gu_")))
	return "gu_%03d" % (highest + 1)


func append_event(event: Dictionary) -> RunState:
	# Returns a new RunState; applies event.after and records a normalized event without mutating this instance.
	var next := _copy()
	var entry := _normalized_event(event, next.event_log.size())
	next._apply_after(entry["after"])
	next.event_log.append(entry)
	return next


func estimate_feeding_materials(catalog: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	for instance in refined_instances():
		var definition: Dictionary = gu_by_id.get(str(instance.get("definition_id", "")), {})
		for material_id_value in definition.get("feeding_need", {}):
			var material_id := str(material_id_value)
			totals[material_id] = int(totals.get(material_id, 0)) + int(definition["feeding_need"][material_id_value])
	var extra := RelicHookResolverScript.feeding_extra(self, catalog)
	if extra > 0:
		totals["feed_points"] = int(totals.get("feed_points", 0)) + extra
	return totals


func estimate_feeding(catalog: Dictionary) -> int:
	var total := 0
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	for gu_id in refined_gu_ids:
		total += int(gu_by_id.get(gu_id, {}).get("feeding_cost", 0))
	return total


func to_save_data() -> Dictionary:
	var data := {}
	for field in STATE_FIELDS:
		data[field] = _copy_value(get(field))
	return data


func _initial_event() -> Dictionary:
	return {
		"id": "event_0000",
		"stage": stage,
		# Logical clock/event sequence, not wall-clock time.
		"time": 0,
		"node_id": current_node_id,
		"action": "run_started",
		"before": {},
		"after": {
			"stone": stone,
			"essence": essence,
			"gu_ids": gu_ids.duplicate(),
			"refined_gu_ids": refined_gu_ids.duplicate(),
			"equipped_gu_ids": equipped_gu_ids.duplicate(),
		},
		"reason": "new_run",
		"source": "run_state",
		"targets": [],
	}


func _copy() -> RunState:
	var copy := RunState.new()
	for field in STATE_FIELDS:
		if field == "event_log":
			# Entries are append-only and never mutated after append, so copies
			# may share entry dictionaries; duplicating the array itself keeps
			# later appends invisible to older states.
			copy.event_log = event_log.duplicate()
			continue
		copy.set(field, _copy_value(get(field)))
	return copy


func _normalized_event(event: Dictionary, index: int) -> Dictionary:
	return {
		"id": "event_%04d" % index,
		"stage": event.get("stage", stage),
		# Logical clock/event sequence, not wall-clock time.
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
		if str(key).begins_with("_"):
			# "_"-prefixed info keys ride the log for offline attribution only;
			# they must never reach live state fields.
			continue
		if not STATE_FIELDS.has(key) or key == "event_log" or key == "seed":
			# event_log is append-only and seed is immutable once set; event
			# after-payloads must never touch either.
			continue
		set(key, _copy_value(after[key]))


func _copy_value(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
