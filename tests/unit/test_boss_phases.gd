extends GutTest


# P1a R5.2/R5.7 boss phases minimal slice:
# - enemies.json may declare optional "phases" keyed by until_hp_ratio; the
#   battle engine picks the active intent set from current hp/max_hp;
# - crossing a threshold appends exactly one boss_phase_shift event carrying
#   _from/_to info keys (exactly 50% counts as crossed);
# - intents may declare "cooldown":n — fired on turn T they are next
#   selectable from turn T+n+1; while every phase intent rests the boss shows
#   a harmless cooldown_wait instead of attacking (no earliest-release
#   fallback) — and "essence_burn":n (direct essence drain through the enemy
#   channel);
# - enemies without phases behave byte-for-byte like before.


const ResolverScript = preload("res://scripts/domain/resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _boss_battle(run_seed: int = 101) -> Dictionary:
	var run := RunState.new_run(run_seed)
	var battle := BattleResolver.start({"enemy_kind": "miasma_vein_lord"}, run, catalog)
	return {"run": run, "battle": battle}


func _shift_events(state: RunState) -> Array:
	var events: Array = []
	for entry in state.event_log:
		if str(entry.get("action", "")) == "boss_phase_shift":
			events.append(entry)
	return events


func test_enemy_without_phases_keeps_legacy_behavior() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_elite_scout"}, run, catalog)

	assert_true((battle.get("enemy_phases", []) as Array).is_empty())
	assert_eq(str(battle["visible_intent"]["id"]), "swift_crossbow")

	battle["enemy_hp"] = 1
	var turned := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, catalog)
	assert_false(bool(turned.get("finished", false)) and str(turned.get("result", "")) == "death")
	assert_eq(_shift_events(turned["state"]).size(), 0)


func test_boss_starts_in_phase_one_with_primary_intent() -> void:
	var setup := _boss_battle()
	var battle: Dictionary = setup["battle"]

	assert_eq(int(battle["enemy_phase_index"]), 0)
	assert_eq(str(battle["visible_intent"]["id"]), "miasma_burst")
	assert_true(battle["intent_cooldowns"].is_empty())


func test_crossing_threshold_shifts_phase_and_fires_exactly_one_event() -> void:
	var setup := _boss_battle()
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	# Counter corrosive_mist (counter_status guarded) so strikes land.
	battle["flags"] = ["guarded"]
	battle["enemy_hp"] = 4

	var crossed := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, catalog)

	# hp 4 -> 3 crosses the 50% line (3/6) during this action.
	assert_eq(int(crossed["battle"]["enemy_hp"]), 3)
	assert_eq(int(crossed["battle"]["enemy_phase_index"]), 1)
	var shifts: Array = _shift_events(crossed["state"])
	assert_eq(shifts.size(), 1)
	assert_eq(int(shifts[0]["after"]["_from"]), 0)
	assert_eq(int(shifts[0]["after"]["_to"]), 1)

	battle = crossed["battle"]
	run = crossed["state"]
	battle["flags"] = ["guarded"]
	var deeper := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, catalog)
	assert_eq(_shift_events(deeper["state"]).size(), 1, "further crossings never re-fire the shift")
	assert_eq(int(deeper["battle"]["enemy_phase_index"]), 1)


func test_visible_intent_after_shift_comes_from_the_phase_two_set() -> void:
	var setup := _boss_battle()
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	battle["flags"] = ["guarded"]
	battle["enemy_hp"] = 5

	var crossed := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, catalog)
	var intent_id := str(crossed["battle"]["visible_intent"]["id"])
	assert_true(["miasma_burst", "essence_scorch"].has(intent_id),
			"post-shift intent must come from the phase-two pool (got %s)" % intent_id)


func test_full_health_boss_never_shifts_or_rotates_out_of_phase_one() -> void:
	var setup := _boss_battle()
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	var turned := BattleResolver.take_turn(battle, {"type": "end_turn"}, run, catalog)

	assert_eq(_shift_events(turned["state"]).size(), 0)
	assert_eq(int(turned["battle"]["enemy_phase_index"]), 0)
	# The fired burst rests for two turns; the boss idles instead of attacking.
	assert_eq(str(turned["battle"]["visible_intent"]["id"]), "cooldown_wait")


func test_essence_burn_drains_player_essence_through_the_enemy_channel() -> void:
	var setup := _boss_battle()
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	battle["visible_intent"] = {
		"id": "essence_scorch", "label": "蚀脉扰元", "damage": 0,
		"speed": 2, "essence_burn": 2,
	}
	var essence_before := int(run.essence)

	var turned := BattleResolver.take_turn(battle, {"type": "end_turn"}, run, catalog)

	# 收势回气 (regen 2, cap 4) lands the same end turn, offsetting the burn.
	assert_eq(int(turned["state"].essence), mini(essence_before - 2 + 2, 4))
	assert_eq(int(turned["state"].health), int(run.health))
	assert_eq(int(turned["battle"]["log"].back().get("burned", 0)), 2)


