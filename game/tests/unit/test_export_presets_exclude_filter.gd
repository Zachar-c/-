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


func test_release_presets_exclude_build_dir() -> void:
	var source := FileAccess.get_file_as_string("res://export_presets.cfg")
	var filters := _all_values_for_key(source, "exclude_filter")
	# Windows Desktop + Android 两个 Release 预设都必须排除 build/*。
	assert_eq(filters.size(), 2, "expected Windows Desktop + Android presets")
	for exclude_filter in filters:
		assert_true(exclude_filter.contains("build/*"), "preset missing build/*")


func _value_for_key(source: String, key: String) -> String:
	var values := _all_values_for_key(source, key)
	return values[0] if not values.is_empty() else ""


func _all_values_for_key(source: String, key: String) -> Array:
	var values: Array = []
	var marker := key + "=\""
	var offset := 0
	while true:
		var start := source.find(marker, offset)
		if start < 0:
			break
		start += marker.length()
		var end := source.find("\"", start)
		if end < start:
			break
		values.append(source.substr(start, end - start))
		offset = end + 1
	return values
