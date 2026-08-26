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
		var tier := str(entry.get("tier", "common"))
		if not tier in ["common", "elite", "boss"]:
			errors.append("enemy %s has invalid tier %s" % [enemy_id, tier])
		var reactions: Array = entry.get("reactions", [])
		for index in reactions.size():
			var reaction: Dictionary = reactions[index]
			for key in ["clue", "window", "trigger", "counter_status"]:
				if str(reaction.get(key, "")).is_empty():
					errors.append("enemy %s reaction %d missing %s" % [enemy_id, index, key])
		errors.append_array(_validate_phases(enemy_id, entry.get("phases", [])))
	return errors


# Phase tables (R5.7): until_hp_ratio values must stay inside (0, 1] and
# descend strictly in data order (later phases are reached at lower hp);
# every phase needs a non-empty intents array whose cooldown entries are
# non-negative integers.
static func _validate_phases(enemy_id: String, phases_value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if phases_value == null:
		return errors
	if not phases_value is Array:
		errors.append("enemy %s phases must be an array" % enemy_id)
		return errors
	var phases: Array = phases_value
	var previous_ratio := INF
	for phase_index in phases.size():
		var phase: Dictionary = phases[phase_index]
		var ratio_value: Variant = phase.get("until_hp_ratio", null)
		if ratio_value is int or ratio_value is float:
			var ratio := float(ratio_value)
			if ratio <= 0.0 or ratio > 1.0:
				errors.append("enemy %s phase %d until_hp_ratio %s outside (0, 1]" % [enemy_id, phase_index, str(ratio_value)])
			elif ratio >= previous_ratio:
				errors.append("enemy %s phase %d until_hp_ratio must descend strictly (deeper phases unlock at lower hp)" % [enemy_id, phase_index])
			else:
				previous_ratio = ratio
		else:
			errors.append("enemy %s phase %d missing a numeric until_hp_ratio" % [enemy_id, phase_index])
		var intents: Array = phase.get("intents", [])
		if (intents as Array).is_empty():
			errors.append("enemy %s phase %d needs a non-empty intents array" % [enemy_id, phase_index])
		for intent_index in intents.size():
			var intent: Dictionary = intents[intent_index]
			var cooldown_value: Variant = intent.get("cooldown", 0)
			var integral := cooldown_value is int \
					or (cooldown_value is float and is_equal_approx(float(cooldown_value), floor(float(cooldown_value))))
			if not integral or int(cooldown_value) < 0:
				errors.append("enemy %s phase %d intent %d cooldown must be a non-negative integer" % [enemy_id, phase_index, intent_index])
	return errors


static func _load_entries() -> Array:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string("res://data/enemies.json")) != OK:
		return []
	if json.data is Array:
		return json.data.duplicate(true)
	return []
