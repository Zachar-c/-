class_name RewardSnapshot
extends RefCounted


# W12 split: the Reward (loot confirmation) screen snapshot, moved verbatim
# from run_snapshot_builder.gd. Read-only projection; multi-screen shared
# helpers stay on RunSnapshotBuilder.


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
	return out
