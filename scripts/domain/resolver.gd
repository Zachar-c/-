class_name Resolver
extends RefCounted

# ponytail: 上限=行数门限 2430 仅剩个位数余量；升级触发=下一个功能撞门限时把 _shop_barter 或 rest 簇迁入独立模块（先例：resource_trade_plan -> economy_rules.gd）。


const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")
const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")
const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const InheritanceClaimRulesScript = preload("res://scripts/domain/inheritance_claim_rules.gd")
const SynthesisRulesScript = preload("res://scripts/domain/synthesis_rules.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const EconomyRulesScript = preload("res://scripts/domain/economy_rules.gd")
const ShopRulesScript = preload("res://scripts/domain/shop_rules.gd")
const ResolverHelpersScript = preload("res://scripts/domain/resolver_helpers.gd")
const RestRulesScript = preload("res://scripts/domain/rest_rules.gd")
const ShopCommandRulesScript = preload("res://scripts/domain/shop_command_rules.gd")
const RefineCommandRulesScript = preload("res://scripts/domain/refine_command_rules.gd")
const RunCommandsScript = preload("res://scripts/domain/run_command_rules.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")
# GuBalance 为 class_name 静态公式模块，直接按全局类名调用。


# R4.8: meta-rule grade imprints are rule changers; cap per run lives in deck.json.
# Removal service base prices (Task 5, R6.8) live in deck.json.

# Forced drop of a can_direct_drop=false gu attaches this configured curse.
const FORCED_DROP_CURSE_ID := "gu_erosion"


## 公开价格 API 转发（W11 A3）：实现迁至 shop_command_rules.gd。
## 外部调用点（snapshot_builder/acceptance_driver/测试）经 ResolverScript 引用，
## 签名不变，仅加一行转发。
static func shop_layer_price(catalog: Dictionary, state: RunState, base: int) -> int:
	return ShopCommandRulesScript.shop_layer_price(catalog, state, base)


static func shop_max_tier(state: RunState, catalog: Dictionary) -> int:
	return ShopCommandRulesScript.shop_max_tier(state, catalog)


## 公开 API 转发（W11 A4）：实现迁至 refine_command_rules.gd。
## 外部调用点（action_preview_service / snapshot_builder / 测试）经
## ResolverScript 引用，签名不变，仅加一行转发。
static func recipe_unlocked(state: RunState, recipe: Dictionary) -> bool:
	return RefineCommandRulesScript.recipe_unlocked(state, recipe)


static func scavenge_pending_recipes(state: RunState, catalog: Dictionary) -> Array[String]:
	return RefineCommandRulesScript.scavenge_pending_recipes(state, catalog)


static func service_use_count(state: RunState, service_id: String) -> int:
	return RefineCommandRulesScript.service_use_count(state, service_id)


static func service_limit(catalog: Dictionary, service_id: String) -> int:
	return RefineCommandRulesScript.service_limit(catalog, service_id)


static func service_price_for(catalog: Dictionary, state: RunState, service_id: String, base: int) -> int:
	return RefineCommandRulesScript.service_price_for(catalog, state, service_id, base)


## 跨族桥接（W11 A3/A4）：rest_rules ↔ refine_command_rules 互不 preload
## （避免循环），均经 Resolver 转发。rest 依赖的 refine 移除链与 refine
## 依赖的 rest 类门禁在此薄转发。
static func _upgrade_card(state: RunState, command: Dictionary) -> Dictionary:
	return RefineCommandRulesScript._upgrade_card(state, command)


static func _cursed_drop_block(state: RunState, catalog: Dictionary, definition_id: String) -> Dictionary:
	return RefineCommandRulesScript._cursed_drop_block(state, catalog, definition_id)


static func _destroyed_gu_payload(state: RunState, instance_id: String, extracted: Dictionary = {}) -> Dictionary:
	return RefineCommandRulesScript._destroyed_gu_payload(state, instance_id, extracted)


static func _is_rest_class_node(catalog: Dictionary, node_id: String) -> bool:
	return RestRulesScript._is_rest_class_node(catalog, node_id)


const BODY_IMPRINTS := {
	"iron_bone": {
		"facts": ["iron_bone_defense", "iron_bone_stealth_drawback"],
		"reason": "body_imprint_stealth_drawback",
	},
	"ice_skin": {
		"facts": ["ice_skin_cold_resistance", "ice_skin_cold_injury"],
		"injury": 1,
		"reason": "body_imprint_injury_cost",
	},
	"three_watch": {
		"facts": ["three_watch_vigilance"],
		"lifespan_debt": 1,
		"reason": "body_imprint_cost",
	},
}

const OPPORTUNITY_TYPES := ["gu", "information", "service", "favor", "escape_condition"]

const STANDARD_ACTIONS := [
	"accept", "ally", "buy_information", "claim", "cross", "deceive", "fight", "harvest",
	"inspect", "leave", "lure", "meditate", "open", "prepare", "retreat", "scout",
	"scheme", "take_imprint", "trade", "withdraw", "work",
	"claim_recon", "claim_token",
]


static func apply(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if state.is_terminal():
		return _rejected(state, "terminal_run")
	var handler: Variant = _handler_for(str(command.get("type", "")))
	if handler == null:
		return _rejected(state, "unsupported_command")
	return handler.call(state, command, catalog)


static var _dispatch: Dictionary = {}


static func _handler_for(command_type: String) -> Variant:
	if _dispatch.is_empty():
		_dispatch = {
			"travel": func(state, command, catalog): return _travel(state, command, catalog),
			"resolve_contact": func(state, command, catalog): return _resolve_contact(state, command, catalog),
			"complete_node": func(state, command, _catalog): return _complete_node(state, command),
			"buy_gu": func(state, command, catalog): return RefineCommandRulesScript._buy_gu(state, command, catalog),
			"sell_gu": func(state, command, catalog): return RefineCommandRulesScript._sell_gu(state, command, catalog),
			"exchange_gu": func(state, command, catalog): return RefineCommandRulesScript._exchange_gu(state, command, catalog),
			"refine_gu": func(state, command, catalog):
				var refined := RefineCommandRulesScript._refine_gu(state, command, catalog)
				if bool(refined["result"].get("ok", false)):
					refined["state"] = RestRulesScript._consume_rest_visit_if_rest_class(refined["state"], catalog)
				return refined,
			"refine_free_pair": func(state, command, catalog):
				var paired := SynthesisRulesScript.execute(state, catalog, str(command.get("main_instance_id", "")), str(command.get("partner_instance_id", "")))
				if bool(paired["result"].get("ok", false)):
					paired["state"] = RestRulesScript._consume_rest_visit_if_rest_class(paired["state"], catalog)
				return paired,
			"cultivate_rank_two": func(state, _command, catalog):
				var cultivated := RefineCommandRulesScript._cultivate_rank_two(state, catalog)
				if bool(cultivated["result"].get("ok", false)):
					cultivated["state"] = RestRulesScript._consume_rest_visit_if_rest_class(cultivated["state"], catalog)
				return cultivated,
			"settle_feeding": func(state, _command, catalog): return RefineCommandRulesScript._settle_feeding(state, catalog),
			"settle_node_feeding": func(state, _command, catalog): return RefineCommandRulesScript._settle_node_feeding(state, catalog),
			"disable_card": func(state, command, _catalog): return RefineCommandRulesScript._disable_card(state, command),
			"upgrade_card": func(state, command, _catalog): return RefineCommandRulesScript._upgrade_card(state, command),
			"copy_card": func(state, command, _catalog): return RefineCommandRulesScript._copy_card(state, command),
			"destroy_gu": func(state, command, catalog): return RefineCommandRulesScript._destroy_gu(state, command, catalog),
			"remove_card": func(state, command, catalog): return RefineCommandRulesScript._remove_card_command(state, command, catalog),
			"remove_imprint": func(state, command, catalog): return RefineCommandRulesScript._remove_imprint_command(state, command, catalog),
			"spend_lifespan": func(state, command, _catalog): return _spend_lifespan(state, command),
			"accept_debt": func(state, _command, catalog): return _accept_debt(state, catalog),
			"use_gu": func(state, command, catalog): return _use_gu(state, command, catalog),
			"buy_opportunity": func(state, command, _catalog): return _buy_opportunity(state, command),
			"take_body_imprint": func(state, command, _catalog): return _take_body_imprint(state, command),
			"choose_action": func(state, command, catalog): return _choose_action(state, command, catalog),
			"retreat": func(state, _command, _catalog): return _retreat(state),
			"attempt_ascension": func(state, command, _catalog): return _attempt_ascension(state, command),
			"gain_relic": func(state, command, catalog): return _gain_relic(state, command, catalog),
			"shop_purchase": func(state, command, catalog): return ShopCommandRulesScript._shop_purchase(state, command, catalog),
			"shop_lifespan_deal": func(state, command, catalog): return ShopCommandRulesScript._shop_lifespan_deal(state, command, catalog),
			"shop_barter": func(state, command, catalog): return ShopCommandRulesScript._shop_barter(state, command, catalog),
			"npc_trade": func(state, command, catalog): return _npc_trade(state, command, catalog),
			"scavenge": func(state, command, catalog): return RefineCommandRulesScript._scavenge(state, command, catalog),
			"sell_material": func(state, command, catalog): return RefineCommandRulesScript._sell_material(state, command, catalog),
			"use_material": func(state, command, catalog): return RefineCommandRulesScript._use_material(state, command, catalog),
			"raise_aptitude": func(state, command, catalog): return ShopCommandRulesScript._raise_aptitude(state, command, catalog),
			"record_neutral_npc_kill": func(state, _command, catalog): return _record_neutral_npc_kill(state, catalog),
			"wash_notoriety": func(state, _command, catalog): return _wash_notoriety(state, catalog),
			"record_boss_defeated": func(state, _command, catalog): return _record_boss_defeated(state, catalog),
			"record_layer_boss_defeated": func(state, command, catalog): return _record_layer_boss_defeated(state, command, catalog),
			"rest": func(state, command, catalog): return RestRulesScript._rest(state, command, catalog),
			"gain_force_power": func(state, command, catalog): return _gain_force_power(state, command, catalog),
			"accept_event": func(state, command, catalog): return _accept_event(state, command, catalog),
			"gain_curse": func(state, command, catalog): return _gain_curse_command(state, command, catalog),
			"remove_curse": func(state, command, catalog): return _remove_curse_command(state, command, catalog),
			"swear_contracts": func(state, command, catalog): return _swear_contracts(state, command, catalog),
			# T9.2 v2 command family - thin dispatch to RunCommands (rules live
			# in the phase 1-8 modules; V1 battle path untouched, switch at T10.1-6).
			"confirm_core": func(state, command, catalog): return RunCommandsScript.confirm_core(state, command, catalog),
			"replace_core": func(state, command, catalog): return RunCommandsScript.replace_core(state, command, catalog),
			"feed_instance": func(state, command, catalog): return RunCommandsScript.feed_instance(state, command, catalog),
			"settle_layer": func(state, command, catalog): return RunCommandsScript.settle_layer(state, command, catalog),
			"collect_surviving": func(state, command, catalog): return RunCommandsScript.collect_surviving(state, command, catalog),
			"release_gu": func(state, command, catalog): return RunCommandsScript.release_gu(state, command, catalog),
			"sell_info": func(state, command, catalog): return RunCommandsScript.sell_info(state, command, catalog),
			"enact": func(state, command, catalog): return RunCommandsScript.enact(state, command, catalog),
			"dodge": func(state, command, catalog): return RunCommandsScript.dodge(state, command, catalog),
			"grapple": func(state, command, catalog): return RunCommandsScript.grapple(state, command, catalog),
			"respond": func(state, command, catalog): return RunCommandsScript.respond(state, command, catalog),
			"refine_up_material": func(state, command, catalog): return RunCommandsScript.refine_up_material(state, command, catalog),
			"bloodlet": func(state, command, catalog): return RunCommandsScript.bloodlet(state, command, catalog),
			"absorb_soul": func(state, command, catalog): return RunCommandsScript.absorb_soul(state, command, catalog),
		}
	return _dispatch.get(command_type, null)


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
		return _rejected(state, "unknown_contact")
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
				return _rejected(state, "insufficient_stone")
			ResolverHelpersScript.add_fact(known_facts, "wanderer_alerted")
			after["stone"] = state.stone - 1
		"fight":
			ResolverHelpersScript.add_fact(known_facts, "wanderer_challenged")
			result["start_battle"] = true
		_:
			return _rejected(state, "invalid_contact_approach")
	var next := state.append_event(_event(
		state,
		"contact_%s" % approach,
		before,
		after,
		"%s_%s" % [node_id, approach],
		node_id
	))
	return {"state": next, "result": result}


static func _complete_node(state: RunState, command: Dictionary) -> Dictionary:
	var node_id := str(command.get("node_id", state.current_node_id))
	if node_id.is_empty() or node_id != state.current_node_id:
		return _rejected(state, "invalid_node_completion")
	if state.node_flags.has(node_id):
		return _accepted(state)
	var flags := state.node_flags.duplicate(true)
	flags[node_id] = str(command.get("outcome", "completed"))
	# 真元是节点内资源（2026-08-28 设计点）：节点完成即回满——跨节点不
	# 携带消耗，真元永远是「本节点的预算」。
	var next := state.append_event(_event(
		state,
		"complete_node",
		{"node_flags": state.node_flags, "essence": state.essence},
		{"node_flags": flags, "essence": state.essence_capacity},
		"node_completed",
		node_id
	))
	next.essence = next.essence_capacity
	next.cave_aperture["essence"] = next.essence_capacity
	return _accepted(next)



static func _spend_lifespan(state: RunState, command: Dictionary) -> Dictionary:
	var amount := int(command.get("amount", 0))
	if amount <= 0:
		return _rejected(state, "invalid_lifespan_cost")
	var cultivator := state.cultivator.duplicate(true)
	cultivator["lifespan"] = maxi(0, int(cultivator.get("lifespan", 0)) - amount)
	var next := state.append_event(_event(
		state,
		"spend_lifespan",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"lifespan_spent",
		state.current_node_id
	))
	return _finalize_if_dead(next)


static func _finalize_if_dead(state: RunState) -> Dictionary:
	if state.health > 0 and int(state.cultivator.get("lifespan", 0)) > 0 and int(state.cultivator.get("soul", 0)) > 0:
		return _accepted(state)
	return _accepted(state.finalize_death())


static func _accept_debt(state: RunState, _catalog: Dictionary) -> Dictionary:
	if state.current_node_id != "stage_one_ledger":
		return _rejected(state, "not_stage_ledger")
	if state.known_facts.has("caravan_favor_debt"):
		return _rejected(state, "debt_already_accepted")
	var facts := _facts_with(state, "caravan_favor_debt")
	var flags := state.node_flags.duplicate(true)
	flags["stage_one_ledger"] = "debt"
	var next := state.append_event(_event(
		state,
		"accept_debt",
		{"known_facts": state.known_facts, "node_flags": state.node_flags},
		{"known_facts": facts, "node_flags": flags},
		"caravan_feeding_debt",
		state.current_node_id
	))
	return _accepted(next)



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
		return _rejected(state, blocked_reason)
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
	var next := state.append_event(_event(
		state,
		"gain_relic",
		before,
		after,
		"relic_gained",
		state.current_node_id,
		[relic_id]
	))
	var result := _accepted(next)
	if meta_grade:
		result = ResolverHelpersScript.append_result_feed(result, "meta_rule_recorded")
	return result


static func _accept_event(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var event: Dictionary = catalog.get("event_by_id", {}).get(str(command.get("event_id", "")), {})
	if event.is_empty():
		return _rejected(state, "unknown_event")
	var health_cost := int(event.get("health_cost", 0))
	if state.health <= health_cost:
		return _rejected(state, "insufficient_health")
	var flags := state.node_flags.duplicate(true)
	flags["pending_delayed_soul_drain"] = int(flags.get("pending_delayed_soul_drain", 0)) + int(event.get("delayed_soul_cost", 0))
	var next := state.append_event(_event(
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
	return _accepted(next)


static func _gain_curse_command(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var curse_id := str(command.get("curse_id", ""))
	if not catalog.get("curse_by_id", {}).has(curse_id):
		return _rejected(state, "unknown_curse")
	var source := str(command.get("source", "command"))
	return _accepted(CurseRegistryScript.gain_curse(state, curse_id, source))


# C1-min §16.13: opening contracts are global rule modifiers sworn exactly
# once, at the trailhead. The controller passes allowed_ids from the hall
# save; the domain validates shape (unknown/duplicate/cap/mutual exclusion)
# and applies the immediate hp_max cost behind a lethal precheck so swearing
# can never kill.
static func _swear_contracts(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if str(state.current_node_id) != "trailhead":
		return _rejected(state, "contracts_trailhead_only")
	if str(state.node_flags.get("contracts_sworn", "")) == "true":
		return _rejected(state, "contracts_already_sworn")
	var requested: Array[String] = []
	for value in command.get("ids", []):
		var id := str(value)
		if requested.has(id):
			return _rejected(state, "duplicate_contract")
		requested.append(id)
	if requested.is_empty():
		return _rejected(state, "no_contracts_selected")
	var cfg: Dictionary = catalog.get("contracts", {})
	var entry_by_id := _contract_entry_by_id(cfg)
	var allowed: Array = command.get("allowed_ids", [])
	for id in requested:
		if not entry_by_id.has(id):
			return _rejected(state, "unknown_contract")
		if not allowed.has(id):
			return _rejected(state, "contract_locked")
	if requested.size() > int(cfg.get("contract_cap", 0)):
		return _rejected(state, "contract_cap_exceeded")
	for id in requested:
		for excluded_value in entry_by_id[id].get("mutual_exclusive", []):
			if requested.has(str(excluded_value)):
				return _rejected(state, "contract_mutual_exclusive")
	var hp_delta := 0
	for id in requested:
		for rule_value in entry_by_id[id].get("rules", []):
			var rule: Dictionary = rule_value
			if str(rule.get("key", "")) == "hp_max_penalty":
				hp_delta += int(rule.get("value", 0))
	if state.max_health + hp_delta < 1:
		return _rejected(state, "contract_hp_max_lethal")
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
	var next := state.append_event(_event(
		state,
		"contracts_sworn",
		{"node_flags": state.node_flags},
		after,
		"contracts_sworn",
		state.current_node_id,
		requested.duplicate()
	))
	return _accepted(next)


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
		return _rejected(state, "unknown_curse")
	if CurseRegistryScript.layers_of(state, curse_id) <= 0:
		return _rejected(state, "curse_not_present")
	if service_use_count(state, "remove_curse") >= service_limit(catalog, "remove_curse"):
		return _rejected(state, "service_limit_exceeded")
	var base := int(catalog["curse_by_id"][curse_id].get("removal_base_cost", 1))
	var cost := service_price_for(catalog, state, "remove_curse", base)
	if state.stone < cost:
		return _rejected(state, "insufficient_stone")
	var flags := state.node_flags.duplicate(true)
	RefineCommandRulesScript._bump_service_flag(flags, "remove_curse")
	var paid := state.append_event(_event(
		state,
		"svc_remove_curse",
		{"stone": state.stone, "node_flags": state.node_flags},
		{"stone": state.stone - cost, "node_flags": flags},
		"curse_removal_paid",
		state.current_node_id,
		[curse_id]
	))
	return _accepted(CurseRegistryScript.remove_curse(paid, curse_id))



static func _travel(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var node_id := str(command.get("node_id", ""))
	if node_id.is_empty():
		return _rejected(state, "missing_node_id")
	# R8.1 hard choice (P2a B generalized to every type=="rest" node): entering
	# a rest node commits the player to exactly one benefit; leaving without
	# consuming the visit is refused (skip only means never entering the node).
	# E3a 三选一（规格 §4）：门禁统一覆盖休息类（rest/refinement/cultivation）。
	# 节点已被 complete_node 写入完结标记（left/abandoned/completed 等非 used
	# outcome）时视为探访已结束，门禁不再拦截——否则直接驱动链（choose_action
	# leave → complete_node）会被下一次 travel 软锁。
	if not state.node_flags.has(state.current_node_id) \
			and (RestRulesScript._is_rest_class_node(catalog, state.current_node_id) or RestRulesScript._is_rest_class_node(catalog, str(state.current_node_template_id))) \
			and not RestRulesScript._rest_visit_consumed(state):
		return _rejected(state, "rest_choice_required")
	# R-layering hard gate: the ascension window only opens after the final
	# layer's boss falls. Topology already funnels it behind final_boss_stand;
	# this guard keeps the rule true even against out-of-band travel commands.
	if node_id == "ascension_window" and str(state.node_flags.get("boss_defeated", "")) != "true":
		return _rejected(state, "boss_undefeated")
	var next := state.append_event(_event(
		state,
		"travel",
		{"current_node_id": state.current_node_id},
		{"current_node_id": node_id},
		"travel",
		node_id
	))
	var pending := int(state.node_flags.get("pending_delayed_soul_drain", 0))
	if pending > 0:
		var cultivator := next.cultivator.duplicate(true)
		cultivator["soul"] = maxi(0, int(cultivator.get("soul", 0)) - pending)
		var flags := next.node_flags.duplicate(true)
		flags["pending_delayed_soul_drain"] = 0
		next = next.append_event(_event(
			next,
			"delayed_cost",
			{"cultivator": next.cultivator, "node_flags": next.node_flags},
			{"cultivator": cultivator, "node_flags": flags},
			"delayed_soul_drain",
			node_id
		))
		return _finalize_if_dead(next)
	return _accepted(next)


static func _use_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var gu_id := str(command.get("gu_id", ""))
	if not state.equipped_gu_ids.has(gu_id):
		return _rejected(state, "gu_not_equipped")
	if not catalog.get("gu_by_id", {}).has(gu_id):
		return _rejected(state, "unknown_gu")
	var essence_cost: int = catalog["gu_by_id"][gu_id]["essence_cost"]
	if state.essence < essence_cost:
		return _rejected(state, "insufficient_essence")
	var next := state.append_event(_event(
		state,
		"use_gu",
		{"essence": state.essence},
		{"essence": state.essence - essence_cost},
		"gu_action",
		state.current_node_id,
		[gu_id]
	))
	return _accepted(next)


static func _buy_opportunity(state: RunState, command: Dictionary) -> Dictionary:
	var offer_type := str(command.get("offer_type", ""))
	var cost := int(command.get("cost", 0))
	if not OPPORTUNITY_TYPES.has(offer_type):
		return _rejected(state, "invalid_opportunity_type")
	if cost <= 0 or cost > state.stone:
		return _rejected(state, "invalid_opportunity_cost")
	var known_facts := state.known_facts.duplicate()
	known_facts.append("bought_%s" % offer_type)
	var next := state.append_event(_event(
		state,
		"buy_opportunity",
		{"stone": state.stone, "known_facts": state.known_facts},
		{"stone": state.stone - cost, "known_facts": known_facts},
		"declared_opportunity",
		state.current_node_id
	))
	return _accepted(next)


static func _take_body_imprint(state: RunState, command: Dictionary) -> Dictionary:
	var imprint_id := str(command.get("imprint_id", ""))
	if not BODY_IMPRINTS.has(imprint_id):
		return _rejected(state, "unknown_body_imprint")
	if state.body_imprints.has(imprint_id):
		return _rejected(state, "body_imprint_already_taken")
	var imprint: Dictionary = BODY_IMPRINTS[imprint_id]
	var body_imprints := state.body_imprints.duplicate()
	body_imprints.append(imprint_id)
	var known_facts := state.known_facts.duplicate()
	for fact in imprint["facts"]:
		if not known_facts.has(fact):
			known_facts.append(fact)
	var after := {
		"body_imprints": body_imprints,
		"known_facts": known_facts,
		"injury": state.injury + int(imprint.get("injury", 0)),
		"lifespan_debt": state.lifespan_debt + int(imprint.get("lifespan_debt", 0)),
	}
	var next := state.append_event(_event(
		state,
		"take_body_imprint",
		{"body_imprints": state.body_imprints, "known_facts": state.known_facts},
		after,
		imprint["reason"],
		state.current_node_id,
		[imprint_id]
	))
	return _accepted(next)


static func _choose_action(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var action_id := str(command.get("action_id", ""))
	# NPC-scoped actions own their route even when their verbs overlap generic actions.
	# Generic commands never carry npc_id, so their legacy path remains unchanged.
	if command.has("npc_id"):
		return apply_social_action(state, command, catalog)
	if action_id.is_empty():
		return _rejected(state, "missing_action_id")
	if not STANDARD_ACTIONS.has(action_id):
		return _rejected(state, "unsupported_standard_action")
	if action_id in ["claim_recon", "claim_token"]:
		# S3 遗葬传承：需要目录（站点/配方池），走专属处理器。
		return _claim_inheritance(state, action_id, catalog)
	var transition := _standard_action_transition(state, action_id)
	if not bool(transition.get("ok", true)):
		return _rejected(state, str(transition.get("reason", "action_unavailable")))
	var next := state.append_event(_event(
		state,
		"choose_action",
		transition["before"],
		transition["after"],
		str(transition["reason"]),
		state.current_node_id
	))
	# E3a：修炼族（meditate）在休息类节点成功执行即消费本次探访（三选一）。
	if action_id == "meditate":
		next = RestRulesScript._consume_rest_visit_if_rest_class(next, catalog)
	# Ascension grants (升仙五项): a node may declare that performing one of
	# its actions secures one of the five ascension conditions. The mapping
	# lives on the node in nodes.json (ascension_grants); without it the two
	# flow-granted conditions (heaven_earth_qi, aperture_foundation) had no
	# source and ascension could never succeed outside of tests.
	var grant_flag := _ascension_grant_for(state, action_id, catalog)
	if not grant_flag.is_empty():
		var grant := _ascension_transition(state, grant_flag, true, "ascension_grant_%s" % grant_flag)
		next = next.append_event(_event(
			next,
			"choose_action",
			grant["before"],
			grant["after"],
			str(grant["reason"]),
			state.current_node_id
		))
	var result := {
		"ok": true,
		"action_id": action_id,
		"effect_id": str(transition["effect_id"]),
	}
	# Playthrough finding (night batch): generic combat nodes (no npc_id) could
	# never start a battle because "fight" was only wired for social actions.
	# The standard fight transition signals the controller to open the battle.
	if bool(transition.get("start_battle", false)):
		result["start_battle"] = true
	return {
		"state": next,
		"result": result,
	}


static func _standard_action_transition(state: RunState, action_id: String) -> Dictionary:
	match action_id:
		"work":
			return _resource_transition(state, "stone", 3, "action_work_paid")
		"harvest":
			return _resource_transition(state, "stone", 2, "action_harvest_stone")
		"fight":
			# Generic combat-node fight: no resource exchange, just the battle
			# trigger; the controller opens BattleResolver via start_battle.
			return {
				"ok": true,
				"before": {},
				"after": {},
				"reason": "node_fight_started",
				"effect_id": "fight",
				"start_battle": true,
			}
		"buy_information":
			return _spend_stone_for_fact(state, "bought_information", "action_bought_information")
		"trade":
			return _spend_stone_for_fact(state, "bought_service", "action_trade_service")
		"cross":
			if state.essence < 1:
				return {"ok": false, "reason": "insufficient_essence"}
			return _resource_transition(state, "essence", -1, "action_cross_cost")
		"meditate":
			return _resource_transition(state, "essence", 1, "action_meditate_essence")
		"deceive":
			return _resource_transition(state, "pursuit", 1, "action_deceive_pursuit")
		"retreat":
			return _resource_transition(state, "pursuit", 1, "action_retreat_pursuit")
		"open":
			return _ascension_transition(state, "site", true, "action_open_site")
		"prepare":
			return _ascension_transition(state, "protection", true, "action_prepare_protection")
		"scheme":
			return _ascension_transition(state, "external_interference", false, "action_scheme_interference")
		"take_imprint":
			if state.body_imprints.has("iron_bone"):
				return {"ok": false, "reason": "body_imprint_already_taken"}
			var facts := _facts_with(state, "iron_bone_defense")
			facts = _facts_with_values(facts, "iron_bone_stealth_drawback")
			return {
				"before": {"body_imprints": state.body_imprints, "known_facts": state.known_facts},
				"after": {"body_imprints": state.body_imprints + ["iron_bone"], "known_facts": facts},
				"reason": "action_take_iron_bone",
				"effect_id": "action_take_imprint",
			}
		"accept": return _fact_transition(state, "commission_accepted", "action_accept_commission")
		"ally": return _fact_transition(state, "temporary_ally", "action_ally_support")
		"claim": return _fact_transition(state, "claimed_opportunity", "action_claim_opportunity")
		"inspect": return _fact_transition(state, "site_clue", "action_inspect_clue")
		"leave": return _fact_transition(state, "route_left_behind", "action_leave_route")
		"lure": return _fact_transition(state, "lured_threat", "action_lure_threat")
		"scout": return _fact_transition(state, "route_scouted", "action_scout_route")
		"withdraw": return _fact_transition(state, "withdrawn_safely", "action_withdraw_safely")
	return {"ok": false, "reason": "unsupported_standard_action"}


## S3 遗葬传承：门禁/品质/产出结算见 inheritance_claim_rules.gd
## （独立模块，守住 resolver 行数门限）。
static func _claim_inheritance(state: RunState, action_id: String, catalog: Dictionary) -> Dictionary:
	return InheritanceClaimRulesScript.claim(state, action_id, catalog)


static func _resource_transition(state: RunState, key: String, delta: int, effect_id: String) -> Dictionary:
	var before_value := int(state.get(key))
	return {
		"before": {key: before_value},
		"after": {key: before_value + delta},
		"reason": effect_id,
		"effect_id": effect_id,
	}


static func _spend_stone_for_fact(state: RunState, fact_id: String, effect_id: String) -> Dictionary:
	if state.stone < 2:
		return {"ok": false, "reason": "insufficient_stone"}
	return {
		"before": {"stone": state.stone, "known_facts": state.known_facts},
		"after": {"stone": state.stone - 2, "known_facts": _facts_with(state, fact_id)},
		"reason": effect_id,
		"effect_id": effect_id,
	}


static func _ascension_transition(state: RunState, key: String, value: bool, effect_id: String) -> Dictionary:
	var ascension := state.ascension.duplicate(true)
	ascension[key] = value
	return {
		"before": {"ascension": state.ascension},
		"after": {"ascension": ascension},
		"reason": effect_id,
		"effect_id": effect_id,
	}


## The five ascension conditions of the smoke design's 终局资格 ledger.
const ASCENSION_CONDITION_KEYS := [
	"aperture_foundation", "heaven_earth_qi", "site", "protection", "external_interference",
]


static func _record_layer_boss_defeated(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var layer := int(command.get("layer", 0))
	if layer < 1 or layer > 5:
		return _rejected(state, "invalid_layer_boss")
	var flags := state.node_flags.duplicate(true)
	flags["boss_defeated_L%d" % layer] = "true"
	# 层级 Boss 只记录路线推进；修为与真元成长由各自领域规则处理。
	var next := state.append_event(_event(
		state,
		"record_layer_boss_defeated",
		{"node_flags": state.node_flags},
		{"node_flags": flags},
		"layer_boss_%d_defeated" % layer,
		state.current_node_id
	))
	next.node_flags = flags
	return _accepted(next)


static func _ascension_grant_for(state: RunState, action_id: String, catalog: Dictionary) -> String:
	# 拓扑 v2：实例 id 与模板 id 分离；旧实例（first_run/测试）回退用节点 id。
	var node_id := str(state.current_node_template_id) if not str(state.current_node_template_id).is_empty() else str(state.current_node_id)
	for node_value in catalog.get("nodes", []):
		var node: Dictionary = node_value
		if str(node.get("id", "")) != node_id:
			continue
		var grants: Dictionary = node.get("ascension_grants", {})
		var flag := str(grants.get(action_id, ""))
		return flag if flag in ASCENSION_CONDITION_KEYS else ""
	return ""


static func _fact_transition(state: RunState, fact_id: String, effect_id: String) -> Dictionary:
	return {
		"before": {"known_facts": state.known_facts},
		"after": {"known_facts": _facts_with(state, fact_id)},
		"reason": effect_id,
		"effect_id": effect_id,
	}


static func _facts_with(state: RunState, fact_id: String) -> Array[String]:
	return _facts_with_values(state.known_facts, fact_id)


static func _facts_with_values(existing: Array[String], fact_id: String) -> Array[String]:
	var facts := existing.duplicate()
	ResolverHelpersScript.add_fact(facts, fact_id)
	return facts


static func apply_social_action(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var npc := _npc_by_id(catalog, str(command.get("npc_id", "")))
	if npc.is_empty():
		return _rejected(state, "unknown_npc")
	var action_id := str(command.get("action_id", ""))
	if not ["probe", "trade", "pressure", "deceive", "leave", "fight"].has(action_id):
		return _rejected(state, "invalid_social_action")
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
				return _rejected(state, "missing_trade_evidence")
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
	var next := state.append_event(_event(
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
		return _rejected(state, "unknown_npc")
	var offer_id := str(command.get("offer_id", ""))
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(offer_id, {})
	if offer.is_empty():
		return _rejected(state, "unknown_shop_offer")
	var stock: Array = npc.get("stock", [])
	if not stock.has(offer_id):
		return _rejected(state, "npc_stock_missing")
	if not _current_node_declares_npc(state, catalog, str(npc.get("id", "unknown"))):
		return _rejected(state, "npc_not_present")
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
			return _rejected(state, "unknown_shop_offer")


static func _current_node_declares_npc(state: RunState, catalog: Dictionary, npc_id: String) -> bool:
	for node in catalog.get("nodes", []):
		if str(node.get("id", "")) == state.current_node_id:
			return str(node.get("npc_id", "")) == npc_id
	return false


static func _npc_reaction(state: RunState, npc: Dictionary) -> String:
	if state.injury >= 2:
		return npc["injury_reaction"]
	return "caution"


static func _retreat(state: RunState) -> Dictionary:
	var next := state.append_event(_event(
		state,
		"retreat",
		{"pursuit": state.pursuit},
		{"pursuit": state.pursuit + 1},
		"retreat_pressure",
		state.current_node_id
	))
	return _accepted(next)


static func _grant_lifespan_milestone(state: RunState, catalog: Dictionary, milestone_id: String) -> RunState:
	var milestones: Dictionary = catalog.get("pacing", {}).get("lifespan_milestones", {})
	if not milestones.has(milestone_id):
		return state
	var amount := int(milestones[milestone_id])
	if amount <= 0:
		return state
	var cultivator := state.cultivator.duplicate(true)
	cultivator["lifespan"] = int(cultivator.get("lifespan", 0)) + amount
	return state.append_event(_event(
		state,
		"lifespan_milestone",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"lifespan_milestone_gained",
		state.current_node_id,
		[milestone_id]
	))


static func _gain_force_power(state: RunState, command: Dictionary, _catalog: Dictionary) -> Dictionary:
	var source_id := str(command.get("source_id", ""))
	if source_id.is_empty():
		return _rejected(state, "missing_force_source")
	var cultivator := state.cultivator.duplicate(true)
	var imprints: Array = cultivator.get("force_imprints", []).duplicate()
	if imprints.has(source_id):
		return _rejected(state, "force_imprint_repeated")
	imprints.append(source_id)
	cultivator["force_imprints"] = imprints
	cultivator["force_power"] = int(cultivator.get("force_power", 0)) + int(command.get("amount", 1))
	var next := state.append_event(_event(
		state,
		"gain_force_power",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"force_power_gained",
		state.current_node_id,
		[source_id]
	))
	return _accepted(next)


static func _record_boss_defeated(state: RunState, catalog: Dictionary) -> Dictionary:
	var flags := state.node_flags.duplicate(true)
	var already_defeated := str(flags.get("boss_defeated", "")) == "true"
	if not already_defeated:
		flags["boss_defeated"] = "true"
	var next := state.append_event(_event(
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
	return _accepted(next)


static func _attempt_ascension(state: RunState, command: Dictionary) -> Dictionary:
	if str(state.node_flags.get("boss_defeated", "")) != "true":
		return _rejected(state, "boss_undefeated")
	if command.get("choice", "") != "now":
		return _rejected(state, "unsupported_ascension_choice")
	var conditions := _ascension_conditions(state)
	var met := 0
	for condition in conditions.values():
		if condition:
			met += 1
	var risk := state.pursuit + state.injury + state.lifespan_debt
	# 升仙评价制（2026-08-28 裁定）：五项准备不再是一票否决的硬门槛，而是与
	# 风险共同折算四等评价。score = 达成条件数 - 风险罚分（risk<=1: 0，
	# risk<=3: 1，risk>3: 3）——5 特等 / 4 上等 / 2-3 中等 / 其余下等。
	# Boss 获胜仍是硬前置；冲仙本身不再因缺条件而失败。
	var penalty := 0
	if risk > 3:
		penalty = 3
	elif risk > 1:
		penalty = 1
	var score := met - penalty
	var outcome := "ascension_low"
	if score >= 5:
		outcome = "ascension_special"
	elif score == 4:
		outcome = "ascension_high"
	elif score >= 2:
		outcome = "ascension_medium"
	var ascension := state.ascension.duplicate(true)
	ascension["outcome"] = outcome
	ascension["conditions"] = conditions.duplicate(true)
	ascension["conditions_met"] = met
	ascension["risk"] = risk
	var next := state.append_event(_event(
		state,
		"attempt_ascension",
		{"ascension": state.ascension},
		{"ascension": ascension},
		"ascension_%s" % outcome,
		"ascension_window"
	))
	return {"state": next, "result": {"ok": true, "outcome": outcome, "conditions": conditions, "conditions_met": met, "risk": risk}}


static func _ascension_conditions(state: RunState) -> Dictionary:
	return {
		"aperture_foundation": state.ascension.get("aperture_foundation", false),
		"heaven_earth_qi": state.ascension.get("heaven_earth_qi", false),
		"site": state.ascension.get("site", false),
		"protection": state.ascension.get("protection", false),
		"external_interference": not state.ascension.get("external_interference", true),
	}


static func _event(
	state: RunState,
	action: String,
	before: Dictionary,
	after: Dictionary,
	reason: String,
	node_id: String,
	targets: Array = []
) -> Dictionary:
	return {
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": node_id,
		"action": action,
		"before": before,
		"after": after,
		"reason": reason,
		"source": "resolver",
		"targets": targets,
	}


static func notoriety(state: RunState) -> int:
	return EconomyRulesScript.notoriety(state)


static func roll_chance(state: RunState, pct: int, salt: String) -> bool:
	return EconomyRulesScript.roll_chance(state, pct, salt)


static func price_for(catalog: Dictionary, state: RunState, base: int) -> int:
	return EconomyRulesScript.price_for(catalog, state, base)


static func sell_price_for(catalog: Dictionary, state: RunState, base: int) -> int:
	return EconomyRulesScript.sell_price_for(catalog, state, base)


## 搜刮候选蛊方（预览与执行共用的唯一配方选择函数，2026-09-01）：
## scavenge_recipe 兼容单串与数组；过滤出「存在且尚未持有」的配方。
## 持有判定与图鉴门禁同源：global_codex_ids 命中 recipe id 或产出蛊 id。

static func gain_notoriety(state: RunState, amount: int, reason_key: String) -> RunState:
	if amount <= 0:
		return state
	var cultivator := state.cultivator.duplicate(true)
	cultivator["notorious"] = int(cultivator.get("notorious", 0)) + amount
	return state.append_event(_event(
		state,
		"gain_notoriety",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"notoriety_gained",
		state.current_node_id,
		[reason_key]
	))


static func _record_neutral_npc_kill(state: RunState, catalog: Dictionary) -> Dictionary:
	var gains: Dictionary = catalog.get("reputation", {}).get("gains", {})
	return _accepted(gain_notoriety(state, int(gains.get("kill_neutral_npc", 0)), "kill_neutral_npc"))


static func _wash_notoriety(state: RunState, catalog: Dictionary) -> Dictionary:
	if notoriety(state) <= 0:
		return _rejected(state, "nothing_to_wash")
	var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
	var cost := int(effects.get("wash_lifespan_cost", 10))
	var reduce := int(effects.get("wash_reduce", 2))
	var lifespan := int(state.cultivator.get("lifespan", 0))
	if lifespan - cost < 1:
		return _rejected(state, "lifespan_trade_warning")
	var cultivator := state.cultivator.duplicate(true)
	cultivator["lifespan"] = lifespan - cost
	cultivator["notorious"] = maxi(0, notoriety(state) - reduce)
	var next := state.append_event(_event(
		state,
		"wash_notoriety",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"notoriety_washed",
		state.current_node_id,
		[]
	))
	return _accepted(next)


static func _accepted(next: RunState) -> Dictionary:
	return {"state": next, "result": {"ok": true}}


static func _rejected(state: RunState, reason: String) -> Dictionary:
	return {"state": state, "result": {"ok": false, "reason": reason}}
