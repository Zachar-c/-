class_name LootResolver
extends RefCounted


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")


# R13.1 rare pity threshold: after this many consecutive common-producing
# adventure drops, the next gated gu roll is forced onto non-common buckets.
const PITY_THRESHOLD := 3

# R13.1 rarity outcomes that clear the pity counter; anything else produced
# by the buckets advances it (only "common" exists besides these today).
const PITY_CLEARING_RARITIES := ["rare", "epic", "legendary"]


# B2: victory loot. Rolls are derived from the run seed and the immutable
# event position, so the same seed and position always yield the same loot.


static func settle_victory(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var tier := _resolve_battle_tier(battle, catalog)
	var layer := clampi(int(battle.get("layer", 1)), 1, 5)
	var table: Dictionary = _layer_table(catalog, tier, layer)
	var pity_cfg: Dictionary = catalog.get("loot_tables", {}).get("pity", {})
	# C1-min §16.13: material_bonus/-penalty shift the rolled material count,
	# clamped at >= 0 so a penalty can never invert the roll.
	var mods := ContractRulesScript.aggregate(state, catalog)
	# 2026-08-28 设计点：材料也有转阶差异——修为越高收获越丰（每高
	# 一转多收 1 份材料），一转与五转的采集效率不可同日而语。
	var count_adjustment := int(mods.get("material_bonus", 0)) + int(mods.get("material_penalty", 0)) 		+ maxi(0, int(state.cultivation) - 1)
	var material_ids := _roll_materials(table, state, tier, pity_cfg, count_adjustment, catalog)
	var gu_roll := _roll_gu(table, state, tier, pity_cfg, catalog.get("school_pools", {}), catalog.get("gu_by_id", {}))
	var gu_id := str(gu_roll.get("gu_id", ""))
	var loot := {"material_ids": material_ids, "gu_id": gu_id}
	# P2-a（R-3 校准）：pity 目标派系化——本派链路材料中该池声明且带段
	# 在允许集内的条目；roll 与计数器推进必须用同一目标集。
	var pity_targets := _material_pity_targets(tier, table, state, catalog)
	var next := state
	if not material_ids.is_empty() or not gu_id.is_empty():
		var next_pity := _next_loot_pity(int(state.loot_pity), str(gu_roll.get("rarity", "")), pity_cfg)
		var next_material_pity := (state.material_pity_by_tier as Dictionary).duplicate(true)
		if not material_ids.is_empty():
			next_material_pity = _next_material_pity(next_material_pity, tier, material_ids, pity_targets)
		next = _apply_loot(state, loot, catalog, next_pity, next_material_pity)
	var result := {"state": next, "loot": loot}
	# Q8-G 1-C (Batch 0 §4 frozen semantics): battle is the main stone producer.
	# Reward = base_by_tier[tier] + layer modifier (provisional numbers in
	# balance.battle_stone_rewards). Pure production, never a conversion: stones
	# enter the run only here, settled from tier+layer alone so the reward is
	# deterministic and independent of the loot rolls.
	var stone_reward := _stone_reward(tier, layer, catalog)
	loot["stone_reward"] = stone_reward
	if stone_reward > 0:
		# append_event applies event.after; do NOT also assign next.stone by
		# hand or the reward double-counts.
		next = next.append_event({
			"stage": next.stage,
			"time": next.event_log.size(),
			"node_id": next.current_node_id,
			"action": "battle_loot",
			"before": {"stone": next.stone},
			"after": {"stone": next.stone + stone_reward},
			"reason": "loot_stone_gained",
			"source": "loot_resolver",
			"targets": [tier, "layer_%d" % layer],
		})
	result["state"] = next
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


## Q8-G 1-D: normalize material pool entries to {id, weight}. Legacy string
## entries keep weight 1 so old tables roll exactly as before. 派系共振：
## 主道痕 == 玩家流派的条目权重 × resonance（校准倍率，配置 school_material_resonance）。
static func _material_entries(raw_pool: Array, state: RunState, resonance: int, catalog: Dictionary) -> Array:
	var school := str(state.school)
	var entries: Array = []
	for entry_value in raw_pool:
		if entry_value is String:
			entries.append({"id": str(entry_value), "weight": 1})
		elif entry_value is Dictionary:
			var entry: Dictionary = entry_value
			var weight := int(entry.get("weight", 1))
			var material_id := str(entry.get("id", ""))
			if material_id.is_empty() or weight < 1:
				continue
			if not school.is_empty() and resonance > 1:
				var material: Dictionary = (catalog.get("material_by_id", {}) as Dictionary).get(material_id, {})
				var tags: Array = material.get("dao_tags", [])
				if not tags.is_empty() and str(tags[0]) == school:
					weight *= resonance
			entries.append({"id": material_id, "weight": weight})
	return entries


## Q8-G 1-C: tier+layer stone reward, frozen shape / provisional numbers
## (balance.battle_stone_rewards). Pure function of tier and layer so the
## production ledger stays deterministic and independent of loot rolls.
static func _stone_reward(tier: String, layer: int, catalog: Dictionary) -> int:
	var cfg: Dictionary = catalog.get("balance", {}).get("battle_stone_rewards", {})
	var base := int(cfg.get("base_by_tier", {}).get(tier, 0))
	if base <= 0:
		return 0
	var step_pct := int(cfg.get("layer_step_pct", 0))
	return base + int(float(base) * float(step_pct) * float(maxi(1, layer) - 1) / 100.0)


static func _enemy_tier(enemy_kind: String, catalog: Dictionary) -> String:
	for enemy in catalog.get("enemies", []):
		if str(enemy.get("id", "")) == enemy_kind:
			return str(enemy.get("tier", "common"))
	return "common"


## Domain rule (E6): a multi-enemy victory uses the highest threat tier present:
## boss > elite > common. Any boss => boss; otherwise any elite => elite;
## otherwise common. Single-enemy behavior is preserved: without a non-empty
## enemy_kinds array the lone enemy_kind rules.
static func _resolve_battle_tier(battle: Dictionary, catalog: Dictionary) -> String:
	var kinds_value: Variant = battle.get("enemy_kinds", [])
	if kinds_value is Array and not (kinds_value as Array).is_empty():
		var seen_elite := false
		for kind_value in (kinds_value as Array):
			var tier := _enemy_tier(str(kind_value), catalog)
			if tier == "boss":
				return "boss"
			if tier == "elite":
				seen_elite = true
		if seen_elite:
			return "elite"
		return "common"
	return _enemy_tier(str(battle.get("enemy_kind", "")), catalog)


static func _roll_materials(table: Dictionary, state: RunState, tier: String, pity_cfg: Dictionary = {}, count_adjustment: int = 0, catalog: Dictionary = {}) -> Array[String]:
	# Q8-G 1-D: pool entries may be plain ids (legacy, weight 1) or {id, weight}
	# objects - the quality-band channels need per-material weights.
	# 派系共振（Q8-G 1-D provisional）：主道痕 == 玩家流派的条目权重 ×共振倍率，
	# 与蛊掉落"本流派局掉本流派蛊"同构——单流派局只养本派，19 派平摊会饿死链路。
	var resonance := maxi(1, int(catalog.get("loot_tables", {}).get("school_material_resonance", 1)))
	var pool: Array = _material_entries(table.get("material_pool", []), state, resonance, catalog)
	var count := maxi(0, int(table.get("material_count", 0)) + count_adjustment)
	var picked: Array[String] = []
	while picked.size() < count and not pool.is_empty():
		var entry := _pick_weighted(pool, state, "loot.material.%s" % tier)
		if entry.is_empty():
			break
		picked.append(str(entry["id"]))
		pool.erase(entry)
	var m_pity: Dictionary = pity_cfg.get("material_pity", {})
	var threshold := int(m_pity.get("threshold", 0))
	var targets: Array = _material_pity_targets(tier, table, state, catalog)
	var pity_count := int((state.material_pity_by_tier as Dictionary).get(tier, 0))
	if threshold > 0 and pity_count >= threshold and not targets.is_empty():
		var has_target := false
		for material_value in picked:
			if targets.has(str(material_value)):
				has_target = true
				break
		if not has_target:
			# Only force what the tier pool actually declares; a guarantee can
			# never invent a material the table does not offer.
			var forced_pool: Array = []
			for target_value in targets:
				var target_id := str(target_value)
				for entry_value in pool:
					if str((entry_value as Dictionary).get("id", "")) == target_id:
						forced_pool.append(target_id)
						break
			if not forced_pool.is_empty():
				var forced_id := str(forced_pool[_pick_from(forced_pool.size(), state, "loot.material.forced.%s" % tier)])
				picked.append(forced_id)
	return picked


## P2-a（R-3 校准，2026-09-13 裁定）：material_pity 目标派系化。
## 目标集 = 本派 promotion 配方声明的链路材料 ∩ 该 tier 池实际声明条目
## ∩ 配置允许的 quality_band。硬限：pity 只能补"该池已定义存在的目标
## 带段"（common→crude/f1、elite→plain/refined/f2f3、boss→prized/f4），
## 不得跨 tier 拉取或凭空生成——目标集恒为 池×配方×带段 的纯函数，
## 同种子同状态必得同目标（pity state determinism 门）。
static func _material_pity_targets(tier: String, table: Dictionary, state: RunState, catalog: Dictionary) -> Array[String]:
	var m_pity: Dictionary = catalog.get("loot_tables", {}).get("pity", {}).get("material_pity", {})
	var bands: Array = (m_pity.get("target_bands_by_tier", {}).get(tier, []) as Array)
	var school := str(state.school)
	if bands.is_empty() or school.is_empty():
		return []
	var chain: Dictionary = {}
	for recipe_value in catalog.get("refinement_recipes", []):
		var recipe: Dictionary = recipe_value
		if str(recipe.get("kind", "")) != "promotion":
			continue
		if not str(recipe.get("id", "")).begins_with("promote_%s_" % school):
			continue
		for material_id_value in (recipe.get("materials", {}) as Dictionary):
			chain[str(material_id_value)] = true
	var material_by_id: Dictionary = catalog.get("material_by_id", {})
	var targets: Array[String] = []
	for entry_value in table.get("material_pool", []):
		var material_id := ""
		if entry_value is String:
			material_id = str(entry_value)
		elif entry_value is Dictionary:
			material_id = str((entry_value as Dictionary).get("id", ""))
		if material_id.is_empty() or not chain.has(material_id) or targets.has(material_id):
			continue
		var band := str((material_by_id.get(material_id, {}) as Dictionary).get("quality_band", ""))
		if bands.has(band):
			targets.append(material_id)
	return targets


## Reachability-3（2026-09-13 裁定）：按 tier 独立的材料保底计数——
## common(f1)/elite(f2f3)/boss(f4) 各自累计：本 tier 战斗掉中目标则清零，
## 未掉中则本组 +1；**其他 tier 的掉落对本组计数零影响**（既不重置也不推进）。
## 旧单计数器会被跨带掉落清零，f1 断档沿顺序 promotion 链传导（Reachability-2）。
static func _next_material_pity(current_by_tier: Dictionary, tier: String, material_ids: Array, targets: Array = []) -> Dictionary:
	var next := current_by_tier.duplicate(true)
	if targets.is_empty():
		return next
	var hit := false
	for material_value in material_ids:
		if targets.has(str(material_value)):
			hit = true
			break
	next[tier] = 0 if hit else int(next.get(tier, 0)) + 1
	return next


# Shop purchases are fixed offers and never call _roll_gu, so they bypass
# the R13.1 adventure-drop pity counter by construction.
#
# A table-declared "forced_rarity" (R5.2 elite guarantee) overrides both the
# declared weights and the pity forcing: the rarity is fixed before any roll.
# Forced results therefore never advance the ladder, and the resulting
# non-common rarity clears it exactly like a natural drop would.
static func _roll_gu(table: Dictionary, state: RunState, tier: String, pity_cfg: Dictionary = {}, school_pools: Dictionary = {}, gu_by_id: Dictionary = {}) -> Dictionary:
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
		return _pick_from_bucket(str(forced_rarity), by_rarity[forced_rarity], state, tier, school_pools, gu_by_id)
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
	return _pick_from_bucket(picked_rarity, by_rarity.get(picked_rarity, []), state, tier, school_pools, gu_by_id)


static func _pick_from_bucket(rarity: String, bucket_value: Variant, state: RunState, tier: String, school_pools: Dictionary, gu_by_id: Dictionary = {}) -> Dictionary:
	var bucket: Array = (bucket_value as Array).duplicate()
	var school_exclusive: Array = school_pools.get(str(state.school), [])
	var school_members: Array = []
	if not school_exclusive.is_empty():
		for bucket_gu_value in bucket:
			var bucket_gu_id := str(bucket_gu_value)
			if school_exclusive.has(bucket_gu_id):
				school_members.append(bucket_gu_id)
	var pick_pool: Array = school_members
	if pick_pool.is_empty():
		# 掉落表未登记本流派蛊（如剑道 40 只全不在 loot_tables 内）⇒ 退到
		# school_pools 中同稀有度的本流派蛊，保证「本流派局掉本流派蛊」。
		# 直接退回 bucket 会让剑道局永远掉光道/气道蛊，成长链彻底断裂。
		pick_pool = _school_pool_by_rarity(str(state.school), rarity, school_pools, gu_by_id)
	if pick_pool.is_empty():
		pick_pool = bucket
	if pick_pool.is_empty():
		return {"gu_id": "", "rarity": ""}
	return {
		"gu_id": str(pick_pool[_pick_from(pick_pool.size(), state, "loot.gu.pick.%s.%s" % [tier, rarity])]),
		"rarity": rarity,
	}


## 本流派池里该稀有度的蛊（掉落表的流派兜底来源）。
static func _school_pool_by_rarity(school: String, rarity: String, school_pools: Dictionary, gu_by_id: Dictionary) -> Array:
	if school.is_empty() or gu_by_id.is_empty():
		return []
	var pool: Array = school_pools.get(school, [])
	if pool.is_empty():
		return []
	var matched: Array = []
	for gu_id_value in pool:
		var gu_id := str(gu_id_value)
		var definition: Dictionary = gu_by_id.get(gu_id, {})
		if str(definition.get("rarity", "common")) == rarity:
			matched.append(gu_id)
	return matched


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


static func _apply_loot(state: RunState, loot: Dictionary, catalog: Dictionary, new_loot_pity: int, new_material_pity_by_tier: Dictionary) -> RunState:
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
			"before": {"material_pity_by_tier": state.material_pity_by_tier.duplicate(true)},
			"after": {"materials": after, "material_pity_by_tier": new_material_pity_by_tier.duplicate(true)},
			"reason": "loot_materials_gained",
			"source": "loot_resolver",
			"targets": material_ids,
		})
		next.materials = after
		next.material_pity_by_tier = new_material_pity_by_tier.duplicate(true)
	var gu_id := str(loot.get("gu_id", ""))
	if not gu_id.is_empty():
		next = _gain_gu(next, gu_id, catalog, new_loot_pity)
	return next


static func _gain_gu(state: RunState, gu_id: String, _catalog: Dictionary, new_loot_pity: int) -> RunState:
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	var instance_id := _next_instance_id(instances)
	instances[instance_id] = GuInstanceScript.new_instance(gu_id, instance_id, _catalog)
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
