class_name EssenceCapacity
extends RefCounted

# Essence cap formula (ruled 2026-08-25):
# essence_max = floor(stage_essence_base(rank_tier) * aptitude_pct / 100).

static func essence_max(state: RunState, catalog: Dictionary) -> int:
	return essence_max_for(state, catalog, int(state.cultivation))


static func essence_max_for(state: RunState, catalog: Dictionary, cultivation_value: int) -> int:
	var data: Dictionary = catalog.get("aptitude", {})
	var tier := rank_tier_for(data, cultivation_value)
	var base := int(data.get("stage_essence_base", {}).get(tier, 4))
	var pct := int(data.get("aptitude_pct", {}).get(str(state.aptitude), 100))
	return floori(float(base) * float(pct) / 100.0)


static func rank_tier_for(data: Dictionary, cultivation_value: int) -> String:
	var tiers: Dictionary = data.get("rank_tier", {})
	if tiers.has(str(cultivation_value)):
		return str(tiers[str(cultivation_value)])
	return "peak"