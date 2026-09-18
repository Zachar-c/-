class_name MarketRules
extends RefCounted


# Spec-v4 phase-2 (T6.3): yuanstone scale (§9.1), NPC demand quotes (§9.2),
# gu prices and the big-layer purchase rhythm (§9.3), identity-gated
# exchanges (§3.3) and structured information (§9.4). Pure static,
# deterministic, config-driven - every ratio comes from balance.json.
# Acceptance #18: selling keeps knowledge, spreading decays exclusivity, and
# each buyer pays for the same fact only once.


const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")


static func _b(cat: Dictionary, key: String, fallback: float) -> float:
	return float(cat.get("balance", {}).get(key, fallback))


# ---- §9.1 yuanstone scale ------------------------------------------------

# A 1-turn normal material's public standard buy price.
static func t1_material_base_price(cat: Dictionary) -> float:
	return _b(cat, "stone_per_t1_material", 10.0)


# Standard value of a rank-R normal material = base x rank multiplier.
static func rank_standard_price(material_rank: int, cat: Dictionary) -> float:
	return t1_material_base_price(cat) * float(
			GuBalanceScript.rank_multiplier(maxi(1, material_rank), cat))


# Public liquidity resale: 50% of the standard buy price.
static func public_resale(value: float, cat: Dictionary) -> float:
	return maxf(0.0, value) * _b(cat, "public_buyback_ratio", 0.5)


# Low-liquidity items resale at 30% (never applied to normal circulation).
static func low_liquidity_resale(value: float, cat: Dictionary) -> float:
	return maxf(0.0, value) * _b(cat, "low_liquidity_ratio", 0.3)


# ---- §9.2 NPC demand -------------------------------------------------------

# demand_quote: tier 0/1/2 -> 80% / 100% / 120% of the standard buy price,
# gated by the real demand identity (the caller checks the identity before
# quoting; a quote is not a sale).
static func demand_quote(base_per_unit: float, amount: int, tier: int, cat: Dictionary) -> Dictionary:
	var tiers: Array = cat.get("balance", {}).get("demand_price_tiers", [0.8, 1.0, 1.2])
	var index := clampi(tier, 0, tiers.size() - 1)
	var unit := maxf(0.0, base_per_unit) * float(tiers[index])
	return {"unit_price": unit, "total": unit * float(maxi(0, amount))}


# §9.2: fulfilling a demand advances its state - the quantity drops and a
# fully satisfied demand closes (anti-farming core).
static func advance_demand(demand: Dictionary, fulfilled_amount: int) -> Dictionary:
	var out := demand.duplicate(true)
	var left := maxi(0, int(out.get("quantity", 0)) - maxi(0, fulfilled_amount))
	out["quantity"] = left
	if left <= 0:
		out["closed"] = true
	return out


# ---- §9.3 gu prices --------------------------------------------------------

# A common base gu publicly sells at about 4 same-rank material values and
# recycles at about 1. The big-layer rhythm: after growth and feeding the
# player usually keeps roughly one common-base-gu-level purchase.
static func gu_public_price(gu_rank: int, cat: Dictionary) -> float:
	return rank_standard_price(gu_rank, cat) * 4.0


static func gu_recycle_price(gu_rank: int, cat: Dictionary) -> float:
	return rank_standard_price(gu_rank, cat)


# Reference valuation - distinct from any buy/sell price. A valuation never
# means the gu is buyable with stones. The ratio rides balance.json
# (gu_estimate_ratio); the 4.0/1.0 multipliers above are the spec 9.3 pinned
# values (public ~4x / recycle ~1x same-rank material value).
static func gu_estimate(gu_rank: int, cat: Dictionary) -> float:
	return rank_standard_price(gu_rank, cat) * _b(cat, "gu_estimate_ratio", 6.5)


# ---- §3.3 exchange gate -------------------------------------------------

# No mechanical "top up stones to complete the trade". The screen surfaces
# the permanent-loss list before the second confirmation and marks
# nature-incompatible offers as rejected (ferocious / parasitic / bound /
# fleeing gu may be refused on nature).
static func exchange_screen(offers: Array, _catalog: Dictionary) -> Dictionary:
	var permanent_losses: Array = []
	var rejected_natures := {}
	for offer_value in offers:
		var offer: Dictionary = offer_value
		var instance_id := str(offer.get("instance_id", ""))
		var nature_reject := false
		for key in ["ferocity", "parasitic", "bound"]:
			if float(offer.get(key, 0.0)) > 0.0 or bool(offer.get(key, false)):
				nature_reject = true
		if nature_reject:
			rejected_natures[instance_id] = "nature_incompatible"
			continue
		permanent_losses.append({
			"instance_id": instance_id,
			"definition_id": str(offer.get("definition_id", "")),
			"core_state": offer.get("core_state", {}),
			"unfed_value_note": str(offer.get("unfed_value_note", "")),
		})
	return {"permanent_losses": permanent_losses, "rejected_natures": rejected_natures}


# ---- §9.4 structured information ------------------------------------------

# Deterministic exclusivity decay: each spread halves the residual exclusive
# value; an already-public fact decays toward zero.
static func info_value(info: Dictionary, spread_count: int) -> float:
	var base := maxf(0.0, float(info.get("base_value", 0.0)))
	var decayed := base * pow(0.5, maxi(0, spread_count))
	return decayed


# sell_info: the seller keeps the knowledge; spreading decays the exclusive
# value; every buyer pays for the same fact only once (tracked in sold_to).
static func sell_info(info: Dictionary, buyer_id: String, spread_count: int, sold_to: Dictionary, _cat: Dictionary) -> Dictionary:
	if bool(sold_to.get(buyer_id, false)):
		return {"sold": false, "reason": "buyer_already_paid", "price": 0.0}
	return {
		"sold": true,
		"seller_keeps_knowledge": true,
		"spread_count": spread_count + 1,
		"price": info_value(info, spread_count),
	}
