class_name SynthesisRules
extends RefCounted

## D1b 古方知识模型：自由配对合炼（零门槛试炼 + 配对稳定映射 + 古方知识）。
## Spec：docs/superpowers/specs/2026-09-06-gu-synthesis-design.md
##
## - 任何两只已炼化蛊（主+辅，同转数）都可入炉，无需持有任何方子。
## - 产物 = 产出道（主蛊主道）× 产出转（主蛊转数+1）域内，由
##   （主蛊 id, 辅蛊 id）的种子无关稳定映射选出的一只——同对永远同果。
## - 古方按产物蛊登记：产物 id 进入 global_codex_ids 即「持有古方」；
##   首次炼成自动授予；持有与否决定预检揭示（产物名 vs "？？？"）。
## - 失败：元石照耗，主蛊受伤（state → weakened，休整可愈）。

const EconomyRulesScript = preload("res://scripts/domain/economy_rules.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")
const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")


## 稳定配对映射（与种子无关的纯函数）：FNV-1a 32 位散列取域内索引。
static func pair_output_id(main_id: String, partner_id: String, catalog: Dictionary) -> String:
	var main: Dictionary = catalog.get("gu_by_id", {}).get(main_id, {})
	if main.is_empty():
		return ""
	var out_rank := int(main.get("rank", 0)) + 1
	if out_rank > 5:
		return ""
	var group: Array[String] = []
	for gu_value in catalog.get("gu", []):
		var gdef: Dictionary = gu_value
		if int(gdef.get("rank", 0)) == out_rank and str(gdef.get("school", "")) == str(main.get("school", "")):
			group.append(str(gdef.get("id", "")))
	if group.is_empty():
		return ""
	group.sort()
	return group[_stable_index("%s|%s" % [main_id, partner_id], group.size())]


## 预检：domain / success_pct / stone_cost / output_id / known（古方持有）/
## output_name 由表现层按 output_id + known 解析（领域层不引 DisplayText）。
static func pair_preview(state: RunState, catalog: Dictionary, main_instance_id: String, partner_instance_id: String) -> Dictionary:
	var result := {
		"ok": false, "reason": "", "executable": false,
		"output_id": "", "output_known": false,
		"success_pct": 0, "stone_cost": 0, "domain": "",
	}
	var main_inst: Dictionary = state.gu_instances.get(str(main_instance_id), {})
	var partner_inst: Dictionary = state.gu_instances.get(str(partner_instance_id), {})
	if main_inst.is_empty() or partner_inst.is_empty():
		result["reason"] = "先选择主蛊与辅蛊。"
		return result
	if str(main_inst.get("state", "")) == "dead" or str(partner_inst.get("state", "")) == "dead":
		result["reason"] = "已死的蛊虫无法入炉。"
		return result
	if str(main_instance_id) == str(partner_instance_id):
		result["reason"] = "主蛊与辅蛊不能是同一只。"
		return result
	var main_def: Dictionary = catalog.get("gu_by_id", {}).get(str(main_inst.get("definition_id", "")), {})
	var partner_def: Dictionary = catalog.get("gu_by_id", {}).get(str(partner_inst.get("definition_id", "")), {})
	if main_def.is_empty() or partner_def.is_empty():
		result["reason"] = "蛊定义缺失。"
		return result
	var main_rank := int(main_def.get("rank", 0))
	if main_rank != int(partner_def.get("rank", 0)):
		result["reason"] = "主蛊与辅蛊必须同转数（当前 %d 转与 %d 转）。" % [main_rank, int(partner_def.get("rank", 0))]
		return result
	if main_rank >= 5:
		result["reason"] = "五转已是顶点，无法再合炼。"
		return result
	var out_rank := main_rank + 1
	var output_id := pair_output_id(str(main_def.get("id", "")), str(partner_def.get("id", "")), catalog)
	if output_id.is_empty():
		result["reason"] = "该流派在 %d 转没有产物蛊。" % out_rank
		return result
	var cfg: Dictionary = catalog.get("balance", {}).get("free_pair", {})
	var success_pct := int(cfg.get("success_pct", {}).get(str(out_rank), 90))
	var stone_cost := int(cfg.get("stone_cost", {}).get(str(out_rank), 50))
	result["ok"] = true
	result["output_id"] = output_id
	result["output_known"] = state.global_codex_ids.has(output_id)
	result["success_pct"] = success_pct
	result["stone_cost"] = stone_cost
	result["domain"] = "%s·%d转" % [str(main_def.get("school", "")), out_rank]
	result["executable"] = state.stone >= stone_cost
	if not result["executable"]:
		result["reason"] = "元石不足：需要 %d 枚。" % stone_cost
	return result


