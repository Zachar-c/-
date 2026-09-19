class_name GuBalance
extends RefCounted


# Spec-v4 central balance module (T1.2 skeleton, T2.1 formula bodies).
# All tuning parameters live in data/balance.json as the single source of
# truth (schema-guarded by ContentCatalog.validate); this module only projects
# the formulas from §10/§11/§14 of the 2026-09-01 spec. No hardcoded
# multiplier tables or value arrays anywhere else.
#
# RUL-2026-09-19-008 D2/D12 (Rank Power Budget,唯一真源):
# rank_power_budget(rank) = rank1_budget * rank_step_ratio^(rank-1), rank 1..5
# -> 40 / 80 / 160 / 320 / 640 (rank1_budget = 100 * 0.2 * 2 = 40,零数值漂移).
# 口径关系(同一条曲线,三种读法):
# - rank_multiplier(rank) = rank_step_ratio^(rank-1)
#   = rank_power_budget(rank) / rank1_budget (无量纲步进比,1/2/4/8/16).
# - standard_gu_power(rank) = human_base_health * standard_hit_ratio * rank_step_ratio^rank
#   = rank_power_budget(rank) (数值恒等,指定为本曲线的唯一真源;本函数仍保留作
#   为战斗/防御侧的具名投影,实现上委托给 rank_power_budget,不再各自算一套).
# 其余曲线已归位(见 balance.json rank_axis_annotations):真元两条归 Essence
# Budget 轴;gu_value_by_rank 归 Economy 轴;boss 层倍率归敌人/关卡系统;进阶奖励
# 归进度/奖励系统;beast_scale 为并列参照系(基数不同,只标注不改值).


static func _b(cat: Dictionary, key: String, fallback: float) -> float:
	return float(cat.get("balance", {}).get(key, fallback))


## 中央蛊虫计价（2026-09-04 经济支配）：卖出/回购基准 = max(定义字面价值,
## gu_value_by_rank[实例转数])。同名升阶让实例转数高于定义时，价值随中央
## 表上浮；表未覆盖的转数回退定义价值。gen_ 批量蛊的价值由 Schema 强制
## 等于表值（ContentCatalog.validate），手工蛊保留设计字面量为下限。
static func gu_value(definition: Dictionary, instance_rank: int, cat: Dictionary) -> int:
	var literal := int(definition.get("value", 0))
	var table: Dictionary = cat.get("balance", {}).get("gu_value_by_rank", {})
	var tiered := int(table.get(str(maxi(1, instance_rank)), literal))
	return maxi(literal, tiered)


# §10.1 rank_multiplier(rank) = rank_step_ratio ^ (rank - 1); rank >= 1.
# RUL-008:本函数是 rank_power_budget 的无量纲读法(= budget(rank)/rank1_budget).
static func rank_multiplier(rank: int, cat: Dictionary) -> float:
	return pow(_b(cat, "rank_step_ratio", 2.0), maxi(1, rank) - 1)


# RUL-2026-09-19-008 D2:唯一的 rank_power_budget(rank)访问点.优先读上游
# balance.json rank_power_budget.budget_by_rank 的具名表(构建器已按公式核对),
# 缺表时按 rank1_budget * step^(rank-1) 现算;其余代码不得再各自算一套.
static func rank1_budget(cat: Dictionary) -> float:
	return _b(cat, "human_base_health", 100.0) * _b(cat, "standard_hit_ratio", 0.2) \
			* _b(cat, "rank_step_ratio", 2.0)


static func rank_power_budget(rank: int, cat: Dictionary) -> float:
	# 公式与 standard_gu_power 恒等:rank1 * step^(rank-1) = human*hit*step^rank.
	# rank 0 (凡人) -> 20,与旧 standard_gu_power(0) 一致;1..5 -> 40/80/160/320/640.
	var expected := rank1_budget(cat) * pow(_b(cat, "rank_step_ratio", 2.0), maxi(0, rank) - 1)
	var upstream: Variant = cat.get("balance", {}).get("rank_power_budget", {})
	if upstream is Dictionary:
		var table: Variant = (upstream as Dictionary).get("budget_by_rank", {})
		if table is Dictionary and (table as Dictionary).has(str(rank)):
			var listed := float((table as Dictionary)[str(rank)])
			# 具名表是公式的物化视图:一致时直接读表,不一致(如调参后)以公式为准,
			# 保证投影永远跟随 balance.json (single source 红线).
			if absf(listed - expected) < 0.0001:
				return listed
	return expected


