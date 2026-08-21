class_name JournalBuilder
extends RefCounted


const CONDITION_HEADINGS := {
	"aperture_foundation": "Aperture foundation",
	"heaven_earth_qi": "Heaven and earth qi",
	"site": "Ascension site",
	"protection": "Protection",
	"external_interference": "External interference",
}

const BODY_TEXT := {
	"condition_ready": "The condition was secured before the ascension window.",
	"condition_missing": "This condition remained incomplete when the ascension window opened.",
	"stone_balance": "The final stone balance was %d.",
	"cultivation_progress": "Cultivation closed at stage %d.",
	"body_imprint": "The body imprint %s left a lasting consequence.",
	"lifespan_debt": "Lifespan debt of %d remained at the final decision.",
	"relationship": "The caravan relationship settled as %s.",
	"turning_point": "A recorded decision changed the path to ascension.",
	"success": "The complete preparation held through the final crossing.",
	"risky_success": "The crossing succeeded, but the accumulated risk remains part of the new life.",
	"survived_failure_retreat": "The chance passed, but the survivor carried the path onward.",
	"survived_failure_debt": "The chance passed beneath a burden that could not be ignored.",
	"survived_failure_imprint": "The chance passed, leaving a marked body and a remembered lesson.",
}


static func build(state: RunState, outcome: Dictionary) -> Array[Dictionary]:
	var conditions: Dictionary = outcome.get("conditions", _conditions_from_state(state)).duplicate(true)
	var entries: Array[Dictionary] = []
	for condition_id in CONDITION_HEADINGS:
		entries.append(_condition_entry(state, condition_id, bool(conditions.get(condition_id, false))))
	entries.append(_stone_entry(state))
	entries.append(_cultivation_entry(state))
	var imprint_entry := _imprint_entry(state)
	if not imprint_entry.is_empty():
		entries.append(imprint_entry)
	var relationship_entry := _relationship_entry(state)
	if not relationship_entry.is_empty():
		entries.append(relationship_entry)
	var turning_point := _turning_point_entry(state)
	if not turning_point.is_empty():
		entries.append(turning_point)
	entries.append(_outcome_entry(state, str(outcome.get("outcome", "survived_failure"))))
	return entries


static func text_for(entry: Dictionary) -> String:
	var body_key := str(entry.get("body_key", ""))
	var template := str(BODY_TEXT.get(body_key, ""))
	var values: Array = entry.get("values", [])
	if values.is_empty():
		return template
	return template % values


static func _condition_entry(state: RunState, condition_id: String, is_ready: bool) -> Dictionary:
	return _entry(
		str(CONDITION_HEADINGS[condition_id]),
		"condition_ready" if is_ready else "condition_missing",
		_condition_event_ids(state.event_log, condition_id),
		_condition_facts(state.known_facts, condition_id)
	)


static func _stone_entry(state: RunState) -> Dictionary:
	return _entry("Stone balance", "stone_balance", _events_changing(state.event_log, "stone"), [], [state.stone])


static func _cultivation_entry(state: RunState) -> Dictionary:
	return _entry("Cultivation", "cultivation_progress", _events_changing(state.event_log, "cultivation"), [], [state.cultivation])


static func _imprint_entry(state: RunState) -> Dictionary:
	var event_ids := _events_with_action(state.event_log, "take_body_imprint")
	if state.body_imprints.is_empty() and state.lifespan_debt == 0:
		return {}
	if not state.body_imprints.is_empty():
		return _entry("Body imprint", "body_imprint", event_ids, _facts_for_imprints(state), [", ".join(state.body_imprints)])
	return _entry("Lifespan consequence", "lifespan_debt", event_ids, [], [state.lifespan_debt])


static func _relationship_entry(state: RunState) -> Dictionary:
	if not state.relations.has("caravan_steward"):
		return {}
	var relation: Dictionary = state.relations["caravan_steward"]
	return _entry(
		"Caravan relationship",
		"relationship",
		_events_with_action_prefix(state.event_log, "social_"),
		_facts_with_prefix(state.known_facts, "caravan_"),
		[str(relation.get("stance", "neutral"))]
	)


