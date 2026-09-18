class_name SchoolRules
extends RefCounted

# Pure helpers backing the three-school framework (blood / qi / force).
# Battle-local effects live on the battle dict; cultivation-scoped effects
# live on the cultivator record and the immutable event log.
# 2026-09-09 (W11 measure 4): drain_blood_stacks / overchannel_benefit /
# apply_overchannel_soul removed as dead code - zero production callers and
# the overchannel rules (old R4.7/R2.3) have no implementation anywhere in
# the V1 engine. is_soul stays: relic_hook_resolver reads it. The blood-stack
# helpers and material_fuel are kept as contract stubs pinned by
# test_school_framework (B1 bucket C) until a school effect needs them.


static func blood_stacks(battle: Dictionary) -> int:
	return int(battle.get("blood_stacks", 0))


static func add_blood_stacks(battle: Dictionary, amount: int) -> int:
	battle["blood_stacks"] = maxi(0, blood_stacks(battle) + amount)
	return blood_stacks(battle)


# ── 剑道跨回合剑意（任务书 T8，2026-09-11）────────────────────────────
# 与回合内 turn_supports（v1_battle_resolver，end_turn 清零）是两个独立通道：
# sword_intent 跨回合存续、上限 5、回合末按 50% 向下取整保留。
# 与 blood_stacks 同形状（契约桩：引擎接线按血道先例逐批跟进）。
const SWORD_INTENT_CAP := 5


static func sword_intent(battle: Dictionary) -> int:
	return int(battle.get("sword_intent", 0))


static func add_sword_intent(battle: Dictionary, amount: int) -> int:
	battle["sword_intent"] = clampi(sword_intent(battle) + amount, 0, SWORD_INTENT_CAP)
	return sword_intent(battle)


static func decay_sword_intent(battle: Dictionary) -> int:
	## 回合末衰减：保留 50% 向下取整（5→2→1→0）。
	battle["sword_intent"] = sword_intent(battle) / 2
	return sword_intent(battle)


# ── 身上道痕：体印 → 图谱节点的转义（T10，2026-09-12）──────────────────
# 依据：specs/2026-09-11-gu-knowledge-graph.md §1-L2「身上道痕」（属性 = 道归属 school
# + 层数/深浅）与 §2 关系表（承载 / 属于 / 共鸣 / 排斥）；
# specs/2026-09-11-gu-everything-mapping.md §3（容器用 body_imprints，不新建系统）。
#
# 转义边界（这是本步唯一的语义判断）：体印 id 形如 `mark_<school>` 的才是**道痕**；
# `iron_bone` / `ice_skin` / `three_watch` 这类淬体体印**不进图谱**——它们没有道归属。
# 层数 = 该道的 `mark_<school>*` 条目数（同一 id 不可重复取得，故今日上限为 1；
# 后续 G1 登记更多同道条目（如 `mark_sword_deep`）即自然增层）。
const MARK_PREFIX := "mark_"


static func school_of_mark(imprint_id: String) -> String:
	## 体印 id → 道归属；非道痕体印返回 ""（不进图谱）。
	if not imprint_id.begins_with(MARK_PREFIX):
		return ""
	var rest := imprint_id.substr(MARK_PREFIX.length())
	if rest.is_empty():
		return ""
	var cut := rest.find("_")
	return rest if cut < 0 else rest.substr(0, cut)


static func school_marks(state: RunState) -> Dictionary:
	## 转义：`state.body_imprints` → `{school: 层数}`（图谱 L2「身上道痕」节点集合）。
	var marks := {}
	for imprint_id_value in state.body_imprints:
		var school := school_of_mark(str(imprint_id_value))
		if school.is_empty():
			continue
		marks[school] = int(marks.get(school, 0)) + 1
	return marks


static func mark_layers(state: RunState, school: String) -> int:
	## 单道道痕层数（共鸣增幅的读数入口，见图谱 §4-D6）。
	return int(school_marks(state).get(school, 0))


# ── 兼修代价（T11，2026-09-12）────────────────────────────────────────
# 依据：原文「残留的剑道道痕横霸于此，隔绝了水道道痕」（道痕排斥实例）
# + 图谱 §2「排斥」关系、§4-D6（school_marks / cross_school_penalty）。
# 边界（红线）：只产出**罚值读数 + 命中的互斥对**，不做全局克制倍率（规格 §2.3）；
# 数值与互斥对全部落 data/balance.json，不硬编码在代码里。
static func cross_school_penalty(state: RunState, catalog: Dictionary) -> Dictionary:
	var balance: Dictionary = catalog.get("balance", {})
	var schools: Array = school_marks(state).keys()
	schools.sort()
	if schools.size() < 2:
		return {
			"schools": schools,
			"count": schools.size(),
			"penalty": 0,
			"excluded_pairs": [],
			"reason": "",
		}
	var excluded: Array = []
	for pair_value in balance.get("school_exclusions", []):
		if not (pair_value is Array) or (pair_value as Array).size() != 2:
			continue
		var pair: Array = pair_value
		if schools.has(str(pair[0])) and schools.has(str(pair[1])):
			excluded.append([str(pair[0]), str(pair[1])])
	var per_extra := int(balance.get("cross_school_penalty_per_extra", 1))
	var per_exclusion := int(balance.get("cross_school_exclusion_penalty", 1))
	return {
		"schools": schools,
		"count": schools.size(),
		"penalty": per_extra * (schools.size() - 1) + per_exclusion * excluded.size(),
		"excluded_pairs": excluded,
		"reason": "cross_school_penalty",
	}


static func material_fuel(state: RunState, catalog: Dictionary) -> int:
	var total := 0
	for material_id_value in state.materials:
		total += int(state.materials[material_id_value])
	return total

static func is_soul(state: RunState) -> bool:
	return state.school == "soul"
