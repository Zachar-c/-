extends GutTest

const FORMAL_EXTENSIONS := [".gd", ".tres", ".tscn"]
const FORMAL_PATHS := ["scripts/presentation", "ui", "scenes", "tools"]


func test_formal_ui_has_no_global_theme_reference() -> void:
	assert_false(_files_contain(FORMAL_PATHS, "gu_theme.tres"))
	assert_false(_files_contain(FORMAL_PATHS, "ui_theme.gd"))
	assert_false(_files_contain(FORMAL_PATHS, "UiTheme"))
	assert_false(_files_contain(FORMAL_PATHS, "@theme"))


func test_gu_style_has_no_removed_aliases() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/presentation/gu_style.gd")
	for alias in ["BG_DEEP", "BG_PANEL", "BG_RAISED", "BONE", "BONE_DIM"]:
		assert_false(source.contains("const %s" % alias), "removed alias remains: %s" % alias)


func _files_contain(paths: Array, needle: String) -> bool:
	for path in paths:
		if _directory_contains("res://%s" % path, needle):
			return true
	return false


func _directory_contains(path: String, needle: String) -> bool:
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := "%s/%s" % [path, entry]
			if dir.current_is_dir():
				if _directory_contains(child, needle):
					dir.list_dir_end()
					return true
			elif FORMAL_EXTENSIONS.any(func(extension: String): return entry.ends_with(extension)):
				if FileAccess.get_file_as_string(child).contains(needle):
					dir.list_dir_end()
					return true
			entry = dir.get_next()
			dir.list_dir_end()
	return false