func test_interrupted_intent_cancels_damage_and_burn() -> void:
	var setup := _boss_battle()
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	battle["visible_intent"] = {
		"id": "essence_scorch", "label": "蚀脉扰元", "damage": 0,
		"speed": 2, "essence_burn": 2,
	}
	battle["flags"] = ["enemy_interrupted"]

	var turned := BattleResolver.take_turn(battle, {"type": "end_turn"}, run, catalog)

	assert_eq(int(turned["state"].essence), mini(int(run.essence) + 2, 4))
	assert_eq(int(turned["battle"]["log"].back().get("burned", 0)), 0)


func test_cooldown_blocks_recently_fired_intents() -> void:
	var setup := _boss_battle(2026)
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	battle["enemy_phase_index"] = 1
	battle["turn"] = 4
	battle["intent_cooldowns"] = {"miasma_burst": 6}

	BattleResolver._select_enemy_intent(battle, run, 4)
	assert_eq(str(battle["visible_intent"]["id"]), "essence_scorch",
			"a burst blocked until turn 6 leaves scorch as the only pick at turn 4")

	battle["intent_cooldowns"] = {"miasma_burst": 6, "essence_scorch": 6}
	BattleResolver._select_enemy_intent(battle, run, 4)
	assert_eq(str(battle["visible_intent"]["id"]), "cooldown_wait",
			"all-cooled phases idle on cooldown_wait instead of falling back to an attack")

	var waited: Dictionary = BattleResolver.take_turn(battle.duplicate(true), {"type": "end_turn"}, run, catalog)
	assert_eq(int(waited["state"].health), int(run.health),
			"a cooldown_wait turn deals no damage")


func test_executed_high_danger_intent_starts_its_cooldown() -> void:
	var setup := _boss_battle(101)
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	var turned := BattleResolver.take_turn(battle, {"type": "end_turn"}, run, catalog)

	var executed_id := str(turned["battle"]["log"].back()["id"])
	var cooldowns: Dictionary = turned["battle"]["intent_cooldowns"]
	if int(catalog["enemy_by_id"]["miasma_vein_lord"]["phases"][0]["intents"][0].get("cooldown", 0)) > 0:
		assert_true(cooldowns.has(executed_id),
				"fired intent %s must enter cooldown bookkeeping" % executed_id)
		assert_eq(int(cooldowns[executed_id]), int(setup["battle"]["turn"]) + 2 + 1,
				"cooldown anchors to execution turn + window + 1 (next usable turn)")
	# The very next selection must refuse the cooled intent whenever its phase
	# offers an alternative.
	turned["battle"]["enemy_phase_index"] = 1
	BattleResolver._select_enemy_intent(turned["battle"], turned["state"], int(turned["battle"]["turn"]))
	if cooldowns.has(executed_id) and int(cooldowns[executed_id]) > int(turned["battle"]["turn"]):
		assert_ne(str(turned["battle"]["visible_intent"]["id"]), executed_id,
				"cooled intent cannot be re-picked while its partner is free")


func test_backlash_event_uses_scalar_anchor_snapshot_not_deep_cultivator() -> void:
	var tuned := catalog.duplicate(true)
	tuned["gu_by_id"]["small_light_gu"]["rank"] = 2
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, tuned)
	for instance in battle["hand"]:
		if str(instance["definition_id"]) == "light_probe":
			var played := BattleResolver.apply_action_card(battle, run, {
				"type": "action_card",
				"action_id": "battle.%s.%s" % [str(battle["battle_id"]), str(instance["instance_id"])],
				"state_version": int(battle["hand_version"]),
			}, tuned)
			assert_true(bool(played.get("accepted", false)))
			for entry in played["state"].event_log:
				if str(entry.get("action", "")) == "battle_backlash":
					var before: Dictionary = entry["before"]
					assert_false(before.has("cultivator"), "deep cultivator snapshot must be gone")
					assert_true(before.has("health"))
					assert_true(before.has("soul"))
					assert_true(before.has("curse_layers"))
					return
			push_error("expected a battle_backlash event after the rank-gap play")
			return
	push_error("light_probe missing from opening hand")


func test_pre_turn_first_move_still_deals_legacy_burst_damage() -> void:
	var setup := _boss_battle()
	var battle: Dictionary = setup["battle"]
	var pre := BattleResolver.apply_enemy_pre_turn(battle, setup["run"], catalog)

	assert_false(bool(pre["finished"]))
	assert_eq(int(pre["state"].health), 4)
	assert_eq(int(pre["battle"]["log"].back()["damage"]), 2)


