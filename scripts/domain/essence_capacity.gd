class_name EssenceCapacity
extends RefCounted

# Essence formula (ruled 2026-08-31):
# essence_max = essence_base(10) * aptitude_factor(jia4/yi3/bing2/ding1)
#               * cultivation_factor(1:3:9:27:81 for rank 1..5).
# Per-turn regen = floor(essence_max * regen_pct / 100), regen_pct follows
# the same 4:3:2:1 aptitude ladder (40/30/20/10).

static func essence_max(state: RunState, catalog: Dictionary) -> int:
	return essence_max_for(state, catalog, int(state.cultivation))


static func essence_max_for(state: RunState, catalog: Dictionary, cultivation_value: int) -> int:
	var data: Dictionary = catalog.get("aptitude", {})
	var base := int(data.get("essence_base", 10))
	var apt := int(data.get("aptitude_factor", {}).get(str(state.aptitude), 2))
	var cult := int(data.get("cultivation_factor", {}).get(str(maxi(1, cultivation_value)), 1))
	return base * apt * cult


static func regen_pct(state: RunState, catalog: Dictionary) -> int:
	var data: Dictionary = catalog.get("aptitude", {})
	return int(data.get("regen_pct", {}).get(str(state.aptitude), 20))
