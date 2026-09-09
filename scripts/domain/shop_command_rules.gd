extends RefCounted

# W11 measure 3, atomic A3 (2026-09-10): the shop command family moved out
# of resolver.gd. Extracted verbatim - behavior unchanged.
#
# Shared low-level helpers (_accepted/_rejected/_event) and cross-family
# helpers (price_for / _can_gain_relic / _finalize_if_dead, which live in
# resolver.gd until the A5 social extraction) are reached via the global
# Resolver class name. resolver.gd preloads this script (one-way), so there
# is no preload cycle. APTITUDE_LADDER moved here with _raise_aptitude (its
# only consumer in the old file).

const EconomyRulesScript = preload("res://scripts/domain/economy_rules.gd")
const ShopRulesScript = preload("res://scripts/domain/shop_rules.gd")
const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const ResolverHelpersScript = preload("res://scripts/domain/resolver_helpers.gd")


const APTITUDE_LADDER := ["ding", "bing", "yi", "jia"]


## 统一裁定表：当前大层的黑市参数（货阶上限 / 价格乘数%）。
static func _current_shop_layer(state: RunState, catalog: Dictionary) -> int:
	var layer := clampi(int(state.current_node_layer), 1, 5)
	var layers_cfg: Dictionary = catalog.get("pacing", {}).get("layers", {})
	if layer == 0 or not layers_cfg.has(str(layer)):
		return 1
	return layer


static func shop_layer_price(catalog: Dictionary, state: RunState, base: int) -> int:
	var price := Resolver.price_for(catalog, state, base)
	var layers_cfg: Dictionary = catalog.get("pacing", {}).get("layers", {})
	var layer_cfg: Dictionary = layers_cfg.get(str(_current_shop_layer(state, catalog)), {})
	var pct := int(layer_cfg.get("shop_price_pct", 0))
	return price + int(price * pct / 100.0)


static func shop_max_tier(state: RunState, catalog: Dictionary) -> int:
	var layers_cfg: Dictionary = catalog.get("pacing", {}).get("layers", {})
	var layer_cfg: Dictionary = layers_cfg.get(str(_current_shop_layer(state, catalog)), {})
	return int(layer_cfg.get("shop_max_tier", 1))


