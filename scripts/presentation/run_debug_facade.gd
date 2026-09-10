class_name RunDebugFacade
extends RefCounted


# W12 split: §16.22 D5 developer-debug method family moved out of
# run_controller.gd. Static functions take the controller reference (panel
# nodes and the `_debug_enabled_for_test` test-injection switch stay on the
# controller); the controller keeps same-name one-line wrappers so the public
# API and test call sites are unchanged.
#
# Gate ownership (single source of truth): the is_debug_build gate lives on the
# controller via `_debug_enabled_for_test` (initialized from OS.is_debug_build);
# this facade reads it through `_debug_enabled(controller)` and every entry
# point early-returns when disabled. Release builds therefore keep zero debug
# nodes and inert methods, exactly as before the split.


const DebugActionsScript = preload("res://scripts/domain/debug_actions.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const ResourceVocabularyScript = preload("res://scripts/presentation/resource_vocabulary.gd")

const DEBUG_PANEL_PATH := "res://scenes/ui/widgets/debug_panel.tscn"
## 元石调试硬上限（经济供给上限未在数据表落地前的展示层安全界）。
const DEBUG_STONE_CAP := 99999
static var DEBUG_RESOURCE_LABELS := {
	"yuanstone": ResourceVocabularyScript.label("yuanstone"),
	"health": "生命",
	"lifespan": ResourceVocabularyScript.label("lifespan"),
	"soul": ResourceVocabularyScript.label("soul"),
	"essence": ResourceVocabularyScript.label("essence"),
}


static func _debug_enabled(controller) -> bool:
	return controller._debug_enabled_for_test


static func debug_panel_mounted(controller) -> bool:
	return controller._debug_panel != null


static func debug_add_gu(controller, gu_id: String) -> Dictionary:
	if not _debug_enabled(controller):
		return {"ok": false, "reason": "debug_disabled"}
	if controller.state == null or controller.catalog == null or controller.catalog.is_empty():
		return _debug_fail(controller, "no_active_run")
	var target := str(gu_id).strip_edges()
	var result := DebugActionsScript.apply(controller.state, controller.catalog,
			{"op": "add_gu", "definition_id": target}, _debug_enabled(controller))
	controller.state = result["state"]
	if not bool(result.get("ok", false)):
		var reason := str(result.get("result", {}).get("reason", ""))
		return _debug_fail_with(controller, reason, "调试失败：%s" % reason)
	var instance_id := str(result.get("result", {}).get("instance_id", ""))
	controller._debug_feedback = "调试：已加入 %s（实例 %s）" % [DisplayText.gu(target), instance_id]
	print("[debug] add_gu %s as %s" % [target, instance_id])
	controller._render()
	return {"ok": true, "instance_id": instance_id}


static func debug_set_resource(controller, kind: String, value) -> Dictionary:
	if not _debug_enabled(controller):
		return {"ok": false, "reason": "debug_disabled"}
	if controller.state == null:
		return _debug_fail(controller, "no_active_run")
	var amount := 0
	if value is int or value is float:
		amount = int(value)
	elif value is String:
		var text_value := str(value).strip_edges()
		if not text_value.is_valid_int():
			return _debug_fail_with(controller, "invalid_number", "调试失败：数值必须是整数（收到 %s）" % text_value)
		amount = int(text_value)
	else:
		return _debug_fail_with(controller, "invalid_number", "调试失败：数值类型不支持")
	# UI-layer clamp: stones uncapped in domain but panel shows 99999 cap.
	var api_kind := str(kind)
	if api_kind == "yuanstone" or api_kind == "stones":
		amount = clampi(amount, 0, DEBUG_STONE_CAP)
		api_kind = "stones"
	elif api_kind == "lifespan":
		return _debug_fail_with(controller, "unknown_kind", "调试失败：未知资源类别（%s）" % str(kind))
	elif api_kind not in ["stones", "health", "soul", "essence"]:
		return _debug_fail_with(controller, "unknown_kind", "调试失败：未知资源类别（%s）" % str(kind))
	var action := {"op": "set_resources"}
	action[api_kind] = amount
	var result := DebugActionsScript.apply(controller.state, controller.catalog, action, _debug_enabled(controller))
	controller.state = result["state"]

	if not bool(result.get("ok", false)):
		var reason := str(result.get("result", {}).get("reason", ""))
		return _debug_fail_with(controller, reason, "调试失败：%s" % reason)
	var applied := amount
	if api_kind == "essence":
		applied = int(result.get("result", {}).get("essence", amount))
	elif api_kind == "stones":
		applied = int(result.get("result", {}).get("stones", amount))
	elif api_kind == "health":
		applied = int(result.get("result", {}).get("health", amount))
	elif api_kind == "soul":
		applied = int(result.get("result", {}).get("soul", amount))
	print("[debug] set_resource %s -> %d" % [str(kind), applied])
	controller._debug_feedback = "调试：%s 已设为 %d" % [str(DEBUG_RESOURCE_LABELS.get(str(kind), str(kind))), applied]
	controller._render()
	return {"ok": true, "applied": applied}


static func debug_travel(controller, node_id: String) -> Dictionary:
	if not _debug_enabled(controller):
		return {"ok": false, "reason": "debug_disabled"}
	if controller.state == null or controller.route.is_empty():
		return _debug_fail(controller, "no_active_run")
	if not controller.current_battle.is_empty():
		return _debug_fail_with(controller, "battle_in_progress", "调试失败：战斗进行中，禁止跳层")
	var target := str(node_id).strip_edges()
	var visible_ids: Array[String] = []
	for visible_node in controller.visible_route_nodes():
		visible_ids.append(str(visible_node.get("id", "")))
	if not visible_ids.has(target):
		return _debug_fail_with(controller, "invisible_node", "调试失败：目标节点不在当前可见范围（%s）" % target)
	var result := DebugActionsScript.apply(controller.state, controller.catalog,
			{"op": "jump_to_node", "node_id": target}, _debug_enabled(controller), controller.route)
	controller.state = result["state"]

	if not bool(result.get("ok", false)):
		var reason := str(result.get("result", {}).get("reason", ""))
		return _debug_fail_with(controller, reason, "调试失败：跳层被拒（%s）" % reason)
	controller._debug_travel_node = target
	controller._view_name = "Map"
	controller._show_map()
	print("[debug] travel -> %s" % target)
	controller._debug_feedback = "调试：已跳至 %s" % target
	controller._render()
	return {"ok": true}


static func debug_snapshot_dump(controller) -> Dictionary:
	if not _debug_enabled(controller):
		return {}
	if controller.state == null:
		return {}
	var result := DebugActionsScript.apply(controller.state, controller.catalog,
			{"op": "dump_snapshot"}, _debug_enabled(controller))
	controller.state = result["state"]

	var snapshot: Dictionary = result.get("result", {}).get("snapshot", {})
	print("[debug] snapshot ", JSON.stringify(snapshot))
	controller._debug_feedback = "调试：RunData 快照已打印到 stdout"
	_render_debug_panel(controller)
	return snapshot


## 调试面板跳层下拉选项：仅当前可见节点（防越层破坏地图不变量）。
static func _debug_travel_options(controller) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if controller.state == null or controller.route.is_empty():
		return options
	for node in controller.visible_route_nodes():
		var nid := str(node.get("id", ""))
		options.append({
			"id": nid,
			# 调试跳层标签带节点类型，便于直接跳进战斗做交互验收。
			"label": "[%s] %s·%s" % [nid, str(node.get("type", "?")), str(node.get("label", DisplayText.node(nid)))],
		})
	return options


static func _debug_props(controller) -> Dictionary:
	var info: Dictionary = {}
	if controller.state != null:
		info = RunSnapshotBuilderScript.debug(controller)
	return {
		"open": controller._debug_panel_open,
		"feedback": controller._debug_feedback,
		"info": info,
		"gu_schools": _debug_gu_schools(controller),
		"gu_school": controller._debug_gu_school,
		"gu_options": _debug_gu_options(controller, controller._debug_gu_school),
		"gu_selected": controller._debug_gu_selected,
		"res_kind": controller._debug_res_kind,
		"res_value": controller._debug_res_value,
		"travel_options": _debug_travel_options(controller),
		"travel_selected": controller._debug_travel_node,
		"commands": {
			"toggle_open": func(): _toggle_debug_panel(controller),
			"set_gu_school": func(school_id: String): _set_debug_gu_school(controller, school_id),
			"set_gu_option": func(gu_id: String): _set_debug_gu_option(controller, gu_id),
			"add_gu": func(): debug_add_gu(controller, controller._debug_gu_selected),
			"set_res_kind": func(kind_value: String): _set_debug_res_kind(controller, kind_value),
			"set_res_value": func(num_text: String): _set_debug_res_value(controller, num_text),
			"apply_resource": func(): debug_set_resource(controller, controller._debug_res_kind, controller._debug_res_value),
			"set_travel_node": func(node_value: String): _set_debug_travel_node(controller, node_value),
			"travel": func(): debug_travel(controller, controller._debug_travel_node),
			"snapshot_dump": func(): debug_snapshot_dump(controller),
		},
	}


## 加蛊下拉 · 流派列表：目录 schools 顺序即展示顺序，label 用流派中文名。
static func _debug_gu_schools(controller) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if controller.catalog == null or controller.catalog.is_empty():
		return out
	var schools: Dictionary = controller.catalog.get("schools", {})
	for sid: String in schools.keys():
		var school_meta: Dictionary = schools[sid]
		out.append({
			"id": sid,
			"label": str(school_meta.get("name", school_meta.get("label", sid))),
		})
	return out


## 加蛊下拉 · 蛊虫选项：按所选流派过滤目录，label 用蛊虫中文名（DisplayText 同源）。
static func _debug_gu_options(controller, school_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if controller.catalog == null or controller.catalog.is_empty():
		return out
	for g: Dictionary in controller.catalog.get("gu", []):
		if str(g.get("school", "")) == school_id:
			var gid := str(g.get("id", ""))
			out.append({"id": gid, "label": DisplayText.gu(gid)})
	return out


static func _set_debug_gu_school(controller, value: String) -> void:
	controller._debug_gu_school = value
	# 切换流派后复位选择到该流派第一只蛊，保证"加蛊"永远有确定目标。
	controller._debug_gu_selected = ""
	for g: Dictionary in _debug_gu_options(controller, value):
		controller._debug_gu_selected = str(g.get("id", ""))
		break


static func _set_debug_gu_option(controller, value: String) -> void:
	controller._debug_gu_selected = value


static func _set_debug_res_kind(controller, value: String) -> void:
	controller._debug_res_kind = value


static func _set_debug_res_value(controller, value: String) -> void:
	controller._debug_res_value = value


static func _set_debug_travel_node(controller, value: String) -> void:
	controller._debug_travel_node = value


static func _toggle_debug_panel(controller) -> void:
	controller._debug_panel_open = not controller._debug_panel_open
	_render_debug_panel(controller)


static func _mount_debug_panel(controller) -> void:
	if controller._debug_panel != null:
		return
	var scene := load(DEBUG_PANEL_PATH) as PackedScene
	if scene == null:
		print("[debug] debug_panel 场景缺失，面板未挂载")
		return
	controller._debug_host = Control.new()
	controller._debug_host.name = "DebugPanelHost"
	controller._debug_host.position = Vector2(20, 80)
	controller._debug_host.custom_minimum_size = Vector2(420, 44)
	controller._debug_host.size = _debug_host_size(controller)
	controller._debug_host.mouse_filter = Control.MOUSE_FILTER_PASS
	controller.add_child(controller._debug_host)
	controller._debug_panel = scene.instantiate()
	controller._debug_host.add_child(controller._debug_panel)
	controller._debug_panel.set_props(_debug_props(controller))


static func _debug_host_size(controller) -> Vector2:
	# 线框稿 v2 基准：420px 分区浮窗（加蛊/资源/跳层/池情报/快照）。
	return Vector2(420, 450) if controller._debug_panel_open else Vector2(420, 44)


static func _render_debug_panel(controller) -> void:
	if controller._debug_panel == null:
		return
	if controller._debug_host != null:
		controller._debug_host.size = _debug_host_size(controller)
	controller._debug_panel.set_props(_debug_props(controller))


static func _debug_ok(controller, feedback: String) -> Dictionary:
	controller._debug_feedback = feedback
	# 主屏重渲染末尾已联动刷新调试面板（_render -> _render_debug_panel）。
	controller._render()
	return {"ok": true}


static func _debug_fail(_controller, reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _debug_fail_with(controller, reason: String, feedback: String) -> Dictionary:
	controller._debug_feedback = feedback
	_render_debug_panel(controller)
	return {"ok": false, "reason": reason}
