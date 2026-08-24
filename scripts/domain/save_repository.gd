class_name SaveRepository
extends RefCounted


const SAVE_PATH := "user://nanjiang_smoke_save.json"
const TEMP_PATH := "user://nanjiang_smoke_save.json.tmp"
const META_PATH := "user://nanjiang_smoke_meta.json"
const META_TEMP_PATH := "user://nanjiang_smoke_meta.json.tmp"
const SAVE_VERSION := 2


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
	var state_data := state.to_save_data()
	return {
		"version": SAVE_VERSION,
		"state": state_data,
		"_checksum": _state_checksum(state_data),
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


static func _is_integral(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, floor(value)))


static func load_run_from_data(data: Dictionary) -> Dictionary:
	if int(data.get("version", -1)) != SAVE_VERSION:
		return {}
	if not data.get("state", null) is Dictionary:
		return {}
	if not data.get("route", null) is Array:
		return {}
	if not _is_integral(data.get("_checksum", null)):
		return {}
	if int(data["_checksum"]) != _state_checksum(data["state"]):
		return {}
	var state: Variant = _state_from_save_data(data["state"])
	if state == null:
		return {}
	var replies := _validated_replies(data.get("replies", []))
	return {
		"state": state,
		"route": data["route"].duplicate(true),
		"replies": replies,
	}


static func serialize_meta(meta: RefCounted) -> Dictionary:
	var meta_data: Dictionary = meta.to_save_data()
	return {
		"version": SAVE_VERSION,
		"meta": meta_data,
		"_checksum": _state_checksum(meta_data),
	}


static func load_meta_from_data(data: Dictionary) -> RefCounted:
	if int(data.get("version", -1)) != SAVE_VERSION:
		return null
	if not data.get("meta", null) is Dictionary:
		return null
	if not _is_integral(data.get("_checksum", null)):
		return null
	var meta_data: Dictionary = data["meta"]
	if int(data["_checksum"]) != _state_checksum(meta_data):
		return null
	var meta = load("res://scripts/domain/meta_progress.gd").new()
	meta.gu_codex_ids = _string_array(meta_data.get("gu_codex_ids", []))
	meta.recipe_codex_ids = _string_array(meta_data.get("recipe_codex_ids", []))
	meta.inheritance_codex_ids = _string_array(meta_data.get("inheritance_codex_ids", []))
	meta.unlocked_content_ids = _string_array(meta_data.get("unlocked_content_ids", []))
	meta.unlocked_random_outcomes = meta_data.get("unlocked_random_outcomes", {}).duplicate(true)
	meta.statistics = meta_data.get("statistics", {
		"runs_started": 0,
		"runs_won": 0,
		"deaths": 0,
	}).duplicate(true)
	return meta


static func save_meta_file(meta: RefCounted) -> Error:
	var payload := serialize_meta(meta)
	var file := FileAccess.open(META_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload))
	file = null
	if FileAccess.file_exists(META_PATH):
		DirAccess.remove_absolute(META_PATH)
	if DirAccess.rename_absolute(META_TEMP_PATH, META_PATH) != OK:
		return FAILED
	return OK


static func load_meta_file() -> RefCounted:
	if not FileAccess.file_exists(META_PATH):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(META_PATH)) != OK:
		return null
	if not json.data is Dictionary:
		return null
	return load_meta_from_data(json.data)


static func _state_from_save_data(data: Dictionary) -> Variant:
	var state := RunState.new()
	state.seed = int(data.get("seed", 0))
	state.stage = str(data.get("stage", "one"))
	state.cultivation = int(data.get("cultivation", 1))
	state.essence = int(data.get("essence", 3))
	state.essence_capacity = int(data.get("essence_capacity", 4))
	state.health = int(data.get("health", 6))
	state.max_health = int(data.get("max_health", 6))
	state.aptitude = str(data.get("aptitude", "bing"))
	state.injury = int(data.get("injury", 0))
	state.lifespan_debt = int(data.get("lifespan_debt", 0))
	state.stone = int(data.get("stone", 12))
	state.gu_ids = _string_array(data.get("gu_ids", []))
	state.refined_gu_ids = _string_array(data.get("refined_gu_ids", state.gu_ids))
	state.equipped_gu_ids = _string_array(data.get("equipped_gu_ids", []))
	state.inheritance_ids = _string_array(data.get("inheritance_ids", []))
	state.body_imprints = _string_array(data.get("body_imprints", []))
	state.clues = _string_array(data.get("clues", []))
	state.relations = data.get("relations", {}).duplicate(true)
	state.pursuit = int(data.get("pursuit", 0))
	state.ascension = data.get("ascension", {}).duplicate(true)
	state.known_facts = _string_array(data.get("known_facts", []))
	state.current_node_id = str(data.get("current_node_id", "awakening"))
	state.route_progress = _string_array(data.get("route_progress", []))
	state.node_flags = data.get("node_flags", {}).duplicate(true)
	state.encounter_session = data.get("encounter_session", {}).duplicate(true)
	state.encounter_results = _dictionary_array(data.get("encounter_results", []))
	state.saved_combos = _dictionary_array(data.get("saved_combos", []))
	state.event_log = _dictionary_array(data.get("event_log", []))
	state.cultivator = data.get("cultivator", {
		"reincarnation": state.cultivation,
		"stage": 0,
		"aptitude": state.aptitude,
		"health": state.health,
		"max_health": state.max_health,
		"lifespan": 60,
		"soul": 4,
		"soul_max": 4,
		"soul_control_limit": 2,
		"statuses": {},
	}).duplicate(true)
	state.cave_aperture = data.get("cave_aperture", {
		"essence": state.essence,
		"essence_max": state.essence_capacity,
		"essence_regen_per_turn": 2,
		"integrity": 6,
		"integrity_max": 6,
		"stored_gu_instance_ids": [],
	}).duplicate(true)
	state.gu_instances = data.get("gu_instances", {}).duplicate(true)
	state.gu_card_overrides = data.get("gu_card_overrides", {}).duplicate(true)
	state.materials = data.get("materials", {"feed_points": 0}).duplicate(true)
	state.relic_ids = _string_array(data.get("relic_ids", []))
	state.terminal_state = str(data.get("terminal_state", "active"))
	if not _has_valid_event_log(state):
		return null
	return state


static func _has_valid_event_log(state: RunState) -> bool:
	if state.event_log.is_empty():
		return false
	for index in state.event_log.size():
		var event: Variant = state.event_log[index]
		if not event is Dictionary or str(event.get("id", "")) != "event_%04d" % index:
			return false
	var last_event: Dictionary = state.event_log.back()
	var after: Variant = last_event.get("after", {})
	if not after is Dictionary:
		return false
	for key in after:
		if not key in state or state.get(key) != after[key]:
			return false
	return true


static func _state_checksum(state_data: Dictionary) -> int:
	return _checksum_value(state_data)


static func _checksum_value(value: Variant) -> int:
	if value is int:
		return int(value)
	if value is float and is_equal_approx(value, floor(value)):
		return int(value)
	if value is Array:
		var array_checksum := 0
		for item in value:
			array_checksum ^= _checksum_value(item)
		return array_checksum
	if value is Dictionary:
		var dictionary_checksum := 0
		var keys: Array = value.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for key in keys:
			dictionary_checksum ^= _checksum_value(value[key])
		return dictionary_checksum
	return 0


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


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for item in value:
		if item is Dictionary:
			result.append(item.duplicate(true))
	return result
