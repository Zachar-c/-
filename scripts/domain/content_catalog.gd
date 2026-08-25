class_name ContentCatalog
extends RefCounted


const EFFECT_IDS := ["reveal_hidden", "heal_and_strike", "control_escape"]
const RARITY_IDS := ["common", "rare", "epic", "legendary"]
const SCHOOL_IDS := ["blood", "qi", "force", "soul", "refine"]
const RELIC_GRADES := ["meta_rule"]
const CURSE_EFFECT_IDS := ["draw_pollution", "essence_surcharge", "slot_seal"]
const DECK_SERVICE_IDS := ["remove_card", "remove_imprint", "remove_curse"]
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
	var curses := _load_array("res://data/curse.json")
	var events: Array = _load_object("res://data/events.json").get("events", [])
	var shop_offers: Array = _load_object("res://data/shops.json").get("offers", [])
	var reputation := _load_object("res://data/reputation.json")
	var deck := _load_object("res://data/deck.json")
	var pacing := _load_object("res://data/pacing.json")
	var aptitude := _load_object("res://data/aptitude.json")
	var synthesis := _load_object("res://data/synthesis.json")
	var schools := _load_object("res://data/schools.json")
	var loot_tables := _load_object("res://data/loot_tables.json")
	var loot_materials: Dictionary = loot_tables.get("materials", {})
	var material_ids: Array[String] = ["feed_points"]
	for material_id in loot_materials:
		material_ids.append(str(material_id))
	return {
		"gu": gu,
		"gu_by_id": _index_by_id(gu),
		"cards": cards,
		"card_by_id": _index_by_id(cards),
		"material_ids": material_ids,
		"loot_tables": loot_tables,
		"material_by_id": loot_tables.get("materials", {}),
		"inheritances": inheritances,
		"npcs": _load_array("res://data/npcs.json"),
		"refinement_recipes": recipes,
		"refinement_by_id": _index_by_id(recipes),
		"caravan_offers": caravan_offers,
		"caravan_offer_by_id": _index_by_id(caravan_offers),
		"relics": relics,
		"relic_by_id": _index_by_id(relics),
		"curses": curses,
		"curse_by_id": _index_by_id(curses),
		"events": events,
		"event_by_id": _index_by_id(events),
		"nodes": _load_object("res://data/nodes.json").get("nodes", []),
		"shop_offers": shop_offers,
		"shop_offer_by_id": _index_by_id(shop_offers),
		"reputation": reputation,
		"deck": deck,
		"pacing": pacing,
		"aptitude": aptitude,
		"synthesis": synthesis,
		"schools": schools,
		"school_pools": _load_object("res://data/school_pools.json"),
		"enemies": enemy_catalog["enemies"],
		"enemy_by_id": enemy_catalog["enemy_by_id"],
	}


