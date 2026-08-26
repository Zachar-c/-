extends GutTest


func test_only_connected_visible_nodes_are_reachable() -> void:
	var state := RunState.new_run(101)
	var route := MapGenerator.build(101, true)
	var ids: Array[String] = []
	for node in MapGenerator.reachable_nodes(route, state):
		ids.append(str(node["id"]))
	assert_eq(ids, ["neutral_wanderer", "ridge_caravan"])


func test_fog_reveals_the_current_choice_layer_and_one_layer_ahead() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	var route := MapGenerator.build(101, true)
	assert_eq(_ids(MapGenerator.visible_nodes(route, state)), [
		"neutral_wanderer", "ridge_caravan", "beast_swarm_pass", "moonlit_trail", "refinement_hollow",
		"cultivation_spring", "village_short_work",
	])
	state = Resolver.apply(state, {"type": "travel", "node_id": "ridge_caravan"}, catalog)["state"]
	state = Resolver.apply(state, {"type": "complete_node", "node_id": "ridge_caravan", "outcome": "abandoned"}, catalog)["state"]
	assert_true(MapGenerator.visible_node_ids(route, state).has("toxic_mountain_path"))
	assert_false(MapGenerator.visible_node_ids(route, state).has("stage_one_ledger"))
	assert_false(MapGenerator.visible_node_ids(route, state).has("black_mud_marsh"))


func test_route_tree_hides_nodes_outside_the_visible_fog_layers() -> void:
	var tree := preload("res://scripts/presentation/route_tree_canvas.gd").new()
	tree.configure(MapGenerator.build(101, true), RunState.new_run(101))
	assert_eq(tree.get_child_count(), 7)
	for child in tree.get_children():
		assert_ne(child.text, "未明地带")
	tree.free()


func _ids(nodes: Array) -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(str(node["id"]))
	return ids
