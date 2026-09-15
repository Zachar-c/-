class_name RewardSnapshot
extends RefCounted


# W12 split: the Reward (loot confirmation) screen snapshot, moved verbatim
# from run_snapshot_builder.gd. Read-only projection; multi-screen shared
# helpers stay on RunSnapshotBuilder.


const BuildGoalProjectionScript = preload("res://scripts/presentation/snapshots/build_goal_projection.gd")


## C2/D3 战利品确认屏快照：真实已入账 loot（settle_victory 结果）+ 精英绑定代价
## + 真实保底计数。规格口径：战后战利品自动入账（§16.4 来源隔离由 loot_tables 承担），
## 本屏为确认展示而非再抽取——假三选一快照已删除。
static func build(controller) -> Dictionary:
	var out := RunSnapshotBuilder._gui_state(controller)
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var loot: Dictionary = controller.get("last_battle_loot") if controller.get("last_battle_loot") != null else {}
	var elite_cost: Dictionary = controller.get("last_battle_cost") if controller.get("last_battle_cost") != null else {}
	out["title"] = "战利品"
	var rows: Array[Dictionary] = []
	for material_value in loot.get("material_ids", []):
		rows.append({
			"name": DisplayText.material(str(material_value)),
			"kind": "素材 · 已入账",
			"quality": "普通",
			"effect": "本局材料 +1，用于炼蛊与事件支付。",
			"cost": "",
		})
	var loot_gu := str(loot.get("gu_id", ""))
	if not loot_gu.is_empty():
		var gu_entry: Dictionary = catalog.get("gu_by_id", {}).get(loot_gu, {})
		rows.append({
			"name": DisplayText.gu(loot_gu),
			"kind": "蛊 · 已入蛊囊",
			"quality": str(gu_entry.get("rarity", "普通")),
			"effect": str(gu_entry.get("summary", "获得蛊虫，可在炼蛊台合成。")),
			"cost": "",
		})
	if not elite_cost.is_empty():
		rows.append({
			"name": "精英代价（强制绑定）",
			"kind": "代价 · 已生效",
			"quality": "史诗",
			"effect": DisplayText.elite_cost(elite_cost),
			"cost": "",
			"curse_warning": true,
		})
	out["rewards"] = rows
	out["full_satchel"] = false
	out["pity_note"] = "蛊掉落保底计数：%d · 材料保底计数：%d" % [int(state.loot_pity), int(state.material_pity_by_tier.get("common", 0))]
	# T6-E 空池回退小字：真实 loot 为空即空池回退信号。
	# T6-E 空池回退小字：仅在真实结算过的战斗（loot 字典非空）且未掉落任何条目时
	# 展示；未开战（loot 为空字典）不发常驻假提示。
	out["pool_fallback_note"] = "（空池回退：本场未掉落战利品）" if (not loot.is_empty() and rows.is_empty()) else ""
	# Playable Core Loop（2026-09-15）Phase 3：把本场产出接到当前构筑目标。
	# 只用**已入账**的 loot 派生（不重抽、不改状态）；before 值由「当前库存 − 本场入账」反推。
	out["build_progress"] = _build_progress(state, catalog, loot)
	return out


## 本场战利品 → 构筑目标的进度连接。
## 回答三件事：本场拿到了什么 / 它推进了什么 / 现在能不能做下一步。
static func _build_progress(state, catalog: Dictionary, loot: Dictionary) -> Dictionary:
	var goal: Dictionary = BuildGoalProjectionScript.build_goal(state, catalog)
	var available := bool(goal.get("available", false)) and not loot.is_empty()
	if not available:
		return {
			"available": false,
			"title": "",
			"recipe_id": "",
			"lines": [],
			"stone_gained": 0,
			"stone_before": 0,
			"stone_after": 0,
			"stone_required": 0,
			"ready_before": false,
			"ready_after": false,
			"became_ready": false,
			"next_step_text": "",
		}
	var recipe: Dictionary = catalog.get("refinement_by_id", {}).get(str(goal.get("recipe_id", "")), {})
	if recipe.is_empty():
		return {"available": false, "title": "", "recipe_id": "", "lines": [],
				"stone_gained": 0, "stone_before": 0, "stone_after": 0, "stone_required": 0,
				"ready_before": false, "ready_after": false, "became_ready": false,
				"next_step_text": ""}
	# 本场入账（按材料 id 计数）与元石入账。
	var gained_by_material: Dictionary = {}
	for material_value in loot.get("material_ids", []):
		var material_id := str(material_value)
		gained_by_material[material_id] = int(gained_by_material.get(material_id, 0)) + 1
	var stone_gained := int(loot.get("stone_reward", 0))
	# after = 当前库存；before = after − 本场入账（下限 0）。
	var after_materials: Dictionary = state.materials if state != null else {}
	var before_materials: Dictionary = after_materials.duplicate()
	for material_id in gained_by_material:
		before_materials[material_id] = maxi(0,
				int(before_materials.get(material_id, 0)) - int(gained_by_material[material_id]))
	var stone_after := int(state.stone) if state != null else 0
	var stone_before := maxi(0, stone_after - stone_gained)
	# 输入蛊：本场掉落的蛊若正是目标输入，则「入账前」不持有。
	var input_ready_after := bool(goal.get("input_gu_ready", false))
	var loot_gu := str(loot.get("gu_id", ""))
	var input_gu_id := str(goal.get("input_gu_id", ""))
	var gained_input := not loot_gu.is_empty() and loot_gu == input_gu_id
	var input_ready_before := input_ready_after and not gained_input
	var before: Dictionary = BuildGoalProjectionScript.evaluate_requirements(
			recipe, before_materials, stone_before, input_ready_before, catalog)
	var after: Dictionary = BuildGoalProjectionScript.evaluate_requirements(
			recipe, after_materials, stone_after, input_ready_after, catalog)
	var lines: Array[Dictionary] = []
	for row_value in after["materials"]:
		var row: Dictionary = row_value
		var material_id := str(row["id"])
		lines.append({
			"id": material_id,
			"name": str(row["name"]),
			"gained": int(gained_by_material.get(material_id, 0)),
			"owned_before": maxi(0, int(row["owned"]) - int(gained_by_material.get(material_id, 0))),
			"owned_after": int(row["owned"]),
			"required": int(row["required"]),
			"complete": bool(row["complete"]),
		})
	var ready_before := bool(before["ready"])
	var ready_after := bool(after["ready"])
	var next_step := ""
	if ready_after:
		next_step = "下一步：前往炼蛊台执行「%s」。" % str(goal.get("title", ""))
	else:
		next_step = "下一步：%s（战斗节点可能补齐）。" % str(after["missing_summary"])
	return {
		"available": true,
		"title": str(goal.get("title", "")),
		"recipe_id": str(goal.get("recipe_id", "")),
		"lines": lines,
		"stone_gained": stone_gained,
		"stone_before": stone_before,
		"stone_after": stone_after,
		"stone_required": int(recipe.get("stone_cost", 0)),
		"ready_before": ready_before,
		"ready_after": ready_after,
		"became_ready": ready_after and not ready_before,
		"next_step_text": next_step,
	}
