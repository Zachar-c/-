extends RefCounted

## A7：地图 travel / 节点抵达会话启动外提。controller 保持同名一行包装。


const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")


static func travel_to(controller, node_id: String) -> Dictionary:
	var node: Dictionary = controller._node_by_id(node_id)
	if node.is_empty():
		return {"ok": false, "reason": "unknown_route_node"}
	var reachable_ids: Array[String] = []
	for reachable in MapGeneratorScript.reachable_nodes(controller.route, controller.state):
		reachable_ids.append(str(reachable["id"]))
	if not reachable_ids.has(node_id):
		return {"ok": false, "reason": "unreachable_route_node"}
	var resolved := Resolver.apply(controller.state, {"type": "travel", "node_id": node_id}, controller.catalog)
	controller.state = resolved["state"]
	controller.current_node = node
	controller._stamp_current_node(controller.state, node)
	var session_started := EncounterSessionResolverScript.begin(controller.state, node)
	controller.state = session_started["state"]
	controller.current_session = session_started["session"]
	controller.last_result = resolved["result"]
	# E4a：新探访开始，炼蛊子屏状态复位（上一个休息探访的子屏语境不残留）。
	controller._refine_from_rest = false
	controller._refine_initial_channel = ""
	if node["type"] in ["combat", "pursuit"]:
		controller._start_battle()
	elif node["type"] in ["shop", "market", "caravan"]:
		controller._show_shop()
	elif node["type"] in ["rest", "refinement", "cultivation"]:
		# E4a 三选一（规格 §4）：三个休息类模板统一 Rest；炼蛊经休息屏子屏进入。
		controller._show_rest()
	elif node["type"] == "contact":
		controller._show_npc()
	else:
		if node["type"] == "event" and controller._dialogue_gateway != null \
				and controller._dialogue_gateway.has_method("begin"):
			controller._dialogue_gateway.begin(
				str(node.get("event_id", node.get("id", ""))),
				str(node.get("dialogue_title", "start"))
			)
			if controller._dialogue_gateway.has_method("set_branch_selection_callback"):
				controller._dialogue_gateway.set_branch_selection_callback(
					Callable(controller, "submit_dialogue_selection"))
		controller._show_encounter()
	return resolved["result"]
