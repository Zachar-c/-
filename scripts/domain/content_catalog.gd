class_name ContentCatalog
extends RefCounted


const EFFECT_IDS := ["reveal_hidden", "heal_and_strike", "control_escape"]
const RARITY_IDS := ["common", "rare", "epic", "legendary"]
const SCHOOL_IDS := ["blood", "qi", "force", "soul", "refine"]
const RELIC_GRADES := ["meta_rule"]
const CURSE_EFFECT_IDS := ["draw_pollution", "essence_surcharge", "slot_seal"]
const DECK_SERVICE_IDS := ["remove_card", "remove_imprint", "remove_curse"]
const EVENT_KIND_IDS := ["delayed_cost", "curse_bargain"]
const DIALOGUE_INTENT_IDS := ["probe", "trade", "pressure", "leave", "clarify"]
const NODE_KIND_IDS := ["start", "combat", "pursuit", "event", "shop", "market", "rest", "seclusion", "cultivation", "ascension", "refinement", "inheritance", "caravan", "wild_gu", "contact", "hazard", "earth_vein", "ledger"]
# C1-min §16.13: contract rule keys are a closed whitelist; the ending ids
# mirror the snapshot builder's ending_type vocabulary.
const CONTRACT_RULE_KEYS := [
	"strike_damage_pct", "enemy_damage_pct", "shop_price_pct",
	"material_bonus", "material_penalty", "turn_essence_bonus",
	"hp_max_penalty", "hall_material_bonus_pct", "enemy_hp_pct",
]
const ENDING_TYPE_IDS := ["success", "risky", "retreat", "death", "gu_fall", "true_ending"]
# N1 §16.9: journal layers are a closed enum and route markers must name real
# event-log signals produced by MetaProgress._run_markers (single mapping).
const JOURNAL_LAYER_IDS := ["hall"]
const JOURNAL_MARKER_IDS := [
	"boss_defeated", "sworn_contracts", "ascension_attempted",
	"notoriety_gte_5", "shop_barter", "rest_curse_removed",
]
const EnemyCatalogScript = preload("res://scripts/domain/enemy_catalog.gd")
const RelicHookResolverScript = preload("res://scripts/domain/relic_hook_resolver.gd")
const DialogueGatewayScript = preload("res://scripts/domain/dialogue_gateway.gd")


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
	var contracts_cfg := _load_object("res://data/contracts.json")
	var journal_cfg := _load_object("res://data/journal.json")
	var dda_cfg := _load_object("res://data/dda.json")
	var debug_cfg := _load_object("res://data/debug.json")
	var first_run_cfg := _load_object("res://data/first_run.json")
	var dialogue_templates_cfg := _load_object("res://data/dialogue_templates.json")
	var names_cfg := _load_object("res://data/names.json")
	var nodes_data := _load_object("res://data/nodes.json")
	var nodes: Array = nodes_data.get("nodes", [])
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
		"nodes": nodes,
		"node_by_id": _index_by_id(nodes),
		"nodes_data": nodes_data,
		"shop_offers": shop_offers,
		"shop_offer_by_id": _index_by_id(shop_offers),
		"reputation": reputation,
		"deck": deck,
		"pacing": pacing,
		"aptitude": aptitude,
		"synthesis": synthesis,
		"schools": schools,
		"school_pools": _load_object("res://data/school_pools.json"),
		"contracts": contracts_cfg,
		"contract_entry_by_id": _index_by_id(contracts_cfg.get("entries", [])),
		"journal": journal_cfg,
		"journal_entry_by_id": _index_by_id(journal_cfg.get("entries", [])),
		"dda": dda_cfg,
		"debug": debug_cfg,
		"first_run": first_run_cfg,
		"dialogue_templates": dialogue_templates_cfg,
		"names": names_cfg,
		"enemies": enemy_catalog["enemies"],
		"enemy_by_id": enemy_catalog["enemy_by_id"],
	}


static func load_and_validate_all() -> Dictionary:
	var catalog := load_all()
	var errors := validate(catalog)
	return {"catalog": catalog, "errors": errors}


static func _validate_events(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	for entry_value in catalog.get("events", []):
		if not entry_value is Dictionary:
			errors.append("events entry must be an object")
			continue
		var entry: Dictionary = entry_value
		var event_id := str(entry.get("id", ""))
		if event_id.is_empty():
			errors.append("event entry missing id")
		elif seen.has(event_id):
			errors.append("duplicate event id %s" % event_id)
		seen[event_id] = true
		var kind := str(entry.get("kind", ""))
		if entry.has("kind") and not EVENT_KIND_IDS.has(kind):
			errors.append("event %s has unknown kind %s" % [event_id, kind])
		for field in ["health_cost", "delayed_soul_cost"]:
			if entry.has(field) and (not _is_integral(entry.get(field)) or int(entry.get(field)) < 0):
				errors.append("event %s.%s must be a non-negative integer" % [event_id, field])
		var trigger := str(entry.get("delayed_trigger", ""))
		if entry.has("delayed_trigger") and trigger != "next_travel":
			errors.append("event %s.delayed_trigger has unknown value %s" % [event_id, trigger])
		if entry.has("kind") and kind == "curse_bargain" and str(entry.get("curse_id", "")).is_empty():
			errors.append("event %s curse_bargain needs curse_id" % event_id)
		var curse_id := str(entry.get("curse_id", ""))
		if not curse_id.is_empty() and not catalog.get("curse_by_id", {}).has(curse_id):
			errors.append("event %s references unknown curse %s" % [event_id, curse_id])
	return errors


static func _validate_pacing(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var pacing: Dictionary = catalog.get("pacing", {})
	var scaling: Dictionary = pacing.get("turn_scaling", {})
	for field in ["hp_add_per_turn", "damage_add_per_turn"]:
		if not _is_integral(scaling.get(field, null)) or int(scaling.get(field, 0)) < 0:
			errors.append("pacing turn_scaling.%s must be a non-negative integer" % field)
	var layers: Dictionary = pacing.get("layers", {})
	for layer_number in range(1, 6):
		var layer_id := str(layer_number)
		if not layers.has(layer_id):
			errors.append("pacing layers missing %s" % layer_id)
			continue
		var layer: Dictionary = layers[layer_id]
		for range_field in ["rows", "row_nodes", "entry_nodes"]:
			var bounds: Variant = layer.get(range_field, null)
			if not bounds is Array or (bounds as Array).size() != 2:
				errors.append("pacing layer %s.%s must be a two-item array" % [layer_id, range_field])
				continue
			if not _is_integral(bounds[0]) or not _is_integral(bounds[1]) or int(bounds[0]) < 1 or int(bounds[1]) < int(bounds[0]):
				errors.append("pacing layer %s.%s has invalid bounds" % [layer_id, range_field])
			var loot: Dictionary = layer.get("loot", {})
			if not _is_integral(loot.get("material_count", null)) or int(loot.get("material_count", -1)) < 0:
				errors.append("pacing layer %s loot.material_count must be non-negative" % layer_id)
			var weights: Dictionary = loot.get("weights", {})
			var has_weight := false
			for rarity_value in weights:
				var rarity := str(rarity_value)
				if not RARITY_IDS.has(rarity):
					errors.append("pacing layer %s loot.weights uses unknown rarity %s" % [layer_id, rarity])
				if not _is_integral(weights[rarity_value]) or int(weights[rarity_value]) < 0:
					errors.append("pacing layer %s loot.weights.%s must be non-negative" % [layer_id, rarity])
				elif int(weights[rarity_value]) > 0:
					has_weight = true
			if not weights.is_empty() and not has_weight:
				errors.append("pacing layer %s loot.weights needs a positive weight" % layer_id)
			var enemy_turn := int(layer.get("enemy_turn", 0))
			if enemy_turn < 1 or enemy_turn > 5:
				errors.append("pacing layer %s enemy_turn must be within 1..5" % layer_id)
			var price := int(layer.get("shop_price_pct", -1))
			if price < 0:
				errors.append("pacing layer %s shop_price_pct must be non-negative" % layer_id)
			var max_tier := int(layer.get("shop_max_tier", 0))
			if max_tier < 1 or max_tier > 5:
				errors.append("pacing layer %s shop_max_tier must be within 1..5" % layer_id)
			for anchor_value in layer.get("anchors", []):
				var anchor: Dictionary = anchor_value
				var template_id := str(anchor.get("template", ""))
				if not catalog.get("node_by_id", {}).has(template_id):
					errors.append("pacing layer %s anchor references unknown node %s" % [layer_id, template_id])
				if str(anchor.get("row", "")) not in ["mid", "pre_boss"]:
					errors.append("pacing layer %s anchor %s has unknown row" % [layer_id, template_id])
			for template_id_value in layer.get("pool", []):
				var pool_id := str(template_id_value)
				if not catalog.get("node_by_id", {}).has(pool_id):
					errors.append("pacing layer %s pool references unknown node %s" % [layer_id, pool_id])
	return errors


static func _validate_aptitude(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var data: Dictionary = catalog.get("aptitude", {})
	var base_map: Dictionary = data.get("stage_essence_base", {})
	for tier in ["low", "mid", "high", "peak", "nirvana"]:
		if not base_map.has(tier):
			errors.append("aptitude stage_essence_base missing %s" % tier)
	var pct_map: Dictionary = data.get("aptitude_pct", {})
	for aptitude_id in ["jia", "yi", "bing", "ding", "wu"]:
		if not pct_map.has(aptitude_id):
			errors.append("aptitude aptitude_pct missing %s" % aptitude_id)
	var rank_map: Dictionary = data.get("rank_tier", {})
	for rank in ["1", "2", "3", "4", "5"]:
		if not rank_map.has(rank):
			errors.append("aptitude rank_tier missing %s" % rank)
		elif not base_map.has(str(rank_map[rank])):
			errors.append("aptitude rank_tier references unknown tier %s" % rank_map[rank])
	for path_value in data.get("paths", []):
		var path: Dictionary = path_value
		var path_id := str(path.get("id", ""))
		if path_id.is_empty():
			errors.append("aptitude path missing id")
		for field in ["cost_lifespan", "cost_stone", "limit_per_run"]:
			if not _is_integral(path.get(field, null)) or int(path.get(field, 0)) < 1:
				errors.append("aptitude path %s.%s must be a positive integer" % [path_id, field])
		for node_kind_value in path.get("node_kinds", []):
			if not NODE_KIND_IDS.has(str(node_kind_value)):
				errors.append("aptitude path %s references unknown node kind %s" % [path_id, node_kind_value])
	return errors


static func _validate_first_run(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var cfg: Dictionary = catalog.get("first_run", {})
	if not _is_integral(cfg.get("seed", null)):
		errors.append("first_run seed must be an integer")
	var seen := {}
	for route_id_value in cfg.get("route_ids", []):
		var route_id := str(route_id_value)
		if seen.has(route_id):
			errors.append("first_run route_ids duplicates %s" % route_id)
		seen[route_id] = true
		if not catalog.get("node_by_id", {}).has(route_id):
			errors.append("first_run route_ids references missing node %s" % route_id)
	return errors


static func _validate_dialogue_templates(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var cfg: Dictionary = catalog.get("dialogue_templates", {})
	var responses: Variant = cfg.get("responses", null)
	if not responses is Dictionary:
		return ["dialogue_templates responses must be an object"]
	if not (responses as Dictionary).has("clarify"):
		errors.append("dialogue_templates responses missing clarify fallback")
	for intent_value in responses:
		var intent := str(intent_value)
		if not DIALOGUE_INTENT_IDS.has(intent):
			errors.append("dialogue_templates has unknown intent %s" % intent)
			continue
		var response: Variant = responses[intent_value]
		if not response is Dictionary or not DialogueGatewayScript.is_valid_response(response):
			errors.append("dialogue_templates response %s has invalid shape" % intent)
		elif str(response.get("intent", "")) != intent:
			errors.append("dialogue_templates response %s intent mismatch" % intent)
	return errors


static func _validate_names(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var names: Variant = catalog.get("names", null)
	if not names is Dictionary:
		return ["names must be an object"]
	for table_value in names:
		var table_name := str(table_value)
		var table: Variant = names[table_value]
		if not table is Dictionary:
			errors.append("names.%s must be an object" % table_name)
			continue
		for key_value in table:
			if str(key_value).is_empty() or not table[key_value] is String or str(table[key_value]).is_empty():
				errors.append("names.%s.%s must be a non-empty string" % [table_name, key_value])

	return errors


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
	for enemy_value in catalog.get("enemies", []):
		var enemy_entry: Dictionary = enemy_value
		var enemy_turn := int(enemy_entry.get("turn", 1))
		if enemy_turn < 1 or enemy_turn > 5:
			errors.append("enemy %s turn must be within 1..5" % enemy_entry.get("id", ""))
	var enemy_by_id: Dictionary = catalog.get("enemy_by_id", {})
	for node_value in catalog.get("nodes", []):
		var node: Dictionary = node_value
		# 同名/单数引用同样校验：战斗节点 enemy_kind 必须真实存在。
		var singular_kind := str(node.get("enemy_kind", ""))
		if not singular_kind.is_empty() and not (catalog.get("enemy_by_id", {}) as Dictionary).has(singular_kind):
			errors.append("node %s references unknown enemy %s" % [node.get("id", ""), singular_kind])
		var grants: Dictionary = node.get("ascension_grants", {})
		for grant_action_value in grants.keys():
			var grant_action := str(grant_action_value)
			var grant_flag := str(grants[grant_action_value])
			if not grant_flag in ["aperture_foundation", "heaven_earth_qi", "site", "protection", "external_interference"]:
				errors.append("node %s grants unknown ascension condition %s" % [node.get("id", ""), grant_flag])
			var choices: Array = node.get("choices", [])
			if not choices.has(grant_action):
				errors.append("node %s grants ascension condition on unknown action %s" % [node.get("id", ""), grant_action])
		if not node.has("enemy_kinds"):
			continue
		var enemy_kinds_value: Variant = node.get("enemy_kinds", [])
		if not enemy_kinds_value is Array or (enemy_kinds_value as Array).is_empty():
			errors.append("node %s enemy_kinds must be a non-empty array" % node.get("id", ""))
			continue
		var seen_enemy_ids := {}
		for enemy_id_value in enemy_kinds_value:
			var enemy_id := str(enemy_id_value)
			if not enemy_by_id.has(enemy_id):
				errors.append("node %s references unknown enemy %s" % [node.get("id", ""), enemy_id])
			if seen_enemy_ids.has(enemy_id):
				errors.append("node %s has duplicate enemy %s" % [node.get("id", ""), enemy_id])
			seen_enemy_ids[enemy_id] = true
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
		if str(recipe.get("kind", "")) == "advance":
			var adv_inputs: Array = recipe.get("input_gu_ids", [])
			if adv_inputs.size() != 1 or str(recipe.get("output_gu_id", "")) != str(adv_inputs[0]):
				errors.append("advance recipe %s must map one same-name gu onto itself" % recipe.get("id", ""))
		for rank_field in ["output_rank", "input_min_rank"]:
			var rank_value = recipe.get(rank_field, null)
			if rank_value != null and (not _is_integral(rank_value) or int(rank_value) < 1 or int(rank_value) > 5):
				errors.append("recipe %s %s must be an integer in 1..5" % [recipe.get("id", ""), rank_field])
		if recipe.has("default_unlocked") and not (recipe["default_unlocked"] is bool):
			errors.append("recipe %s default_unlocked must be a boolean" % recipe.get("id", ""))
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
	var loot_tables: Dictionary = catalog.get("loot_tables", {})
	var materials: Dictionary = loot_tables.get("materials", {})
	for material_id in materials:
		if int(materials[material_id].get("value", 0)) < 1:
			errors.append("material %s needs a positive value" % material_id)
	for recipe in catalog.get("refinement_recipes", []):
		for material_id_value in recipe.get("materials", {}):
			if not materials.has(str(material_id_value)):
				errors.append("recipe %s references unknown material %s" % [recipe.get("id", ""), material_id_value])
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
	if catalog.has("contracts"):
		errors.append_array(_validate_contracts(catalog.get("contracts", {})))
	if catalog.has("npcs"):
		errors.append_array(_validate_npcs(catalog.get("npcs", []), catalog.get("shop_offer_by_id", {})))
	if catalog.has("dda"):
		errors.append_array(_validate_dda(catalog.get("dda", {}), catalog.get("enemy_by_id", {})))
	if catalog.has("journal"):
		errors.append_array(_validate_journal(catalog.get("journal", {})))
	if catalog.has("debug"):
		var enabled_value: Variant = catalog.get("debug", {}).get("enabled", null)
		if not (enabled_value is bool):
			errors.append("debug.enabled must be a boolean")
	if catalog.has("first_run"):
		errors.append_array(_validate_first_run(catalog))
	if catalog.has("dialogue_templates"):
		errors.append_array(_validate_dialogue_templates(catalog))
	if catalog.has("names"):
		errors.append_array(_validate_names(catalog))
	errors.append_array(_validate_events(catalog))
	errors.append_array(_validate_pacing(catalog))
	errors.append_array(_validate_aptitude(catalog))

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
		var forced_rarity := str(tier.get("forced_rarity", ""))
		if not forced_rarity.is_empty():
			if not RARITY_IDS.has(forced_rarity):
				errors.append("loot tier %s has invalid forced rarity %s" % [tier_key, forced_rarity])
			elif (by_rarity.get(forced_rarity, []) as Array).is_empty():
				errors.append("loot tier %s forced rarity %s sits on an empty bucket" % [tier_key, forced_rarity])
		var cost_pool: Array = tier.get("cost_pool", [])
		var cost_positive_weight := false
		for cost_value in cost_pool:
			var cost: Dictionary = cost_value
			if not _is_integral(cost.get("weight", 1)) or int(cost.get("weight", 1)) < 0:
				errors.append("loot tier %s cost weight must be a non-negative integer" % tier_key)
				continue
			if int(cost.get("weight", 1)) > 0:
				cost_positive_weight = true
			match str(cost.get("kind", "")):
				"backlash":
					var curse_id := str(cost.get("curse_id", ""))
					if not curse_by_id.has(curse_id):
						errors.append("loot tier %s cost references unknown curse %s" % [tier_key, curse_id])
					if not _is_integral(cost.get("layers", 0)) or int(cost.get("layers", 0)) < 1:
						errors.append("loot tier %s backlash cost needs positive layers" % tier_key)
				"notoriety":
					if not _is_integral(cost.get("amount", 0)) or int(cost.get("amount", 0)) < 1:
						errors.append("loot tier %s notoriety cost needs a positive amount" % tier_key)
				_:
					errors.append("loot tier %s cost uses unknown cost kind %s" % [tier_key, cost.get("kind", "")])
		if not cost_pool.is_empty() and not cost_positive_weight:
			errors.append("loot tier %s cost_pool needs at least one positive weight" % tier_key)
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
		var raw_scavenge: Variant = tier.get("scavenge_recipe", "")
		var scavenge_ids: Array[String] = []
		if raw_scavenge is Array:
			for value in raw_scavenge:
				scavenge_ids.append(str(value))
		elif not str(raw_scavenge).is_empty():
			scavenge_ids.append(str(raw_scavenge))
		for scavenge_recipe in scavenge_ids:
			if not catalog.get("refinement_by_id", {}).has(scavenge_recipe):
				errors.append("loot tier %s references missing scavenge recipe %s" % [tier_key, scavenge_recipe])
	return errors


static func _is_data_driven_card_linked(gu: Dictionary, cards: Array) -> bool:
	for card in cards:
		if str(card.get("id", "")) == str(gu.get("card_blueprint_ids", [])[0]) \
				and (card.get("source_gu_ids", []) as Array).has(gu["id"]):
			return true
	return false


# N-candidate (night batch): NPC personal inventory schema guard — stock ids
# must resolve to real shop offers of a supported kind, without duplicates.
static func _validate_npcs(npcs: Array, shop_offer_by_id: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for npc_value in npcs:
		var npc: Dictionary = npc_value
		var npc_id := str(npc.get("id", ""))
		var stock: Array = npc.get("stock", [])
		var seen := {}
		for offer_id_value in stock:
			var offer_id := str(offer_id_value)
			if seen.has(offer_id):
				errors.append("npc %s stock duplicates offer %s" % [npc_id, offer_id])
			seen[offer_id] = true
			var offer: Dictionary = shop_offer_by_id.get(offer_id, {})
			if offer.is_empty():
				errors.append("npc %s stock references unknown offer %s" % [npc_id, offer_id])
				continue
			var kind := str(offer.get("kind", ""))
			if not kind in ["purchase", "soul_boost", "lifespan_deal", "barter"]:
				errors.append("npc %s stock offer %s has unsupported kind %s" % [npc_id, offer_id, kind])
	return errors


# R14.5/R14.6 (night batch) schema guard: ascending score bands within
# [0, max_score], sys:-prefixed markers, known enemy ids in swap pools,
# positive integer weights.
static func _validate_dda(cfg: Dictionary, enemy_by_id: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var max_score := int(cfg.get("max_score", 10))
	if max_score < 1:
		errors.append("dda max_score must be a positive integer")
	var previous := -1
	var bands: Array = cfg.get("bands", [])
	for band_index in bands.size():
		var band: Dictionary = bands[band_index]
		var min_score := int(band.get("min_score", 0))
		if min_score < 0 or min_score > max_score:
			errors.append("dda band %d min_score %d outside [0, %d]" % [band_index, min_score, max_score])
		if min_score <= previous:
			errors.append("dda band %d min_score must ascend strictly" % band_index)
		previous = min_score
		var marker := str(band.get("marker", ""))
		if not marker.is_empty() and not marker.begins_with("sys:"):
			errors.append("dda band %d marker %s must start with sys:" % [band_index, marker])
	var pools: Dictionary = cfg.get("enemy_swap_pools", {})
	for marker_value in pools:
		var marker := str(marker_value)
		if not marker.begins_with("sys:"):
			errors.append("dda swap pool key %s must start with sys:" % marker)
		for enemy_id_value in pools[marker]:
			if not enemy_by_id.has(str(enemy_id_value)):
				errors.append("dda swap pool %s references unknown enemy %s" % [marker, enemy_id_value])
	var weights: Dictionary = cfg.get("weights", {})
	for weight_value in weights.values():
		if not _is_integral(weight_value) or int(weight_value) < 1:
			errors.append("dda weights must be positive integers")
	# R14.6⑦ boss-local rules: known condition keys; intent must exist in some
	# boss enemy's phase pool (a rule pointing nowhere is a silent no-op).
	var boss_intent_ids := {}
	var boss_checked := false
	for enemy_value in enemy_by_id.values():
		var enemy: Dictionary = enemy_value
		if str(enemy.get("tier", "")) != "boss":
			continue
		boss_checked = true
		for phase_value in enemy.get("phases", []):
			var phase: Dictionary = phase_value
			for intent_value in phase.get("intents", []):
				boss_intent_ids[str((intent_value as Dictionary).get("id", ""))] = true
	for rule_value in cfg.get("boss_local", []):
		var rule: Dictionary = rule_value
		var when := str(rule.get("when", ""))
		if when != "many_curses":
			errors.append("dda boss_local rule has unknown condition %s" % when)
		var intent_id := str(rule.get("intent_id", ""))
		if boss_checked and not boss_intent_ids.has(intent_id):
			errors.append("dda boss_local intent %s not in any boss phase pool" % intent_id)
	return errors


# C1-min §16.13 schema guard: id uniqueness, closed rule-key whitelist,
# mutual-exclusion references, unlock shape and a positive contract cap.
static func _validate_contracts(cfg: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not _is_integral(cfg.get("contract_cap", null)) or int(cfg.get("contract_cap", 0)) < 1:
		errors.append("contracts contract_cap must be a positive integer")
	var entries: Array = cfg.get("entries", [])
	var seen_ids := {}
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var entry_id := str(entry.get("id", ""))
		if entry_id.is_empty():
			errors.append("contract entry missing id")
			continue
		if seen_ids.has(entry_id):
			errors.append("duplicate contract id %s" % entry_id)
		seen_ids[entry_id] = true
		for field in ["label", "desc"]:
			if str(entry.get(field, "")).is_empty():
				errors.append("contract %s missing %s" % [entry_id, field])
		for rule_value in entry.get("rules", []):
			var rule: Dictionary = rule_value
			if not CONTRACT_RULE_KEYS.has(str(rule.get("key", ""))):
				errors.append("contract %s uses unknown rule key %s" % [entry_id, rule.get("key", "")])
			if not _is_integral(rule.get("value", null)):
				errors.append("contract %s rule %s value must be an integer" % [entry_id, rule.get("key", "")])
		# Quality batch ③: player-visible desc numerals must state every rule
		# value (by magnitude), so the copy cannot drift from the config.
		# Numerals are standalone digit tokens: runs inside longer numbers
		# (e.g. "30" inside "130") do not count; extra numerals are allowed.
		var desc := str(entry.get("desc", ""))
		if not desc.is_empty():
			var token_regex := RegEx.new()
			token_regex.compile("(?<![0-9])[0-9]+(?![0-9])")
			var stated := {}
			for token_match in token_regex.search_all(desc):
				stated[int(token_match.get_string())] = true
			for rule_value in entry.get("rules", []):
				var rule: Dictionary = rule_value
				if not _is_integral(rule.get("value", null)):
					continue
				var magnitude := absi(int(rule["value"]))
				if not stated.has(magnitude):
					errors.append("contract %s desc lacks numeral %d for rule %s" % [entry_id, magnitude, rule.get("key", "")])
		var unlock: Dictionary = entry.get("unlock", {})
		var kind := str(unlock.get("kind", ""))
		if kind != "always" and kind != "ending":
			errors.append("contract %s has unknown unlock kind %s" % [entry_id, kind])
		elif kind == "ending":
			var endings: Array = unlock.get("endings", [])
			if endings.is_empty():
				errors.append("contract %s ending unlock needs endings" % entry_id)
			else:
				for ending_value in endings:
					if not ENDING_TYPE_IDS.has(str(ending_value)):
						errors.append("contract %s ending unlock lists unknown ending %s" % [entry_id, ending_value])
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var entry_id := str(entry.get("id", ""))
		if entry_id.is_empty():
			continue
		for excluded_value in entry.get("mutual_exclusive", []):
			var excluded := str(excluded_value)
			if excluded == entry_id:
				errors.append("contract %s mutual_exclusive must not reference itself" % entry_id)
			elif not seen_ids.has(excluded):
				errors.append("contract %s mutual_exclusive references unknown id %s" % [entry_id, excluded])
	return errors


# N1 §16.9 schema guard: unique ids, hall-layer enum, unlock shape and a
# closed route-marker whitelist aligned with MetaProgress._run_markers.
static func _validate_journal(cfg: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids := {}
	for entry_value in cfg.get("entries", []):
		var entry: Dictionary = entry_value
		var entry_id := str(entry.get("id", ""))
		if entry_id.is_empty():
			errors.append("journal entry missing id")
			continue
		if seen_ids.has(entry_id):
			errors.append("duplicate journal id %s" % entry_id)
		seen_ids[entry_id] = true
		for field in ["title", "text"]:
			if str(entry.get(field, "")).is_empty():
				errors.append("journal %s missing %s" % [entry_id, field])
		if not JOURNAL_LAYER_IDS.has(str(entry.get("layer", ""))):
			errors.append("journal %s has unknown layer %s" % [entry_id, entry.get("layer", "")])
		var unlock: Dictionary = entry.get("unlock", {})
		var kind := str(unlock.get("kind", ""))
		if kind != "always" and kind != "ending" and kind != "route":
			errors.append("journal %s has unknown unlock kind %s" % [entry_id, kind])
		elif kind == "ending":
			var endings: Array = unlock.get("endings", [])
			if endings.is_empty():
				errors.append("journal %s ending unlock needs endings" % entry_id)
			else:
				for ending_value in endings:
					if not ENDING_TYPE_IDS.has(str(ending_value)):
						errors.append("journal %s ending unlock lists unknown ending %s" % [entry_id, ending_value])
		elif kind == "route":
			var markers: Array = unlock.get("markers", [])
			if markers.is_empty():
				errors.append("journal %s route unlock needs markers" % entry_id)
			else:
				for marker_value in markers:
					if not JOURNAL_MARKER_IDS.has(str(marker_value)):
						errors.append("journal %s route unlock lists unknown marker %s" % [entry_id, marker_value])
	for ending_key in cfg.get("ending_texts", {}):
		if not ENDING_TYPE_IDS.has(str(ending_key)):
			errors.append("journal ending_texts lists unknown ending %s" % ending_key)
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
