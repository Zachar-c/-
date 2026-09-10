extends RefCounted

# W11 measure 3, atomic A5 (2026-09-10): the npc / social / contact /
# event / curse / contract / relic / reputation command family moved out
# of resolver.gd. Extracted verbatim - behavior unchanged. The travel /
# choose_action / ascension family joins this module in the A5b follow-up
# commit.
#
# Shared low-level helpers (_rejected/_accepted/_event) and cross-family
# helpers still owned by resolver (_finalize_if_dead / gain_notoriety /
# notoriety / service_use_count / service_limit / service_price_for /
# _can_gain_relic / _grant_lifespan_milestone, thin forwards) are reached
# via the global Resolver class name. resolver.gd preloads this script
# (one-way), so there is no preload cycle.

const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")
const ResolverHelpersScript = preload("res://scripts/domain/resolver_helpers.gd")
const ShopCommandRulesScript = preload("res://scripts/domain/shop_command_rules.gd")
const RefineCommandRulesScript = preload("res://scripts/domain/refine_command_rules.gd")


static func _resolve_contact(state: RunState, command: Dictionary, catalog: Dictionary = {}) -> Dictionary:
	var node_id := str(command.get("node_id", ""))
	# preview 会把 node_id 注入为实例 id（wenzhen_LxRxNx），catalog 里只有模板 id。
	# run 状态记录 current_node_template_id 作兜底，实例与模板两态都能定位。
	var template_id := str(state.current_node_template_id)
	if not template_id.is_empty():
		node_id = template_id
	# Contact approaches are node-generic: any contact template may be
	# approached; fight drills the node's own enemy_kind via start_battle.
	# neutral_wanderer keeps its legacy effect set unchanged (pinned by tests).
	var node_type := ""
	for node_value in catalog.get("nodes", []):
		if str((node_value as Dictionary).get("id", "")) == node_id:
			node_type = str((node_value as Dictionary).get("type", ""))
			break
	if node_id != "neutral_wanderer" and node_type != "contact":
		return Resolver._rejected(state, "unknown_contact")
	var approach := str(command.get("approach", ""))
	var known_facts := state.known_facts.duplicate()
	var node_flags := state.node_flags.duplicate(true)
	var before := {"stone": state.stone, "known_facts": state.known_facts, "node_flags": state.node_flags}
	var after := {"known_facts": known_facts, "node_flags": node_flags}
	var result := {"ok": true, "approach": approach}
	match approach:
		"deceive":
			ResolverHelpersScript.add_fact(known_facts, "wanderer_misdirected")
			after["stone"] = state.stone + 2
			result["reward"] = "stone"
		"negotiate":
			ResolverHelpersScript.add_fact(known_facts, "caravan_friendly_prices")
			result["reward"] = "caravan_discount"
		"retreat":
			if state.stone < 1:
				return Resolver._rejected(state, "insufficient_stone")
			ResolverHelpersScript.add_fact(known_facts, "wanderer_alerted")
			after["stone"] = state.stone - 1
		"fight":
			ResolverHelpersScript.add_fact(known_facts, "wanderer_challenged")
			result["start_battle"] = true
		_:
			return Resolver._rejected(state, "invalid_contact_approach")
	var next := state.append_event(Resolver._event(
		state,
		"contact_%s" % approach,
		before,
		after,
		"%s_%s" % [node_id, approach],
		node_id
	))
	return {"state": next, "result": result}


static func _can_gain_relic(state: RunState, catalog: Dictionary, relic_id: String) -> String:
	# Shared gate for every relic-granting path (direct gain and shop barter).
	# Returns "" when the relic may be gained, else the rejection reason.
	var relic: Dictionary = catalog.get("relic_by_id", {}).get(relic_id, {})
	if relic.is_empty():
		return "unknown_relic"
	if state.relic_ids.has(relic_id):
		return "relic_already_owned"
	# R4.9 imprint slots: the hard cap forces build trade-offs.
	if state.relic_ids.size() >= int(catalog.get("balance", {}).get("imprint_capacity", 4)):
		return "imprint_capacity_exceeded"
	# Order locked by brief: capacity rejection wins before the meta cap (R4.8).
	# R14.6 (night batch): system DDA markers (sys: keys) never count against
	# the player meta-rule cap.
	if str(relic.get("grade", "")) == "meta_rule" and DdaResolverScript.player_rule_count(state.meta_rules) >= int(catalog.get("balance", {}).get("meta_rule_cap", 2)):
		return "meta_rule_cap_reached"
	return ""


