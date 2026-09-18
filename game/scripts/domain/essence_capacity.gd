class_name EssenceCapacity
extends RefCounted

# Essence formula (ruled 2026-08-31):
# essence_max = essence_base(10) * aptitude_factor(jia4/yi3/bing2/ding1)
#               * cultivation_factor(1:3:9:27:81 for rank 1..5).
# Per-turn regen = floor(essence_max * regen_pct / 100), regen_pct follows
# the same 4:3:2:1 aptitude ladder (40/30/20/10).

static func essence_max(state: RunState, catalog: Dictionary) -> int:
	return essence_max_for(state, catalog, int(state.cultivation))


static func essence_max_for(state: RunState, catalog: Dictionary, cultivation_value: int) -> int:
	var data: Dictionary = catalog.get("aptitude", {})
	var base := int(data.get("essence_base", 10))
	var apt := int(data.get("aptitude_factor", {}).get(str(state.aptitude), 2))
	var cult := int(data.get("cultivation_factor", {}).get(str(maxi(1, cultivation_value)), 1))
	return base * apt * cult


static func regen_pct(state: RunState, catalog: Dictionary) -> int:
	var data: Dictionary = catalog.get("aptitude", {})
	return int(data.get("regen_pct", {}).get(str(state.aptitude), 20))


# ── 元石 → 真元（T13，2026-09-12）────────────────────────────────────
# 原文元石的第二职能：「用元石补充真元」（元石「凝聚着天然真元，可以被蛊师吸收」）。
# 依据：specs/2026-09-11-gu-knowledge-graph.md §2「补充」关系与 §5-L5
#   （元石与真元不是两套系统）；specs/2026-09-11-sword-cosmology-integration.md §7
#   （剑道的「快」以元石为燃料 ⇒ 爆发带经济代价）。
# 口径：吸收效率**复用既有钩子** natural_recovery(资质%)（其系数来自
#   balance.aptitude_recovery_multiplier）——资质越高，吸收越充分；
#   每颗元石的基准真元 = balance.stone_to_essence_per_stone。
# 纯函数：只产出转换读数，不改 state（接线沿用既有 before/after 过渡形状）。
# 三条硬约束：真元不超 essence_max、元石不为负、不浪费元石（按容量向下取整）。
static func stone_to_essence(state: RunState, stones: int, catalog: Dictionary) -> Dictionary:
	if stones <= 0:
		return {"ok": false, "reason": "invalid_stone_amount", "stones_spent": 0, "essence_gain": 0}
	if stones > int(state.stone):
		return {"ok": false, "reason": "insufficient_stone", "stones_spent": 0, "essence_gain": 0}
	var balance: Dictionary = catalog.get("balance", {})
	var rate := GuBalance.natural_recovery(float(regen_pct(state, catalog)), catalog)
	var per_stone := maxi(1, int(floor(float(balance.get("stone_to_essence_per_stone", 5)) * rate)))
	var capacity := maxi(0, essence_max(state, catalog) - int(state.essence))
	# 向下取整：可换满容量的最大颗数，既不超上限也不浪费元石。
	var max_useful := capacity / per_stone
	if max_useful <= 0:
		return {"ok": false, "reason": "essence_full", "stones_spent": 0, "essence_gain": 0}
	var spent := mini(stones, max_useful)
	var gain := spent * per_stone
	return {
		"ok": true,
		"reason": "",
		"stones_spent": spent,
		"essence_gain": gain,
		"essence_after": int(state.essence) + gain,
		"stone_after": int(state.stone) - spent,
		"per_stone": per_stone,
		"clamped": spent < stones,
	}
