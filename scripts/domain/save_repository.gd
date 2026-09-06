class_name SaveRepository
extends RefCounted


const SAVE_PATH := "user://nanjiang_smoke_save.json"
const TEMP_PATH := "user://nanjiang_smoke_save.json.tmp"
const META_PATH := "user://nanjiang_smoke_meta.json"
const META_TEMP_PATH := "user://nanjiang_smoke_meta.json.tmp"
const SAVE_VERSION := 4


static func delete_run_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


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


# E0 存档导入导出：把进行中冒险导出为调用方指定路径的 JSON（分享/备份）。
# 载荷与固定路径存档完全一致（serialize_run：版本 + 校验和 + 路由 + 回复），
# 导出是副本写入，不触碰 user:// 下的活动存档。
static func export_run_to_file(state: RunState, route: Array, replies: Array, path: String) -> Error:
	var payload := serialize_run(state, route, replies)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	return OK


# 从任意路径导入存档：拒绝契约与 load_run_from_data 一致 —— 返回
# {"ok": false, "reason", "message"} 拒绝字典（缺失/非法 JSON/版本不符/
# 校验和不符），成功返回 {"state", "route", "replies"}，绝不静默空字典。
# 校验复用 diagnose_run_data，因此导入文件与固定存档受同一 schema 版本门。
static func import_run_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _run_load_rejection({"ok": false, "kind": "missing"})
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return _run_load_rejection({"ok": false, "kind": "invalid_json"})
	return load_run_from_data(json.data)


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
	var diagnosis := diagnose_run_file()
	if not bool(diagnosis.get("ok", false)):
		# Failure contract is uniform with load_run_from_data: a refusal dict,
		# never a silent {} — callers must check has("state"), not is_empty().
		return _run_load_rejection(diagnosis)
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK or not json.data is Dictionary:
		return _run_load_rejection({"ok": false, "kind": "invalid_json"})
	return load_run_from_data(json.data)


static func diagnose_run_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"ok": false, "kind": "missing"}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK or not json.data is Dictionary:
		return {"ok": false, "kind": "invalid_json"}
	return diagnose_run_data(json.data)


static func _is_integral(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, floor(value)))


static func diagnose_run_data(data: Dictionary) -> Dictionary:
	var version_value: Variant = data.get("version", null)
	if not _is_integral(version_value) or int(version_value) != SAVE_VERSION:
		return {"ok": false, "kind": "unsupported_version", "version": int(version_value) if _is_integral(version_value) else -1}
	if not data.get("state", null) is Dictionary:
		return {"ok": false, "kind": "invalid_state"}
	if not data.get("route", null) is Array:
		return {"ok": false, "kind": "invalid_route"}
	if not _is_integral(data.get("_checksum", null)):
		return {"ok": false, "kind": "checksum_missing"}
	if int(data["_checksum"]) != _state_checksum(data["state"]):
		return {"ok": false, "kind": "checksum_mismatch"}
	if _state_from_save_data(data["state"]) == null:
		return {"ok": false, "kind": "invalid_event_log"}
	return {"ok": true, "kind": "ok", "version": SAVE_VERSION}


static func load_run_from_data(data: Dictionary) -> Dictionary:
	var diagnosis := diagnose_run_data(data)
	if not bool(diagnosis.get("ok", false)):
		return _run_load_rejection(diagnosis)
	var state: Variant = _state_from_save_data(data["state"])
	if state == null:
		return {}
	# P2a B: v2 saves keyed rest visit/mode by the bare node id and a global
	# literal; the per-node scheme derives "<id>_used"/"<id>_mode". Add-only
	# because the bare-id key doubles as the visited marker (_complete_node
	# idempotency + MapGenerator.reachable_nodes).
	_migrate_legacy_rest_flags(state.node_flags)
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


# Spec-v4 (T1.1): refuse incompatible in-progress runs with a player-readable
# reason instead of a silent empty dict. The hall save is never the victim —
# codex / recipes / contracts / stats are migrated separately (see load_meta).
static func _run_load_rejection(diagnosis: Dictionary) -> Dictionary:
	var kind := str(diagnosis.get("kind", "unknown"))
	if kind == "unsupported_version" and int(diagnosis.get("version", 0)) == 3:
		return {
			"ok": false,
			"reason": "schema_v4_required",
			"message": "规则版本已升级，旧进行中冒险无法继续；大厅进度、蛊方图鉴与已解锁信息已保留。",
		}
	return {"ok": false, "reason": kind, "message": "存档无法载入（%s）。" % kind}


static func load_meta_from_data(data: Dictionary) -> RefCounted:
	# Spec-v4 (T1.1): a v3 hall save is migrated, never dropped. The checksum
	# already hashes only the meta fields, so the pre-migration payload stays
	# verifiable; MetaProgress.from_save_data keeps codex/recipes/contracts/
	# stats with zero loss.
	var version_value := int(data.get("version", -1))
	if version_value != SAVE_VERSION and version_value != 3:
		return null
	if not data.get("meta", null) is Dictionary:
		return null
	if not _is_integral(data.get("_checksum", null)):
		return null
	var meta_data: Dictionary = data["meta"]
	if int(data["_checksum"]) != _state_checksum(meta_data):
		return null
	return MetaProgress.from_save_data(meta_data)


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


# P2a B: derive per-node rest flags from the legacy bare-id/global literals.
static func _migrate_legacy_rest_flags(flags: Dictionary) -> void:
	if not flags.has("rest_hollow_used") and flags.has("rest_hollow"):
		flags["rest_hollow_used"] = str(flags["rest_hollow"])
	if not flags.has("rest_hollow_mode") and str(flags.get("rest_mode_used", "")) != "":
		flags["rest_hollow_mode"] = str(flags["rest_mode_used"])


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
