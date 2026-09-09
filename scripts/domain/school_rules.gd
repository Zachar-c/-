class_name SchoolRules
extends RefCounted

# Pure helpers backing the three-school framework (blood / qi / force).
# Battle-local effects live on the battle dict; cultivation-scoped effects
# live on the cultivator record and the immutable event log.
# 2026-09-09 (W11 measure 4): drain_blood_stacks / overchannel_benefit /
# apply_overchannel_soul removed as dead code - zero production callers and
# the overchannel rules (old R4.7/R2.3) have no implementation anywhere in
# the V1 engine. is_soul stays: relic_hook_resolver reads it. The blood-stack
# helpers and material_fuel are kept as contract stubs pinned by
# test_school_framework (B1 bucket C) until a school effect needs them.


static func blood_stacks(battle: Dictionary) -> int:
	return int(battle.get("blood_stacks", 0))


static func add_blood_stacks(battle: Dictionary, amount: int) -> int:
	battle["blood_stacks"] = maxi(0, blood_stacks(battle) + amount)
	return blood_stacks(battle)


static func material_fuel(state: RunState, catalog: Dictionary) -> int:
	var total := 0
	for material_id_value in state.materials:
		total += int(state.materials[material_id_value])
	return total

static func is_soul(state: RunState) -> bool:
	return state.school == "soul"
