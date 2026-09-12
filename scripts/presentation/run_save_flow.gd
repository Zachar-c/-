class_name RunSaveFlow
extends RefCounted


# W12 split: run save/load lifecycle moved out of run_controller.gd. Static
# functions take the controller reference (same object identity, no duplication
# of run state); the controller keeps same-name one-line public wrappers so the
# external API and test call sites are unchanged.


const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const DialogueManagerAdapterScript = preload("res://scripts/domain/dialogue_manager_adapter.gd")


static func save_and_leave_map(controller) -> void:
	if controller._view_name != "Map" or controller.state == null:
		return
	var save_error := save_current_run(controller)
	if save_error == OK:
		controller.last_feedback = "进度已保存 · 已返回大厅"
		controller._map_leave_confirm = false
		controller._show_title()
	else:
		controller.last_feedback = "存档失败（错误码 %d），仍留在地图。" % save_error
		controller._render()


static func leave_map_without_save(controller) -> void:
	if controller._view_name != "Map":
		return
	controller._map_leave_confirm = false
	controller.last_feedback = "未保存本次变化 · 返回大厅后仍可继续上次存档"
	controller._show_title()


static func save_current_run(controller) -> Error:
	return SaveRepository.save_run(controller.state, controller.route, controller.dialogue_replies)


static func load_saved_run(controller) -> bool:
	controller.last_load_diagnosis = SaveRepositoryScript.diagnose_run_file()
	if not bool(controller.last_load_diagnosis.get("ok", false)):
		return false
	return _restore_game(controller, SaveRepositoryScript.load_run())


static func _save_load_feedback(diagnosis: Dictionary) -> String:
	match str(diagnosis.get("kind", "missing")):
		"unsupported_version":
			# T1.1: v3 runs are rejected with a domain refusal dict whose message
			# reassures that hall progress / codex / unlocked recipes survive.
			if int(diagnosis.get("version", -1)) == 3:
				return SaveRepositoryScript._run_load_rejection(diagnosis)["message"]
			return "上次冒险存档版本不受支持（v%d）。" % int(diagnosis.get("version", -1))
		"checksum_missing", "checksum_mismatch":
			return "上次冒险存档校验失败，已拒绝载入。"
		"invalid_json":
			return "上次冒险存档格式损坏，已拒绝载入。"
		"invalid_state", "invalid_route", "invalid_event_log":
			return "上次冒险存档内容损坏，已拒绝载入。"
		_: return "暂无可继续的冒险：先在地图「存档」一次。"


static func _restore_game(controller, loaded: Dictionary) -> bool:
	# Spec-v4 T1.1: refusal dicts carry ok=false and no "state"; judge by the
	# presence of state, never by is_empty().
	if not loaded.has("state"):
		return false
	controller.state = loaded["state"]
	if loaded.has("route"):
		controller.route = loaded["route"].duplicate(true)
	controller.current_node = controller._node_by_id(controller.state.current_node_id)
	if controller.current_node.is_empty() and not controller.route.is_empty():
		for node_value in controller.route:
			var node_item: Dictionary = node_value
			if str(node_item.get("id", "")) == controller.state.current_node_id:
				controller.current_node = node_item
				break
	controller._stamp_current_node(controller.state, controller.current_node)
	controller.current_battle = {}
	# M3：会话镜像已删，state.encounter_session 随存档整体恢复。
	controller.dialogue_replies = loaded.get("replies", [])
	controller._dialogue_gateway = DialogueManagerAdapterScript.new()
	if controller.meta == null and FileAccess.file_exists(SaveRepositoryScript.META_PATH):
		controller.meta = SaveRepositoryScript.load_meta_file()
	controller._show_map()
	return true
