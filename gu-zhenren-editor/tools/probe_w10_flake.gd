extends SceneTree

## W10 首跑 has_save=false flake 诊断探针（headless，一次性实验件）。
## 复刻 verify_w10_continue_run.gd 的存档-离开-快照序列，去掉真窗截图步骤，
## 支持多轮循环：每轮清掉存档文件，模拟"首跑"状态，逐轮报告 has_save。
##
## 用法：
##   tools\godot.ps1 --headless --path . -s tools/probe_w10_flake.gd -- --rounds=5

const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")
const RunSnapshotBuilderScript := preload("res://scripts/presentation/run_snapshot_builder.gd")
const SaveRepositoryScript := preload("res://scripts/domain/save_repository.gd")

var _failed := 0


func _wipe_save() -> void:
	for path in [SaveRepositoryScript.SAVE_PATH, SaveRepositoryScript.TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _initialize() -> void:
	var rounds := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rounds="):
			rounds = int(arg.split("=")[1])
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	await process_frame

	for r in range(1, rounds + 1):
		_wipe_save()
		print("[probe] round %d: save file wiped, exists=%s" % [
			r, FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH)])

		var hall_snap: Dictionary = RunSnapshotBuilderScript.for_screen("Title", controller)
		print("[probe] round %d: no-save has_save=%s primary=%s" % [
			r, hall_snap.get("has_save"), hall_snap.get("primary_action")])

		controller.start_new_run(20260914, "", [])
		var traveled := false
		for node_value in controller.visible_route_nodes(2):
			var node: Dictionary = node_value
			var res: Dictionary = controller.submit_command({"type": "travel", "node_id": str(node.get("id", ""))})
			if bool(res.get("ok", false)):
				traveled = true
				break
		print("[probe] round %d: traveled=%s view=%s" % [
			r, traveled, controller.current_view_name()])

		var save_result: Dictionary = controller.submit_command({"type": "save_run"})
		print("[probe] round %d: save_run ok=%s err=%s" % [
			r, save_result.get("ok"), save_result.get("error", "")])
		print("[probe] round %d: file exists after save_run=%s" % [
			r, FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH)])

		controller.save_and_leave_map()
		await process_frame
		await process_frame
		print("[probe] round %d: after leave view=%s exists=%s" % [
			r, controller.current_view_name(),
			FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH)])

		var hall_snap2: Dictionary = RunSnapshotBuilderScript.for_screen("Title", controller)
		print("[probe] round %d: with-save has_save=%s primary=%s" % [
			r, hall_snap2.get("has_save"), hall_snap2.get("primary_action")])
		if not bool(hall_snap2.get("has_save", false)):
			_failed += 1
			print("[probe] round %d: FLAKE REPRODUCED (has_save=false)" % r)

	print("[probe] done rounds=%d flakes=%d" % [rounds, _failed])
	quit(1 if _failed > 0 else 0)
