extends GutTest


func test_controller_rejects_commands_when_content_validation_failed() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller._content_errors = ["events: invalid kind"]
	var result := controller.submit_command({"type": "start_new_run"})
	assert_false(result.get("ok", true))
	assert_eq(result.get("reason", ""), "content_invalid")
	assert_eq(controller.current_view_name(), "ContentError")


func test_content_error_snapshot_exposes_bounded_summary() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller._content_errors = ["events: invalid kind", "pacing: missing layer 3"]
	var snapshot := controller._snapshot_for("ContentError")
	assert_eq(snapshot.get("title", ""), "内容配置无法加载")
	assert_eq(snapshot.get("error_count", 0), 2)
	assert_eq(snapshot.get("errors", []).size(), 2)