# RUL-008 HP 基准(D11):standard_human_hp = 100 为 SoT;player_start_hp 为开局
# 显式配置(现 100 = 标准一转肉身的 100%).Godot 开局数值统一经此处读取.
static func standard_human_hp(cat: Dictionary) -> float:
	return _b(cat, "standard_human_hp", _b(cat, "human_base_health", 100.0))


static func player_start_hp(cat: Dictionary) -> float:
	return _b(cat, "player_start_hp", standard_human_hp(cat))


# §10.3 standard_gu_power(rank) = human_base_health * standard_hit_ratio * rank_step_ratio ^ rank.
# RUL-008:数值恒等于 rank_power_budget(rank),指定为其唯一真源;实现委托,不再另写一套公式.
static func standard_gu_power(rank: int, cat: Dictionary) -> float:
	return rank_power_budget(rank, cat)


# §14.3 beast body scale: rank 0 (凡兽) .. 5 (五转) -> 100 .. 3200, the shared
# basis for a beast's health / natural strength / body capacity.
static func beast_scale(rank: int, cat: Dictionary) -> float:
	return _b(cat, "human_base_health", 100.0) \
			* pow(_b(cat, "rank_step_ratio", 2.0), maxi(0, rank))


# §10.3 fixed defense reference: 20% of a same-rank effective heavy hit; can
# reduce damage to zero (no forced minimum).
static func fixed_defense(rank: int, cat: Dictionary) -> float:
	return standard_gu_power(rank, cat) * _b(cat, "fixed_defense_ratio", 0.2)


# §10.5 human standard heal: human_base_health * standard_hit_ratio * rank.
# standard_hit_ratio stays single source (drift-gate token).
static func human_standard_heal(rank: int, cat: Dictionary) -> float:
	return _b(cat, "human_base_health", 100.0) * _b(cat, "standard_hit_ratio", 0.2) * maxi(0, rank)


# §11.2 true-yuan down-rank discount: high-turn cultivators drive lower-turn
# gu at native_cost * rank_multiplier(gu_rank) / rank_multiplier(cultivator_rank).
# The spec applies this only when cultivator_rank >= gu_rank (low-rank
# cultivators cannot drive ordinary higher-rank gu); the projected percent is
# the pure formula, the eligibility guard lives at the call site.
static func actual_cost_percent(native_cost_percent: float, gu_rank: int, cultivator_rank: int, cat: Dictionary) -> float:
	return native_cost_percent * rank_multiplier(gu_rank, cat) / rank_multiplier(cultivator_rank, cat)


# §11.4 natural recovery RATE keyed by aptitude percent (0-100 scale):
# aptitude_recovery_multiplier + aptitude_percent / 100, anchors 20/50/100 -> 0.7/1.0/1.5.
# The per-turn recovered fraction = standard_activation_cost
# * natural_recovery_cost_ratio * this value (~1% at standard aptitude).
static func natural_recovery(aptitude_percent: float, cat: Dictionary) -> float:
	return _b(cat, "aptitude_recovery_multiplier", 0.5) + aptitude_percent / 100.0


# §14.2 unarmed raw damage = actual_strength * unarmed_damage_ratio * action_multiplier.
static func unarmed_raw_damage(actual_strength: float, action_multiplier: float, cat: Dictionary) -> float:
	return actual_strength * _b(cat, "unarmed_damage_ratio", 0.2) * action_multiplier


# §14.2 strength overload: only the portion above body capacity self-damages,
# scaled by unarmed_damage_ratio * standard reaction_multiplier (central
# parameter; explicit gu effects may lower it). At or below capacity: zero.
static func overload_self_damage(actual_strength: float, body_capacity: float, cat: Dictionary) -> float:
	var overload := maxf(0.0, actual_strength - body_capacity)
	return overload * _b(cat, "unarmed_damage_ratio", 0.2) * _b(cat, "reaction_multiplier", 1.0)
