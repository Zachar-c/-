class_name SchoolRules
extends RefCounted

# Pure helpers backing the three-school framework (blood / qi / force).
# Battle-local effects live on the battle dict; cultivation-scoped effects
# live on the cultivator record and the immutable event log.


static func blood_stacks(battle: Dictionary) -> int:
	return int(battle.get("blood_stacks", 0))


static func add_blood_stacks(battle: Dictionary, amount: int) -> int:
	battle["blood_stacks"] = maxi(0, blood_stacks(battle) + amount)
	return blood_stacks(battle)


static func drain_blood_stacks(battle: Dictionary, amount: int) -> int:
	battle["blood_stacks"] = maxi(0, blood_stacks(battle) - amount)
	return blood_stacks(battle)


static func material_fuel(state: RunState, catalog: Dictionary) -> int:
	var total := 0
	for material_id_value in state.materials:
		total += int(state.materials[material_id_value])
	return total

static func is_soul(state: RunState) -> bool:
	return state.school == "soul"


# R4.7 soul anchor: overchannel benefits scale with the declared level.
static func overchannel_benefit(level: int) -> Dictionary:
	match level:
		2:
			return {"damage": 4, "draws": 1}
		3:
			return {"damage": 6, "bound": true}
	return {"damage": 2}


# R2.3 mercy rule: the first sub-zero overchannel in a battle clamps soul to
# 1 instead of killing; a second one with mercy spent returns {} so the
# caller rejects the play outright (never a surprise death).
static func apply_overchannel_soul(cultivator: Dictionary, level: int, mercy_available: bool) -> Dictionary:
	var before := int(cultivator.get("soul", 0))
	if before >= level:
		return {"soul": before - level, "mercy_used": false, "fatal": false}
	if mercy_available:
		return {"soul": 1, "mercy_used": true, "fatal": false}
	return {}