func _enemy_log_entries(log: Array, from_index: int) -> Array:
	var entries: Array = []
	for index in range(from_index, log.size()):
		var entry: Dictionary = log[index]
		if str(entry.get("source", "")) == "enemy":
			entries.append(entry)
	return entries


func test_p2_double_intent_refires_keep_at_least_two_gap_turns() -> void:
	var setup := _boss_battle(2026)
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	battle["enemy_phase_index"] = 1
	run.health = maxi(int(run.health), 60)
	var last_fire := {}
	var saw_scorch := false
	var saw_burst := false
	var saw_wait := false

	for _round in range(10):
		battle["flags"] = ["guarded"]
		var exec_turn := int(battle["turn"])
		var prev_len := int((battle["log"] as Array).size())
		var turned := BattleResolver.take_turn(battle, {"type": "end_turn"}, run, catalog)
		assert_false(bool(turned.get("finished", false)), "the soak run must survive")
		for entry in _enemy_log_entries(turned["battle"]["log"], prev_len):
			var intent_id := str(entry["id"])
			match intent_id:
				"miasma_burst": saw_burst = true
				"essence_scorch": saw_scorch = true
				"cooldown_wait":
					saw_wait = true
					assert_eq(int(entry["damage"]), 0, "cooldown_wait never deals damage")
					continue
			if last_fire.has(intent_id):
				assert_gt(exec_turn - int(last_fire[intent_id]), 2,
						"%s refires with at least two full gap turns (cooldown 2)" % intent_id)
			last_fire[intent_id] = exec_turn
		battle = turned["battle"]
		run = turned["state"]

	assert_true(saw_burst and saw_scorch, "both phase-two intents must fire during the soak")
	assert_true(saw_wait, "alternating two-turn cooldowns must produce idle gap turns")


func test_single_intent_cooldown_phase_shows_gap_turns_then_resumes() -> void:
	var setup := _boss_battle(101)
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	# Turn 1 fires the only phase-one intent (cooldown 2); turns 2 and 3 idle.
	var fired := BattleResolver.take_turn(battle, {"type": "end_turn"}, run, catalog)
	assert_eq(str(fired["battle"]["visible_intent"]["id"]), "cooldown_wait",
			"the single resting intent forces a visible gap turn")

	var health_before := int(fired["state"].health)
	var idle := BattleResolver.take_turn(fired["battle"], {"type": "end_turn"}, fired["state"], catalog)
	assert_eq(int(idle["state"].health), health_before, "gap turns deal no damage")
	assert_eq(str(idle["battle"]["log"].back()["id"]), "cooldown_wait")
	assert_eq(int(idle["battle"]["log"].back()["damage"]), 0)
	assert_eq(str(idle["battle"]["visible_intent"]["id"]), "cooldown_wait",
			"turn three is still inside the two-turn rest window")

	var resumed := BattleResolver.take_turn(idle["battle"], {"type": "end_turn"}, idle["state"], catalog)
	assert_eq(str(resumed["battle"]["visible_intent"]["id"]), "miasma_burst",
			"after exactly n=2 gap turns the intent is selectable again")


func test_exactly_fifty_percent_hp_ratio_enters_the_deeper_phase() -> void:
	var setup := _boss_battle(77)
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	battle["enemy_max_hp"] = 10
	battle["enemy_hp"] = 6

	BattleResolver._sync_boss_phases(battle, run)
	assert_eq(int(battle["enemy_phase_index"]), 0, "60% stays in phase one")

	battle["enemy_hp"] = 5
	var crossed := BattleResolver._sync_boss_phases(battle, run)
	assert_eq(int(battle["enemy_phase_index"]), 1, "exactly 50% crosses into phase two")
	assert_eq(_shift_events(crossed).size(), 1)


func test_enemy_intent_event_anchors_essence_symmetrically_in_before() -> void:
	var setup := _boss_battle()
	var run: RunState = setup["run"]
	var battle: Dictionary = setup["battle"]
	battle["visible_intent"] = {
		"id": "essence_scorch", "label": "蚀脉扰元", "damage": 0,
		"speed": 2, "essence_burn": 2,
	}

	var turned := BattleResolver.take_turn(battle, {"type": "end_turn"}, run, catalog)

	var found := false
	for entry in turned["state"].event_log:
		if str(entry.get("action", "")) != "battle_enemy_intent":
			continue
		if str(entry.get("reason", "")) != "battle_enemy_essence_scorch":
			continue
		found = true
		var before: Dictionary = entry["before"]
		assert_true(before.has("essence"), "before anchors essence like it anchors health")
		assert_eq(int(before["essence"]), int(run.essence))
		assert_true((entry["after"] as Dictionary).has("essence"))
	assert_true(found, "the scorch turn must emit a battle_enemy_intent event")
