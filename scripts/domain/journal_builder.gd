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
	var snapshot := _log_snapshot(state.event_log)
	var conditions: Dictionary = outcome.get("conditions", _conditions_from_snapshot(snapshot)).duplicate(true)
	var entries: Array[Dictionary] = []
	for condition_id in CONDITION_HEADINGS:
		entries.append(_condition_entry(state.event_log, snapshot, condition_id, bool(conditions.get(condition_id, false))))
	entries.append(_stone_entry(state.event_log, snapshot))
	entries.append(_cultivation_entry(state.event_log, snapshot))
	var imprint_entry := _imprint_entry(state.event_log, snapshot)
	if not imprint_entry.is_empty():
		entries.append(imprint_entry)
	var relationship_entry := _relationship_entry(state.event_log, snapshot)
	if not relationship_entry.is_empty():
		entries.append(relationship_entry)
	var turning_point := _turning_point_entry(state.event_log)
	if not turning_point.is_empty():
		entries.append(turning_point)
	entries.append(_outcome_entry(state.event_log, snapshot, str(outcome.get("outcome", "survived_failure"))))
	return entries


static func text_for(entry: Dictionary) -> String:
	var body_key := str(entry.get("body_key", ""))
	var template := str(BODY_TEXT.get(body_key, ""))
	var values: Array = entry.get("values", [])
	if values.is_empty():
		return template
	return template % values


static func _condition_entry(events: Array[Dictionary], snapshot: Dictionary, condition_id: String, is_ready: bool) -> Dictionary:
	return _entry(
		str(CONDITION_HEADINGS[condition_id]),
		"condition_ready" if is_ready else "condition_missing",
		_condition_event_ids(events, condition_id),
		_condition_facts(_string_array(snapshot["known_facts"]), condition_id)
	)


static func _stone_entry(events: Array[Dictionary], snapshot: Dictionary) -> Dictionary:
	return _entry("Stone balance", "stone_balance", _events_changing(events, "stone"), [], [snapshot["stone"]])


static func _cultivation_entry(events: Array[Dictionary], snapshot: Dictionary) -> Dictionary:
	return _entry("Cultivation", "cultivation_progress", _events_changing(events, "cultivation"), [], [snapshot["cultivation"]])


static func _imprint_entry(events: Array[Dictionary], snapshot: Dictionary) -> Dictionary:
	var event_ids := _events_with_action(events, "take_body_imprint")
	var imprints := _string_array(snapshot["body_imprints"])
	if imprints.is_empty() and snapshot["lifespan_debt"] == 0:
		return {}
	if not imprints.is_empty():
		return _entry("Body imprint", "body_imprint", event_ids, _facts_for_imprints(_string_array(snapshot["known_facts"]), imprints), [", ".join(imprints)])
	return _entry("Lifespan consequence", "lifespan_debt", event_ids, [], [snapshot["lifespan_debt"]])


static func _relationship_entry(events: Array[Dictionary], snapshot: Dictionary) -> Dictionary:
	var relations: Dictionary = snapshot["relations"]
	if not relations.has("caravan_steward"):
		return {}
	var relation: Dictionary = relations["caravan_steward"]
	return _entry(
		"Caravan relationship",
		"relationship",
		_events_with_action_prefix(events, "social_"),
		_facts_with_prefix(_string_array(snapshot["known_facts"]), "caravan_"),
		[str(relation.get("stance", "neutral"))]
	)


static func _turning_point_entry(events: Array[Dictionary]) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("action", "")) not in ["run_started", "attempt_ascension"]:
			return _entry("Key turning point", "turning_point", [str(event.get("id", ""))], [])
	return {}


static func _outcome_entry(events: Array[Dictionary], snapshot: Dictionary, outcome_id: String) -> Dictionary:
	var body_key := outcome_id
	if outcome_id == "survived_failure":
		if snapshot["lifespan_debt"] > 0:
			body_key = "survived_failure_debt"
		elif not snapshot["body_imprints"].is_empty():
			body_key = "survived_failure_imprint"
		else:
			body_key = "survived_failure_retreat"
	return _entry("Outcome", body_key, _events_with_action(events, "attempt_ascension"), [])


static func _conditions_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var ascension: Dictionary = snapshot["ascension"]
	if ascension.has("conditions"):
		return ascension["conditions"].duplicate(true)
	return {
		"aperture_foundation": ascension.get("aperture_foundation", false),
		"heaven_earth_qi": ascension.get("heaven_earth_qi", false),
		"site": ascension.get("site", false),
		"protection": ascension.get("protection", false),
		"external_interference": not ascension.get("external_interference", true),
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


static func _facts_for_imprints(known_facts: Array[String], imprints: Array[String]) -> Array[String]:
	var facts: Array[String] = []
	for imprint_id in imprints:
		facts.append_array(_facts_with_prefix(known_facts, imprint_id))
	return facts


static func _facts_with_prefix(facts: Array[String], prefix: String) -> Array[String]:
	var visible: Array[String] = []
	for fact in facts:
		if fact.begins_with(prefix):
			visible.append(fact)
	return visible


static func _log_snapshot(events: Array[Dictionary]) -> Dictionary:
	var snapshot := {
		"stone": 0,
		"cultivation": 0,
		"lifespan_debt": 0,
		"body_imprints": [],
		"known_facts": [],
		"relations": {},
		"ascension": {},
	}
	for event in events:
		var after: Dictionary = event.get("after", {})
		for key in snapshot:
			if after.has(key):
				snapshot[key] = _copy_log_value(after[key])
	return snapshot


static func _copy_log_value(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate(true)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		result.append(str(item))
	return result


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
