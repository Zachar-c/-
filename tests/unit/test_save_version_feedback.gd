extends GutTest


func test_load_feedback_distinguishes_unsupported_run_version() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	var feedback: String = controller._save_load_feedback({"ok": false, "kind": "unsupported_version", "version": 2})
	assert_eq(feedback, "上次冒险存档版本不受支持（v2）。")


func test_v3_feedback_uses_schema_v4_reassurance_message() -> void:
	# T1.1 contract: rejecting a v3 run must tell the player the hall progress,
	# codex and unlocked recipes are preserved; the reassurance lives in the
	# domain refusal dict and must be reachable from the UI feedback path.
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	var feedback: String = controller._save_load_feedback({"ok": false, "kind": "unsupported_version", "version": 3})
	assert_true(feedback.contains("已保留"), feedback)


func test_load_feedback_distinguishes_checksum_failure() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	var feedback: String = controller._save_load_feedback({"ok": false, "kind": "checksum_mismatch"})
	assert_eq(feedback, "上次冒险存档校验失败，已拒绝载入。")
