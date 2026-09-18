class_name CultivatorRules
extends RefCounted


# Spec-v4 phase-2 (T3.2): cultivator model - true-yuan activation gate
# (§11.2), down-rank cost and natural recovery (§11.4), thought capacity
# (§12.1) and the mortal body (§14.1). Pure static rules; every tuning value
# comes from balance.json through GuBalance projections (already in the drift
# gate): this module only gates eligibility and projects the per-cultivator
# surface. The legacy essence-action-point path (cave_aperture
# essence_regen_per_turn etc.) is untouched here and retired by T10.1-⑤.


const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")

# §2.3 open dao tags: the wisdom tag drives the §12.1 thought bonus. Shipped
# content carries no wisdom-tagged gu yet, so the bonus is 0 until the wisdom
# content batch defines the per-cultivator accumulation.
const WISDOM_TAG := "wisdom"


static func _balance(cat: Dictionary, key: String, fallback: float) -> float:
	return float(cat.get("balance", {}).get(key, fallback))


# §11.2: ordinary low-turn true yuan cannot drive a higher-turn gu; rare gu
# explicitly grant themselves the low_rank_exception.
static func can_activate(cultivator_rank: int, gu_rank: int, low_rank_exception: bool = false) -> bool:
	return low_rank_exception or cultivator_rank >= gu_rank


# §11.2 down-rank cost: thin delegate - the formula lives in GuBalance only
# (the growth gate flags any second implementation). Only meaningful when the
# cultivator is eligible to activate (see can_activate).
static func actual_cost_percent(native_cost_percent: float, gu_rank: int, cultivator_rank: int, cat: Dictionary) -> float:
	return GuBalanceScript.actual_cost_percent(native_cost_percent, gu_rank, cultivator_rank, cat)


# §11.4 natural recovery rate by aptitude percent: thin delegate.
static func natural_recovery(aptitude_percent: float, cat: Dictionary) -> float:
	return GuBalanceScript.natural_recovery(aptitude_percent, cat)


# §12.1 thought capacity: 3 base + wisdom-gu bonus. Thoughts are wholly
# separate from soul - this projection never reads soul or soul_capacity.
# The base rides balance.json (thought_base_capacity); the bonus is
# catalog-driven (wisdom-tagged gu). The cultivator argument is accepted for
# the future per-cultivator hooks (statuses etc.) and is intentionally unused
# today - the whole point of the §12.1/#5 anchor is zero soul coupling.
static func thought_capacity(_cultivator: Dictionary, catalog: Dictionary) -> int:
	return int(_balance(catalog, "thought_base_capacity", 3.0)) + wisdom_bonus(catalog)


# Catalog-rebuild 2026-09: the batch pools tag every school member with the
# generic {school, role} pair, so counting every wisdom-tagged gu would hand
# +40 thoughts for a whole wisdom school. The §12.1 bonus is meant for
# *curated* wisdom insight gu (authored entries whose tags go beyond the
# generic pair); the batch members stay silent until such gu are authored.
static func wisdom_bonus(catalog: Dictionary) -> int:
	var count := 0
	for gu in catalog.get("gu", []):
		var tags: Array = gu.get("tags", [])
		if not tags.has(WISDOM_TAG):
			continue
		if tags.size() == 2 \
				and tags.has(str(gu.get("school", ""))) \
				and tags.has(str(gu.get("role", ""))):
			continue
		count += 1
	return count


# §14.1 mortal body: health / strength / body_capacity project from the
# human_base_* anchors; ascension (转数/资历) never grows any of them. The
# cultivator argument is accepted for the future correction hooks and is
# intentionally unused today.
static func body(_cultivator: Dictionary, cat: Dictionary) -> Dictionary:
	return {
		"health": _balance(cat, "human_base_health", 100.0),
		"strength": _balance(cat, "human_base_strength", 100.0),
		"body_capacity": _balance(cat, "human_base_body_capacity", 100.0),
	}
