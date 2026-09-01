extends GutTest


# Spec-v4 phase-5 (P0.2): repository hygiene guard. Human-run EOF discipline
# failed three batches in a row, so this test pins it: every .gd file under
# res://scripts must end with a trailing newline. Text-file hygiene is a
# mechanical invariant, enforced here instead of by convention.


func test_every_gd_file_under_scripts_ends_with_a_newline() -> void:
	var offenders: Array[String] = []
	var files: Array[String] = []
	_collect_gd_files("res://scripts", files)
	for full in files:
		var text := FileAccess.get_file_as_string(full)
		if not text.ends_with("\n"):
			offenders.append(full)
	assert_eq(offenders, [] as Array[String],
			"these .gd files miss the final newline: %s" % str(offenders))


func _collect_gd_files(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if name != "." and name != "..":
				_collect_gd_files(path.path_join(name), out)
		elif name.get_extension() == "gd":
			out.append(path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()