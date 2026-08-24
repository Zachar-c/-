class_name SoulCapacity
extends RefCounted

# Approved 2026-08-25: soul drives multitasking capacity.
# Battle ops cap is 1:1 with the soul value (floor 1 while a run is alive);
# refining input cap follows a step table so the two curves are non-linear.

static func battle_ops_cap(state: RunState) -> int:
	return maxi(1, int(state.cultivator.get("soul", 0)))


static func craft_cap(state: RunState) -> int:
	return craft_cap_for_soul(int(state.cultivator.get("soul", 0)))


static func craft_cap_for_soul(soul: int) -> int:
	if soul >= 5:
		return 4
	if soul >= 3:
		return 3
	return 2