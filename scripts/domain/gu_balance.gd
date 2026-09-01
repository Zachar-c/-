class_name GuBalance
extends RefCounted


# Spec-v4 phase-1 (T1.2): central balance module. All tuning parameters live
# in data/balance.json as the single source of truth (schema-guarded by
# ContentCatalog.validate); this module only projects the formulas from §10
# /§11 of the 2026-09-01 spec. No hardcoded multiplier tables anywhere else.


static func _b(cat: Dictionary, key: String, fallback: float) -> float:
	return float(cat.get("balance", {}).get(key, fallback))


# §10.1 rank_multiplier(rank) = rank_step_ratio ^ (rank - 1); rank >= 1.
static func rank_multiplier(rank: int, cat: Dictionary) -> float:
	return pow(_b(cat, "rank_step_ratio", 2.0), maxi(1, rank) - 1)


# §10.3 standard_gu_power(rank) = human_base_health * standard_hit_ratio * rank_step_ratio ^ rank.
static func standard_gu_power(rank: int, cat: Dictionary) -> float:
	return _b(cat, "human_base_health", 100.0) * _b(cat, "standard_hit_ratio", 0.2) \
			* pow(_b(cat, "rank_step_ratio", 2.0), maxi(0, rank))


# §10.4 natural beast body scale at rank (used by beast fixed defense budgets).
# T2.1: §10.2 beast body scale covers health/strength/capacity anchors
# (100..3200 scale) — plan signature keeps beast_scale(rank).
static func beast_scale(rank: int, cat: Dictionary) -> float:
	return pow(_b(cat, "rank_step_ratio", 2.0), maxi(0, rank))


# §10.3 fixed defense reference: offset a same-rank effective heavy hit's 20%.
static func fixed_defense(rank: int, cat: Dictionary) -> float:
	return standard_gu_power(rank, cat) * _b(cat, "fixed_defense_ratio", 0.2)


# §10.x human standard heal: human_base_health * standard_hit_ratio * rank.
static func human_standard_heal(rank: int, cat: Dictionary) -> float:
	return _b(cat, "human_base_health", 100.0) * _b(cat, "standard_hit_ratio", 0.2) * maxi(0, rank)


# §11 actual activation cost: base percent scaled by the cost weight
# (light_cost_ratio 0.5 / standard 1.0 / heavy_cost_ratio 2.0).
# T2.1: §11.2 down-rank discount — plan signature becomes
# actual_cost_percent(native, gu_rank, cultivator_rank).
static func actual_cost_percent(base_percent: float, weight: float, cat: Dictionary) -> float:
	return base_percent * weight


# §11 natural recovery cost: standard_activation_cost * natural_recovery_cost_ratio.
# T2.1: §11.4 natural recovery is a recovery RATE keyed by aptitude (anchors
# 0.7 / 1.0 / 1.5) — plan signature becomes natural_recovery(aptitude).
static func natural_recovery(cat: Dictionary) -> float:
	return _b(cat, "standard_activation_cost", 0.1) * _b(cat, "natural_recovery_cost_ratio", 0.1)
