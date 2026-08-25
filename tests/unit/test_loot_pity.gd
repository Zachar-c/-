extends "res://addons/gut/test.gd"


# T2 rare pity counter (lockdown spec R13.1): after 3 consecutive
# common-producing adventure drops the next gated gu roll is forced onto
# non-common buckets; a rare-or-better drop clears the counter; chance-gate
# failures never touch it and shop purchases bypass it by construction.
# All rolls stay seeded from the run seed.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const LootResolverScript := preload("res://scripts/domain/loot_resolver.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")
const SaveRepositoryScript := preload("res://scripts/domain/save_repository.gd")

const ELITE_BATTLE := {"enemy_kind": "ridge_elite_scout"}
const PITY_THRESHOLD := 3


func make_state(run_seed: int = 2026) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func elite_table(cat: Dictionary) -> Dictionary:
	return cat["loot_tables"]["loot"]["elite"]


func _rarity_of(cat: Dictionary, gu_id: String) -> String:
	var pool: Dictionary = elite_table(cat)["gu_pool"]
	for rarity_id in pool["by_rarity"]:
		if (pool["by_rarity"][rarity_id] as Array).has(gu_id):
			return str(rarity_id)
	return str(cat["gu_by_id"][gu_id].get("rarity", ""))


func test_fourth_consecutive_common_drop_is_forced_rare_or_better() -> void:
	var cat := catalog()
	var forced_observations := 0
	for run_seed in range(2026, 2046):
		var state: RunState = make_state(run_seed)
		var streak := 0
		for fight_index in range(60):
			var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
			state = rolled["state"]
			var gu_id := str(rolled["loot"].get("gu_id", ""))
			if gu_id.is_empty():
				continue
			var rarity := _rarity_of(cat, gu_id)
			var was_forced := streak >= PITY_THRESHOLD
			if was_forced:
				assert_ne(rarity, "common",
						"seed %d fight %d: drop after %d commons must be rare or better" % [run_seed, fight_index, streak])
			streak = 0 if rarity != "common" else streak + 1
			assert_eq(int(state.loot_pity), streak,
					"seed %d fight %d: counter must track consecutive commons" % [run_seed, fight_index])
			if was_forced:
				forced_observations += 1
	assert_true(forced_observations > 0, "expected at least one forced-drop scenario across seeds")


func test_forced_rarity_roll_excludes_common_bucket() -> void:
	var cat := catalog()
	# Gate raised to 100 so every seed reaches the forced rarity roll instead
	# of being filtered by the elite 30% drop gate.
	var table: Dictionary = elite_table(cat).duplicate(true)
	table["gu_chance_pct"] = 100
	var seen := {}
	for run_seed in range(1, 41):
		var state: RunState = make_state(run_seed)
		state.loot_pity = PITY_THRESHOLD
		var roll: Variant = LootResolverScript._roll_gu(table, state, "elite")
		var gu_id := str(roll.get("gu_id", ""))
		assert_false(gu_id.is_empty(), "seed %d: forced roll must produce a gu" % run_seed)
		var rarity := _rarity_of(cat, gu_id)
		assert_ne(rarity, "common", "seed %d: forced roll produced common gu %s" % [run_seed, gu_id])
		seen[rarity] = true
	assert_true(seen.has("rare"), "renormalized weights must keep rare reachable")
	assert_true(seen.has("epic"), "renormalized weights must keep epic reachable")


func test_counter_resets_to_zero_after_rare_or_better_drop() -> void:
	var cat := catalog()
	var state: RunState = make_state(424242)
	state.loot_pity = PITY_THRESHOLD
	var observed := false
	for _fight in range(30):
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
		state = rolled["state"]
		if str(rolled["loot"].get("gu_id", "")).is_empty():
			continue
		assert_ne(_rarity_of(cat, str(rolled["loot"]["gu_id"])), "common")
		assert_eq(int(state.loot_pity), 0, "rare-or-better drop must clear the counter")
		observed = true
		break
	assert_true(observed, "pity state must force a gated drop within 30 elite fights for seed 424242")


func test_gate_failure_does_not_advance_the_counter() -> void:
	var cat := catalog()
	var state: RunState = make_state(2026)
	state.loot_pity = 2
	var observed_failure := false
	for _fight in range(30):
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
		state = rolled["state"]
		if str(rolled["loot"].get("gu_id", "")).is_empty():
			assert_eq(int(state.loot_pity), 2, "chance-gate failure must not touch the counter")
			observed_failure = true
			break
	assert_true(observed_failure, "seed 2026 must hit a gate failure within 30 elite fights")


