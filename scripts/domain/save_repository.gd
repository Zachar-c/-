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
		"route": _dictionary_array(data.get("route", [])),
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
	meta.relic_codex_ids = _string_array(meta_data.get("relic_codex_ids", []))
	meta.inheritance_codex_ids = _string_array(meta_data.get("inheritance_codex_ids", []))
	meta.unlocked_content_ids = _string_array(meta_data.get("unlocked_content_ids", []))
	meta.unlocked_random_outcomes = meta_data.get("unlocked_random_outcomes", {}).duplicate(true)
	# C1-min §16.13: fields added after v2 ship; old saves default to empty.
	meta.contracts_unlocked = _string_array(meta_data.get("contracts_unlocked", []))
	meta.hall_material_bonus_accrued = int(meta_data.get("hall_material_bonus_accrued", 0))
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
	for field in RunState.STATE_FIELDS:
		if not data.has(field):
			continue
		state.set(field, _coerce_state_field(field, data[field]))
	if not _has_valid_event_log(state):
		return null
	return state


static func _coerce_state_field(field: String, value: Variant) -> Variant:
	if value is Dictionary:
		return value.duplicate(true)
	var string_list_fields := [
		"gu_ids", "refined_gu_ids", "equipped_gu_ids", "inheritance_ids", "body_imprints",
		"contracts", "clues", "known_facts", "route_progress", "relic_ids", "global_codex_ids",
	]
	var dictionary_list_fields := ["encounter_results", "saved_combos", "event_log"]
	if string_list_fields.has(field):
		return _string_array(value)
	if dictionary_list_fields.has(field):
		return _dictionary_array(value)
	return value


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
		if str(key).begins_with("_"):
			# "_"-prefixed info keys are attribution metadata, not state fields.
			continue
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
