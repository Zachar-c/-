class_name EconomyRules
extends RefCounted


# Spec-v4 (resolver shrink, pre-phase-2): central buy/sell price and seeded
# chance module migrated out of resolver.gd and re-exposed as one-line
# delegates on Resolver, so ALL existing call sites (Resolver.price_for etc.)
# keep working unchanged. This module only reads catalog/state; it never
# depends on Resolver (avoids a preload cycle with the delegating file).


const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")

# Per-run service usage counters live in node_flags as "svc_used_<id>" strings
# (mirrors Resolver.SERVICE_USE_FLAG_PREFIX; kept here so the module is
# self-contained and free of a Resolver dependency).
const SERVICE_USE_FLAG_PREFIX := "svc_used_"


static func service_use_count(state: RunState, service_id: String) -> int:
	return int(str(state.node_flags.get(SERVICE_USE_FLAG_PREFIX + service_id, "0")))


static func service_limit(catalog: Dictionary, service_id: String) -> int:
	# Shipped data validates the limits exist; the default only keeps tuned
	# in-memory catalogs built by tests playable.
	var limits: Dictionary = catalog.get("deck", {}).get("service_limits", {})
	return int(limits.get(service_id, 2))


static func service_price_for(catalog: Dictionary, state: RunState, service_id: String, base: int) -> int:
	var price := price_for(catalog, state, base)
	var uses := service_use_count(state, service_id)
	if uses <= 0:
		return price
	var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
	var per := int(effects.get("service_use_price_pct_per_use", 25))
	var cap := int(effects.get("service_use_price_cap_pct", 100))
	var lift := mini(cap, uses * per)
	return maxi(0, ceili(float(price) * (1.0 + float(lift) / 100.0)))


static func notoriety(state: RunState) -> int:
	return int(state.cultivator.get("notorious", 0))


static func roll_chance(state: RunState, pct: int, salt: String) -> bool:
	var bound := clampi(pct, 0, 100)
	if bound <= 0:
		return false
	if bound >= 100:
		return true
	return SeededRollScript.index(100, int(state.seed), salt, state.event_log.size()) < bound


static func price_for(catalog: Dictionary, state: RunState, base: int) -> int:
	var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
	var notoriety_lift := 0
	if notoriety(state) > 0:
		var pct := int(effects.get("price_pct_per_point", 10))
		var cap := int(effects.get("price_cap_pct", 60))
		notoriety_lift = mini(cap, pct * notoriety(state))
	var revisit_lift := 0
	var visits := int(state.node_flags.get("shop_visits", 0))
	if visits > 1:
		var per := int(effects.get("revisit_price_pct_per_visit", 0))
		var revisit_cap := int(effects.get("revisit_price_cap_pct", 100))
		revisit_lift = mini(revisit_cap, (visits - 1) * per)
	# C1-min §16.13: sworn contracts lift buy prices multiplicatively with the
	# existing inflations; sell prices stay untouched.
	# N1 §16.13 MINOR: the maxi(0, ...) clamp keeps negative (discount) rule
	# values inert on purpose — forward-compatible until §16.13 grows explicit
	# discount keys, then this clamp opens up deliberately.
	var contract_pct := maxi(0, int(ContractRulesScript.aggregate(state, catalog).get("shop_price_pct", 0)))
	return maxi(0, ceili(float(base) * (1.0 + float(notoriety_lift) / 100.0) * (1.0 + float(revisit_lift) / 100.0) * (1.0 + float(contract_pct) / 100.0)))


static func sell_price_for(catalog: Dictionary, state: RunState, base: int) -> int:
	var multiplier := 1.0
	if notoriety(state) > 0:
		var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
		var pct := int(effects.get("price_pct_per_point", 10))
		var cap := int(effects.get("price_cap_pct", 60))
		var uplift := mini(cap, pct * notoriety(state))
		multiplier = 1.0 - float(uplift) / 100.0
	var visits := int(state.node_flags.get("shop_visits", 0))
	if visits > 1:
		var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
		var per := int(effects.get("revisit_price_pct_per_visit", 0))
		var revisit_cap := int(effects.get("revisit_price_cap_pct", 100))
		var discount := mini(revisit_cap, (visits - 1) * per)
		multiplier *= 1.0 - float(discount) / 100.0
	return maxi(1, int(floor(float(base) * multiplier)))