static func _gain_relic(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var relic_id := str(command.get("relic_id", ""))
	var blocked_reason := _can_gain_relic(state, catalog, relic_id)
	# R4.9 rejection is a pure no-op so callers can offer swaps without losing
	# state.
	if not blocked_reason.is_empty():
		return Resolver._rejected(state, blocked_reason)
	var meta_grade := str(catalog["relic_by_id"][relic_id].get("grade", "")) == "meta_rule"
	var relics := state.relic_ids.duplicate()
	relics.append(relic_id)
	var before := {"relic_ids": state.relic_ids}
	var after := {"relic_ids": relics}
	if meta_grade:
		var meta_rules := state.meta_rules.duplicate(true)
		meta_rules[relic_id] = true
		before["meta_rules"] = state.meta_rules
		after["meta_rules"] = meta_rules
	var next := state.append_event(Resolver._event(
		state,
		"gain_relic",
		before,
		after,
		"relic_gained",
		state.current_node_id,
		[relic_id]
	))
	var result := Resolver._accepted(next)
	if meta_grade:
		result = ResolverHelpersScript.append_result_feed(result, "meta_rule_recorded")
	return result


static func _accept_event(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var event: Dictionary = catalog.get("event_by_id", {}).get(str(command.get("event_id", "")), {})
	if event.is_empty():
		return Resolver._rejected(state, "unknown_event")
	var health_cost := int(event.get("health_cost", 0))
	if state.health <= health_cost:
		return Resolver._rejected(state, "insufficient_health")
	var flags := state.node_flags.duplicate(true)
	flags["pending_delayed_soul_drain"] = int(flags.get("pending_delayed_soul_drain", 0)) + int(event.get("delayed_soul_cost", 0))
	var next := state.append_event(Resolver._event(
		state,
		"accept_event",
		{"health": state.health, "node_flags": state.node_flags},
		{"health": state.health - health_cost, "node_flags": flags},
		"event_accepted_delayed_cost",
		state.current_node_id,
		[str(event["id"])]
	))
	var curse_id := str(event.get("curse_id", ""))
	if not curse_id.is_empty():
		next = CurseRegistryScript.gain_curse(next, curse_id, "event:%s" % str(event.get("id", "")))
	return Resolver._accepted(next)


static func _gain_curse_command(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var curse_id := str(command.get("curse_id", ""))
	if not catalog.get("curse_by_id", {}).has(curse_id):
		return Resolver._rejected(state, "unknown_curse")
	var source := str(command.get("source", "command"))
	return Resolver._accepted(CurseRegistryScript.gain_curse(state, curse_id, source))


# C1-min §16.13: opening contracts are global rule modifiers sworn exactly
# once, at the trailhead. The controller passes allowed_ids from the hall
# save; the domain validates shape (unknown/duplicate/cap/mutual exclusion)
# and applies the immediate hp_max cost behind a lethal precheck so swearing
# can never kill.
static func _swear_contracts(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if str(state.current_node_id) != "trailhead":
		return Resolver._rejected(state, "contracts_trailhead_only")
	if str(state.node_flags.get("contracts_sworn", "")) == "true":
		return Resolver._rejected(state, "contracts_already_sworn")
	var requested: Array[String] = []
	for value in command.get("ids", []):
		var id := str(value)
		if requested.has(id):
			return Resolver._rejected(state, "duplicate_contract")
		requested.append(id)
	if requested.is_empty():
		return Resolver._rejected(state, "no_contracts_selected")
	var cfg: Dictionary = catalog.get("contracts", {})
	var entry_by_id := _contract_entry_by_id(cfg)
	var allowed: Array = command.get("allowed_ids", [])
	for id in requested:
		if not entry_by_id.has(id):
			return Resolver._rejected(state, "unknown_contract")
		if not allowed.has(id):
			return Resolver._rejected(state, "contract_locked")
	if requested.size() > int(cfg.get("contract_cap", 0)):
		return Resolver._rejected(state, "contract_cap_exceeded")
	for id in requested:
		for excluded_value in entry_by_id[id].get("mutual_exclusive", []):
			if requested.has(str(excluded_value)):
				return Resolver._rejected(state, "contract_mutual_exclusive")
	var hp_delta := 0
	for id in requested:
		for rule_value in entry_by_id[id].get("rules", []):
			var rule: Dictionary = rule_value
			if str(rule.get("key", "")) == "hp_max_penalty":
				hp_delta += int(rule.get("value", 0))
	if state.max_health + hp_delta < 1:
		return Resolver._rejected(state, "contract_hp_max_lethal")
	var flags := state.node_flags.duplicate(true)
	flags["contracts_sworn"] = "true"
	var after := {"contracts": requested.duplicate(), "node_flags": flags}
	if hp_delta != 0:
		var new_max := state.max_health + hp_delta
		var cultivator := state.cultivator.duplicate(true)
		cultivator["max_health"] = new_max
		after["max_health"] = new_max
		# Clamping keeps health <= max and can never reach 0 because of the
		# lethal precheck above (new_max >= 1).
		after["health"] = mini(state.health, new_max)
		after["cultivator"] = cultivator
	var next := state.append_event(Resolver._event(
		state,
		"contracts_sworn",
		{"node_flags": state.node_flags},
		after,
		"contracts_sworn",
		state.current_node_id,
		requested.duplicate()
	))
	return Resolver._accepted(next)


static func _contract_entry_by_id(cfg: Dictionary) -> Dictionary:
	var indexed := {}
	for entry_value in cfg.get("entries", []):
		var entry: Dictionary = entry_value
		indexed[str(entry.get("id", ""))] = entry
	return indexed


# R9.3: the black-market paid service. Pricing uses the shared M5 uplift plus
# the Task 5 per-service use escalation, and consumes the same limit pool as
# remove_card/remove_imprint so all three services share one accounting family.
static func _remove_curse_command(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var curse_id := str(command.get("curse_id", ""))
	if not catalog.get("curse_by_id", {}).has(curse_id):
		return Resolver._rejected(state, "unknown_curse")
	if CurseRegistryScript.layers_of(state, curse_id) <= 0:
		return Resolver._rejected(state, "curse_not_present")
	if Resolver.service_use_count(state, "remove_curse") >= Resolver.service_limit(catalog, "remove_curse"):
		return Resolver._rejected(state, "service_limit_exceeded")
	var base := int(catalog["curse_by_id"][curse_id].get("removal_base_cost", 1))
	var cost := Resolver.service_price_for(catalog, state, "remove_curse", base)
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	var flags := state.node_flags.duplicate(true)
	RefineCommandRulesScript._bump_service_flag(flags, "remove_curse")
	var paid := state.append_event(Resolver._event(
		state,
		"svc_remove_curse",
		{"stone": state.stone, "node_flags": state.node_flags},
		{"stone": state.stone - cost, "node_flags": flags},
		"curse_removal_paid",
		state.current_node_id,
		[curse_id]
	))
	return Resolver._accepted(CurseRegistryScript.remove_curse(paid, curse_id))


static func apply_social_action(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var npc := _npc_by_id(catalog, str(command.get("npc_id", "")))
	if npc.is_empty():
		return Resolver._rejected(state, "unknown_npc")
	var action_id := str(command.get("action_id", ""))
	if not ["probe", "trade", "pressure", "deceive", "leave", "fight"].has(action_id):
		return Resolver._rejected(state, "invalid_social_action")
	var social: Dictionary = state.relations.get("caravan_steward", {
		"stance": "neutral",
		"round": 0,
		"evidence": [],
		"concession": 0,
		"threat": 0,
		"escape_route": false,
		"deadline_days": 3,
		"npc_disposition": "neutral",
	}).duplicate(true)
	var known_facts := state.known_facts.duplicate()
	var npc_reaction := _npc_reaction(state, npc)
	var reason := "caravan_%s" % action_id
	var surrendered := false
	match action_id:
		"probe":
			if not social["evidence"].has("ledger_evidence") and known_facts.has("ledger_evidence"):
				social["evidence"].append("ledger_evidence")
			social["npc_disposition"] = "examining"
			if not known_facts.has("procured_weakness"):
				known_facts.append("procured_weakness")
		"trade":
			if command.get("offer", "") == "ledger_evidence" and social["evidence"].has("ledger_evidence"):
				social["stance"] = "helpful"
				social["concession"] += 1
				if not known_facts.has("earth_vein_entry"):
					known_facts.append("earth_vein_entry")
				reason = "caravan_trade_evidence"
			else:
				return Resolver._rejected(state, "missing_trade_evidence")
		"pressure":
			social["threat"] += 1
			social["npc_disposition"] = npc_reaction
			surrendered = social["threat"] >= int(npc["will"]) + 1 and social["evidence"].size() > 0
		"leave":
			social["stance"] = "suspicious"
			social["escape_route"] = true
			if not known_facts.has("caravan_suspicion"):
				known_facts.append("caravan_suspicion")
		"deceive", "fight":
			social["npc_disposition"] = "guarded"
	social["round"] += 1
	social["deadline_days"] = maxi(0, int(social["deadline_days"]) - 1)
	if social["deadline_days"] == 0 and not known_facts.has("caravan_reinforcements_arrived"):
		known_facts.append("caravan_reinforcements_arrived")
	var relations := state.relations.duplicate(true)
	relations["caravan_steward"] = social
	var next := state.append_event(Resolver._event(
		state,
		"social_%s" % action_id,
		{"relations": state.relations, "known_facts": state.known_facts},
		{"relations": relations, "known_facts": known_facts},
		reason,
		state.current_node_id,
		["caravan_steward"]
	))
	return {
		"state": next,
		"result": {
			"ok": true,
			"action_id": action_id,
			"npc_reaction": npc_reaction,
			"surrendered": surrendered,
		},
	}


static func _npc_by_id(catalog: Dictionary, npc_id: String) -> Dictionary:
	for npc in catalog.get("npcs", []):
		if npc["id"] == npc_id:
			return npc
	return {}


# N-candidate (night batch): NPC personal inventories. npc_trade reuses the
# shop handlers verbatim after the NPC-scoped gates, so prices (price_for:
# inflation/contracts/notoriety), deck capacity, soul/lifespan deals and the
# seeded barter roll stay byte-identical with shop purchases.
static func _npc_trade(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var npc := _npc_by_id(catalog, str(command.get("npc_id", "")))
	if npc.is_empty():
		return Resolver._rejected(state, "unknown_npc")
	var offer_id := str(command.get("offer_id", ""))
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(offer_id, {})
	if offer.is_empty():
		return Resolver._rejected(state, "unknown_shop_offer")
	var stock: Array = npc.get("stock", [])
	if not stock.has(offer_id):
		return Resolver._rejected(state, "npc_stock_missing")
	if not _current_node_declares_npc(state, catalog, str(npc.get("id", "unknown"))):
		return Resolver._rejected(state, "npc_not_present")
	match str(offer.get("kind", "")):
		"purchase":
			return ShopCommandRulesScript._shop_purchase(state, {"offer_id": offer_id}, catalog)
		"soul_boost":
			return ShopCommandRulesScript._shop_soul_boost(state, {}, catalog, offer)
		"lifespan_deal":
			return ShopCommandRulesScript._shop_lifespan_deal(state, {"offer_id": offer_id}, catalog)
		"barter":
			return ShopCommandRulesScript._shop_barter(state, {"offer_id": offer_id, "input_instance_ids": command.get("input_instance_ids", [])}, catalog)
		_:
			return Resolver._rejected(state, "unknown_shop_offer")


static func _current_node_declares_npc(state: RunState, catalog: Dictionary, npc_id: String) -> bool:
	for node in catalog.get("nodes", []):
		if str(node.get("id", "")) == state.current_node_id:
			return str(node.get("npc_id", "")) == npc_id
	return false


static func _npc_reaction(state: RunState, npc: Dictionary) -> String:
	if state.injury >= 2:
		return npc["injury_reaction"]
	return "caution"


static func _grant_lifespan_milestone(state: RunState, catalog: Dictionary, milestone_id: String) -> RunState:
	var milestones: Dictionary = catalog.get("pacing", {}).get("lifespan_milestones", {})
	if not milestones.has(milestone_id):
		return state
	var amount := int(milestones[milestone_id])
	if amount <= 0:
		return state
	var cultivator := state.cultivator.duplicate(true)
	cultivator["lifespan"] = int(cultivator.get("lifespan", 0)) + amount
	return state.append_event(Resolver._event(
		state,
		"lifespan_milestone",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"lifespan_milestone_gained",
		state.current_node_id,
		[milestone_id]
	))


static func _record_boss_defeated(state: RunState, catalog: Dictionary) -> Dictionary:
	var flags := state.node_flags.duplicate(true)
	var already_defeated := str(flags.get("boss_defeated", "")) == "true"
	if not already_defeated:
		flags["boss_defeated"] = "true"
	var next := state.append_event(Resolver._event(
		state,
		"record_boss_defeated",
		{"node_flags": state.node_flags},
		{"node_flags": flags},
		"boss_defeated_recorded",
		state.current_node_id,
		[]
	))
	if not already_defeated:
		next = _grant_lifespan_milestone(next, catalog, "boss_defeated")
	return Resolver._accepted(next)


static func _record_neutral_npc_kill(state: RunState, catalog: Dictionary) -> Dictionary:
	var gains: Dictionary = catalog.get("reputation", {}).get("gains", {})
	return Resolver._accepted(Resolver.gain_notoriety(state, int(gains.get("kill_neutral_npc", 0)), "kill_neutral_npc"))


static func _wash_notoriety(state: RunState, catalog: Dictionary) -> Dictionary:
	if Resolver.notoriety(state) <= 0:
		return Resolver._rejected(state, "nothing_to_wash")
	var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
	var cost := int(effects.get("wash_lifespan_cost", 10))
	var reduce := int(effects.get("wash_reduce", 2))
	var lifespan := int(state.cultivator.get("lifespan", 0))
	if lifespan - cost < 1:
		return Resolver._rejected(state, "lifespan_trade_warning")
	var cultivator := state.cultivator.duplicate(true)
	cultivator["lifespan"] = lifespan - cost
	cultivator["notorious"] = maxi(0, Resolver.notoriety(state) - reduce)
	var next := state.append_event(Resolver._event(
		state,
		"wash_notoriety",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"notoriety_washed",
		state.current_node_id,
		[]
	))
	return Resolver._accepted(next)


