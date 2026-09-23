class_name EconomyRules
extends RefCounted


# Spec-v4 (resolver shrink, pre-phase-2): central buy/sell price and seeded
# chance module migrated out of resolver.gd and re-exposed as one-line
# delegates on Resolver, so ALL existing call sites (Resolver.price_for etc.)
# keep working unchanged. This module only reads catalog/state; it never
# depends on Resolver (avoids a preload cycle with the delegating file).


const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")

# Per-run service usage counters live in node_flags as "svc_used_<id>" strings.
# Single definition point (P0.2): Resolver references this constant instead of
# re-declaring it, so the prefix cannot drift between the two files.
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


## L0 2026-09-22 市价对齐：蛊卖出价唯一入口。基准 = GuBalance.gu_value
## （gu_value_by_rank 中央表），再叠 sell_price_for 声望/回访系数。
## 预览与结算必须同调本函数，禁止各报一个数。
static func gu_sell_price(catalog: Dictionary, state: RunState, gu: Dictionary, instance_rank: int) -> int:
	var base := int(GuBalanceScript.gu_value(gu, maxi(1, instance_rank), catalog))
	return sell_price_for(catalog, state, base)


## 材料卖出价唯一入口：挂牌 value 经 sell_price_for；预览/结算共用。
static func material_sell_price(catalog: Dictionary, state: RunState, material_id: String) -> int:
	var materials: Dictionary = catalog.get("loot_tables", {}).get("materials", {})
	var base := int(materials.get(material_id, {}).get("value", 0))
	if base <= 0:
		return 0
	return sell_price_for(catalog, state, base)


# 2026-09-05 从 resolver.gd 迁出的资源交易门禁与数值结算（T1.2 行数门限：
# 新规则独立模块）。返回 {error} 表示拒绝且不得改动任何状态；成功返回
# {cultivator, health, max_health, node_flags} 结算后状态（输入不被修改）。
static func resource_trade_plan(offer: Dictionary, cultivator: Dictionary, health: int, max_health: int, node_flags: Dictionary) -> Dictionary:
	var offer_id := str(offer.get("id", ""))
	if offer_id.is_empty():
		return {"error": "resource_trade_unknown"}
	# 一次门禁：以 offer_id 为 key 写在 node_flags，第二次访问拒且不改 state。
	if str(node_flags.get(offer_id, "")) == "used":
		return {"error": "resource_trade_already_used"}
	var cost_kind := str(offer.get("cost_kind", ""))
	var gain_kind := str(offer.get("gain_kind", ""))
	var cost_amount := int(offer.get("cost_amount", 0))
	var gain_amount := int(offer.get("gain_amount", 0))
	var next_cultivator := cultivator.duplicate(true)
	var health_after := health
	var max_health_after := max_health
	if cost_kind == "lifespan":
		var lifespan := int(next_cultivator.get("lifespan", 0))
		if lifespan - cost_amount < 1:
			return {"error": "insufficient_lifespan"}
		next_cultivator["lifespan"] = lifespan - cost_amount
	elif cost_kind == "soul":
		var soul := int(next_cultivator.get("soul", 0))
		if soul - cost_amount < 1:
			return {"error": "insufficient_soul"}
		next_cultivator["soul"] = soul - cost_amount
	elif cost_kind == "health":
		if health - cost_amount <= 0:
			return {"error": "insufficient_health"}
		health_after = health - cost_amount
	else:
		return {"error": "resource_trade_unknown"}
	var flags := node_flags.duplicate(true)
	flags[offer_id] = "used"
	if gain_kind == "lifespan":
		next_cultivator["lifespan"] = int(next_cultivator.get("lifespan", 0)) + gain_amount
	elif gain_kind == "soul":
		var soul := int(next_cultivator.get("soul", 0))
		var soul_max := int(next_cultivator.get("soul_max", soul + gain_amount))
		next_cultivator["soul"] = mini(soul + gain_amount, soul_max)
	elif gain_kind == "health":
		max_health_after = max_health + gain_amount
		health_after = min(max_health_after, health_after + gain_amount)
	else:
		return {"error": "resource_trade_unknown"}
	return {"cultivator": next_cultivator, "health": health_after, "max_health": max_health_after, "node_flags": flags}
