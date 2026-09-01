class_name SoulCapacity
extends RefCounted

# NOTE (T3.2): legacy soul-derived multitasking caps - replaced by the
# per-turn thought ledger (spec §12.1, §18 item 3) and deleted in T10.1-③.
# No logic changes here; keep working until the retirement batch.
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