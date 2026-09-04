extends SceneTree
## 渲染级冒烟探针：把 .tscn 渲进 SubViewport，统计像素颜色分布。
##
## 为什么要有它：`--headless --quit-after N` 只检查"无脚本错误"，而白屏、
## 控件不显示属于**静默失败**，退出码照样 0。本工具直接量化"屏幕上到底有没有东西"。
##
## 用法（必须非 headless，需要真实渲染器）：
##   godot --path . -s res://scripts/render_probe.gd -- scene=res://scenes/main.tscn
##
## 判据：
##   UNIQUE = 1        → 整屏纯色，白屏 / 空渲染
##   UNIQUE 个位数     → 几乎空白，高度可疑
##   UNIQUE 数百       → 正常（文字、描边、色块都会贡献不同颜色）
##
## 关注点：改动主场景或 .tscn 结构后必跑；与已知基线对比 UNIQUE 更可靠。

const DEFAULT_SCENE := "res://scenes/main.tscn"


func _initialize() -> void:
	var path := _arg("scene", DEFAULT_SCENE)
	var scene: PackedScene = load(path)
	if scene == null:
		print("RENDER_PROBE_FAIL cannot load ", path)
		quit(1)
		return
	var inst: Node = scene.instantiate()
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	vp.add_child(inst)
	for _i in 10:
		await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var counts := {}
	var total := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var key := img.get_pixel(x, y).to_html(false).substr(0, 6)
			counts[key] = int(counts.get(key, 0)) + 1
			total += 1
	var rows := []
	for k in counts:
		rows.append([k, int(counts[k])])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	print("SCENE=", path)
	print("UNIQUE=", rows.size(), " SAMPLED=", total)
	for i in mini(3, rows.size()):
		print("TOP ", rows[i][0], " ", rows[i][1],
				" ", "%.1f%%" % (100.0 * float(rows[i][1]) / float(total)))
	print("VERDICT=", "BLANK" if rows.size() <= 1 else "OK")
	var exit_code := 0 if rows.size() > 1 else 1
	# SubViewport owns the instantiated scene and its RenderingServer resources.
	# Stop updates and release it synchronously before quitting so repeated probes
	# do not leave ObjectDB/RID state alive at process teardown.
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.free()
	await process_frame
	await process_frame
	quit(exit_code)


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback
