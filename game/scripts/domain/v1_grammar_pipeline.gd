class_name V1GrammarPipeline
extends RefCounted


## Effect Grammar V2 管线（唯一权威：docs/q8/GU_EFFECT_GRAMMAR_V2_FINAL.md §1、§12）。
## Q8-IMPLEMENT Step 2（2026-09-12）：gate 骨架 + cost commit 前短路（H1）。
## Q8-IMPLEMENT Step 3（2026-09-12）：selector 三选择器 + condition 三谓词 +
## consume_status modifier（H2 原子事务的 gate 验证步与定参公式）。
## 行为零漂移：48 只显式蛊基线（tests/unit/test_q8_grammar_baseline.gd，378 asserts）
## 逐只保持绿是合入前置。
##
## 管线（R2 验收定稿 + H1 硬约束）：
##   can_activate -> trigger -> condition(false -> 结束) -> cost commit -> selector -> modifier -> operation
## gate 段（本文件，cost commit 之前，miss 零消耗，调用方落事件）：
##   trigger -> condition -> selector 合法性 -> consume_status 资格。
## 结算段（v1_battle_resolver._apply_effect）：
##   selector 解析 -> modifier.prepare（consume_status 定参）-> operation ->
##   modifier.commit（consume 清除 / support 登记）。
##
## Step 3 边界（严禁扩展设计空间）：
##   - selector 冻结集合 self / enemy_first / enemy_all；operation × selector 合法
##     矩阵见 SELECTOR_MATRIX，非法组合 gate 拒绝（零消耗），不静默放行。
##   - H4：enemy_first = 行动队列（enemies 数组序）第一个存活目标——不是数组
##     第一个元素（不查存活），更不是「最危险敌人」。
##   - 遗留兼容：effect.aoe == true 等价 selector "enemy_all"（test_slay_gu 现状）。
##   - condition 冻结三谓词 self_hp_below / enemies_alive_gte / turn_gte；
##     未知谓词类型一律资格不成立（零成本 miss），不静默放行。
##   - consume_status 只允许单目标（缺省 / enemy_first）；与 enemy_all 或 aoe 键
##     组合一律 gate 拒绝。本版唯一消费源：敌方 marked（FINAL §3）。
##   - weaken_intent / sealed（Step 4）、delay（Step 5）本文件不出现。


## operation × selector 合法矩阵（"" = 缺省回退，现状语义）。
## weaken_intent：selector 必填、缺省 enemy_first（FINAL §2）。
const SELECTOR_MATRIX := {
	"strike": ["", "enemy_first", "enemy_all"],
	"shield": ["", "self"],
	"heal": ["", "self"],
	"status": ["", "enemy_first"],
	"weaken_intent": ["", "enemy_first"],
	"buff": [""],
	"heal_and_strike": [""],
	"shift": [""],
	"sword_intent": [""],
}


