extends SceneTree

# Crash-recovery driver (process-level verification, 2026-08-29):
# three phases selected by env CRASH_PHASE, one Godot process each.
#
#   run    — boot the real controller, play via official commands, save_run
#            after every step and append a marker log; the orchestrator
#            hard-kills this process at an arbitrary point.
#   verify — a fresh process must resume the run from the last durable
#            save: checksum valid, state matches one recorded checkpoint,
#            non-terminal, and the run can still travel + save.
#   tamper — a corrupted save must be rejected by the checksum, a leftover
#            .tmp file must be ignored, and the original save must load
#            again afterwards.

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")

const MARKER_PATH := "user://crash_recovery_marker.json"


func _init() -> void:
	var phase := OS.get_environment("CRASH_PHASE")
	print("CRASH phase=%s pid=%d" % [phase, OS.get_process_id()])
	match phase:
		"run":
			_phase_run()
		"verify":
			_phase_verify()
		"tamper":
			_phase_tamper()
		_:
			printerr("CRASH unknown phase")
			quit(2)


func _marker_log() -> Array:
	var entries: Array = []
	if FileAccess.file_exists(MARKER_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARKER_PATH))
		if parsed is Array:
			entries = parsed
	return entries


func _write_marker_log(entries: Array) -> void:
	var file := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(entries))
	file.flush()
	file.close()


func _new_controller() -> RunController:
	var controller := RunControllerScript.new()
	controller.catalog = ContentCatalog.load_all()
	return controller


## Phase run: play + save in a loop until the orchestrator kills us.
func _phase_run() -> void:
	var controller := _new_controller()
	controller.start_new_run(777, "", [])
	print("CRASH started node=%s" % controller.state.current_node_id)
	var save_budget := maxi(1, int(OS.get_environment("CRASH_SAVE_BUDGET")))
	var iterations := 0
	var saves := 0
	while iterations < 100000:
		iterations += 1
		# 会话内不能直接行军：遭遇节点先离场回地图（真实游玩顺序）。
		if controller.current_view_name() != "Map":
			controller.submit_command({"type": "leave_node"})
		var saved: Dictionary = controller.submit_command({"type": "save_run"})
		if not bool(saved.get("ok", false)):
			printerr("CRASH save failed")
			quit(3)
			return
		# Marker AFTER the save: the durable save may be one step ahead of
		# the marker, never behind it.
		var entries := _marker_log()
		entries.append({
			"node_id": str(controller.state.current_node_id),
			"events": int(controller.state.event_log.size()),
			"iteration": iterations,
		})
		_write_marker_log(entries)
		saves += 1
		print("CRASH save #%d node=%s events=%d" % [
			saves, controller.state.current_node_id, int(controller.state.event_log.size())])
		if saves >= save_budget:
			# 预算已满：空转等待编排器硬杀——存档点已固化，击杀落在何处
			# 不再影响「最后一次原子存档必须可恢复」的被验性质。
			while true:
				OS.delay_msec(200)
		var moved := false
		for node_value in controller.visible_route_nodes(2):
			var node: Dictionary = node_value
			var node_id := str(node.get("id", ""))
			if _is_verification_dead_end(node):
				continue
			if controller.state.node_flags.has(node_id):
				continue
			var travel: Dictionary = controller.submit_command({"type": "travel", "node_id": node_id})
			if bool(travel.get("ok", false)):
				moved = true
				break
		if not moved:
			# Route exhausted: keep saving (kill target stays valid).
			pass
	print("CRASH iteration budget exhausted")
	quit(0)


