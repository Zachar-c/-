class_name LootResolver
extends RefCounted


const SeededRngScript = preload("res://scripts/domain/rng.gd")


# B2: victory loot. Rolls are derived from the run seed and the immutable
# event position, so the same seed and position always yield the same loot.


static func settle_victory(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var tier := _enemy_tier(str(battle.get("enemy_kind", "")), catalog)
	var table: Dictionary = catalog.get("loot_tables", {}).get("loot", {}).get(tier, {})
	var material_ids := _roll_materials(table, state, tier)
	var gu_id := _roll_gu(table, state, tier)
	var loot := {"material_ids": material_ids, "gu_id": gu_id}
	var next := state
	if not material_ids.is_empty() or not gu_id.is_empty():
		next = _apply_loot(state, loot, catalog)
	return {"state": next, "loot": loot}


static func _enemy_tier(enemy_kind: String, catalog: Dictionary) -> String:
	for enemy in catalog.get("enemies", []):
		if str(enemy.get("id", "")) == enemy_kind:
			return str(enemy.get("tier", "common"))
	return "common"


static func _roll_materials(table: Dictionary, state: RunState, tier: String) -> Array[String]:
	var pool: Array = (table.get("material_pool", []) as Array).duplicate()
	var count := int(table.get("material_count", 0))
	var picked: Array[String] = []
	while picked.size() < count and not pool.is_empty():
		var index := _pick_from(pool.size(), state, "loot.material.%s" % tier)
		picked.append(str(pool[index]))
		pool.remove_at(index)
	return picked


static func _roll_gu(table: Dictionary, state: RunState, tier: String) -> String:
	var chance := int(table.get("gu_chance_pct", 0))
	var pool: Array = table.get("gu_pool", [])
	if chance <= 0 or pool.is_empty():
		return ""
	var bound := clampi(chance, 0, 100)
	if bound >= 100 or _pick_from(100, state, "loot.gu.%s" % tier) < bound:
		return str(pool[_pick_from(pool.size(), state, "loot.gu.pick.%s" % tier)])
	return ""


static func _pick_from(bound: int, state: RunState, salt: String) -> int:
	if bound <= 1:
		return 0
	var salt_hash := 0
	for character in salt:
		salt_hash = salt_hash * 31 + character.unicode_at(0)
	var rng := SeededRngScript.new(int(state.seed) * 1000003 + state.event_log.size() * 97 + salt_hash)
	return rng.next_index(bound)


static func _apply_loot(state: RunState, loot: Dictionary, catalog: Dictionary) -> RunState:
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
			"before": {"materials": state.materials},
			"after": {"materials": after},
			"reason": "loot_materials_gained",
			"source": "loot_resolver",
			"targets": material_ids,
		})
		next.materials = after
	var gu_id := str(loot.get("gu_id", ""))
	if not gu_id.is_empty():
		next = _gain_gu(next, gu_id, catalog)
	return next


static func _gain_gu(state: RunState, gu_id: String, catalog: Dictionary) -> RunState:
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
		"before": {"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		"after": {"gu_instances": instances, "cave_aperture": aperture},
		"reason": "loot_gu_gained",
		"source": "loot_resolver",
		"targets": [gu_id],
	})
	next.gu_instances = instances
	next.cave_aperture = aperture
	next.sync_legacy_gu_projections()
	return next


static func _next_instance_id(instances: Dictionary) -> String:
	var highest := 0
	for key_value in instances:
		var text := str(key_value)
		if text.begins_with("gu_"):
			highest = maxi(highest, int(text.trim_prefix("gu_")))
	return "gu_%03d" % (highest + 1)