extends SceneTree

# W5 实测：ContentCatalog 全量加载 + 校验耗时。
# 目的：判定 `start_new_run` 里 load_and_validate_all() 的重复全量解析是否值得加缓存。
# 用法：godot --headless --path . -s tools/time_catalog_load.gd


func _initialize() -> void:
	var cc = preload("res://scripts/domain/content_catalog.gd")
	# 首次（冷）加载
	var t0 := Time.get_ticks_msec()
	var cat: Dictionary = cc.load_all()
	var t1 := Time.get_ticks_msec()
	var errs: Array = cc.validate(cat)
	var t2 := Time.get_ticks_msec()
	print("cold  load_all=%dms validate=%dms errors=%d" % [t1 - t0, t2 - t1, errs.size()])
	# 重复（热）加载 ×3
	for i in 3:
		var s0 := Time.get_ticks_msec()
		var c2: Dictionary = cc.load_all()
		var s1 := Time.get_ticks_msec()
		cc.validate(c2)
		var s2 := Time.get_ticks_msec()
		print("hot%d  load_all=%dms validate=%dms" % [i, s1 - s0, s2 - s1])
	quit()
