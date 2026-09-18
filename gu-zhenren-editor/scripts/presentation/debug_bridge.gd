extends RefCounted
## Release-safe debug façade bridge (P0-1 compile-time prune).
## No class_name — RunController preloads this script. The façade
## implementation is loaded by path only on debug builds; Release packs
## keep inert methods and never load façade / panel / debug_actions.

const FACADE_PATH := "res://scripts/presentation/run_debug_facade.gd"

static var _facade: Script = null
static var _resolved := false


static func _should_load() -> bool:
	return OS.is_debug_build() or OS.has_feature("debug")


static func _ensure() -> void:
	if _resolved:
		return
	_resolved = true
	if not _should_load():
		_facade = null
		return
	if not ResourceLoader.exists(FACADE_PATH):
		_facade = null
		return
	_facade = load(FACADE_PATH) as Script


## Test seam: force re-resolve (GUT can re-enable after mutating gates).
static func reset_for_test() -> void:
	_facade = null
	_resolved = false


static func enabled(controller) -> bool:
	return controller._debug_enabled_for_test


static func panel_mounted(controller) -> bool:
	return controller._debug_panel != null


static func debug_add_gu(controller, gu_id: String) -> Dictionary:
	_ensure()
	if _facade == null:
		return {"ok": false, "reason": "debug_disabled"}
	return _facade.debug_add_gu(controller, gu_id)


static func debug_set_resource(controller, kind: String, value) -> Dictionary:
	_ensure()
	if _facade == null:
		return {"ok": false, "reason": "debug_disabled"}
	return _facade.debug_set_resource(controller, kind, value)


static func debug_travel(controller, node_id: String) -> Dictionary:
	_ensure()
	if _facade == null:
		return {"ok": false, "reason": "debug_disabled"}
	return _facade.debug_travel(controller, node_id)


static func debug_snapshot_dump(controller) -> Dictionary:
	_ensure()
	if _facade == null:
		return {}
	return _facade.debug_snapshot_dump(controller)


static func travel_options(controller) -> Array[Dictionary]:
	_ensure()
	if _facade == null:
		return [] as Array[Dictionary]
	return _facade._debug_travel_options(controller)


static func props(controller) -> Dictionary:
	_ensure()
	if _facade == null:
		return {}
	return _facade._debug_props(controller)


static func gu_schools(controller) -> Array[Dictionary]:
	_ensure()
	if _facade == null:
		return [] as Array[Dictionary]
	return _facade._debug_gu_schools(controller)


static func gu_options(controller, school_id: String) -> Array[Dictionary]:
	_ensure()
	if _facade == null:
		return [] as Array[Dictionary]
	return _facade._debug_gu_options(controller, school_id)


static func set_gu_school(controller, value: String) -> void:
	_ensure()
	if _facade == null:
		return
	_facade._set_debug_gu_school(controller, value)


static func set_gu_option(controller, value: String) -> void:
	_ensure()
	if _facade == null:
		return
	_facade._set_debug_gu_option(controller, value)


static func set_res_kind(controller, value: String) -> void:
	_ensure()
	if _facade == null:
		return
	_facade._set_debug_res_kind(controller, value)


static func set_res_value(controller, value: String) -> void:
	_ensure()
	if _facade == null:
		return
	_facade._set_debug_res_value(controller, value)


static func set_travel_node(controller, value: String) -> void:
	_ensure()
	if _facade == null:
		return
	_facade._set_debug_travel_node(controller, value)


static func toggle_panel(controller) -> void:
	_ensure()
	if _facade == null:
		return
	_facade._toggle_debug_panel(controller)


static func mount_panel(controller) -> void:
	_ensure()
	if _facade == null:
		return
	_facade._mount_debug_panel(controller)


static func host_size(controller) -> Vector2:
	_ensure()
	if _facade == null:
		return Vector2.ZERO
	return _facade._debug_host_size(controller)


static func render_panel(controller) -> void:
	_ensure()
	if _facade == null:
		return
	_facade._render_debug_panel(controller)


static func debug_ok(controller, feedback: String) -> Dictionary:
	_ensure()
	if _facade == null:
		return {"ok": false, "reason": "debug_disabled"}
	return _facade._debug_ok(controller, feedback)


static func debug_fail(_controller, reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func debug_fail_with(controller, reason: String, feedback: String) -> Dictionary:
	_ensure()
	if _facade == null:
		return {"ok": false, "reason": reason}
	return _facade._debug_fail_with(controller, reason, feedback)
