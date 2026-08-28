class_name LootResolver
extends RefCounted


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")


# R13.1 rare pity threshold: after this many consecutive common-producing
# adventure drops, the next gated gu roll is forced onto non-common buckets.
const PITY_THRESHOLD := 3

# R13.1 rarity outcomes that clear the pity counter; anything else produced
# by the buckets advances it (only "common" exists besides these today).
const PITY_CLEARING_RARITIES := ["rare", "epic", "legendary"]


# B2: victory loot. Rolls are derived from the run seed and the immutable
# event position, so the same seed and position always yield the same loot.


static func settle_victory(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var tier := _enemy_tier(str(battle.get("enemy_kind", "")), catalog)
	var table: Dictionary = _layer_table(catalog, tier, int(battle.get("layer", 1)))
	var pity_cfg: Dictionary = catalog.get("loot_tables", {}).get("pity", {})
	# C1-min §16.13: material_bonus/-penalty shift the rolled material count,
	# clamped at >= 0 so a penalty can never invert the roll.
	var mods := ContractRulesScript.aggregate(state, catalog)
	var count_adjustment := int(mods.get("material_bonus", 0)) + int(mods.get("material_penalty", 0))
	var material_ids := _roll_materials(table, state, tier, pity_cfg, count_adjustment)
	var gu_roll := _roll_gu(table, state, tier, pity_cfg, catalog.get("school_pools", {}))
	var gu_id := str(gu_roll.get("gu_id", ""))
	var loot := {"material_ids": material_ids, "gu_id": gu_id}
	var next := state
	if not material_ids.is_empty() or not gu_id.is_empty():
		var next_pity := _next_loot_pity(int(state.loot_pity), str(gu_roll.get("rarity", "")), pity_cfg)
		var next_material_pity := int(state.material_pity)
		if not material_ids.is_empty():
			next_material_pity = _next_material_pity(int(state.material_pity), material_ids, pity_cfg)
		next = _apply_loot(state, loot, catalog, next_pity, next_material_pity)
	var result := {"state": next, "loot": loot}
	# R5.2/R6.9/R13.1 elite victories always bind exactly one seeded cost.
	if tier == "elite":
		var costed := _apply_elite_cost(next, catalog)
		result["state"] = costed["state"]
		result["cost"] = costed["cost"]
	return result


# Elite cost binding (R5.2/R6.9): the cost is drawn seeded from the table's
# cost_pool; backlash entries attach curse layers via CurseRegistry and
# notoriety entries go through the shared gain_notoriety funnel. The chosen
# cost rides a single elite_cost_applied event whose "_cost" key is log-only
# information and never lands in live state. Curses never kill directly here,
# so no silent death can originate from this path.
static func _apply_elite_cost(state: RunState, catalog: Dictionary) -> Dictionary:
	var pool: Array = catalog.get("loot_tables", {}).get("loot", {}).get("elite", {}).get("cost_pool", [])
	if pool.is_empty():
		return {"state": state, "cost": {}}
	var chosen := _pick_weighted(pool, state, "elite.cost")
	var next := state
	match str(chosen.get("kind", "")):
		"backlash":
			for _layer in maxi(1, int(chosen.get("layers", 1))):
				next = CurseRegistryScript.gain_curse(next, str(chosen.get("curse_id", "")), "elite_cost")
		"notoriety":
			next = ResolverScript.gain_notoriety(next, maxi(1, int(chosen.get("amount", 1))), "elite_cost")
		_:
			return {"state": state, "cost": {}}
	next = next.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "elite_cost_applied",
		"before": {},
		"after": {"_cost": chosen.duplicate(true)},
		"reason": "elite_cost_applied",
		"source": "loot_resolver",
		"targets": [str(chosen.get("kind", ""))],
	})
	return {"state": next, "cost": _normalized_cost(chosen)}


# Player-facing settlement contract: every cost carries "kind" plus either
# "layers" (backlash, with its curse_id) or "amount" (notoriety). Table-only
# keys such as "weight" never leave the resolver.
static func _normalized_cost(chosen: Dictionary) -> Dictionary:
	var cost := {"kind": str(chosen.get("kind", ""))}
	match cost["kind"]:
		"backlash":
			cost["curse_id"] = str(chosen.get("curse_id", ""))
			cost["layers"] = maxi(1, int(chosen.get("layers", 1)))
		"notoriety":
			cost["amount"] = maxi(1, int(chosen.get("amount", 1)))
	return cost


static func _pick_weighted(entries: Array, state: RunState, salt: String) -> Dictionary:
	var total := 0
	for entry_value in entries:
		total += maxi(0, int((entry_value as Dictionary).get("weight", 1)))
	if total <= 0:
		return {}
	var roll := _pick_from(total, state, salt)
	var cursor := 0
	for entry_value in entries:
		var entry: Dictionary = entry_value
		cursor += maxi(0, int(entry.get("weight", 1)))
		if roll < cursor:
			return entry
	return {}


