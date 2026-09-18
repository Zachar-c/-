extends SceneTree

## 渲染级验证：大厅图鉴蛊条目的转数/效果标签（2026-09-04）。
## 挂载 hall_screen.tscn + 带真实 codex 数据的快照 → force_draw →
## 像素色彩分布 + 文本节点存在性断言。UNIQUE 色彩个位数 = 白屏。

const HallScene := "res://scenes/ui/screens/hall_screen.tscn"


func _initialize() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var meta: Variant = MetaProgress.new()
	for g in catalog.get("gu", []).slice(0, 8):
		meta.gu_codex_ids.append(str(g["id"]))
	var codex: Dictionary = RunSnapshotBuilder._codex(catalog, meta)
	print("CODEX_GU=%d UNLOCKED=%d" % [(codex.get("gu", []) as Array).size(),
			(codex.get("gu", []) as Array).filter(func(e): return bool(e.get("unlocked", false))).size()])
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
	# -s 模式 @onready 推迟到首帧：先等一帧让节点树就绪再开图鉴。
	await process_frame
	# 打开图鉴视图：hall_screen_view 通过 open_codex 命令切换可见性。
	hall._refresh_codex()
	print("CODEX_LIST_CHILDREN=%d" % (hall.get_node("Root/CodexView/CodexScroll/CodexList") as Node).get_child_count())
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
	else:
		# headless 无渲染目标：跳过像素段，文本断言兜底。
		print("PIXEL_UNIQUE=SKIPPED_NO_HEADLESS_RENDER")
	# 文本级断言：转数与效果标签真的渲染出来。
	# 注意：GDScript lambda 捕获局部变量是值语义，须用引用容器收集结果。
	var found := {"rank": false, "effect": false}
	_walk(hall, func(n: Node) -> void:
		if n is Label:
			var t := str((n as Label).text)
			if t.begins_with("转数："):
				found["rank"] = true
			if t.begins_with("效果：") and t != "效果：":
				found["effect"] = true
	)
	print("FOUND_RANK=%s FOUND_EFFECT=%s" % [str(found["rank"]), str(found["effect"])])
	if not bool(found["rank"]) or not bool(found["effect"]):
		push_error("图鉴条目缺少 转数/效果 标签")
		quit(1)
		return
	print("OK CodexRankEffect")
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass


func _walk(node: Node, fn: Callable) -> void:
	fn.call(node)
	for child in node.get_children():
		_walk(child, fn)
