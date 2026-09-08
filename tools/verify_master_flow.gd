extends SceneTree

## 主流程无阻塞 smoke v4：正常 travel 逐层推进，多 seed 覆盖各屏类型。
## 战斗内验证设置 overlay 开合 + leave_encounter 放弃战斗回地图。
## Reward 屏（战斗胜利进入）已由 verify_reward_v1_render.gd 单独验收。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_master_flow.gd

const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")


func _initialize() -> void:
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	await process_frame
	var seen: Dictionary = {}
	var targets := ["Battle", "Rest", "Shop", "Refine", "Encounter", "Npc"]
	for seed in [20260908, 20260909, 20260910, 20260911]:
		controller.start_new_run(int(seed), "", [])
		if controller.current_view_name() != "Map":
			printerr("FAIL start -> " + controller.current_view_name())
			quit(2)
			return
		seen["Map"] = true
		var save := controller.submit_command({"type": "save_run"})
		printerr("SAVE_OK=%s" % str(save.get("ok", false)))
		var visited: Dictionary = {}
		var guard := 0
		while targets.size() > 0 and guard < 500:
			guard += 1
			var moved := false
			for node_value in controller.visible_route_nodes(5):
				var node: Dictionary = node_value
				var nid := str(node.get("id", ""))
				if visited.has(nid):
					continue
				var r: Dictionary = controller.submit_command({"type": "travel", "node_id": nid})
				if not bool(r.get("ok", false)):
					continue
				visited[nid] = true
				moved = true
				var view := controller.current_view_name()
				seen[view] = true
				targets.erase(view)
				if view == "Battle":
					controller._show_settings()
					if controller.current_view_name() != "Settings":
						printerr("FAIL battle settings")
						quit(2)
						return
					controller.back_from_overlay()
					if controller.current_view_name() != "Battle":
						printerr("FAIL battle back")
						quit(2)
						return
				controller.submit_command({"type": "leave_encounter"})
				await process_frame
				await process_frame
				if controller.current_view_name() == "Battle":
					controller.submit_command({"type": "leave_encounter"})
					await process_frame
					await process_frame
				break
			if not moved:
				break
		if targets.size() == 0:
			break
	if targets.size() > 0:
		printerr("FAIL views not reached: " + str(targets))
		printerr("SEEN=" + str(seen.keys()))
		quit(2)
		return
	var load := controller.submit_command({"type": "load_run"})
	printerr("LOAD_OK=%s view=%s" % [str(load.get("ok", false)), controller.current_view_name()])
	print("MASTER_FLOW_OK views=" + str(seen.keys()))
	quit(0)
