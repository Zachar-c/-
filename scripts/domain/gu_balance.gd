class_name GuBalance
extends RefCounted


# Spec-v4 central balance module (T1.2 skeleton, T2.1 formula bodies).
# All tuning parameters live in data/balance.json as the single source of
# truth (schema-guarded by ContentCatalog.validate); this module only projects
# the formulas from §10/§11/§14 of the 2026-09-01 spec. No hardcoded
# multiplier tables or value arrays anywhere else.


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
static func rank_multiplier(rank: int, cat: Dictionary) -> float:
	return pow(_b(cat, "rank_step_ratio", 2.0), maxi(1, rank) - 1)


# §10.3 standard_gu_power(rank) = human_base_health * standard_hit_ratio * rank_step_ratio ^ rank.
static func standard_gu_power(rank: int, cat: Dictionary) -> float:
	return _b(cat, "human_base_health", 100.0) * _b(cat, "standard_hit_ratio", 0.2) \
			* pow(_b(cat, "rank_step_ratio", 2.0), maxi(0, rank))


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