static func _turning_point_entry(state: RunState) -> Dictionary:
	for index in range(state.event_log.size() - 1, -1, -1):
		var event: Dictionary = state.event_log[index]
		if str(event.get("action", "")) not in ["run_started", "attempt_ascension"]:
			return _entry("Key turning point", "turning_point", [str(event.get("id", ""))], [])
	return {}


static func _outcome_entry(state: RunState, outcome_id: String) -> Dictionary:
	var body_key := outcome_id
	if outcome_id == "survived_failure":
		if state.lifespan_debt > 0:
			body_key = "survived_failure_debt"
		elif not state.body_imprints.is_empty():
			body_key = "survived_failure_imprint"
		else:
			body_key = "survived_failure_retreat"
	return _entry("Outcome", body_key, _events_with_action(state.event_log, "attempt_ascension"), [])


static func _conditions_from_state(state: RunState) -> Dictionary:
	return {
		"aperture_foundation": state.ascension.get("aperture_foundation", false),
		"heaven_earth_qi": state.ascension.get("heaven_earth_qi", false),
		"site": state.ascension.get("site", false),
		"protection": state.ascension.get("protection", false),
		"external_interference": not state.ascension.get("external_interference", true),
	}


static func _condition_event_ids(events: Array[Dictionary], condition_id: String) -> Array[String]:
	var tokens := [condition_id]
	if condition_id == "heaven_earth_qi":
		tokens.append_array(["caravan_trade", "earth_vein", "qi"])
	elif condition_id == "external_interference":
		tokens.append_array(["pursuit", "retreat", "caravan_reinforcements"])
	var ids: Array[String] = []
	for event in events:
		var text := "%s %s %s" % [event.get("action", ""), event.get("reason", ""), event.get("node_id", "")]
		for token in tokens:
			if text.contains(token):
				ids.append(str(event.get("id", "")))
				break
	return ids


static func _events_changing(events: Array[Dictionary], key: String) -> Array[String]:
	var ids: Array[String] = []
	for event in events:
		var before: Dictionary = event.get("before", {})
		var after: Dictionary = event.get("after", {})
		if before.has(key) or after.has(key):
			ids.append(str(event.get("id", "")))
	return ids


static func _events_with_action(events: Array[Dictionary], action: String) -> Array[String]:
	var ids: Array[String] = []
	for event in events:
		if event.get("action", "") == action:
			ids.append(str(event.get("id", "")))
	return ids


static func _events_with_action_prefix(events: Array[Dictionary], prefix: String) -> Array[String]:
	var ids: Array[String] = []
	for event in events:
		if str(event.get("action", "")).begins_with(prefix):
			ids.append(str(event.get("id", "")))
	return ids


static func _condition_facts(facts: Array[String], condition_id: String) -> Array[String]:
	var prefix := condition_id
	if condition_id == "heaven_earth_qi":
		prefix = "heaven_earth_qi"
	return _facts_with_prefix(facts, prefix)


static func _facts_for_imprints(state: RunState) -> Array[String]:
	var facts: Array[String] = []
	for imprint_id in state.body_imprints:
		facts.append_array(_facts_with_prefix(state.known_facts, imprint_id))
	return facts


static func _facts_with_prefix(facts: Array[String], prefix: String) -> Array[String]:
	var visible: Array[String] = []
	for fact in facts:
		if fact.begins_with(prefix):
			visible.append(fact)
	return visible


static func _entry(
	heading: String,
	body_key: String,
	event_ids: Array[String],
	visible_facts: Array[String],
	values: Array = []
) -> Dictionary:
	return {
		"heading": heading,
		"body_key": body_key,
		"event_ids": event_ids,
		"visible_facts": visible_facts,
		"values": values,
	}