## 统一数值裁定表（pacing.json layers）：大层的材料数与稀有度权重优先，
## 敌人 tier 表提供材料池/by_rarity 桶；未声明的稀有度桶不进入权重。
static func _layer_table(catalog: Dictionary, tier: String, layer: int) -> Dictionary:
	var base: Dictionary = catalog.get("loot_tables", {}).get("loot", {}).get(tier, {})
	var layers_cfg: Dictionary = catalog.get("pacing", {}).get("layers", {})
	var layer_cfg: Dictionary = layers_cfg.get(str(clampi(layer, 1, 5)), {})
	var loot_cfg: Dictionary = layer_cfg.get("loot", {})
	if loot_cfg.is_empty() or base.is_empty():
		return base
	var table := base.duplicate(true)
	if loot_cfg.has("material_count"):
		table["material_count"] = int(loot_cfg["material_count"])
	var weights: Dictionary = loot_cfg.get("weights", {})
	if not weights.is_empty():
		var by_rarity: Dictionary = table.get("gu_pool", {}).get("by_rarity", {})
		var effective: Dictionary = {}
		for rarity_id_value in weights:
			var rarity_id := str(rarity_id_value)
			if int(weights[rarity_id_value]) > 0 and not (by_rarity.get(rarity_id, []) as Array).is_empty():
				effective[rarity_id] = int(weights[rarity_id_value])
		if not effective.is_empty():
			(table["gu_pool"] as Dictionary)["weights"] = effective
	return table


static func _enemy_tier(enemy_kind: String, catalog: Dictionary) -> String:
	for enemy in catalog.get("enemies", []):
		if str(enemy.get("id", "")) == enemy_kind:
			return str(enemy.get("tier", "common"))
	return "common"


static func _roll_materials(table: Dictionary, state: RunState, tier: String, pity_cfg: Dictionary = {}, count_adjustment: int = 0) -> Array[String]:
	var pool: Array = (table.get("material_pool", []) as Array).duplicate()
	var count := maxi(0, int(table.get("material_count", 0)) + count_adjustment)
	var picked: Array[String] = []
	while picked.size() < count and not pool.is_empty():
		var index := _pick_from(pool.size(), state, "loot.material.%s" % tier)
		picked.append(str(pool[index]))
		pool.remove_at(index)
	var m_pity: Dictionary = pity_cfg.get("material_pity", {})
	var threshold := int(m_pity.get("threshold", 0))
	var targets: Array = m_pity.get("target_material_ids", [])
	if threshold > 0 and int(state.material_pity) >= threshold and not targets.is_empty():
		var has_target := false
		for material_value in picked:
			if targets.has(str(material_value)):
				has_target = true
				break
		if not has_target:
			# Only force what the tier pool actually declares; a guarantee can
			# never invent a material the table does not offer.
			var forced_pool: Array = []
			var table_pool: Array = table.get("material_pool", [])
			for target_value in targets:
				var target_id := str(target_value)
				if table_pool.has(target_id):
					forced_pool.append(target_id)
			if not forced_pool.is_empty():
				var forced_id := str(forced_pool[_pick_from(forced_pool.size(), state, "loot.material.forced.%s" % tier)])
				picked.append(forced_id)
	return picked


static func _next_material_pity(current: int, material_ids: Array, pity_cfg: Dictionary = {}) -> int:
	var targets: Array = pity_cfg.get("material_pity", {}).get("target_material_ids", [])
	if targets.is_empty():
		return current
	for material_value in material_ids:
		if targets.has(str(material_value)):
			return 0
	return current + 1