## H1 资格段：cost commit 之前调用。返回空串 = 通过；非空 = miss 原因（零消耗）。
## 顺序即管线：delay 形态锁（schema 级，优先）-> trigger -> condition ->
## selector 合法性 -> consume_status 资格。
static func gate_miss_reason(effect: Dictionary, battle: Dictionary) -> String:
	# Step 5（FINAL §3 delay 形态锁定）：只允许 on_play + delay + operation 一种
	# 形态；与 condition / consume_status / support / 非 on_play 触发器组合一律
	# shape 拒绝（零消耗）。delay.turns 必须 >= 1。shape 校验是 schema 级约束，
	# 优先于其余资格段——组合非法拒绝理由是形态违规，不是条件落空。
	if effect.has("delay"):
		var delay_check: Dictionary = effect["delay"]
		if str(effect.get("trigger", "on_play")) != "on_play":
			return "delay_shape_rejected"
		if effect.has("condition") or effect.has("consume_status") or not str(effect.get("support_school", "")).is_empty():
			return "delay_shape_rejected"
		if int(delay_check.get("turns", 0)) < 1:
			return "delay_shape_rejected"
	var trigger := str(effect.get("trigger", "on_play"))
	if trigger != "on_play":
		# on_turn_end / on_kill 是 FINAL §4 记录的未来候选：批准为候选 != 批准实现。
		return "trigger_unsupported"
	if effect.has("condition"):
		if not evaluate_condition(battle, effect["condition"]):
			return "condition_miss"
	var kind := str(effect.get("kind", ""))
	var selector := str(effect.get("selector", ""))
	var allowed: Array = SELECTOR_MATRIX.get(kind, [""])
	if not allowed.has(selector):
		return "selector_unsupported"
	if effect.has("consume_status"):
		var consume: Dictionary = effect["consume_status"]
		# H2 前置：consume_status 只许单目标；enemy_all / aoe 组合越面拒绝。
		if selector == "enemy_all" or bool(effect.get("aoe", false)):
			return "consume_selector_unsupported"
		# D2：消费落空是零成本资格路径（与 condition miss 同构）。
		var stacks := _consume_stacks_on_first_alive(battle, str(consume.get("name", "marked")))
		if stacks < 1:
			return "consume_miss"
	return ""


## condition 三谓词求值（纯读，无副作用）。未知类型返回 false（资格不成立）。
static func evaluate_condition(battle: Dictionary, condition: Dictionary) -> bool:
	match str(condition.get("type", "")):
		"self_hp_below":
			var max_hp := maxi(1, int(battle["player"].get("max_hp", 1)))
			return float(int(battle["player"]["hp"])) / float(max_hp) < float(condition.get("threshold", 0.5))
		"enemies_alive_gte":
			return alive_count(battle) >= int(condition.get("count", 1))
		"turn_gte":
			return int(battle.get("turn", 1)) >= int(condition.get("turn", 1))
	return false


## selector 解析：返回目标 id 列表（operation 逐个应用）。
## 缺省保持现状回退语义：target_key 有效用之，否则首个存活敌。
static func resolve_targets(battle: Dictionary, effect: Dictionary, target_key: String) -> Array:
	var selector := str(effect.get("selector", ""))
	if bool(effect.get("aoe", false)) or selector == "enemy_all":
		var ids: Array = []
		for enemy_value in (battle.get("enemies", []) as Array):
			var enemy: Dictionary = enemy_value
			if int(enemy.get("hp", 0)) > 0:
				ids.append(str(enemy["id"]))
		return ids
	if selector == "self":
		return ["self"]
	if selector == "enemy_first":
		var alive_index := first_alive_index(battle)
		if alive_index >= 0:
			return [str((battle["enemies"][alive_index] as Dictionary)["id"])]
		return []
	if not str(target_key).is_empty():
		return [str(target_key)]
	var alive_index := first_alive_index(battle)
	if alive_index >= 0:
		return [str((battle["enemies"][alive_index] as Dictionary)["id"])]
	return []


## H2 计算步公式（FINAL §3）：final_amount = base + stacks * per_stack。
static func consume_final_amount(base_amount: int, stacks: int, per_stack: int) -> int:
	return base_amount + stacks * per_stack


static func alive_count(battle: Dictionary) -> int:
	var count := 0
	for enemy_value in (battle.get("enemies", []) as Array):
		if int((enemy_value as Dictionary).get("hp", 0)) > 0:
			count += 1
	return count


## H4 的实现基元：enemies 数组序第一个 hp > 0 的下标（行动队列第一个存活目标）。
static func first_alive_index(battle: Dictionary) -> int:
	for i in (battle.get("enemies", []) as Array).size():
		if int((battle["enemies"][i] as Dictionary).get("hp", 0)) > 0:
			return i
	return -1


static func _consume_stacks_on_first_alive(battle: Dictionary, status_name: String) -> int:
	var index := first_alive_index(battle)
	if index < 0:
		return 0
	var statuses: Dictionary = (battle["enemies"][index] as Dictionary).get("statuses", {})
	return int(statuses.get(status_name, 0))