static func validate(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var entry_tables := {
		"gu": catalog.get("gu", []),
		"cards": catalog.get("cards", []),
		"refinement_recipes": catalog.get("refinement_recipes", []),
		"caravan_offers": catalog.get("caravan_offers", []),
		"relics": catalog.get("relics", []),
		"shop_offers": catalog.get("shop_offers", []),
		"nodes": catalog.get("nodes", []),
		"enemies": catalog.get("enemies", []),
	}
	for table_name in entry_tables:
		for entry in entry_tables[table_name]:
			if str(entry.get("id", "")).is_empty():
				errors.append("%s entry missing id" % table_name)
	var gu_by_id: Dictionary = catalog["gu_by_id"]
	var card_by_id: Dictionary = catalog.get("card_by_id", {})
	var material_ids: Array = catalog.get("material_ids", [])
	var seen_gu_ids := {}
	var seen_card_ids := {}
	for gu in catalog.get("gu", []):
		if seen_gu_ids.has(gu["id"]):
			errors.append("duplicate gu id %s" % gu["id"])
		seen_gu_ids[gu["id"]] = true
		if not gu.has("school"):
			errors.append("gu %s missing school" % gu["id"])
		elif not SCHOOL_IDS.has(str(gu["school"])):
			errors.append("gu %s invalid school %s" % [gu["id"], gu["school"]])
		if not gu.has("rarity"):
			errors.append("gu %s missing rarity" % gu["id"])
		elif not RARITY_IDS.has(str(gu["rarity"])):
			errors.append("gu %s invalid rarity %s" % [gu["id"], gu["rarity"]])
		if not gu.has("role"):
			errors.append("gu %s missing role" % gu["id"])
		elif not str(gu["role"]) in ["attack", "defense", "movement", "healing", "logistics", "recon"]:
			errors.append("gu %s invalid role %s" % [gu["id"], gu["role"]])
		for material_id in gu.get("feeding_need", {}):
			if not material_ids.has(material_id):
				errors.append("gu %s has unknown feeding material %s" % [gu["id"], material_id])
		for card_id in gu.get("card_blueprint_ids", []):
			if not card_by_id.has(card_id):
				errors.append("gu %s references missing card %s" % [gu["id"], card_id])
		if gu.has("combat_effects"):
			if (gu.get("card_blueprint_ids", []) as Array).size() != 1:
				errors.append("gu %s data-driven entries need exactly one blueprint" % gu["id"])
			elif not _is_data_driven_card_linked(gu, catalog.get("cards", [])):
				errors.append("gu %s blueprint does not back-reference it" % gu["id"])
		if gu.has("can_direct_drop") and not (gu["can_direct_drop"] is bool):
			errors.append("gu %s can_direct_drop must be a boolean" % gu["id"])
	for card in catalog.get("cards", []):
		if seen_card_ids.has(card["id"]):
			errors.append("duplicate card id %s" % card["id"])
		seen_card_ids[card["id"]] = true
		if not card.has("rarity"):
			errors.append("card %s missing rarity" % card["id"])
		elif not RARITY_IDS.has(str(card["rarity"])):
			errors.append("card %s invalid rarity %s" % [card["id"], card["rarity"]])
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
		if not relic.has("rarity"):
			errors.append("relic %s missing rarity" % relic["id"])
		elif not RARITY_IDS.has(str(relic["rarity"])):
			errors.append("relic %s invalid rarity %s" % [relic["id"], relic["rarity"]])
		var grade := str(relic.get("grade", ""))
		if not grade.is_empty() and not RELIC_GRADES.has(grade):
			errors.append("relic %s has unknown grade %s" % [relic["id"], grade])
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
	var curse_by_id: Dictionary = catalog.get("curse_by_id", {})
	for curse in catalog.get("curses", []):
		for field in ["id", "name_zh", "effect"]:
			if str(curse.get(field, "")).is_empty():
				errors.append("curse %s missing %s" % [curse.get("id", ""), field])
		if not CURSE_EFFECT_IDS.has(str(curse.get("effect", ""))):
			errors.append("curse %s unknown effect %s" % [curse.get("id", ""), curse.get("effect", "")])
		if not _is_integral(curse.get("base_intensity", null)) or int(curse.get("base_intensity", 0)) < 1:
			errors.append("curse %s base_intensity must be a positive integer" % curse.get("id", ""))
		if not _is_integral(curse.get("escalation_per_stage", null)) or int(curse.get("escalation_per_stage", 0)) < 0:
			errors.append("curse %s escalation_per_stage must be a non-negative integer" % curse.get("id", ""))
		if not _is_integral(curse.get("removal_base_cost", null)) or int(curse.get("removal_base_cost", 0)) < 1:
			errors.append("curse %s removal_base_cost must be a positive integer" % curse.get("id", ""))
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
	var raw_imprint_capacity: Variant = catalog.get("deck", {}).get("imprint_capacity", -1)
	if not _is_integral(raw_imprint_capacity) or int(raw_imprint_capacity) < 1:
		errors.append("deck imprint_capacity must be a positive integer")
	var raw_service_limits: Variant = catalog.get("deck", {}).get("service_limits", null)
	if not raw_service_limits is Dictionary:
		errors.append("deck service_limits must be an object")
	else:
		for service_id_value in DECK_SERVICE_IDS:
			var service_id := str(service_id_value)
			if not (raw_service_limits as Dictionary).has(service_id):
				errors.append("deck service_limits missing %s" % service_id)
				continue
			var limit_value: Variant = (raw_service_limits as Dictionary)[service_id]
			if not _is_integral(limit_value) or int(limit_value) < 1:
				errors.append("deck service_limits.%s must be a positive integer" % service_id)
	var milestones: Dictionary = catalog.get("pacing", {}).get("lifespan_milestones", {})
	for milestone_id in milestones:
		var milestone_value: Variant = milestones[milestone_id]
		if not _is_integral(milestone_value) or int(milestone_value) < 0:
			errors.append("pacing lifespan_milestones.%s must be a non-negative integer" % milestone_id)
	var aptitude_data: Dictionary = catalog.get("aptitude", {})
	var base_map: Dictionary = aptitude_data.get("stage_essence_base", {})
	for tier_id in base_map:
		var tier_value: Variant = base_map[tier_id]
		if not _is_integral(tier_value) or int(tier_value) < 1:
			errors.append("aptitude stage_essence_base.%s must be a positive integer" % tier_id)
	var pct_map: Dictionary = aptitude_data.get("aptitude_pct", {})
	for aptitude_id in pct_map:
		var pct_value: Variant = pct_map[aptitude_id]
		if not _is_integral(pct_value) or int(pct_value) < 0:
			errors.append("aptitude aptitude_pct.%s must be a non-negative integer" % aptitude_id)
	for rank_value in aptitude_data.get("rank_tier", {}).values():
		if not base_map.has(str(rank_value)):
			errors.append("aptitude rank_tier references unknown tier %s" % rank_value)
	var schools_data: Dictionary = catalog.get("schools", {})
	for school_id in SCHOOL_IDS:
		if not schools_data.has(school_id):
			errors.append("schools missing %s" % school_id)
	for school_id in schools_data:
		var school_entry: Dictionary = schools_data[school_id]
		if str(school_entry.get("name", "")).is_empty():
			errors.append("school %s needs display name" % school_id)
		if str(school_entry.get("summary", "")).is_empty():
			errors.append("school %s needs summary" % school_id)
		var starters: Array = school_entry.get("starter_gu_ids", [])
		if starters.is_empty():
			errors.append("school %s needs starter gu ids" % school_id)
		for starter in starters:
			if not gu_by_id.has(str(starter)):
				errors.append("school %s starter references missing gu %s" % [school_id, starter])
	var school_pools: Dictionary = catalog.get("school_pools", {})
	var pool_gu_seen := {}
	for school_id in SCHOOL_IDS:
		if not school_pools.has(school_id):
			errors.append("school %s needs exclusive pool" % school_id)
			continue
		var pool: Array = school_pools[school_id]
		if pool.is_empty():
			errors.append("school %s exclusive pool is empty" % school_id)
			continue
		for pool_gu_value in pool:
			var pool_gu_id := str(pool_gu_value)
			if not gu_by_id.has(pool_gu_id):
				errors.append("school %s pool references missing gu %s" % [school_id, pool_gu_id])
				continue
			if pool_gu_seen.has(pool_gu_id):
				errors.append("gu %s appears in multiple school pools" % pool_gu_id)
				continue
			pool_gu_seen[pool_gu_id] = school_id
			if str(gu_by_id[pool_gu_id].get("school", "")) != school_id:
				errors.append("school %s pool gu %s belongs to school %s" % [school_id, pool_gu_id, gu_by_id[pool_gu_id].get("school", "")])
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
		for outcome_value in recipe.get("outcomes", []):
			var fail_curse_id := str(outcome_value.get("fail_curse_id", ""))
			if not fail_curse_id.is_empty() and not curse_by_id.has(fail_curse_id):
				errors.append("recipe %s failure references unknown curse %s" % [recipe["id"], fail_curse_id])
	for event_entry in catalog.get("events", []):
		var event_curse_id := str(event_entry.get("curse_id", ""))
		if not event_curse_id.is_empty() and not curse_by_id.has(event_curse_id):
			errors.append("event %s references unknown curse %s" % [event_entry.get("id", ""), event_curse_id])
	var loot_tables: Dictionary = catalog.get("loot_tables", {})
	var materials: Dictionary = loot_tables.get("materials", {})
	for material_id in materials:
		if int(materials[material_id].get("value", 0)) < 1:
			errors.append("material %s needs a positive value" % material_id)
	var material_pity: Dictionary = loot_tables.get("pity", {}).get("material_pity", {})
	if not material_pity.is_empty():
		if not _is_integral(material_pity.get("threshold", null)) or int(material_pity.get("threshold", 0)) < 1:
			errors.append("loot material_pity threshold must be a positive integer")
		for target_value in material_pity.get("target_material_ids", []):
			if not materials.has(str(target_value)):
				errors.append("loot material_pity references unknown material %s" % target_value)
	var synthesis: Dictionary = catalog.get("synthesis", {})
	if not synthesis.is_empty():
		var battle_cfg: Dictionary = synthesis.get("battle", {})
		if not _is_integral(battle_cfg.get("success_base_pct", null)) or int(battle_cfg.get("success_base_pct", 0)) < 1 or int(battle_cfg.get("success_base_pct", 0)) > 99:
			errors.append("synthesis battle success_base_pct must be 1..99")
		if not _is_integral(battle_cfg.get("per_fail_bonus_pct", null)) or int(battle_cfg.get("per_fail_bonus_pct", 0)) < 1:
			errors.append("synthesis battle per_fail_bonus_pct must be positive")
		if not _is_integral(battle_cfg.get("max_bonus_pct", null)) or int(battle_cfg.get("max_bonus_pct", 0)) < 1 or int(battle_cfg.get("max_bonus_pct", 0)) > 99:
			errors.append("synthesis battle max_bonus_pct must be 1..99")
		if not _is_integral(battle_cfg.get("blind_penalty_pct", null)) or int(battle_cfg.get("blind_penalty_pct", 0)) < 0:
			errors.append("synthesis battle blind_penalty_pct must be non-negative")
		var blind_curse := str(battle_cfg.get("blind_fail_curse_id", ""))
		if not blind_curse.is_empty() and not curse_by_id.has(blind_curse):
			errors.append("synthesis blind failure references unknown curse %s" % blind_curse)
		for recipe_value in synthesis.get("battle_recipes", []):
			var recipe: Dictionary = recipe_value
			if str(recipe.get("id", "")).is_empty():
				errors.append("synthesis recipe missing id")
			for material_id_value in recipe.get("material_cost", {}):
				if not materials.has(str(material_id_value)):
					errors.append("synthesis recipe %s references unknown material %s" % [recipe.get("id", ""), material_id_value])
			var temp_card := str(recipe.get("temp_card_id", ""))
			if not temp_card.is_empty() and not card_by_id.has(temp_card):
				errors.append("synthesis recipe %s references missing card %s" % [recipe.get("id", ""), temp_card])
		var blind_cfg: Dictionary = synthesis.get("battle_blind", {})
		if not blind_cfg.is_empty():
			for material_id_value in blind_cfg.get("material_cost", {}):
				if not materials.has(str(material_id_value)):
					errors.append("synthesis blind references unknown material %s" % material_id_value)
			for card_value in blind_cfg.get("blind_pool", []):
				if not card_by_id.has(str(card_value)):
					errors.append("synthesis blind references missing card %s" % card_value)
	for tier_key in loot_tables.get("loot", {}):
		var tier: Dictionary = loot_tables["loot"][tier_key]
		if int(tier.get("material_count", 0)) < 0:
			errors.append("loot tier %s has a negative material count" % tier_key)
		var chance := int(tier.get("gu_chance_pct", 0))
		if chance < 0 or chance > 100:
			errors.append("loot tier %s has invalid gu chance %d" % [tier_key, chance])
		for material_id_value in tier.get("material_pool", []):
			if not materials.has(str(material_id_value)):
				errors.append("loot tier %s references unknown material %s" % [tier_key, material_id_value])
		var gu_pool: Dictionary = tier.get("gu_pool", {})
		var weights: Dictionary = gu_pool.get("weights", {})
		var by_rarity: Dictionary = gu_pool.get("by_rarity", {})
		var has_positive_weight := false
		for rarity_id_value in weights:
			var weighted_rarity := str(rarity_id_value)
			if not RARITY_IDS.has(weighted_rarity):
				errors.append("loot tier %s weight uses unknown rarity %s" % [tier_key, weighted_rarity])
				continue
			if not _is_integral(weights[rarity_id_value]) or int(weights[rarity_id_value]) < 0:
				errors.append("loot tier %s weight %s must be a non-negative integer" % [tier_key, weighted_rarity])
				continue
			if int(weights[rarity_id_value]) > 0:
				has_positive_weight = true
				var weighted_bucket: Array = by_rarity.get(weighted_rarity, [])
				if weighted_bucket.is_empty():
					errors.append("loot tier %s weight %s sits on an empty bucket" % [tier_key, weighted_rarity])
		if not weights.is_empty() and not has_positive_weight:
			errors.append("loot tier %s gu_pool needs at least one positive weight" % tier_key)
		for rarity_id_value in by_rarity:
			var bucket_rarity := str(rarity_id_value)
			if not RARITY_IDS.has(bucket_rarity):
				errors.append("loot tier %s bucket uses unknown rarity %s" % [tier_key, bucket_rarity])
			for gu_id_value in by_rarity[rarity_id_value]:
				var pool_gu_id := str(gu_id_value)
				if not gu_by_id.has(pool_gu_id):
					errors.append("loot tier %s references unknown gu %s" % [tier_key, pool_gu_id])
				elif str(gu_by_id[pool_gu_id].get("rarity", "")) != bucket_rarity:
					errors.append("loot tier %s gu %s rarity mismatch with bucket %s" % [tier_key, pool_gu_id, bucket_rarity])
		var scavenge_recipe := str(tier.get("scavenge_recipe", ""))
		if not scavenge_recipe.is_empty() and not catalog.get("refinement_by_id", {}).has(scavenge_recipe):
			errors.append("loot tier %s references missing scavenge recipe %s" % [tier_key, scavenge_recipe])
	return errors


static func _is_data_driven_card_linked(gu: Dictionary, cards: Array) -> bool:
	for card in cards:
		if str(card.get("id", "")) == str(gu.get("card_blueprint_ids", [])[0]) \
				and (card.get("source_gu_ids", []) as Array).has(gu["id"]):
			return true
	return false


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
