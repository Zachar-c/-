extends GutTest


# E0 存档导入导出：export_run_to_file / import_run_from_file 复用 SaveRepository
# 既有的 serialize_run / load_run_from_data 校验管线，因此文件级契约与固定
# 路径存档完全一致（schema 版本 + 校验和 + 事件日志校验，拒绝时返回
# {"ok": false, "reason", "message"} 拒绝字典，绝不静默返回空字典）。
# 导出路径由调用方给出（调试面板后续接 FileDialog）；测试固定在 user:// 下
# 并在每个用例后清理。

const EXPORT_PATH := "user://test_export_save.json"


func after_each() -> void:
	if FileAccess.file_exists(EXPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(EXPORT_PATH))


func _sample_state() -> RunState:
	var state := RunState.new_run(101)
	state.health = 4
	state.encounter_session = {"node_id": "neutral_wanderer", "completed": false}
	return state


func test_export_then_import_round_trip_preserves_state() -> void:
	var state := _sample_state()
	var route := MapGenerator.build(101, true)

	var err := SaveRepository.export_run_to_file(state, route, [], EXPORT_PATH)
	assert_eq(err, OK)

	var loaded := SaveRepository.import_run_from_file(EXPORT_PATH)
	assert_true(loaded.has("state"), "round trip must restore state")
	assert_eq(loaded["state"].health, 4)
	assert_eq(loaded["state"].encounter_session["node_id"], "neutral_wanderer")
	assert_eq(loaded["route"].size(), route.size())


func test_exported_file_carries_schema_version() -> void:
	var state := RunState.new_run(101)
	var err := SaveRepository.export_run_to_file(state, MapGenerator.build(101, true), [], EXPORT_PATH)
	assert_eq(err, OK)

	var json := JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(EXPORT_PATH)), OK)
	assert_true(json.data is Dictionary, "exported file must be a JSON object")
	assert_eq(int(json.data.get("version", -1)), SaveRepository.SAVE_VERSION)


func test_import_rejects_missing_file() -> void:
	var loaded := SaveRepository.import_run_from_file("user://definitely_missing_export.json")
	assert_false(loaded.has("state"), "rejected imports must not carry state")
	assert_eq(str(loaded.get("reason", "")), "missing")


func test_import_rejects_invalid_json() -> void:
	var file := FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	file.store_string("{not valid json")
	file = null

	var loaded := SaveRepository.import_run_from_file(EXPORT_PATH)
	assert_false(loaded.has("state"), "rejected imports must not carry state")
	assert_eq(str(loaded.get("reason", "")), "invalid_json")


func test_import_rejects_tampered_file() -> void:
	var state := RunState.new_run(101)
	assert_eq(SaveRepository.export_run_to_file(state, MapGenerator.build(101, true), [], EXPORT_PATH), OK)

	var json := JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(EXPORT_PATH)), OK)
	var data: Dictionary = json.data
	data["state"]["seed"] = int(data["state"]["seed"]) + 1
	var file := FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file = null

	var loaded := SaveRepository.import_run_from_file(EXPORT_PATH)
	assert_false(loaded.has("state"), "rejected imports must not carry state")
	assert_eq(str(loaded.get("reason", "")), "checksum_mismatch")


func test_import_rejects_wrong_schema_version() -> void:
	# v3 存档走 Spec-v4 T1.1 的玩家可读映射 reason（大厅进度保留语义）。
	var state := RunState.new_run(101)
	var payload := SaveRepository.serialize_run(state, MapGenerator.build(101, true), [])
	payload["version"] = 3
	var file := FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file = null

	var loaded := SaveRepository.import_run_from_file(EXPORT_PATH)
	assert_false(loaded.has("state"), "rejected imports must not carry state")
	assert_eq(str(loaded.get("reason", "")), "schema_v4_required")

	# 更旧/未知版本回落到原始 kind。
	var payload_v2 := SaveRepository.serialize_run(state, MapGenerator.build(101, true), [])
	payload_v2["version"] = 2
	var file2 := FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	file2.store_string(JSON.stringify(payload_v2))
	file2 = null

	var loaded_v2 := SaveRepository.import_run_from_file(EXPORT_PATH)
	assert_false(loaded_v2.has("state"), "rejected imports must not carry state")
	assert_eq(str(loaded_v2.get("reason", "")), "unsupported_version")


func test_export_fails_on_unwritable_path() -> void:
	var state := RunState.new_run(101)
	var err := SaveRepository.export_run_to_file(
			state, MapGenerator.build(101, true), [], "user://no_such_dir/export.json")
	assert_ne(err, OK)
