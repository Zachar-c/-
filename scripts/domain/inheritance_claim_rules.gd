class_name InheritanceClaimRules
extends RefCounted

## S3 遗葬门控传承：三选项门槛（同转阶侦察蛊 / 传承信物 / 离开走 leave_node）。
## 继承产出按站点品质权重种子化判定：残破（1--2 只蛊）/普通（3--4 只蛊
## +1--2 份蛊方）/稀有（5--8 只蛊+3--4 份蛊方）；蛊取同等级随机蛊入洞天，
## 蛊方取 level+1 转随机 fixed 方入 global_codex_ids（局内解锁）。超级传承
## 暂不实现（用户裁定 2026-09-06）。独立模块以守住 resolver 行数门限。

const EconomyRulesScript = preload("res://scripts/domain/economy_rules.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")


static func claim(state: RunState, action_id: String, catalog: Dictionary) -> Dictionary:
	var node_id := str(state.current_node_id)
	var site: Dictionary = catalog.get("inheritance_site_by_id", {}).get(node_id, {})
	# 拓扑 v2：路由节点是实例 id，站点按模板 id 登记在站点表。
	if site.is_empty():
		site = catalog.get("inheritance_site_by_id", {}).get(str(state.current_node_template_id), {})
	if site.is_empty():
		return _rejected(state, "no_inheritance_site")
	var claimed_key := "%s_claimed" % node_id
	if str(state.node_flags.get(claimed_key, "")) == "true":
		return _rejected(state, "site_already_claimed")
	var level := int(site.get("level", 1))
	if action_id == "claim_recon" and not has_scout_gu(state, catalog, level):
		return _rejected(state, "inheritance_scout_required")
	if action_id == "claim_token" and int(state.materials.get("inheritance_token", 0)) < 1:
		return _rejected(state, "inheritance_token_required")
	var weights: Dictionary = site.get("quality_weights", {"rare": 10, "common": 30, "broken": 60})
	var quality := "broken"
	if roll_chance(state, int(weights.get("rare", 0)), "inheritance_quality_rare"):
		quality = "rare"
	elif roll_chance(state, int(weights.get("common", 0)), "inheritance_quality_common"):
		quality = "common"
	var gu_bounds: Dictionary = {"broken": [1, 2], "common": [3, 4], "rare": [5, 8]}
	var recipe_bounds: Dictionary = {"broken": [0, 0], "common": [1, 2], "rare": [3, 4]}
	var gu_target := int(gu_bounds[quality][0]) + (1 if roll_chance(state, 50, "inheritance_gu_extra") else 0)
	var recipe_target := int(recipe_bounds[quality][0])
	if int(recipe_bounds[quality][1]) > int(recipe_bounds[quality][0]):
		# 残破传承不给蛊方；普通/稀有在区间内做种子化上探。
		recipe_target += 1 if roll_chance(state, 50, "inheritance_recipe_extra") else 0
	var gu_pool: Array[String] = []
	for gu_value in catalog.get("gu", []):
		var gdef: Dictionary = gu_value
		if int(gdef.get("rank", 0)) == level and not str(gdef.get("id", "")).is_empty():
			gu_pool.append(str(gdef.get("id", "")))
	gu_pool.sort()
	var granted_gu: Array[String] = []
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	var pick_round := 0
	while granted_gu.size() < gu_target and not gu_pool.is_empty():
		var pick_idx := _seeded_pool_index(state, gu_pool.size(), "inheritance_pick_%d" % pick_round)
		pick_round += 1
		var gu_id := str(gu_pool[pick_idx])
		gu_pool.remove_at(pick_idx)
		var instance_id := _next_instance_id(instances)
		instances[instance_id] = GuInstanceScript.new_instance(gu_id, instance_id, catalog)
		stored.append(instance_id)
		granted_gu.append(gu_id)
	aperture["stored_gu_instance_ids"] = stored
	var recipe_pool: Array[String] = []
	for recipe_value in catalog.get("refinement_recipes", []):
		var recipe: Dictionary = recipe_value
		if int(recipe.get("output_rank", 0)) == level + 1 and str(recipe.get("kind", "")) == "fixed":
			recipe_pool.append(str(recipe.get("id", "")))
	recipe_pool.sort()
	var granted_recipes: Array[String] = []
	pick_round = 0
	var codex := state.global_codex_ids.duplicate(true)
	while granted_recipes.size() < recipe_target and not recipe_pool.is_empty():
		var recipe_pick := _seeded_pool_index(state, recipe_pool.size(), "inheritance_recipe_%d" % pick_round)
		pick_round += 1
		granted_recipes.append(str(recipe_pool[recipe_pick]))
		recipe_pool.remove_at(recipe_pick)
	for recipe_id in granted_recipes:
		if not codex.has(recipe_id):
			codex.append(recipe_id)
	var flags := state.node_flags.duplicate(true)
	flags[claimed_key] = "true"
	var next := state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": node_id,
		"action": "inheritance_claimed",
		"before": {
			"node_flags": state.node_flags,
			"gu_instances": state.gu_instances,
			"cave_aperture": state.cave_aperture,
			"global_codex_ids": state.global_codex_ids,
		},
		"after": {
			"node_flags": flags,
			"gu_instances": instances,
			"cave_aperture": aperture,
			"global_codex_ids": codex,
		},
		"reason": "inheritance_claimed_%s" % quality,
		"source": "inheritance_claim_rules",
		"targets": [],
	})
	next.node_flags = flags
	next.gu_instances = instances
	next.cave_aperture = aperture
	next.global_codex_ids = codex
	next.sync_legacy_gu_projections()
	return {"state": next, "result": {"ok": true, "quality": quality, "granted_gu": granted_gu, "granted_recipes": granted_recipes}}


## 侦察蛊门槛：role=="recon"（重建目录）或 slot_role=="scout"（存量蛊），转阶达标即可。
static func has_scout_gu(state: RunState, catalog: Dictionary, level: int) -> bool:
	for instance_value in state.gu_instances.values():
		var inst: Dictionary = instance_value
		var gdef: Dictionary = catalog.get("gu_by_id", {}).get(str(inst.get("definition_id", "")), {})
		var is_scout := str(gdef.get("role", "")) == "recon" or str(gdef.get("slot_role", "")) == "scout"
		if is_scout and int(gdef.get("rank", 0)) >= level:
			return true
	return false


## 种子化池内取一：对有序池做累计阈值判定，同种子同池同序结果一致。
static func _seeded_pool_index(state: RunState, pool_size: int, salt: String) -> int:
	var pick_idx := 0
	for pool_i in pool_size:
		if roll_chance(state, int(100.0 * float(pool_i + 1) / float(pool_size)), "%s_idx_%d" % [salt, pool_i]):
			pick_idx = pool_i
	return pick_idx


static func _next_instance_id(instances: Dictionary) -> String:
	var max_index := 0
	for existing_id in instances:
		var digits := ""
		for ch in str(existing_id):
			if ch >= "0" and ch <= "9":
				digits += ch
		if not digits.is_empty() and int(digits) > max_index:
			max_index = int(digits)
	return "gu_%04d" % (max_index + 1)


static func roll_chance(state: RunState, pct: int, salt: String) -> bool:
	return EconomyRulesScript.roll_chance(state, pct, salt)


static func _rejected(state: RunState, reason: String) -> Dictionary:
	return {"state": state, "result": {"ok": false, "reason": reason}}
