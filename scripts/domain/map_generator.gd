class_name MapGenerator
extends RefCounted


static func build(seed_value: int, first_run: bool) -> Array[Dictionary]:
	var data := _load_json("res://data/nodes.json")
	var node_by_id := _index_nodes(data["nodes"])
	node_by_id[data["ascension_node"]["id"]] = data["ascension_node"]
	if first_run:
		var route_ids: Array = _load_json("res://data/first_run.json")["route_ids"]
		return _route_from_ids(route_ids, node_by_id)
	var stage_picks := _generated_stage_picks(seed_value, data["nodes"], node_by_id)
	return _route_with_network(stage_picks, node_by_id, seed_value)


static func _generated_stage_picks(seed_value: int, nodes: Array, node_by_id: Dictionary) -> Dictionary:
	var by_stage := {}
	for node in nodes:
		if not by_stage.has(node["stage"]):
			by_stage[node["stage"]] = []
		by_stage[node["stage"]].append(node["id"])
	var rng := SeededRng.new(seed_value)
	var stage_picks := {}
	# Stage order omits "two" intentionally: nodes.json currently carries no
	# stage-two nodes, so the picker is data-driven and would pick them as soon
	# as any appear. Topological order stays one -> three -> four -> five.
	for stage in ["one", "three", "four", "five"]:
		if not by_stage.has(stage):
			continue
		var candidates: Array = by_stage[stage].duplicate()
		if stage == "four":
			candidates.erase("earth_vein_contest")
		var picks: Array = []
		var pick_count := mini(3, candidates.size())
		while picks.size() < pick_count and not candidates.is_empty():
			var pick_id := str(candidates[rng.next_index(candidates.size())])
			candidates.erase(pick_id)
			picks.append(pick_id)
		if stage == "one":
			for node_id_value in by_stage["one"]:
				var start_id := str(node_id_value)
				if bool(node_by_id.get(start_id, {}).get("start", false)) and not picks.has(start_id):
					picks.append(start_id)
		stage_picks[stage] = picks
	_guarantee_anchor_types(stage_picks, by_stage, node_by_id)
	if by_stage.has("four") and not stage_picks.get("four", []).has("earth_vein_contest"):
		stage_picks["four"].append("earth_vein_contest")
	if not stage_picks.has("five"):
		stage_picks["five"] = []
	if not stage_picks["five"].has("poison_fog_vein"):
		stage_picks["five"].append("poison_fog_vein")
	if not stage_picks["five"].has("final_boss_stand"):
		stage_picks["five"].append("final_boss_stand")
	return stage_picks


static func _guarantee_anchor_types(stage_picks: Dictionary, by_stage: Dictionary, node_by_id: Dictionary) -> void:
	for required_type in ["shop", "refinement", "inheritance"]:
		var present := false
		for stage in stage_picks:
			if present:
				break
			for node_id_value in stage_picks[stage]:
				var node_id := str(node_id_value)
				if str(node_by_id.get(node_id, {}).get("type", "")) == required_type:
					present = true
					break
		if present:
			continue
		for stage in ["one", "three", "four", "five"]:
			if present or not by_stage.has(stage):
				continue
			for node_id_value in by_stage[stage]:
				var node_id := str(node_id_value)
				if not stage_picks.get(stage, []).has(node_id) and str(node_by_id.get(node_id, {}).get("type", "")) == required_type:
					stage_picks[stage].append(node_id)
					present = true
					break


static func _route_with_network(stage_picks: Dictionary, node_by_id: Dictionary, seed_value: int) -> Array[Dictionary]:
	var stage_order: Array[String] = ["one", "three", "four", "five"]
	var stage_one_starts: Array = []
	var stage_one_rest: Array = []
	for node_id_value in stage_picks.get("one", []):
		var pick_id := str(node_id_value)
		if bool(node_by_id.get(pick_id, {}).get("start", false)):
			stage_one_starts.append(pick_id)
		else:
			stage_one_rest.append(pick_id)
	stage_picks["one"] = stage_one_starts + stage_one_rest
	var flat_ids: Array = []
	for stage in stage_order:
		for node_id_value in stage_picks.get(stage, []):
			flat_ids.append(str(node_id_value))
	flat_ids.append("ascension_window")
	var by_stage_ids := {}
	for index in flat_ids.size():
		var node_id := str(flat_ids[index])
		var stage := str(node_by_id.get(node_id, {}).get("stage", "one"))
		if not by_stage_ids.has(stage):
			by_stage_ids[stage] = []
		by_stage_ids[stage].append(node_id)
	var outgoing := {}
	var incoming_count := {}
	for node_id in flat_ids:
		outgoing[node_id] = []
		incoming_count[node_id] = 0
	for stage_index in range(stage_order.size() - 1):
		var this_stage := stage_order[stage_index]
		var next_stage := stage_order[stage_index + 1]
		var from_ids: Array = by_stage_ids.get(this_stage, [])
		var to_ids: Array = by_stage_ids.get(next_stage, [])
		if from_ids.is_empty() or to_ids.is_empty():
			continue
		for from_id_value in from_ids:
			var from_id := str(from_id_value)
			var rng := _node_rng(seed_value, from_id)
			var links := mini(2, to_ids.size())
			var pool: Array = to_ids.duplicate()
			for _link in links:
				outgoing[from_id].append(str(pool[rng.next_index(pool.size())]))
				incoming_count[str(outgoing[from_id].back())] = int(incoming_count.get(str(outgoing[from_id].back()), 0)) + 1
			# Cross-branch jump: a minority of nodes also reach into the stage after next.
			if stage_index + 2 < stage_order.size() and rng.next_index(100) < 30:
				var jump_ids: Array = by_stage_ids.get(stage_order[stage_index + 2], [])
				if not jump_ids.is_empty():
					var jump_id := str(jump_ids[rng.next_index(jump_ids.size())])
					outgoing[from_id].append(jump_id)
					incoming_count[jump_id] = int(incoming_count.get(jump_id, 0)) + 1
	# Multiple-entry guarantee: every non-start node keeps at least one incoming
	# edge, donated deterministically by an earlier node (start nodes lead the flat order).
	for index in range(1, flat_ids.size()):
		var node_id := str(flat_ids[index])
		if int(incoming_count.get(node_id, 0)) > 0:
			continue
		if bool(node_by_id.get(node_id, {}).get("start", false)):
			continue
		var donor := str(flat_ids[_node_rng(seed_value, node_id).next_index(index)])
		outgoing[donor].append(node_id)
		incoming_count[node_id] = 1
	# Every stage-five node converges onto the ascension window.
	for node_id_value in by_stage_ids.get("five", []):
		var node_id := str(node_id_value)
		if not outgoing[node_id].has("ascension_window"):
			outgoing[node_id].append("ascension_window")
	var route: Array[Dictionary] = []
	for index in flat_ids.size():
		var node_id := str(flat_ids[index])
		var node: Dictionary = node_by_id[node_id].duplicate(true)
		node["visible"] = index <= 1
		node["next_ids"] = outgoing[node_id]
		route.append(node)
	return route


static func _node_rng(seed_value: int, node_id: String) -> SeededRng:
	var digest := 0
	for character in node_id:
		digest = digest * 31 + character.unicode_at(0)
	return SeededRng.new(int(seed_value) * 1000003 + digest)


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
