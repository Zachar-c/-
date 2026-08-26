# Gu Card Roguelike Plan Amendment

This amendment is part of [the implementation plan](2026-08-23-gu-card-roguelike-implementation.md). It replaces the pseudocode block in **Task 4, Step 3**. Apply this block verbatim; it has no deferred placeholder.

```gdscript
func _expire_effects(battle: Dictionary) -> void:
	var retained := {}
	for effect_id in battle["active_effect_registry"]:
		var effect: Dictionary = battle["active_effect_registry"][effect_id].duplicate(true)
		if str(effect["tick_phase"]) == "end_turn":
			effect["remaining_turns"] = int(effect["remaining_turns"]) - 1
		if int(effect["remaining_turns"]) > 0:
			retained[effect_id] = effect
	battle["active_effect_registry"] = retained
	var occupied: Array[String] = []
	for effect in retained.values():
		if bool(effect["occupies_soul_slots"]):
			for source_id in effect["soul_occupancy_gu_ids"]:
				if not occupied.has(source_id):
					occupied.append(source_id)
	battle["active_gu_instance_ids"] = occupied
```

At every other tick phase, the implementation must use the same retain-and-recompute sequence, decrementing only effects whose `tick_phase` equals the current phase. `pending_kill_move_state` records `move_id`, `next_sequence_index`, `source_gu_instance_ids`, and `expires_at_turn`; only a matching card played within the declared sequence window advances it. An unrelated card or reaching `expires_at_turn` applies the declared `sequence_timeout_action` and clears the pending state.
