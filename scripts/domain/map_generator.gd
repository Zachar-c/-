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
	for stage in ["one", "two", "three", "four"]:
		var candidates: Array = by_stage[stage].duplicate()
		if stage == "four":
			candidates.erase("earth_vein_contest")
		route_ids.append(candidates[rng.next_index(candidates.size())])
		if route_ids.size() < 8:
			route_ids.append(candidates[rng.next_index(candidates.size())])
	route_ids.append("earth_vein_contest")
	route_ids.append("poison_fog_vein")
	route_ids.append("ascension_window")
	return route_ids


static func _route_from_ids(route_ids: Array, node_by_id: Dictionary) -> Array[Dictionary]:
	var route: Array[Dictionary] = []
	for index in route_ids.size():
		var node: Dictionary = node_by_id[route_ids[index]].duplicate(true)
		node["visible"] = index <= 1
		if index < route_ids.size() - 1:
			node["next_ids"] = [route_ids[index + 1]]
		route.append(node)
	return route


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
