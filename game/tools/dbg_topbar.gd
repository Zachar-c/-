extends SceneTree

func _initialize() -> void:
	var scene := load("res://scenes/ui/widgets/gu_top_bar.tscn") as PackedScene
	var bar := scene.instantiate()
	root.add_child(bar)
	await process_frame
	await process_frame
	var row := bar.get_node("BarMargin/BarRow")
	var host := bar.get_node("BarMargin/BarRow/StatusHost")
	print("row size=", row.size, " host pos=", host.position, " size=", host.size)
	for kind in ["qi", "shou", "hun", "yuan"]:
		var status := host.get_node(kind.capitalize() + "Status")
		var label: Label = status.get_node(kind.capitalize() + "Label")
		print(kind, " status pos=", status.position, " size=", status.size,
			" label size=", label.size, " label_pos=", label.position)
	bar.queue_free()
	quit()
