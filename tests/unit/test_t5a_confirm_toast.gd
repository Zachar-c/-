extends GutTest


# T5-A: D1 confirm-dialog family + D4 save toast.
# Locks the R1.5 save feedback wording, the snapshot toast passthrough,
# and the reserved hall version-warning slot (§16.22).


const SAVE_FEEDBACK := "进度已保存 · 关闭游戏后可继续本次冒险"


func _new_controller() -> RunController:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(101)
	return controller


func test_save_run_feedback_uses_continue_wording() -> void:
	var controller := _new_controller()
	var result := controller.submit_command({"type": "save_run"})
	assert_true(bool(result.get("ok", false)), "save_run must succeed")
	assert_eq(str(result.get("feedback", "")), SAVE_FEEDBACK)


func test_load_run_feedback_never_says_du_dang() -> void:
	if FileAccess.file_exists("user://nanjiang_smoke_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nanjiang_smoke_save.json"))
	var controller := _new_controller()
	var result := controller.submit_command({"type": "load_run"})
	assert_false(str(result.get("feedback", "")).contains("读档"), "no load-save wording allowed (R1.5)")
	assert_false(controller.last_feedback.contains("读档"), "toast text must avoid 读档 wording")


func test_map_snapshot_exposes_toast_from_controller_feedback() -> void:
	var controller := _new_controller()
	assert_eq(str(controller._snapshot_for("Map").get("toast", "missing")), "", "toast empty before feedback")
	controller.submit_command({"type": "save_run"})
	assert_eq(str(controller._snapshot_for("Map").get("toast", "missing")), SAVE_FEEDBACK)


func test_hall_snapshot_reserves_version_warning_slot() -> void:
	var controller := _new_controller()
	var snapshot: Dictionary = controller._snapshot_for("Title")
	assert_true(snapshot.has("hall_version_warning"), "hall must reserve the version-conflict slot")
	assert_eq(str(snapshot.get("hall_version_warning", "")), "")
