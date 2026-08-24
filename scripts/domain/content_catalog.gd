class_name ContentCatalog
extends RefCounted


const EFFECT_IDS := ["reveal_hidden", "heal_and_strike", "control_escape"]
const EnemyCatalogScript = preload("res://scripts/domain/enemy_catalog.gd")
const RelicHookResolverScript = preload("res://scripts/domain/relic_hook_resolver.gd")


static func load_all() -> Dictionary:
	var gu := _load_array("res://data/gu.json")
	var cards := _load_array("res://data/cards.json")
	var inheritances := _load_array("res://data/inheritances.json")
	var refinement := _load_object("res://data/refinement_recipes.json")
	var recipes: Array = refinement.get("recipes", [])
	var caravan_offers: Array = refinement.get("caravan_offers", [])
	var enemy_catalog := EnemyCatalogScript.load_all()
	var relics := _load_array("res://data/relics.json")
	var events: Array = _load_object("res://data/events.json").get("events", [])
	var shop_offers: Array = _load_object("res://data/shops.json").get("offers", [])
	var reputation := _load_object("res://data/reputation.json")
	var deck := _load_object("res://data/deck.json")
	return {
		"gu": gu,
		"gu_by_id": _index_by_id(gu),
		"cards": cards,
		"card_by_id": _index_by_id(cards),
		"material_ids": ["feed_points"],
		"inheritances": inheritances,
		"npcs": _load_array("res://data/npcs.json"),
		"refinement_recipes": recipes,
		"refinement_by_id": _index_by_id(recipes),
		"caravan_offers": caravan_offers,
		"caravan_offer_by_id": _index_by_id(caravan_offers),
		"relics": relics,
		"relic_by_id": _index_by_id(relics),
		"events": events,
		"event_by_id": _index_by_id(events),
		"shop_offers": shop_offers,
		"shop_offer_by_id": _index_by_id(shop_offers),
		"reputation": reputation,
		"deck": deck,
		"enemies": enemy_catalog["enemies"],
		"enemy_by_id": enemy_catalog["enemy_by_id"],
	}


static func validate(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var gu_by_id: Dictionary = catalog["gu_by_id"]
	var card_by_id: Dictionary = catalog.get("card_by_id", {})
	var material_ids: Array = catalog.get("material_ids", [])
	for gu in catalog.get("gu", []):
		for material_id in gu.get("feeding_need", {}):
			if not material_ids.has(material_id):
				errors.append("gu %s has unknown feeding material %s" % [gu["id"], material_id])
		for card_id in gu.get("card_blueprint_ids", []):
			if not card_by_id.has(card_id):
				errors.append("gu %s references missing card %s" % [gu["id"], card_id])
	for card in catalog.get("cards", []):
		for source_gu_id in card.get("source_gu_ids", []):
			if not gu_by_id.has(source_gu_id):
				errors.append("card %s references missing source gu %s" % [card["id"], source_gu_id])
		if int(card.get("duration_turns", -1)) < 0:
			errors.append("card %s requires integer duration_turns" % card["id"])
		if card.has("kill_move_sequence"):
			for source_gu_id in card["kill_move_sequence"]:
				if not gu_by_id.has(source_gu_id):
					errors.append("kill move %s references missing gu %s" % [card["id"], source_gu_id])

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
	errors.append_array(EnemyCatalogScript.validate(catalog.get("enemies", [])))
	var relic_by_id: Dictionary = catalog.get("relic_by_id", {})
	for relic in catalog.get("relics", []):
		for hook in relic.get("hooks", []):
			var trigger := str(hook.get("trigger", ""))
			if not RelicHookResolverScript.TRIGGERS.has(trigger):
				errors.append("relic %s references unknown trigger %s" % [relic["id"], trigger])
			var effect: Dictionary = hook.get("effect", {})
			var kind := str(effect.get("kind", ""))
			if not RelicHookResolverScript.EFFECT_KINDS.has(kind):
				errors.append("relic %s references unknown effect kind %s" % [relic["id"], kind])
			if not _is_integral(effect.get("amount", -1)) or int(effect.get("amount", -1)) < 0:
				errors.append("relic %s effect amount must be a non-negative integer" % relic["id"])
	for offer in catalog.get("shop_offers", []):
		if str(offer.get("kind", "")) in ["purchase", "lifespan_deal"] and not gu_by_id.has(str(offer.get("gu_id", ""))):
			errors.append("shop offer %s references missing gu %s" % [offer["id"], offer.get("gu_id", "")])
		for input_gu_id in offer.get("input_gu_ids", []):
			if not gu_by_id.has(str(input_gu_id)):
				errors.append("shop offer %s references missing gu %s" % [offer["id"], input_gu_id])
		for reward in offer.get("rewards", []):
			if reward.has("gu_id") and not gu_by_id.has(str(reward["gu_id"])):
				errors.append("shop offer %s rewards missing gu %s" % [offer["id"], reward["gu_id"]])
			if reward.has("relic_id") and not relic_by_id.has(str(reward["relic_id"])):
				errors.append("shop offer %s rewards missing relic %s" % [offer["id"], reward["relic_id"]])
	var reputation: Dictionary = catalog.get("reputation", {})
	for group_name in ["gains", "effects"]:
		for key_value in reputation.get(group_name, {}):
			var value: Variant = reputation[group_name][key_value]
			if not _is_integral(value) or int(value) < 0:
				errors.append("reputation %s.%s must be a non-negative integer" % [group_name, key_value])
	var raw_capacity: Variant = catalog.get("deck", {}).get("capacity", -1)
	if not _is_integral(raw_capacity) or int(raw_capacity) < 1:
		errors.append("deck capacity must be a positive integer")
	var gu_tags: Array[String] = []
	for gu in catalog.get("gu", []):
		for tag_value in gu.get("tags", []):
			if not gu_tags.has(str(tag_value)):
				gu_tags.append(str(tag_value))
	for recipe in catalog.get("refinement_recipes", []):
		for rule_value in recipe.get("risk_hints", []):
			var rule: Dictionary = rule_value
			for required_tag in rule.get("tags", []):
				if not gu_tags.has(str(required_tag)):
					errors.append("recipe %s risk hint references unknown tag %s" % [recipe["id"], required_tag])
			if str(rule.get("text", "")).is_empty():
				errors.append("recipe %s risk hint needs non-empty text" % recipe["id"])
	return errors


static func _load_array(path: String) -> Array:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return []
	if json.data is Array:
		return json.data
	return []


static func _load_object(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


static func _index_by_id(entries: Array) -> Dictionary:
	var indexed := {}
	for entry in entries:
		indexed[entry["id"]] = entry
	return indexed


static func _is_integral(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, floor(value)))
