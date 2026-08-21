class_name SaveRepository
extends RefCounted


const SAVE_PATH := "user://nanjiang_smoke_save.json"
const TEMP_PATH := "user://nanjiang_smoke_save.json.tmp"
const SAVE_VERSION := 1


static func save_run(state: RunState, route: Array, replies: Array) -> Error:
	var data := serialize_run(state, route, replies)
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if remove_error != OK:
			return remove_error
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(TEMP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH)
	)


static func serialize_run(state: RunState, route: Array, replies: Array) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"state": state.to_save_data(),
		"route": route.duplicate(true),
		"replies": _validated_replies(replies),
	}


static func load_run() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK:
		return {}
	if not json.data is Dictionary:
		return {}
	return load_run_from_data(json.data)


static func load_run_from_data(data: Dictionary) -> Dictionary:
	if int(data.get("version", -1)) != SAVE_VERSION:
		return {}
	if not data.get("state", null) is Dictionary:
		return {}
	if not data.get("route", null) is Array:
		return {}
	var replies := _validated_replies(data.get("replies", []))
	return {
		"state": _state_from_save_data(data["state"]),
		"route": data["route"].duplicate(true),
		"replies": replies,
	}


static func _state_from_save_data(data: Dictionary) -> RunState:
	var state := RunState.new()
	state.seed = int(data.get("seed", 0))
	state.stage = str(data.get("stage", "one"))
	state.cultivation = int(data.get("cultivation", 1))
	state.essence = int(data.get("essence", 3))
	state.injury = int(data.get("injury", 0))
	state.lifespan_debt = int(data.get("lifespan_debt", 0))
	state.stone = int(data.get("stone", 12))
	state.gu_ids = _string_array(data.get("gu_ids", []))
	state.equipped_gu_ids = _string_array(data.get("equipped_gu_ids", []))
	state.inheritance_ids = _string_array(data.get("inheritance_ids", []))
	state.body_imprints = _string_array(data.get("body_imprints", []))
	state.clues = _string_array(data.get("clues", []))
	state.relations = data.get("relations", {}).duplicate(true)
	state.pursuit = int(data.get("pursuit", 0))
	state.ascension = data.get("ascension", {}).duplicate(true)
	state.known_facts = _string_array(data.get("known_facts", []))
	state.current_node_id = str(data.get("current_node_id", "awakening"))
	state.event_log = data.get("event_log", []).duplicate(true)
	return state


static func _validated_replies(replies: Variant) -> Array[Dictionary]:
	var valid: Array[Dictionary] = []
	if not replies is Array:
		return valid
	for reply in replies:
		if not reply is Dictionary:
			continue
		var payload: Dictionary = reply.duplicate(true)
		payload.erase("source")
		if DialogueGateway.is_valid_response(payload):
			valid.append(payload)
	return valid


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		result.append(str(item))
	return result