# Shop purchases are fixed offers and never call _roll_gu, so they bypass
# the R13.1 adventure-drop pity counter by construction.
#
# A table-declared "forced_rarity" (R5.2 elite guarantee) overrides both the
# declared weights and the pity forcing: the rarity is fixed before any roll.
# Forced results therefore never advance the ladder, and the resulting
# non-common rarity clears it exactly like a natural drop would.
static func _roll_gu(table: Dictionary, state: RunState, tier: String, pity_cfg: Dictionary = {}, school_pools: Dictionary = {}) -> Dictionary:
	var chance := int(table.get("gu_chance_pct", 0))
	var pool: Dictionary = table.get("gu_pool", {})
	var weights: Dictionary = pool.get("weights", {})
	if chance <= 0 or weights.is_empty():
		return {"gu_id": "", "rarity": ""}
	var bound := clampi(chance, 0, 100)
	if bound < 100 and _pick_from(100, state, "loot.gu.%s" % tier) >= bound:
		return {"gu_id": "", "rarity": ""}
	var by_rarity: Dictionary = pool.get("by_rarity", {})
	var forced_rarity := str(table.get("forced_rarity", ""))
	if not forced_rarity.is_empty() and not (by_rarity.get(forced_rarity, []) as Array).is_empty():
		return _pick_from_bucket(str(forced_rarity), by_rarity[forced_rarity], state, tier, school_pools)
	var effective_weights := weights
	var rarity_salt := "loot.gu.rarity.%s" % tier
	if state.loot_pity >= int(pity_cfg.get("threshold", PITY_THRESHOLD)):
		var forced := {}
		var forced_total := 0
		for rarity_id_value in weights:
			if str(rarity_id_value) == "common":
				continue
			forced[rarity_id_value] = maxi(0, int(weights[rarity_id_value]))
			forced_total += maxi(0, int(weights[rarity_id_value]))
		# Weights come from data; with no non-common weight the force is a no-op
		# so the rule can never hand out a legendary the table does not declare.
		if forced_total > 0:
			effective_weights = forced
			rarity_salt = "loot.gu.rarity.forced.%s" % tier
	var total_weight := 0
	for rarity_id_value in effective_weights:
		total_weight += maxi(0, int(effective_weights[rarity_id_value]))
	if total_weight <= 0:
		return {"gu_id": "", "rarity": ""}
	var rarity_roll := _pick_from(total_weight, state, rarity_salt)
	var picked_rarity := ""
	for rarity_id_value in effective_weights:
		rarity_roll -= maxi(0, int(effective_weights[rarity_id_value]))
		if rarity_roll < 0:
			picked_rarity = str(rarity_id_value)
			break
	if picked_rarity.is_empty():
		return {"gu_id": "", "rarity": ""}
	return _pick_from_bucket(picked_rarity, by_rarity.get(picked_rarity, []), state, tier, school_pools)


static func _pick_from_bucket(rarity: String, bucket_value: Variant, state: RunState, tier: String, school_pools: Dictionary) -> Dictionary:
	var bucket: Array = (bucket_value as Array).duplicate()
	if bucket.is_empty():
		return {"gu_id": "", "rarity": ""}
	var school_exclusive: Array = school_pools.get(str(state.school), [])
	var school_members: Array = []
	if not school_exclusive.is_empty():
		for bucket_gu_value in bucket:
			var bucket_gu_id := str(bucket_gu_value)
			if school_exclusive.has(bucket_gu_id):
				school_members.append(bucket_gu_id)
	var pick_pool: Array = school_members if not school_members.is_empty() else bucket
	return {
		"gu_id": str(pick_pool[_pick_from(pick_pool.size(), state, "loot.gu.pick.%s.%s" % [tier, rarity])]),
		"rarity": rarity,
	}


static func _next_loot_pity(current: int, rarity: String, pity_cfg: Dictionary = {}) -> int:
	var clearing: Array = pity_cfg.get("clearing_rarities", PITY_CLEARING_RARITIES)
	if (clearing as Array).has(rarity):
		return 0
	if rarity == "common":
		return current + 1
	return current


static func _pick_from(bound: int, state: RunState, salt: String) -> int:
	# P2a C: formula lives in SeededRoll; salt strings and call order unchanged.
	return SeededRollScript.index(bound, int(state.seed), salt, state.event_log.size())


static func _apply_loot(state: RunState, loot: Dictionary, catalog: Dictionary, new_loot_pity: int, new_material_pity: int) -> RunState:
	var next := state
	var material_ids: Array = loot.get("material_ids", [])
	if not material_ids.is_empty():
		var after := state.materials.duplicate(true)
		for material_id_value in material_ids:
			var material_id := str(material_id_value)
			after[material_id] = int(after.get(material_id, 0)) + 1
		next = state.append_event({
			"stage": state.stage,
			"time": state.event_log.size(),
			"node_id": state.current_node_id,
			"action": "battle_loot",
			"before": {"material_pity": state.material_pity},
			"after": {"materials": after, "material_pity": new_material_pity},
			"reason": "loot_materials_gained",
			"source": "loot_resolver",
			"targets": material_ids,
		})
		next.materials = after
		next.material_pity = new_material_pity
	var gu_id := str(loot.get("gu_id", ""))
	if not gu_id.is_empty():
		next = _gain_gu(next, gu_id, catalog, new_loot_pity)
	return next


static func _gain_gu(state: RunState, gu_id: String, _catalog: Dictionary, new_loot_pity: int) -> RunState:
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	var instance_id := _next_instance_id(instances)
	instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": gu_id,
		"state": "refined",
	}
	stored.append(instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var next := state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "battle_loot",
		"before": {},
		"after": {"gu_instances": instances, "cave_aperture": aperture, "loot_pity": new_loot_pity},
		"reason": "loot_gu_gained",
		"source": "loot_resolver",
		"targets": [gu_id],
	})
	next.gu_instances = instances
	next.cave_aperture = aperture
	next.sync_legacy_gu_projections()
	return next


static func _next_instance_id(instances: Dictionary) -> String:
	return RunState.next_gu_instance_id(instances)