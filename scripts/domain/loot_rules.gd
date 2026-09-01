class_name LootRules
extends RefCounted


# Spec-v4 phase-2 (T6.2): loot taxonomy (§8.1), generation-only budget
# (§8.2), surviving-gu collection with deterministic remanence refinement
# (§8.3), pre-declared carrying conditions (§8.4) and world-bound release /
# destruction with declared extraction (§8.5). Pure static, zero dice.
# Acceptance #12: the budget has no data path into post-battle survivor
# accounting - survivors are never trimmed by a budget.


const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")


# §8.1: the four persistent loot kinds; services and opportunities are
# actions, not persistent loot.
const LOOT_KINDS := ["gu", "material", "stone", "info"]


static func is_persistent_loot_kind(kind: String) -> bool:
	return LOOT_KINDS.has(kind)


# §8.2: total-value budget + world-in-source allocation used ONLY to shape
# enemies and scenes. The survivors parameter deliberately does not exist -
# this function can never trim post-battle returns.
static func budget_profile(enemy_composition: Array, scene: Dictionary, cat: Dictionary) -> Dictionary:
	var total := 0.0
	for enemy_value in enemy_composition:
		var enemy_rank := int((enemy_value as Dictionary).get("rank", 1))
		total += float(GuBalanceScript.beast_scale(enemy_rank, cat)) * 0.1
	var wealth := float(scene.get("loot_wealth", 1.0))
	return {
		"total_budget": total * wealth,
		"scope": "generation_only",
		"note": "budget shapes only enemy generation and scenes; it never reads survivors",
	}


# §8.3: collect surviving gu. Every survivor whose conditions are met is
# accounted in full (no budget trimming). With safety and time, ordinary
# same/lower-rank gu refine deterministically (no roll, no swallowed inputs);
# gu above the cultivator's rank are held but cannot activate (true-yuan
# quality). Ferocious / loyal / parasitic / fleeing / bound gu need their
# pre-declared extra conditions (options.satisfied_conditions) - there is no
# post-battle "it does not drop" verdict, only the pre-declared gate.
static func collect_surviving_gu(survivors: Array, state, options: Dictionary, catalog: Dictionary) -> Dictionary:
	var collected: Array = []
	var cultivator_rank := int(options.get("cultivator_rank", 1))
	var safe_and_time := bool(options.get("safe_and_time_available", false))
	var satisfied: Dictionary = options.get("satisfied_conditions", {})
	for survivor_value in survivors:
		var survivor: Dictionary = survivor_value
		var instance_id := str(survivor.get("instance_id", ""))
		var definition_id := str(survivor.get("definition_id", ""))
		var rank := int(survivor.get("rank", 1))
		if not _pre_declared_conditions_satisfied(survivor, satisfied.has(instance_id)):
			collected.append({
				"instance_id": instance_id, "definition_id": definition_id,
				"status": "not_collected", "ok": false,
				"reason": "pre_declared_condition_not_met",
			})
			continue
		if safe_and_time and rank <= cultivator_rank:
			collected.append({
				"instance_id": instance_id, "definition_id": definition_id,
				"status": "refined", "ok": true, "reason": "",
			})
			continue
		collected.append({
			"instance_id": instance_id, "definition_id": definition_id,
			"status": "held_only", "ok": true,
			"reason": "above_cultivator_rank" if rank > cultivator_rank else "not_safe_or_no_time",
		})
	return {"collected": collected}


# §8.4: the extra conditions take from pre-declared traits; each trait that
# exists requires its pre-battle satisfaction, which must be observable
# before the fight (a satisfied_conditions flag is the caller's binding).
static func _pre_declared_conditions_satisfied(instance: Dictionary, flag: bool) -> bool:
	var needs_extra := false
	for key in ["ferocity", "loyal", "parasitic", "bound", "flee"]:
		if bool(instance.get(key, false)) or float(instance.get(key, 0.0)) > 0.0:
			needs_extra = true
			break
	if not needs_extra:
		return true
	return flag


# §8.5: release is a world-bound act, not a delete button. The consequences
# are returned (and are public before the release); a harmless gu simply
# escapes, dangerous ones expose, loyal ones return to their owner.
static func release_gu(instance: Dictionary, _options: Dictionary, _catalog: Dictionary) -> Dictionary:
	var consequences: Array = ["escaped"]
	if bool(instance.get("loyal", false)):
		consequences.append("returns_to_owner")
	if int(instance.get("ferocity", 0)) > 0:
		consequences.append("exposes_player")
	if bool(instance.get("parasitic", false)):
		consequences.append("reappears_later")
	return {"released": true, "consequences": consequences}


# §8.5: destruction never returns a fixed ratio of materials. Extraction
# follows the gu kind's declared death_drops (data-driven, per gu.json
# definition); without a declaration nothing is refunded.
static func destroy_gu(instance: Dictionary, _method: String, _means: String, catalog: Dictionary) -> Dictionary:
	var definition: Dictionary = catalog.get("gu_by_id", {}).get(
			str(instance.get("definition_id", "")), {})
	var extracted := {}
	var death_drops: Dictionary = definition.get("death_drops", {})
	for material_id in death_drops:
		extracted[str(material_id)] = death_drops[material_id]
	return {"destroyed": true, "extracted": extracted}
