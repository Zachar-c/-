extends GutTest


func test_release_excludes_dev_only_wenzhen_files() -> void:
	var source := FileAccess.get_file_as_string("res://export_presets.cfg")
	var exclude_filter := _value_for_key(source, "exclude_filter")
	assert_true(exclude_filter.contains("scripts/ui_capture.gd"))
	assert_true(exclude_filter.contains("scripts/guitkx_build.gd"))
	assert_true(exclude_filter.contains("assets/wenzhen/hall/*"))
	assert_false(exclude_filter.contains("assets/wenzhen/fonts/*"))


func _value_for_key(source: String, key: String) -> String:
	var marker := key + "=\""
	var start := source.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end := source.find("\"", start)
	return source.substr(start, end - start) if end >= start else ""