static func _shop_purchase(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(str(command.get("offer_id", "")), {})
	var kind := str(offer.get("kind", ""))
	if kind == "soul_boost":
		return _shop_soul_boost(state, command, catalog, offer)
	if kind == "material_purchase":
		return _shop_material_purchase(state, offer, catalog)
	if kind == "recipe_unlock":
		return _shop_recipe_unlock(state, offer, catalog)
	if kind == "gu_fang_unlock":
		return _shop_gu_fang_unlock(state, offer, catalog)
	if kind == "resource_trade":
		return _shop_resource_trade(state, offer, catalog)
	if str(offer.get("kind", "")) != "purchase":
		return Resolver._rejected(state, "unknown_shop_offer")
	# 黑市分层上架：货阶高于当前大层时拒绝（层越深货越贵且稀有度越高）。
	if int(offer.get("tier", 1)) > _current_shop_layer(state, catalog):
		return Resolver._rejected(state, "shop_tier_locked")
	var cost := shop_layer_price(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	var instance_id := RunState.next_gu_instance_id(instances)
	instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": str(offer["gu_id"]),
		"state": "refined",
	}
	stored.append(instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var next := state.append_event(Resolver._event(
		state,
		"shop_purchase",
		{"stone": state.stone, "gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		{"stone": state.stone - cost, "gu_instances": instances, "cave_aperture": aperture},
		"shop_purchase_completed",
		state.current_node_id,
		[str(offer["gu_id"])]
	))
	next.sync_legacy_gu_projections()
	return Resolver._accepted(next)


static func _shop_material_purchase(state: RunState, offer: Dictionary, catalog: Dictionary) -> Dictionary:
	var cost := shop_layer_price(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	var material_id := str(offer.get("material_id", ""))
	var materials := state.materials.duplicate(true)
	materials[material_id] = int(materials.get(material_id, 0)) + 1
	var next := state.append_event(Resolver._event(state, "shop_purchase", {"stone": state.stone, "materials": state.materials}, {"stone": state.stone - cost, "materials": materials}, "shop_material_purchase_completed", state.current_node_id, [material_id]))
	next.stone = state.stone - cost
	next.materials = materials
	return Resolver._accepted(next)


## D1b 古方直购：持有即知产物（预检揭示），免未知损失。
static func _shop_gu_fang_unlock(state: RunState, offer: Dictionary, catalog: Dictionary) -> Dictionary:
	var gu_id := str(offer.get("gu_id", ""))
	if not catalog.get("gu_by_id", {}).has(gu_id):
		return Resolver._rejected(state, "unknown_gu")
	if state.global_codex_ids.has(gu_id):
		return Resolver._rejected(state, "gu_fang_already_unlocked")
	var cost := shop_layer_price(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	var codex := state.global_codex_ids.duplicate()
	codex.append(gu_id)
	var next := state.append_event(Resolver._event(state, "shop_gu_fang_unlocked", {"stone": state.stone, "global_codex_ids": state.global_codex_ids}, {"stone": state.stone - cost, "global_codex_ids": codex}, "shop_gu_fang_unlock_completed", state.current_node_id, [gu_id]))
	next.stone = state.stone - cost
	next.global_codex_ids = codex
	return Resolver._accepted(next)


static func _shop_recipe_unlock(state: RunState, offer: Dictionary, catalog: Dictionary) -> Dictionary:
	var recipe_id := str(offer.get("recipe_id", ""))
	if state.global_codex_ids.has(recipe_id):
		return Resolver._rejected(state, "recipe_already_unlocked")
	var cost := shop_layer_price(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	var codex := state.global_codex_ids.duplicate()
	codex.append(recipe_id)
	var next := state.append_event(Resolver._event(state, "shop_recipe_unlocked", {"stone": state.stone, "global_codex_ids": state.global_codex_ids}, {"stone": state.stone - cost, "global_codex_ids": codex}, "shop_recipe_unlock_completed", state.current_node_id, [recipe_id]))
	next.stone = state.stone - cost
	next.global_codex_ids = codex
	return Resolver._accepted(next)


static func _shop_soul_boost(state: RunState, _command: Dictionary, catalog: Dictionary, offer: Dictionary) -> Dictionary:
	var cost := Resolver.price_for(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	var soul := int(state.cultivator.get("soul", 0))
	var soul_max := int(state.cultivator.get("soul_max", soul))
	if soul >= soul_max:
		return Resolver._rejected(state, "soul_at_max")
	var soul_after := soul + int(offer.get("soul_gain", 1))
	var next := state.append_event(Resolver._event(
		state,
		"shop_purchase",
		{"stone": state.stone, "soul": soul},
		{"stone": state.stone - cost, "soul": soul_after},
		"shop_soul_pill",
		state.current_node_id,
		["soul_pill"]
	))
	next.stone = state.stone - cost
	next.cultivator["soul"] = soul_after
	return Resolver._accepted(next)


static func _shop_resource_trade(state: RunState, offer: Dictionary, _catalog: Dictionary) -> Dictionary:
	# 门禁与数值结算在 EconomyRules.resource_trade_plan（T1.2 行数门限）。
	var plan := EconomyRulesScript.resource_trade_plan(offer, state.cultivator, int(state.health), int(state.max_health), state.node_flags)
	if plan.has("error"):
		return Resolver._rejected(state, str(plan["error"]))
	var offer_id := str(offer.get("id", ""))
	var next := state.append_event(Resolver._event(
		state,
		"shop_resource_trade",
		{"cultivator": state.cultivator.duplicate(true), "health": int(state.health), "max_health": int(state.max_health), "node_flags": state.node_flags},
		plan,
		"shop_resource_trade_completed",
		state.current_node_id,
		[offer_id]
	))
	next.cultivator = plan["cultivator"]
	next.health = int(plan["health"])
	next.max_health = int(plan["max_health"])
	next.node_flags = (plan["node_flags"] as Dictionary).duplicate(true)
	return Resolver._accepted(next)


static func _raise_aptitude(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var paths: Array = catalog.get("aptitude", {}).get("paths", [])
	if paths.is_empty():
		return Resolver._rejected(state, "no_aptitude_path")
	var path: Dictionary = paths[0]
	var node_id := str(command.get("node_id", state.current_node_id))
	var node_kind := ""
	for node in catalog.get("nodes", []):
		if str(node.get("id", "")) == node_id:
			node_kind = str(node.get("type", ""))
			break
	if not (path.get("node_kinds", []) as Array).has(node_kind):
		return Resolver._rejected(state, "aptitude_path_unavailable")
	if str(state.node_flags.get("aptitude_raised", "")) == "true":
		return Resolver._rejected(state, "aptitude_raised_once")
	if str(state.aptitude) == "jia":
		return Resolver._rejected(state, "aptitude_at_peak")
	var lifespan_cost := int(path.get("cost_lifespan", 0))
	var stone_cost := int(path.get("cost_stone", 0))
	var lifespan := int(state.cultivator.get("lifespan", 0))
	# Deaths must stay predictable: paying lifespan down to zero is rejected.
	if lifespan - lifespan_cost < 1:
		return Resolver._rejected(state, "lifespan_trade_warning")
	if state.stone < stone_cost:
		return Resolver._rejected(state, "insufficient_stone")
	var ladder: Array = APTITUDE_LADDER
	var index := ladder.find(str(state.aptitude))
	var raised := str(ladder[mini(ladder.size() - 1, index + 1)])
	var flags := state.node_flags.duplicate(true)
	flags["aptitude_raised"] = "true"
	var next := state.append_event(Resolver._event(
		state,
		"raise_aptitude",
		{"aptitude": state.aptitude, "lifespan": lifespan, "stone": state.stone},
		{"aptitude": raised, "lifespan": lifespan - lifespan_cost, "stone": state.stone - stone_cost},
		"aptitude_raised",
		node_id,
		[raised]
	))
	next.aptitude = raised
	next.cultivator["lifespan"] = lifespan - lifespan_cost
	next.node_flags = flags
	next.cave_aperture["essence_max"] = EssenceCapacityScript.essence_max(next, catalog)
	return Resolver._accepted(next)


static func _shop_lifespan_deal(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(str(command.get("offer_id", "")), {})
	if str(offer.get("kind", "")) != "lifespan_deal":
		return Resolver._rejected(state, "unknown_shop_offer")
	var cost := int(offer.get("lifespan_cost", 0))
	var lifespan := int(state.cultivator.get("lifespan", 0))
	# Trade deaths must be predictable: paying to zero is rejected up front.
	if lifespan - cost < 1:
		return Resolver._rejected(state, "lifespan_trade_warning")
	var cultivator := state.cultivator.duplicate(true)
	cultivator["lifespan"] = lifespan - cost
	var next := state.append_event(Resolver._event(
		state,
		"shop_lifespan_deal",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"shop_lifespan_deal_paid",
		state.current_node_id,
		[str(offer["gu_id"])]
	))
	return Resolver._finalize_if_dead(next)


static func _shop_barter(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(str(command.get("offer_id", "")), {})
	var plan := ShopRulesScript.barter_plan(state, command, offer, func(relic_id: String):
		var reason := Resolver._can_gain_relic(state, catalog, relic_id)
		return {"reason": reason, "grade": str(catalog.get("relic_by_id", {}).get(relic_id, {}).get("grade", ""))})
	if plan.has("error"):
		return Resolver._rejected(state, str(plan["error"]))
	var selected: Array = plan["selected"]
	var chosen: Dictionary = plan["chosen"]
	var before := {"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture, "relic_ids": state.relic_ids}
	var after := {"gu_instances": plan["gu_instances"], "cave_aperture": plan["cave_aperture"], "relic_ids": plan["relic_ids"]}
	if plan["meta_rules"] != state.meta_rules:
		before["meta_rules"] = state.meta_rules
		after["meta_rules"] = plan["meta_rules"]
	var next := state.append_event(Resolver._event(state, "shop_barter", before, after, "shop_barter_resolved", state.current_node_id, [str(chosen.get("id", ""))]))
	next.gu_instances = plan["gu_instances"]
	next.cave_aperture = plan["cave_aperture"]
	next.relic_ids = plan["relic_ids"]
	next.meta_rules = plan["meta_rules"]
	next.sync_legacy_gu_projections()
	var result := Resolver._accepted(next)
	result["outcome"] = str(chosen.get("id", ""))
	for feed_value in plan["result_feeds"]:
		result = ResolverHelpersScript.append_result_feed(result, str(feed_value))
	return result
