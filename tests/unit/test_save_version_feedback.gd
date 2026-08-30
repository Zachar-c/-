extends GutTest


func test_load_feedback_distinguishes_unsupported_run_version() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	var feedback: String = controller._save_load_feedback({"ok": false, "kind": "unsupported_version", "version": 2})
	assert_eq(feedback, "上次冒险存档版本不受支持（v2）。")


func test_load_feedback_distinguishes_checksum_failure() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	var feedback: String = controller._save_load_feedback({"ok": false, "kind": "checksum_mismatch"})
	assert_eq(feedback, "上次冒险存档校验失败，已拒绝载入。")
