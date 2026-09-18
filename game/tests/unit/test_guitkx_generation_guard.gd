extends GutTest


func test_ci_entrypoints_run_the_shared_guitkx_gate_before_consumers() -> void:
	var test_script := FileAccess.get_file_as_string("res://tools/test.ps1")
	var check_script := FileAccess.get_file_as_string("res://tools/check.ps1")
	var gate_script := FileAccess.get_file_as_string("res://tools/guitkx_build.ps1")
	assert_true(FileAccess.file_exists("res://scripts/guitkx_build.gd"))
	assert_true(FileAccess.file_exists("res://tools/guitkx_build.ps1"))
	assert_true(test_script.contains("guitkx_build.ps1"))
	assert_true(check_script.contains("guitkx_build.ps1"))
	assert_true(gate_script.contains("scripts/guitkx_build.gd"))


func test_generated_battle_hand_script_loads_after_codegen() -> void:
	var script_resource: Variant = load("res://ui/widgets/gu_battle_hand.gd")
	assert_not_null(script_resource, "generated battle hand script must remain loadable")


func test_guitkx_sources_do_not_call_unsupported_bool_constructor() -> void:
	var violations: Array[String] = []
	_scan_guitkx("res://ui", violations)
	assert_true(violations.is_empty(), "RUI sources must not emit bool() calls: %s" % ", ".join(violations))


func _scan_guitkx(path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var child := path.path_join(entry)
		if dir.current_is_dir():
			_scan_guitkx(child, violations)
		elif entry.ends_with(".guitkx"):
			var source := FileAccess.get_file_as_string(child)
			if source.contains("bool("):
				violations.append(child.trim_prefix("res://"))
	dir.list_dir_end()
