extends SceneTree

# W4 探针：确认 for_screen 在真实 RunController 下各屏可产出结构。
# 用法：godot --headless --path . -s tools/probe_snapshot_contract.gd


func _initialize() -> void:
	var RunSnapshotBuilder = preload("res://scripts/presentation/run_snapshot_builder.gd")
	var RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	# Title（未开局）
	var title: Dictionary = RunSnapshotBuilder.for_screen("Title", controller)
	print("Title top keys=", (title.keys() as Array).size(), " screen=", title.get("screen_name", "?"))
	# Map（开新局后当前屏）
	controller.start_new_run(101)
	await process_frame
	var map: Dictionary = RunSnapshotBuilder.for_screen("Map", controller)
	print("Map   top keys=", (map.keys() as Array).size())
	print("Map   sample=", JSON.stringify(map.keys()).left(400))
	# 其余屏：直接调 builder 看是否空/崩溃
	for screen in ["Shop", "Rest", "Refine", "Battle", "Hall", "Encounter"]:
		var snap: Dictionary = RunSnapshotBuilder.for_screen(screen, controller)
		print("%-10s keys=%d non_empty=%s" % [screen, (snap.keys() as Array).size(), snap.size() > 0])
	controller.queue_free()
	quit()
