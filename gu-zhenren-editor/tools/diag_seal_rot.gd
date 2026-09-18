extends SceneTree

## 隔离实验：单个 PanelContainer + apply_seal 旋转 -3°，截图采样倾角。

func _initialize() -> void:
	var panel := PanelContainer.new()
	GuStyle.apply_seal(panel, -3.0)
	panel.position = Vector2(600, 100)
	root.add_child(panel)
	# 给 SealBox 子节点？apply_seal 会 get_node_or_null，无子节点也不报错
	for i in 30:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var err := img.save_png("res://.preview/seal_rot_test.png")
	print("DIAG saved err=", err, " size=", img.get_width(), "x", img.get_height())
	quit()
