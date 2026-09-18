extends SceneTree

## C2 渲染级验收（2026-09-05）：真实窗口下图鉴蛊条目透出中文流派标签。
## 挂载 hall_screen.tscn + 真实 codex 快照（跨多流派解锁蛊）→ force_draw →
## 像素色彩分布 + 「流派：光道/土道/力道/气道/血道」文本存在性断言。
## UNIQUE 色彩个位数 = 白屏；headless 无渲染目标时文本断言兜底。

const HallScene := "res://scenes/ui/screens/hall_screen.tscn"
const SCHOOL_GU_SAMPLES := {
	"light": ["small_light_gu", "gen_soul_attack_120_gu"],
	"earth": ["stone_shell_gu"],
	"force": ["force_gu"],
	"qi": ["qi_wall_gu"],
	"blood": ["blood_moss_gu"],
}


func _initialize() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var meta: Variant = MetaProgress.new()
	for school_id in SCHOOL_GU_SAMPLES:
		for gu_id in SCHOOL_GU_SAMPLES[school_id]:
			meta.gu_codex_ids.append(gu_id)
	var codex: Dictionary = RunSnapshotBuilder._codex(catalog, meta)
	var unlocked: Array = (codex.get("gu", []) as Array).filter(func(e): return bool(e.get("unlocked", false)))
	print("CODEX_GU=%d UNLOCKED=%d" % [(codex.get("gu", []) as Array).size(), unlocked.size()])
	var snapshot := {"codex": codex, "has_save": true, "meta_stats": {"runs": 1, "endings": 0}}
	var cmds := {
		"open_codex": Callable(self, "_noop"),
		"back_to_hall": Callable(self, "_noop"),
		"new_run": Callable(self, "_noop"),
		"open_settings": Callable(self, "_noop"),
		"continue_run": Callable(self, "_noop"),
	}
	var scene: PackedScene = load(HallScene)
	var hall: Control = scene.instantiate()
	root.add_child(hall)
	hall.mount_snapshot(snapshot, cmds)
	await process_frame
	hall._refresh_codex()
	await process_frame
	RenderingServer.force_draw()
	var tex: Texture2D = root.get_texture()
	if tex != null and tex.get_image() != null:
		var img: Image = tex.get_image()
		var colors := {}
		for x in range(0, img.get_width(), 3):
			for y in range(0, img.get_height(), 3):
				colors[img.get_pixel(x, y).to_html()] = true
		print("PIXEL_UNIQUE=%d" % colors.size())
		if colors.size() < 50:
			push_error("白屏嫌疑：唯一色 %d < 50" % colors.size())
			quit(1)
			return
	else:
		print("PIXEL_UNIQUE=SKIPPED_NO_HEADLESS_RENDER")
	# 文本级断言：多流派中文标签真实渲染（小光蛊=光道 等）。
	var found := {
		"light": false, "earth": false, "force": false, "qi": false, "blood": false,
	}
	_walk(hall, func(n: Node) -> void:
		if n is Label:
			var t := str((n as Label).text)
			if t == "流派：光道":
				found["light"] = true
			elif t == "流派：土道":
				found["earth"] = true
			elif t == "流派：力道":
				found["force"] = true
			elif t == "流派：气道":
				found["qi"] = true
			elif t == "流派：血道":
				found["blood"] = true
	)
	print("FOUND_LIGHT=%s EARTH=%s FORCE=%s QI=%s BLOOD=%s" % [
		str(found["light"]), str(found["earth"]), str(found["force"]),
		str(found["qi"]), str(found["blood"])])
	for school_id in found:
		if not found[school_id]:
			push_error("图鉴缺少流派标签：%s" % school_id)
			quit(1)
			return
	print("OK C2SchoolRender")
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass


func _walk(node: Node, fn: Callable) -> void:
	fn.call(node)
	for child in node.get_children():
		_walk(child, fn)
