class_name V2Commands
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
const Battle2TurnEngineScript = preload("res://scripts/domain/battle2/turn_engine.gd")
const Battle2BodyRulesScript = preload("res://scripts/domain/battle2/body_rules.gd")
const Battle2ActionResolverScript = preload("res://scripts/domain/battle2/action_resolver.gd")
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
			instances[new_id] = GuInstanceScript.new_instance(
					str(entry.get("definition_id", "")), new_id, catalog)
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
static func sell_info(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var sold := MarketRulesScript.sell_info(command.get("info", {}),
			str(command.get("buyer_id", "")), int(command.get("spread_count", 0)),
			command.get("sold_to", {}), catalog)
	if not bool(sold["sold"]):
		return _reject(state, str(sold.get("reason", "info_not_sold")))
	var known: Array[String] = state.known_facts.duplicate()
	known.append(str(command.get("info", {}).get("id", "info_sold")))
	var next: RunState = state.append_event(_event(state, "info_sold",
			{"known_facts": state.known_facts}, {"known_facts": known},
			"sold_info", []))
	return _accept(next, {"price": sold["price"], "seller_keeps_knowledge": bool(sold["seller_keeps_knowledge"])})


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
	var out := Battle2BodyRulesScript.dodge_resolution(
			command.get("conditions", {}), bool(command.get("has_thought", false)))
	if not bool(out["ok"]):
		return _reject(state, str(out["reason"]))
	var next: RunState = state.append_event(_event(state, "battle2_dodge", {}, {}, "dodged", []))
	return _accept(next, {"status": str(out["status"])})


static func grapple(state, command: Dictionary, _catalog: Dictionary) -> Dictionary:
	var pre := Battle2BodyRulesScript.grapple_preflight(
			str(command.get("attacker_distance", "")), str(command.get("target_distance", "")),
			bool(command.get("has_thought", false)))
	if not bool(pre["ok"]):
		return _reject(state, str(pre["reason"]))
	var contest := Battle2BodyRulesScript.grapple_contest(float(command.get("attacker_strength", 0.0)),
			float(command.get("target_strength", 0.0)), bool(command.get("target_resists", true)))
	if not bool(contest["ok"]):
		return _reject(state, str(contest["reason"]))
	var next: RunState = state.append_event(_event(state, "battle2_grapple", {}, {}, "grapple_established", []))
	return _accept(next, {"established": true})


static func respond(state, command: Dictionary, _catalog: Dictionary) -> Dictionary:
	var check := Battle2ActionResolverScript.reaction_allowed(
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
