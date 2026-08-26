class_name OpenRpgAdapter
extends RefCounted


static func create_battle_context(config: Dictionary) -> Dictionary:
	return {
		"enemy_kind": config["enemy_kind"],
		"turn_order": ["player", "enemy"],
	}
