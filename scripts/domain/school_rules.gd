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