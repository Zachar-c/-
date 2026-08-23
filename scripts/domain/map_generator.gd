class_name MapGenerator
extends RefCounted


static func build(seed: int, first_run: bool) -> Array[Dictionary]:
	var data := _load_json("res://data/nodes.json")
	var node_by_id := _index_nodes(data["nodes"])
	node_by_id[data["ascension_node"]["id"]] = data["ascension_node"]
	var route_ids: Array
	if first_run:
		route_ids = _load_json("res://data/first_run.json")["route_ids"]
	else:
		route_ids = _generated_route_ids(seed, data["nodes"])
	return _route_from_ids(route_ids, node_by_id)


static func _generated_route_ids(seed: int, nodes: Array) -> Array:
	var by_stage := {}
	for node in nodes:
		if not by_stage.has(node["stage"]):
			by_stage[node["stage"]] = []
		by_stage[node["stage"]].append(node["id"])
	var rng := SeededRng.new(seed)
	var route_ids: Array = []
	for stage in ["one", "three", "four", "five"]:
		if not by_stage.has(stage):
			continue
		var candidates: Array = by_stage[stage].duplicate()
		if stage == "four":
			candidates.erase("earth_vein_contest")
		if candidates.is_empty():
			continue
		var picks := mini(2, candidates.size())
		for _pick in picks:
			route_ids.append(candidates[rng.next_index(candidates.size())])
	if by_stage.has("four") and not route_ids.has("earth_vein_contest"):
		route_ids.append("earth_vein_contest")
	if by_stage.has("five") and not route_ids.has("poison_fog_vein"):
		route_ids.append("poison_fog_vein")
	route_ids.append("ascension_window")
	return route_ids


static func _route_from_ids(route_ids: Array, node_by_id: Dictionary) -> Array[Dictionary]:
	var route: Array[Dictionary] = []
	for index in route_ids.size():
		var node: Dictionary = node_by_id[route_ids[index]].duplicate(true)
		node["visible"] = index <= 1
		if not node.has("next_ids") or node["next_ids"].is_empty():
			if index < route_ids.size() - 1:
				node["next_ids"] = [route_ids[index + 1]]
		route.append(node)
	return route


static func reachable_nodes(route: Array[Dictionary], state: RunState) -> Array[Dictionary]:
	var by_id := {}
	for node in route:
		by_id[str(node["id"])] = node
	var origin_id := state.current_node_id
	if origin_id == "trailhead":
		var starts: Array[Dictionary] = []
		for node in route:
			if bool(node.get("start", false)):
				starts.append(node.duplicate(true))
		return starts
	if not by_id.has(origin_id):
		return []
	if not state.node_flags.has(origin_id):
		return []
	var reachable: Array[Dictionary] = []
	for next_id in by_id[origin_id].get("next_ids", []):
		if by_id.has(str(next_id)):
			reachable.append(by_id[str(next_id)].duplicate(true))
	return reachable


static func visible_nodes(route: Array[Dictionary], state: RunState, forward_layers: int = 1) -> Array[Dictionary]:
	var by_id := {}
	for node in route:
		by_id[str(node["id"])] = node
	var visible_ids := {}
	for node in route:
		var node_id := str(node["id"])
		if bool(node.get("start", false)) or state.node_flags.has(node_id):
			visible_ids[node_id] = true
	var frontier: Array[Dictionary] = reachable_nodes(route, state)
	for node in frontier:
		visible_ids[str(node["id"])] = true
	for _layer in forward_layers:
		var next_frontier: Array[Dictionary] = []
		for node in frontier:
			for next_id_value in node.get("next_ids", []):
				var next_id := str(next_id_value)
				if not by_id.has(next_id):
					continue
				visible_ids[next_id] = true
				next_frontier.append(by_id[next_id])
		frontier = next_frontier
	var visible: Array[Dictionary] = []
	for node in route:
		if visible_ids.has(str(node["id"])):
			visible.append(node.duplicate(true))
	return visible


static func visible_node_ids(route: Array[Dictionary], state: RunState, forward_layers: int = 1) -> Array[String]:
	var ids: Array[String] = []
	for node in visible_nodes(route, state, forward_layers):
		ids.append(str(node["id"]))
	return ids


static func tree_columns(route: Array[Dictionary]) -> Array[Array]:
	var by_id := {}
	for node in route:
		by_id[str(node["id"])] = node
	var columns: Array[Array] = []
	var visited := {}
	var frontier: Array[String] = []
	for node in route:
		if bool(node.get("start", false)):
			frontier.append(str(node["id"]))
	while not frontier.is_empty():
		var column: Array = []
		var next_frontier: Array[String] = []
		for node_id in frontier:
			if visited.has(node_id) or not by_id.has(node_id):
				continue
			visited[node_id] = true
			var node: Dictionary = by_id[node_id]
			column.append(node.duplicate(true))
			for next_id in node.get("next_ids", []):
				var next_key := str(next_id)
				if not visited.has(next_key) and not next_frontier.has(next_key):
					next_frontier.append(next_key)
		if not column.is_empty():
			columns.append(column)
		frontier = next_frontier
	return columns


static func _load_json(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data


static func _index_nodes(nodes: Array) -> Dictionary:
	var indexed := {}
	for node in nodes:
		indexed[node["id"]] = node
	return indexed