func test_gu_loot_event_payload_carries_new_pity() -> void:
	var cat := catalog()
	var state: RunState = make_state(2026)
	var observed := false
	for _fight in range(40):
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
		var had_gu := not str(rolled["loot"].get("gu_id", "")).is_empty()
		state = rolled["state"]
		if had_gu:
			var entry: Dictionary = state.event_log.back()
			assert_eq(str(entry.get("reason", "")), "loot_gu_gained")
			assert_eq(int(entry["after"].get("loot_pity", -1)), int(state.loot_pity),
					"replays must reproduce pity from the event payload")
			observed = true
			break
	assert_true(observed, "seed 2026 must produce a gated gu drop within 40 elite fights")


func test_loot_pity_survives_save_round_trip() -> void:
	var cat := catalog()
	var state: RunState = make_state(777)
	for _fight in range(40):
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
		state = rolled["state"]
		if int(state.loot_pity) > 0:
			break
	assert_true(int(state.loot_pity) > 0, "seed 777 must raise the counter within 40 elite fights")
	var data := SaveRepositoryScript.serialize_run(state, [], [])
	var loaded: Dictionary = SaveRepositoryScript.load_run_from_data(data)
	assert_false(loaded.is_empty(), "round trip must load")
	assert_eq(int(loaded["state"].loot_pity), int(state.loot_pity),
			"counter must persist through serialize/load")


func test_same_seed_replays_identical_loot_and_pity_sequence() -> void:
	var cat := catalog()
	for run_seed in [11, 424242]:
		var runs := []
		for _copy in range(2):
			var state: RunState = make_state(run_seed)
			var sequence := []
			for _fight in range(25):
				var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
				state = rolled["state"]
				sequence.append({
					"gu_id": str(rolled["loot"].get("gu_id", "")),
					"materials": rolled["loot"].get("material_ids", []),
					"pity": int(state.loot_pity),
				})
			runs.append({"sequence": sequence, "event_log": state.event_log})
		assert_eq_deep(runs[0], runs[1])


# ---- material pity (S3: qi-aligned material guarantee) ----

func test_material_pity_forces_qi_target_on_threshold() -> void:
	var cat := catalog()
	var pity: Dictionary = cat["loot_tables"]["pity"]["material_pity"]
	var state: RunState = make_state(11)
	state.material_pity = int(pity["threshold"])
	var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
	var ids: Array = rolled["loot"]["material_ids"]
	assert_true(ids.has("venom_sac"), "elite pool must supply the forced qi target venom_sac")
	assert_eq(int(rolled["state"].material_pity), 0, "forced target pick resets the counter")


func test_material_pity_resets_when_target_naturally_picked() -> void:
	var cat := catalog()
	var state: RunState = make_state(7)
	state.material_pity = 1
	var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
	# The elite pool can draw venom_sac naturally for some seeds: when it does
	# the counter resets, otherwise it advances by one.
	var ids: Array = rolled["loot"]["material_ids"]
	var expected := 0 if ids.has("venom_sac") else 2
	assert_eq(int(rolled["state"].material_pity), expected)


func test_material_pity_advances_on_material_loot_without_target() -> void:
	var cat := catalog()
	var state: RunState = make_state(3)
	var rolled: Dictionary = LootResolverScript.settle_victory({"enemy_kind": "ridge_hound"}, state, cat)
	assert_eq(int(rolled["state"].material_pity), 1, "common tier has no qi target material")


func test_material_pity_cannot_invent_off_pool_targets() -> void:
	var cat := catalog()
	var pity: Dictionary = cat["loot_tables"]["pity"]["material_pity"]
	var state: RunState = make_state(9)
	state.material_pity = int(pity["threshold"])
	var rolled: Dictionary = LootResolverScript.settle_victory({"enemy_kind": "ridge_hound"}, state, cat)
	var ids: Array = rolled["loot"]["material_ids"]
	assert_eq(ids.size(), 1, "no forced material beyond what the tier pool declares")
	assert_eq(int(rolled["state"].material_pity), int(pity["threshold"]) + 1)
