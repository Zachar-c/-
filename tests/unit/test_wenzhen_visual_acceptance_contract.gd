extends GutTest


const UiCapture = preload("res://scripts/ui_capture.gd")


func test_user_approved_hall_assets_are_present_and_declared() -> void:
	var manifest_path := "res://assets/wenzhen/assets_manifest.json"
	assert_true(FileAccess.file_exists(manifest_path), "hall asset manifest must exist")
	if not FileAccess.file_exists(manifest_path):
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var required_ids := ["title_font_xiawu_zhisong", "hall_first_life_character", "hall_qing_mao_mountain"]
	var found := {}
	for item in manifest.get("assets", []):
		found[str(item.get("id", ""))] = item
	for asset_id in required_ids:
		assert_true(found.has(asset_id), "missing approved asset: %s" % asset_id)
		if found.has(asset_id):
			var item: Dictionary = found[asset_id]
			assert_true(ResourceLoader.exists("res://" + str(item.get("path", ""))), "asset must load: %s" % asset_id)
			assert_false(str(item.get("license", "")).is_empty(), "asset declaration must state use basis: %s" % asset_id)


func test_capture_matrix_covers_every_required_screen_and_viewport() -> void:
	var required := ["hall", "map", "battle", "encounter", "npc", "shop", "rest", "refine", "reward", "school", "contract", "codex", "journal", "settings", "ending"]
	var capture_ids: Array = UiCapture.capture_ids()
	for scene_name in required:
		assert_true(capture_ids.has(scene_name), "missing capture: %s" % scene_name)
	assert_eq(
		UiCapture.CAPTURE_MATRIX["map"],
		["current", "candidate_a_focus", "candidate_b_focus", "future_camera", "collapsed_history", "long_label"],
		"map acceptance requires six deterministic snapshot-only states"
	)
	assert_eq(UiCapture.viewport_sizes(), [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1280, 720)])


func test_capture_batch_reads_full_command_line_when_user_args_are_empty() -> void:
	assert_eq(
		UiCapture.batch_from_args([], ["godot", "--path", ".", "-s", "res://scripts/ui_capture.gd", "--", "--batch", "map"]),
		"map"
	)


func test_old_task_8_cannot_be_marked_approved_without_user_quote() -> void:
	var report_path := "res://docs/superpowers/reports/2026-08-28-wenzhen-ui-visual-acceptance.md"
	assert_true(FileAccess.file_exists(report_path), "visual acceptance report must exist")
	if not FileAccess.file_exists(report_path):
		return
	var report := FileAccess.get_file_as_string(report_path)
	assert_true(report.contains("Status: PENDING"))
	assert_false(report.contains("Status: APPROVED\nUser quote: (missing)"))