## 执行自由配对合炼：成功 = 消耗双蛊+元石、产出域内蛊、首炼授予古方；
## 失败 = 元石照耗、主蛊受伤（weakened，休整可愈）。
static func execute(state: RunState, catalog: Dictionary, main_instance_id: String, partner_instance_id: String) -> Dictionary:
	var preview := pair_preview(state, catalog, str(main_instance_id), str(partner_instance_id))
	if not bool(preview.get("ok", false)):
		# reason 稳定 code（供事件/测试），detail 携带面向玩家的中文文案。
		return {"state": state, "result": {"ok": false, "reason": "pair_invalid", "detail": str(preview.get("reason", "pair_invalid"))}}
	if not bool(preview.get("executable", false)):
		return {"state": state, "result": {"ok": false, "reason": "insufficient_stone"}}
	if 2 > SoulCapacityScript.craft_cap(state):
		return {"state": state, "result": {"ok": false, "reason": "refinement_capacity_exceeded"}}
	var output_id := str(preview["output_id"])
	var success_pct := int(preview["success_pct"])
	var stone_cost := int(preview["stone_cost"])
	var main_key := str(main_instance_id)
	var partner_key := str(partner_instance_id)
	var success := roll_chance(state, success_pct, "free_pair_%s_%s" % [main_key, partner_key])
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	var codex := state.global_codex_ids.duplicate(true)
	var before := {
		"stone": int(state.stone),
		"gu_instances": state.gu_instances,
		"cave_aperture": state.cave_aperture,
		"global_codex_ids": state.global_codex_ids,
	}
	var consumed_ids: Array[String] = [
		str(instances[main_key].get("definition_id", "")),
		str(instances[partner_key].get("definition_id", "")),
	]
	if success:
		instances.erase(main_key)
		instances.erase(partner_key)
		stored.erase(main_key)
		stored.erase(partner_key)
		var instance_id := RunState.next_gu_instance_id(instances)
		instances[instance_id] = GuInstanceScript.new_instance(output_id, instance_id, catalog)
		stored.append(instance_id)
		aperture["stored_gu_instance_ids"] = stored
		var fang_granted := not codex.has(output_id)
		if fang_granted:
			codex.append(output_id)
		var next := state.append_event({
			"stage": state.stage,
			"time": state.event_log.size(),
			"node_id": state.current_node_id,
			"action": "free_pair_refined",
			"before": before,
			"after": {
				"stone": int(state.stone) - stone_cost,
				"gu_instances": instances,
				"cave_aperture": aperture,
				"global_codex_ids": codex,
			},
			"reason": "free_pair_success",
			"source": "synthesis_rules",
			"targets": consumed_ids,
		})
		next.stone = int(state.stone) - stone_cost
		next.gu_instances = instances
		next.cave_aperture = aperture
		next.global_codex_ids = codex
		next.sync_legacy_gu_projections()
		return {"state": next, "result": {
			"ok": true, "output_id": output_id, "gu_fang_granted": fang_granted,
			"success_pct": success_pct, "stone_cost": stone_cost,
		}}
	# 失败：主蛊受伤（weakened 仍可战，休整可愈），双蛊保留，元石照耗。
	instances[main_key]["state"] = "weakened"
	var failed := state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "free_pair_refined",
		"before": before,
		"after": {
			"stone": int(state.stone) - stone_cost,
			"gu_instances": instances,
			"cave_aperture": state.cave_aperture,
			"global_codex_ids": codex,
		},
		"reason": "free_pair_failure",
		"source": "synthesis_rules",
		"targets": consumed_ids,
	})
	failed.stone = int(state.stone) - stone_cost
	failed.gu_instances = instances
	failed.sync_legacy_gu_projections()
	return {"state": failed, "result": {
		"ok": false, "reason": "free_pair_failed", "injured_main": true,
		"success_pct": success_pct, "stone_cost": stone_cost,
	}}


