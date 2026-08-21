class_name ContentCatalog
extends RefCounted


const EFFECT_IDS := ["reveal_hidden", "heal_and_strike", "control_escape"]


static func load_all() -> Dictionary:
	var gu := _load_array("res://data/gu.json")
	var inheritances := _load_array("res://data/inheritances.json")
	return {
		"gu": gu,
		"gu_by_id": _index_by_id(gu),
		"inheritances": inheritances,
		"npcs": _load_array("res://data/npcs.json"),
	}


static func validate(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var gu_by_id: Dictionary = catalog["gu_by_id"]
	for inheritance in catalog["inheritances"]:
		var required_gu_ids: Array = inheritance["required_gu_ids"]
		var available_tags: Array = []
		var has_missing_gu := false
		for gu_id in required_gu_ids:
			if not gu_by_id.has(gu_id):
				errors.append("inheritance %s references missing gu %s" % [inheritance["id"], gu_id])
				has_missing_gu = true
				continue
			for tag in gu_by_id[gu_id]["tags"]:
				if not available_tags.has(tag):
					available_tags.append(tag)
		if not has_missing_gu:
			for tag in inheritance["required_tags"]:
				if not available_tags.has(tag):
					errors.append("inheritance %s requires missing tag %s" % [inheritance["id"], tag])
		if not EFFECT_IDS.has(inheritance["effect_id"]):
			errors.append("inheritance %s has invalid effect %s" % [inheritance["id"], inheritance["effect_id"]])
	return errors


static func _load_array(path: String) -> Array:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return []
	if json.data is Array:
		return json.data
	return []


static func _index_by_id(entries: Array) -> Dictionary:
	var indexed := {}
	for entry in entries:
		indexed[entry["id"]] = entry
	return indexed
