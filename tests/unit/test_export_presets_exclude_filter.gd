extends GutTest


func test_release_excludes_dev_only_wenzhen_files() -> void:
	var source := FileAccess.get_file_as_string("res://export_presets.cfg")
	var exclude_filter := _value_for_key(source, "exclude_filter")
	assert_true(exclude_filter.contains("scripts/acceptance_driver.gd"))
	assert_true(exclude_filter.contains("scripts/guitkx_build.gd"))
	# 2026-09-09：assets/wenzhen/hall/* 已变成运行时目录，不再排除。
	# hall_dots.png 被 battle/encounter/hall/kill/map 五屏引用；
	# first-life-character.png 被 battle/encounter/rest 三屏引用；
	# qing-mao-mountain.png 被 ending 屏引用。本条原为「排除开发期线框图」而设，
	# 线框图现已在 docs/* 下（docs 本身已排除）。若照旧排除 hall/*，
	# Release 包会让上述各屏直接丢图——故改为断言不得排除。
	assert_false(exclude_filter.contains("assets/wenzhen/hall/*"))
	assert_false(exclude_filter.contains("assets/wenzhen/fonts/*"))


func _value_for_key(source: String, key: String) -> String:
	var marker := key + "=\""
	var start := source.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end := source.find("\"", start)
	return source.substr(start, end - start) if end >= start else ""
