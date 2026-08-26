class_name InheritanceResolver
extends RefCounted


static func available_moves(
	equipped_gu_ids: Array[String],
	inheritance_ids: Array[String],
	catalog: Dictionary
) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var equipped_tags: Array = []
	var gu_by_id: Dictionary = catalog["gu_by_id"]
	for gu_id in equipped_gu_ids:
		if not gu_by_id.has(gu_id):
			continue
		for tag in gu_by_id[gu_id]["tags"]:
			if not equipped_tags.has(tag):
				equipped_tags.append(tag)
	for inheritance in catalog["inheritances"]:
		if not inheritance_ids.has(inheritance["id"]):
			continue
		if _matches(inheritance, equipped_gu_ids, equipped_tags):
			moves.append(inheritance.duplicate(true))
	return moves


static func _matches(inheritance: Dictionary, equipped_gu_ids: Array[String], equipped_tags: Array) -> bool:
	for gu_id in inheritance["required_gu_ids"]:
		if not equipped_gu_ids.has(gu_id):
			return false
	for tag in inheritance["required_tags"]:
		if not equipped_tags.has(tag):
			return false
	return true
