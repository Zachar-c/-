class_name LootResolver
extends RefCounted


const SeededRngScript = preload("res://scripts/domain/rng.gd")


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
	var table: Dictionary = catalog.get("loot_tables", {}).get("loot", {}).get(tier, {})
	var pity_cfg: Dictionary = catalog.get("loot_tables", {}).get("pity", {})
	var material_ids := _roll_materials(table, state, tier, pity_cfg)
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
	return {"state": next, "loot": loot}


static func _enemy_tier(enemy_kind: String, catalog: Dictionary) -> String:
	for enemy in catalog.get("enemies", []):
		if str(enemy.get("id", "")) == enemy_kind:
			return str(enemy.get("tier", "common"))
	return "common"


static func _roll_materials(table: Dictionary, state: RunState, tier: String, pity_cfg: Dictionary = {}) -> Array[String]:
	var pool: Array = (table.get("material_pool", []) as Array).duplicate()
	var count := int(table.get("material_count", 0))
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
static func _roll_gu(table: Dictionary, state: RunState, tier: String, pity_cfg: Dictionary = {}, school_pools: Dictionary = {}) -> Dictionary:
	var chance := int(table.get("gu_chance_pct", 0))
	var pool: Dictionary = table.get("gu_pool", {})
	var weights: Dictionary = pool.get("weights", {})
	if chance <= 0 or weights.is_empty():
		return {"gu_id": "", "rarity": ""}
	var bound := clampi(chance, 0, 100)
	if bound < 100 and _pick_from(100, state, "loot.gu.%s" % tier) >= bound:
		return {"gu_id": "", "rarity": ""}
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
	var bucket: Array = (pool.get("by_rarity", {}).get(picked_rarity, []) as Array).duplicate()
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
		"gu_id": str(pick_pool[_pick_from(pick_pool.size(), state, "loot.gu.pick.%s.%s" % [tier, picked_rarity])]),
		"rarity": picked_rarity,
	}


static func _next_loot_pity(current: int, rarity: String, pity_cfg: Dictionary = {}) -> int:
	var clearing: Array = pity_cfg.get("clearing_rarities", PITY_CLEARING_RARITIES)
	if (clearing as Array).has(rarity):
		return 0
	if rarity == "common":
		return current + 1
	return current


static func _pick_from(bound: int, state: RunState, salt: String) -> int:
	if bound <= 1:
		return 0
	var salt_hash := 0
	for character in salt:
		salt_hash = salt_hash * 31 + character.unicode_at(0)
	var rng := SeededRngScript.new(int(state.seed) * 1000003 + state.event_log.size() * 97 + salt_hash)
	return rng.next_index(bound)


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


static func _gain_gu(state: RunState, gu_id: String, catalog: Dictionary, new_loot_pity: int) -> RunState:
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