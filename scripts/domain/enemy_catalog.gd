class_name EnemyCatalog
extends RefCounted


static func load_all() -> Dictionary:
	var entries := _load_entries()
	var indexed := {}
	for entry in entries:
		indexed[str(entry.get("id", ""))] = entry.duplicate(true)
	return {"enemies": entries, "enemy_by_id": indexed}


static func validate(entries: Array) -> Array[String]:
	var errors: Array[String] = []
	for entry in entries:
		var enemy_id := str(entry.get("id", "unknown"))
		var reactions: Array = entry.get("reactions", [])
		for index in reactions.size():
			var reaction: Dictionary = reactions[index]
			for key in ["clue", "window", "trigger", "counter_status"]:
				if str(reaction.get(key, "")).is_empty():
					errors.append("enemy %s reaction %d missing %s" % [enemy_id, index, key])
	return errors


static func _load_entries() -> Array:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string("res://data/enemies.json")) != OK:
		return []
	if json.data is Array:
		return json.data.duplicate(true)
	return []