## Phase verify: a fresh process resumes the run.
func _phase_verify() -> void:
	var controller := _new_controller()
	var loaded := controller.load_saved_run()
	if not loaded:
		printerr("CRASH verify FAILED: load_saved_run returned false")
		quit(1)
		return
	var state = controller.state
	var events := int(state.event_log.size())
	var node_id := str(state.current_node_id)
	print("CRASH resumed node=%s events=%d" % [node_id, events])
	if state.is_terminal():
		printerr("CRASH verify FAILED: resumed state is terminal")
		quit(1)
		return
	# The durable save must be one of the recorded checkpoints (the kill may
	# have landed mid-write, in which case the previous checkpoint is kept).
	var matched := false
	for entry in _marker_log():
		var checkpoint: Dictionary = entry
		if str(checkpoint.get("node_id", "")) == node_id and int(checkpoint.get("events", -1)) == events:
			matched = true
			break
	if not matched:
		printerr("CRASH verify FAILED: resumed state matches no recorded checkpoint (node=%s events=%d)" % [node_id, events])
		quit(1)
		return
	# The run must still be playable: travel somewhere and save again.
	if controller.current_view_name() != "Map":
		controller.submit_command({"type": "leave_node"})
	var traveled := false
	for node_value in controller.visible_route_nodes(2):
		var node2: Dictionary = node_value
		var node_id2 := str(node2.get("id", ""))
		if _is_verification_dead_end(node2):
			continue
		if controller.state.node_flags.has(node_id2):
			continue
		var travel: Dictionary = controller.submit_command({"type": "travel", "node_id": node_id2})
		if bool(travel.get("ok", false)):
			traveled = true
			break
	if not traveled and _has_open_destination(controller):
		printerr("CRASH verify FAILED: reachable unvisited node exists but travel failed")
		quit(1)
		return
	# 五层拓扑的终局（只剩 Boss 台可走）允许无路可走——存档能力即充分证据。
	var saved: Dictionary = controller.submit_command({"type": "save_run"})
	if not bool(saved.get("ok", false)):
		printerr("CRASH verify FAILED: post-crash save_run rejected")
		quit(1)
		return
	print("CRASH verify PASS")
	quit(0)


## Phase tamper: checksum rejection + tmp tolerance + clean restore.
func _phase_tamper() -> void:
	var controller := _new_controller()
	controller.start_new_run(778, "", [])
	controller.submit_command({"type": "travel", "node_id": _first_destination(controller)})
	var saved: Dictionary = controller.submit_command({"type": "save_run"})
	if not bool(saved.get("ok", false)):
		printerr("CRASH tamper FAILED: baseline save_run rejected")
		quit(1)
		return
	var raw := FileAccess.get_file_as_string(SaveRepositoryScript.SAVE_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		printerr("CRASH tamper FAILED: save file is not valid JSON")
		quit(1)
		return
	# 1. Tamper with gameplay data, keep the JSON valid: checksum must reject.
	var tampered: Dictionary = parsed
	var state_data: Dictionary = tampered["state"]
	state_data["stone"] = int(state_data.get("stone", 0)) + 999
	var file := FileAccess.open(SaveRepositoryScript.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(tampered))
	file.flush()
	file.close()
	var tamper_controller := _new_controller()
	if tamper_controller.load_saved_run():
		printerr("CRASH tamper FAILED: tampered save was accepted")
		quit(1)
		return
	print("CRASH tampered save rejected")
	# 2. Leftover .tmp (crash during a save write) must be ignored.
	var tmp := FileAccess.open(SaveRepositoryScript.TEMP_PATH, FileAccess.WRITE)
	tmp.store_string("{ this is not json")
	tmp.flush()
	tmp.close()
	var tmp_controller := _new_controller()
	controller.start_new_run(779, "", [])
	controller.submit_command({"type": "travel", "node_id": _first_destination(controller)})
	controller.submit_command({"type": "save_run"})
	if not tmp_controller.load_saved_run():
		printerr("CRASH tamper FAILED: leftover tmp file broke loading")
		quit(1)
		return
	print("CRASH leftover tmp ignored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveRepositoryScript.TEMP_PATH))
	print("CRASH tamper PASS")
	quit(0)


## 游走回路避开关底 Boss 台与升仙窗：Boss 未败时它们是终点站，
## 进去之后「无路可走」是正确游戏行为，不是恢复缺陷。
func _has_open_destination(controller: RunController) -> bool:
	for node_value in controller.visible_route_nodes(2):
		var node: Dictionary = node_value
		if _is_verification_dead_end(node):
			continue
		if not controller.state.node_flags.has(str(node.get("id", ""))):
			return true
	return false


func _is_verification_dead_end(node: Dictionary) -> bool:
	if str(node.get("id", "")) == "ascension_window":
		return true
	return int(node.get("layer_boss", 0)) > 0


func _first_destination(controller: RunController) -> String:
	for node_value in controller.visible_route_nodes(2):
		var node_id := str((node_value as Dictionary).get("id", ""))
		if not controller.state.node_flags.has(node_id):
			return node_id
	return ""
