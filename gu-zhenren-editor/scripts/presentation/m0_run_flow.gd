extends RefCounted

## M0 独立垂直切片路线。
## 只描述四个最小战斗节点，战斗/旅行/结算仍由现有正式管线负责。


static func build_route() -> Array[Dictionary]:
	return [
		_node("m0_fight_1", "ridge_hound", 0, ["m0_fight_2"], true),
		_node("m0_fight_2", "iron_hide_boar", 1, ["m0_elite"], false),
		_node("m0_elite", "ridge_elite_scout", 2, ["m0_boss"], false),
		_node("m0_boss", "miasma_vein_lord", 3, [], false, 1),
	]


static func _node(node_id: String, enemy_kind: String, row: int,
		next_ids: Array, is_start: bool, layer_boss: int = 0) -> Dictionary:
	return {
		"id": node_id,
		"template_id": node_id,
		"type": "combat",
		"stage": "one",
		"layer": 1,
		"row": row,
		"next_ids": next_ids,
		"start": is_start,
		"visible": is_start,
		"revealed": true,
		"anchor": layer_boss > 0,
		"enemy_kind": enemy_kind,
		"layer_boss": layer_boss,
		"choices": ["fight"],
	}