static func roll_chance(state: RunState, pct: int, salt: String) -> bool:
	return EconomyRulesScript.roll_chance(state, pct, salt)


static func _stable_index(key: String, size: int) -> int:
	var h := 2166136261
	for byte in key.to_utf8_buffer():
		h = ((h ^ int(byte)) * 16777619) & 0xFFFFFFFF
	return h % size


## L0 2026-09-22：战中合卡产出保留到战后——写入 gu_card_overrides（RunState 持久字段），
## 不进 battle 临时表，战斗结束不清理。
static func battle_synthesize(state: RunState, catalog: Dictionary, recipe_id: String) -> Dictionary:
	var synthesis: Dictionary = catalog.get("synthesis", {})
	var recipe: Dictionary = {}
	for entry_value in synthesis.get("battle_recipes", []):
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == str(recipe_id):
			recipe = entry
			break
	if recipe.is_empty():
		return {"state": state, "result": {"ok": false, "reason": "unknown_battle_recipe"}}
	var output_card := str(recipe.get("output_card_id", recipe.get("temp_card_id", "")))
	if output_card.is_empty():
		return {"state": state, "result": {"ok": false, "reason": "missing_output_card"}}
	var cost: Dictionary = recipe.get("material_cost", {})
	var before_materials := state.materials.duplicate(true)
	for material_id_value in cost.keys():
		var material_id := str(material_id_value)
		var need := int(cost[material_id_value])
		if int(state.materials.get(material_id, 0)) < need:
			return {"state": state, "result": {"ok": false, "reason": "insufficient_materials"}}
	var materials := state.materials.duplicate(true)
	for material_id_value in cost.keys():
		materials[str(material_id_value)] = int(materials.get(str(material_id_value), 0)) - int(cost[material_id_value])
	var cfg: Dictionary = synthesis.get("battle", {})
	var base := int(cfg.get("success_base_pct", 60))
	var streak := int(state.synthesis_fail_streak)
	var bonus := mini(int(cfg.get("max_bonus_pct", 30)), streak * int(cfg.get("per_fail_bonus_pct", 10)))
	var chance := clampi(base + bonus, 0, 99)
	var success := roll_chance(state, chance, "battle_synthesize_%s" % str(recipe_id))
	var overrides := state.gu_card_overrides.duplicate(true)
	var before_overrides := state.gu_card_overrides.duplicate(true)
	if success:
		var override: Dictionary = overrides.get(output_card, {}).duplicate(true)
		override["unlocked"] = true
		override["source"] = "battle_synthesis"
		override["persists_after_battle"] = true
		overrides[output_card] = override
		var next := state.append_event({
			"stage": state.stage,
			"time": state.event_log.size(),
			"node_id": state.current_node_id,
			"action": "battle_synthesize",
			"before": {"materials": before_materials, "gu_card_overrides": before_overrides},
			"after": {"materials": materials, "gu_card_overrides": overrides},
			"reason": "battle_synthesis_succeeded",
			"source": "synthesis_rules",
			"targets": [output_card],
		})
		next.materials = materials
		next.gu_card_overrides = overrides
		next.synthesis_fail_streak = 0
		return {"state": next, "result": {
			"ok": true, "output_card": output_card, "chance": chance,
			"persists_after_battle": true,
		}}
	var failed := state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "battle_synthesize",
		"before": {"materials": before_materials, "gu_card_overrides": before_overrides},
		"after": {"materials": materials, "gu_card_overrides": before_overrides},
		"reason": "battle_synthesis_failed",
		"source": "synthesis_rules",
		"targets": [output_card],
	})
	failed.materials = materials
	failed.synthesis_fail_streak = int(state.synthesis_fail_streak) + 1
	return {"state": failed, "result": {
		"ok": false, "reason": "battle_synthesis_failed", "chance": chance,
	}}
