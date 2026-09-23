class_name RunCommands
extends RefCounted


# Spec-v4 phase-2 (T9.2): the v2 command handlers - thin delegation to the
# phase 1-8 rule modules. Every handler: preflight (reason mapped at the
# controller) -> thin rule call -> immutable event log entry. Rejections
# return the untouched state (same-source preflight, 17.3). No new rules
# live here; resolver._dispatch routes the fifteen types to this module.


const CoreGuRulesScript = preload("res://scripts/domain/core_gu_rules.gd")
const FeedingRulesScript = preload("res://scripts/domain/feeding_rules.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const LootRulesScript = preload("res://scripts/domain/loot_rules.gd")
const MarketRulesScript = preload("res://scripts/domain/market_rules.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")
const Battle2TurnEngineScript = preload("res://scripts/domain/battle2/turn_engine.gd")
const BodyRulesScript = preload("res://scripts/domain/body_rules.gd")
const ActionResolverScript = preload("res://scripts/domain/action_resolver.gd")
const MaterialRulesScript = preload("res://scripts/domain/material_rules.gd")
const BloodQiRulesScript = preload("res://scripts/domain/blood_qi_rules.gd")
const SoulRulesScript = preload("res://scripts/domain/soul_rules.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")


static func _reject(state, reason: String) -> Dictionary:
	return {"state": state, "result": {"ok": false, "reason": reason}}


static func _accept(next, extra: Dictionary = {}) -> Dictionary:
	var out := {"state": next, "result": {"ok": true}}
	for key in extra:
		out["result"][key] = extra[key]
	return out


static func _event(state, action: String, before: Dictionary, after: Dictionary, reason: String, targets: Array = []) -> Dictionary:
	return {
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": action,
		"before": before,
		"after": after,
		"reason": reason,
		"source": "v2",
		"targets": targets,
	}


# core family ----------------------------------------------------------------
static func confirm_core(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var instance_id := str(command.get("instance_id", ""))
	var pre := CoreGuRulesScript.can_confirm(state, instance_id, catalog)
	if not bool(pre["ok"]):
		return _reject(state, str(pre["reason"]))
	var confirmed := CoreGuRulesScript.confirm(state, instance_id, catalog)
	if not bool(confirmed["ok"]):
		return _reject(state, str(confirmed["reason"]))
	var instances: Dictionary = state.gu_instances.duplicate(true)
	instances[instance_id] = confirmed["updated_instance"]
	var next: RunState = state.append_event(_event(state, "core_confirmed",
			{"gu_instances": state.gu_instances}, {"gu_instances": instances},
			"player_confirmed", [instance_id]))
	return _accept(next)


static func replace_core(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var old_id := str(command.get("old_instance_id", ""))
	var new_id := str(command.get("new_instance_id", ""))
	var cost: Dictionary = command.get("cost", {})
	var pre := CoreGuRulesScript.can_replace(state, old_id, new_id, cost, catalog)
	if not bool(pre["ok"]):
		return _reject(state, str(pre["reason"]))
	var replaced := CoreGuRulesScript.replace_core(state, old_id, new_id, cost, catalog)
	var instances: Dictionary = state.gu_instances.duplicate(true)
	for key in replaced["instances"]:
		instances[key] = replaced["instances"][key]
	var flags := (state.node_flags as Dictionary).duplicate(true)
	flags["core_replace_count"] = int(replaced.get("replace_count", 0))
	var next: RunState = state.append_event(_event(state, "core_replaced",
			{"gu_instances": state.gu_instances, "node_flags": state.node_flags},
			{"gu_instances": instances, "node_flags": flags},
			"player_confirmed", [old_id, new_id]))
	return _accept(next)


# feeding / settlement family -------------------------------------------------
static func feed_instance(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var instance_id := str(command.get("instance_id", ""))
	if not (state.gu_instances as Dictionary).has(instance_id):
		return _reject(state, "instance_missing")
	var options: Dictionary = command.get("options", {})
	var result := FeedingRulesScript.layer_settle(
			[(state.gu_instances[instance_id] as Dictionary).duplicate(true)],
			state.materials.duplicate(true), options, catalog)
	var instances: Dictionary = state.gu_instances.duplicate(true)
	var pantry: Dictionary = result["pantry_after"]
	var events: Array = result["events"]
	var after := {"gu_instances": instances, "materials": pantry}
	if (result["settled"] as Array).size() > 0:
		var settled_instance: Dictionary = (result["settled"][0] as Dictionary)["instance"]
		instances[str(settled_instance.get("instance_id", ""))] = settled_instance
	for starve_value in events:
		var starve: Dictionary = starve_value
		after["_feeding_" + str(starve.get("instance_id", ""))] = starve
	var next: RunState = state.append_event(_event(state, "feed_instance",
			{"gu_instances": state.gu_instances, "materials": state.materials},
			after, "player_fed", [instance_id]))
	return _accept(next, {"outcome": str((result["settled"] as Array)[0]["outcome"]) if (result["settled"] as Array).size() > 0 else "starved", "events": events})


static func settle_layer(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var new_layer := int(command.get("new_layer", int(state.current_node_layer)))
	var next := RunStateScript.settle_layer(
			state, new_layer, state.materials.duplicate(true), catalog, command.get("options", {}))
	return _accept(next, {"settled": true})


# loot family -----------------------------------------------------------------
static func collect_surviving(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var survivors: Array = command.get("survivors", [])
	var options: Dictionary = command.get("options", {})
	var collected := LootRulesScript.collect_surviving_gu(survivors, state, options, catalog)
	var instances: Dictionary = state.gu_instances.duplicate(true)
	var aperture := (state.cave_aperture as Dictionary).duplicate(true)
	var harvested: Array = []
	for entry in collected["collected"]:
		var status := str(entry.get("status", ""))
		if status in ["refined", "held_only"] and bool(entry.get("ok", false)):
			var new_id := RunStateScript.next_gu_instance_id(instances)
			# Stage 1：held_only（高转 / 不安全无时间）入袋为野生，不能直接催动；
			# 必须经 attune_gu 扣真元炼化后才进 refined_instances / 战斗槽。
			# §8.3 原文口径：held 但 cannot activate。
			var instance_extra := {"state": "wild"} if status == "held_only" else {}
			instances[new_id] = GuInstanceScript.new_instance(
					str(entry.get("definition_id", "")), new_id, catalog, instance_extra)
			(aperture.get("stored_gu_instance_ids", []) as Array).append(new_id)
			harvested.append({"source": str(entry.get("instance_id", "")), "new_instance_id": new_id, "status": status})
	var next: RunState = state.append_event(_event(state, "gu_collected",
			{"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
			{"gu_instances": instances, "cave_aperture": aperture},
			"survivors_collected", []))
	next.sync_legacy_gu_projections()
	return _accept(next, {"collected": harvested})


static func release_gu(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var instance_id := str(command.get("instance_id", ""))
	if not (state.gu_instances as Dictionary).has(instance_id):
		return _reject(state, "instance_missing")
	var instance: Dictionary = state.gu_instances[instance_id]
	var release := LootRulesScript.release_gu(instance, {}, catalog)
	var instances: Dictionary = state.gu_instances.duplicate(true)
	instances.erase(instance_id)
	var aperture := (state.cave_aperture as Dictionary).duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", [])
	stored.erase(instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var next: RunState = state.append_event(_event(state, "gu_released",
			{"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
			{"gu_instances": instances, "cave_aperture": aperture},
			"released_in_world", [instance_id]))
	next.sync_legacy_gu_projections()
	return _accept(next, {"consequences": release["consequences"]})


# market family ---------------------------------------------------------------
# L0 2026-09-22：信息买卖入实账。sold_to / spread_count 以 RunState.info_sales 为准，
# 禁止由命令自带；成交入元石，卖方保留 known_facts。
static func sell_info(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var info: Dictionary = command.get("info", {})
	var info_id := str(info.get("id", ""))
	if info_id.is_empty():
		return _reject(state, "missing_info_id")
	var buyer_id := str(command.get("buyer_id", ""))
	if buyer_id.is_empty():
		return _reject(state, "missing_buyer_id")
	var ledger: Dictionary = (state.info_sales.get(info_id, {}) as Dictionary).duplicate(true)
	var sold_to: Dictionary = ledger.get("sold_to", {}).duplicate(true)
	var spread_count := int(ledger.get("spread_count", 0))
	var sold := MarketRulesScript.sell_info(info, buyer_id, spread_count, sold_to, catalog)
	if not bool(sold["sold"]):
		return _reject(state, str(sold.get("reason", "info_not_sold")))
	sold_to[buyer_id] = true
	ledger["sold_to"] = sold_to
	ledger["spread_count"] = int(sold.get("spread_count", spread_count + 1))
	var info_sales: Dictionary = state.info_sales.duplicate(true)
	info_sales[info_id] = ledger
	var known: Array[String] = state.known_facts.duplicate()
	if not known.has(info_id):
		known.append(info_id)
	var price := int(round(float(sold.get("price", 0.0))))
	var next: RunState = state.append_event(_event(state, "info_sold",
			{"stone": state.stone, "known_facts": state.known_facts, "info_sales": state.info_sales},
			{"stone": state.stone + price, "known_facts": known, "info_sales": info_sales},
			"sold_info", [info_id, buyer_id]))
	return _accept(next, {
		"price": price,
		"seller_keeps_knowledge": bool(sold["seller_keeps_knowledge"]),
		"spread_count": ledger["spread_count"],
	})


# L0 2026-09-22：NPC 需求收购。报价 = MarketRules.demand_quote；履约后
# advance_demand 扣量/关单（防刷核心），元石入账。
static func fulfill_demand(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var demand_id := str(command.get("demand_id", ""))
	if demand_id.is_empty():
		return _reject(state, "missing_demand_id")
	# 模板播种：首遇 NPC 需求写入实账；此后 live 优先（防刷后的扣量/关单保留）。
	var seeded: Dictionary = state.npc_demands.duplicate(true)
	for npc_value in catalog.get("npcs", []):
		seeded = MarketRulesScript.seed_npc_demands(seeded, npc_value)
	var demand: Dictionary = (seeded.get(demand_id, {}) as Dictionary).duplicate(true)
	if demand.is_empty() or bool(demand.get("closed", false)):
		return _reject(state, "demand_unavailable")
	var material_id := str(demand.get("material_id", ""))
	var owned := int(state.materials.get(material_id, 0))
	var want := maxi(1, int(command.get("amount", 0)))
	if want > int(demand.get("quantity", 0)):
		return _reject(state, "demand_quantity_exceeded")
	if owned < want:
		return _reject(state, "insufficient_materials")
	var base := MarketRulesScript.t1_material_base_price(catalog) \
			* float(GuBalanceScript.rank_multiplier(maxi(1, int(demand.get("tier", 1))), catalog))
	var quote := MarketRulesScript.demand_quote(base, want, int(demand.get("tier", 0)), catalog)
	var price := int(round(float(quote.get("total", 0.0))))
	var materials: Dictionary = state.materials.duplicate(true)
	materials[material_id] = owned - want
	var npc_demands: Dictionary = seeded.duplicate(true)
	npc_demands[demand_id] = MarketRulesScript.advance_demand(demand, want)
	var next: RunState = state.append_event(_event(state, "demand_fulfilled",
			{"stone": state.stone, "materials": state.materials, "npc_demands": state.npc_demands},
			{"stone": state.stone + price, "materials": materials, "npc_demands": npc_demands},
			"demand_sold", [demand_id, material_id]))
	return _accept(next, {"price": price, "unit_price": quote.get("unit_price", 0.0)})


# battle2 orchestration family -------------------------------------------------
# battle2 orchestration family ---------------------------------------------
# T10.1-6 authority: the ledger owns the discrete-turn battle state as a
# domain field (created at battle start via a fresh turn, advanced by enact,
# projected read-only in snapshots). The event log carries each transition
# under both the persisted battle2_ledger after-key and the _battle2_ledger
# attribution copy (stateless, never the live owner).
static func enact(state, command: Dictionary, _catalog: Dictionary) -> Dictionary:
	var ledger: Dictionary = state.battle2_ledger
	if (ledger as Dictionary).is_empty():
		return _reject(state, "battle2_not_started")
	var proposal: Dictionary = command.get("proposal", {})
	var out := Battle2TurnEngineScript.enact(ledger, proposal)
	if not bool(out["ok"]):
		return _reject(state, str(out["reason"]))
	var next: RunState = state.append_event(_event(state, "battle2_enact",
			{"battle2_ledger": state.battle2_ledger, "_battle2_ledger": state.battle2_ledger},
			{"battle2_ledger": out["ledger"], "_battle2_ledger": out["ledger"]},
			"player_enact", []))
	return _accept(next, {"ledger": out["ledger"]})


static func dodge(state, command: Dictionary, _catalog: Dictionary) -> Dictionary:
	var out := BodyRulesScript.dodge_resolution(
			command.get("conditions", {}), bool(command.get("has_thought", false)))
	if not bool(out["ok"]):
		return _reject(state, str(out["reason"]))
	var next: RunState = state.append_event(_event(state, "battle2_dodge", {}, {}, "dodged", []))
	return _accept(next, {"status": str(out["status"])})


static func grapple(state, command: Dictionary, _catalog: Dictionary) -> Dictionary:
	var pre := BodyRulesScript.grapple_preflight(
			str(command.get("attacker_distance", "")), str(command.get("target_distance", "")),
			bool(command.get("has_thought", false)))
	if not bool(pre["ok"]):
		return _reject(state, str(pre["reason"]))
	var contest := BodyRulesScript.grapple_contest(float(command.get("attacker_strength", 0.0)),
			float(command.get("target_strength", 0.0)), bool(command.get("target_resists", true)))
	if not bool(contest["ok"]):
		return _reject(state, str(contest["reason"]))
	var next: RunState = state.append_event(_event(state, "battle2_grapple", {}, {}, "grapple_established", []))
	return _accept(next, {"established": true})


static func respond(state, command: Dictionary, _catalog: Dictionary) -> Dictionary:
	var check := ActionResolverScript.reaction_allowed(
			bool(command.get("has_reserved_thought", false)), str(command.get("action", "")))
	if not bool(check["ok"]):
		return _reject(state, str(check["reason"]))
	var next: RunState = state.append_event(_event(state, "battle2_respond", {}, {}, "responded", []))
	return _accept(next)


# material / blood / soul family ----------------------------------------------
static func refine_up_material(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var out_value := MaterialRulesScript.refine_up(float(command.get("input_value", 0.0)),
			int(command.get("from_rank", 1)), int(command.get("to_rank", 1)), catalog)
	var next: RunState = state.append_event(_event(state, "material_refined", {}, {}, "refined_material", []))
	return _accept(next, {"output_value": out_value})


static func bloodlet(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var out := BloodQiRulesScript.self_bleed(float(state.health),
			int(state.cultivator.get("cultivation", 1)), int(command.get("target_rank", 1)),
			float(command.get("amount", 0.0)), catalog)
	if not bool(out["ok"]):
		return _reject(state, str(out["reason"]))
	# Lethal marker never swallowed: the confirmation travels on the result.
	if bool(out["lethal_confirm_required"]):
		return _accept(state, {"ok": true, "lethal_confirm_required": true, "cause": str(out["cause"])})
	var next: RunState = state.append_event(_event(state, "bloodlet",
			{"health": state.health, "materials": state.materials},
			{"health": maxi(1, int(state.health) - int(out["health_cost"])),
			"materials": (state.materials as Dictionary).duplicate(true)},
			"self_bleed", []))
	return _accept(next, {"blood_amount": out["blood_amount"], "health_cost": out["health_cost"]})


static func absorb_soul(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var collected := SoulRulesScript.collect_soul(
			command.get("target", {}), command.get("means", {}), state.cultivator)
	if not bool(collected["ok"]):
		return _reject(state, str(collected["reason"]))
	if float(collected["yield"]) <= 0.0:
		return _reject(state, "soul_yield_zero")
	var strengthened := SoulRulesScript.strengthen_soul(
			(state.cultivator as Dictionary).duplicate(true), float(collected["yield"]))
	var next: RunState = state.append_event(_event(state, "soul_absorbed",
			{"cultivator": state.cultivator},
			{"cultivator": strengthened["cultivator"]},
			"soul_collected", []))
	return _accept(next, {"yield": collected["yield"]})
