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
	# The shipped elite table forces epic (R5.2), so ladder semantics are
	# exercised on an unforced copy of it; pity only governs unforced sources.
	var elite: Dictionary = elite_table(cat)
	elite.erase("forced_rarity")
	elite["gu_chance_pct"] = 100
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
	# of being filtered by the elite 30% drop gate. The R5.2 forced epic is
	# erased so the R13.1 pity forcing itself stays under test here.
	var table: Dictionary = elite_table(cat).duplicate(true)
	table["gu_chance_pct"] = 100
	table.erase("forced_rarity")
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
	# 2026-09-10 改写：原版假设"第一个 gu_id 为空的掉落就是门禁失败、且此前计数器没被动过"，
	# 这只在特定随机序列下成立（稀有掉落会把计数器清零，之后再现空掉落就与前提矛盾）。
	# 现在改为断言**真正的不变量**：任何一次"完全空掉落"都不改变计数器——与它出现在第几次无关。
	var observed_failure := false
	for _fight in range(30):
		var pity_before := int(state.loot_pity)
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
		state = rolled["state"]
		var loot: Dictionary = rolled["loot"]
		# 「门禁失败」= **蛊**没抽出来（材料照常掉，所以不能要求 loot 全空）。
		if str(loot.get("gu_id", "")).is_empty():
			assert_eq(int(state.loot_pity), pity_before,
					"蛊门禁失败不得改动计数器（第 %d 次，材料 %s）"
					% [_fight, str(loot.get("material_ids", []))])
			observed_failure = true
	assert_true(observed_failure, "seed 2026 must hit a gate failure within 30 elite fights")


func test_gu_loot_event_payload_carries_new_pity() -> void:
	var cat := catalog()
	var state: RunState = make_state(2026)
	var observed := false
	for _fight in range(40):
		var log_size_before := state.event_log.size()
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
		var had_gu := not str(rolled["loot"].get("gu_id", "")).is_empty()
		state = rolled["state"]
		if had_gu:
			# The elite cost event may land after the loot events; scan this
			# victory's appended entries for the loot payload.
			for index in range(log_size_before, state.event_log.size()):
				var entry: Dictionary = state.event_log[index]
				if str(entry.get("reason", "")) == "loot_gu_gained":
					assert_eq(int(entry["after"].get("loot_pity", -1)), int(state.loot_pity),
							"replays must reproduce pity from the event payload")
					observed = true
			break
	assert_true(observed, "seed 2026 must produce a gated gu drop within 40 elite fights")


func test_loot_pity_survives_save_round_trip() -> void:
	var state: RunState = make_state(777)
	# The shipped elite table forces epic, which never advances the ladder; the
	# counter value is planted directly since persistence is what is under test.
	state.loot_pity = 2
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
			# P2-a: faction targets make material pity state-dependent too, so
			# the replay determinism gate must cover it (2026-09-13 ruling).
			state.school = "force"
			var sequence := []
			for _fight in range(25):
				var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
				state = rolled["state"]
				sequence.append({
					"gu_id": str(rolled["loot"].get("gu_id", "")),
					"materials": rolled["loot"].get("material_ids", []),
					"pity": int(state.loot_pity),
					"material_pity_by_tier": (state.material_pity_by_tier as Dictionary).duplicate(true),
				})
			runs.append({"sequence": sequence, "event_log": state.event_log})
		assert_eq_deep(runs[0], runs[1])


# ---- material pity (P2-a: faction chain targets, 2026-09-13 R-3 ruling) ----
# Targets are no longer a static id list: they are the intersection of
# (a) the school's promotion-recipe materials, (b) materials the tier pool
# actually declares, (c) bands allowed for that tier in target_bands_by_tier.
# Hard limit from the ruling: pity can only backfill a target band the pool
# already defines - never cross-tier pulls, never invented materials.

const BOSS_BATTLE := {"enemy_kind": "miasma_vein_lord"}


func _pity_targets(tier: String, state: RunState, cat: Dictionary) -> Array:
	var table: Dictionary = cat["loot_tables"]["loot"][tier]
	return LootResolverScript._material_pity_targets(tier, table, state, cat)


func _force_state(run_seed: int) -> RunState:
	var state: RunState = make_state(run_seed)
	state.school = "force"
	return state


func test_pity_targets_are_chain_pool_and_band_intersection() -> void:
	var cat := catalog()
	var force: RunState = _force_state(5)
	# common: only the f1 chain material; force-tagged crude beast_bone is
	# deliberately NOT a target (chain set comes from promotion recipes).
	assert_eq_deep(_pity_targets("common", force, cat), ["mat_force_1"])
	# boss pool declares refined f3 too, but the band hard limit forbids it.
	assert_eq_deep(_pity_targets("boss", force, cat), ["mat_force_4"])
	assert_eq_deep(_pity_targets("elite", force, cat), ["mat_force_2", "mat_force_3"])
	assert_true(_pity_targets("elite", make_state(5), cat).is_empty(),
			"no school means no faction targets, so pity stays a no-op")


func test_material_pity_forces_school_f1_on_threshold() -> void:
	var cat := catalog()
	var state: RunState = _force_state(11)
	state.material_pity_by_tier = {"common": 3, "elite": 0, "boss": 0}
	var rolled: Dictionary = LootResolverScript.settle_victory({"enemy_kind": "ridge_hound"}, state, cat)
	var ids: Array = rolled["loot"]["material_ids"]
	assert_true(ids.has("mat_force_1"), "common pity must force the school f1 chain material")
	assert_eq(int((rolled["state"].material_pity_by_tier as Dictionary).get("common", -1)), 0,
			"forced target pick resets the common counter")


func test_boss_pity_backfills_f4_only() -> void:
	var cat := catalog()
	var state: RunState = _force_state(13)
	state.material_pity_by_tier = {"common": 0, "elite": 0, "boss": 3}
	var rolled: Dictionary = LootResolverScript.settle_victory(BOSS_BATTLE, state, cat)
	var ids: Array = rolled["loot"]["material_ids"]
	assert_true(ids.has("mat_force_4"), "boss pity must backfill the f4 band gap")
	assert_eq(int((rolled["state"].material_pity_by_tier as Dictionary).get("boss", -1)), 0,
			"forced f4 resets only the boss counter")


func test_elite_f23_hit_leaves_common_f1_counter_untouched() -> void:
	# Reachability-3 关键测试（2026-09-13 裁定点名）：elite 的 f2/f3 命中
	# 对 f1（common 组）计数零影响——既不清零也不推进。这是旧单计数器
	# 模型下 f1 断档的根因。
	var cat := catalog()
	var observed := false
	for run_seed in range(1, 61):
		var state: RunState = _force_state(run_seed)
		state.material_pity_by_tier = {"common": 2, "elite": 0, "boss": 0}
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
		var ids: Array = rolled["loot"]["material_ids"]
		var hit_f23 := false
		for material_id_value in ids:
			if _pity_targets("elite", state, cat).has(str(material_id_value)):
				hit_f23 = true
				break
		if not hit_f23:
			continue
		var pity: Dictionary = rolled["state"].material_pity_by_tier
		assert_eq(int(pity.get("common", -1)), 2,
				"seed %d: elite f2/f3 drop must not touch the f1 counter" % run_seed)
		assert_eq(int(pity.get("elite", -1)), 0,
				"seed %d: elite target hit resets only the elite counter" % run_seed)
		observed = true
		break
	assert_true(observed, "expected at least one seed whose elite fight drops an f2/f3 chain material")


func test_material_pity_counters_advance_only_in_own_tier() -> void:
	var cat := catalog()
	var state: RunState = _force_state(3)
	var rolled: Dictionary = LootResolverScript.settle_victory({"enemy_kind": "ridge_hound"}, state, cat)
	var ids: Array = rolled["loot"]["material_ids"]
	var pity: Dictionary = rolled["state"].material_pity_by_tier
	var expected_common := 0 if ids.has("mat_force_1") else 1
	assert_eq(int(pity.get("common", -1)), expected_common,
			"common counter tracks only common fights' f1 outcome")
	assert_eq(int(pity.get("elite", 0)), 0, "common fight must not advance the elite counter")
	assert_eq(int(pity.get("boss", 0)), 0, "common fight must not advance the boss counter")


func test_material_pity_resets_when_target_naturally_picked() -> void:
	var cat := catalog()
	var state: RunState = _force_state(7)
	state.material_pity_by_tier = {"common": 0, "elite": 1, "boss": 0}
	var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
	# The elite pool can draw an f2/f3 chain material naturally for some seeds:
	# when it does the elite counter resets, otherwise it advances by one.
	var ids: Array = rolled["loot"]["material_ids"]
	var hit := false
	for material_id_value in ids:
		if _pity_targets("elite", state, cat).has(str(material_id_value)):
			hit = true
			break
	var expected := 0 if hit else 2
	assert_eq(int((rolled["state"].material_pity_by_tier as Dictionary).get("elite", -1)), expected)


func test_material_pity_by_tier_survives_save_round_trip() -> void:
	var state: RunState = make_state(777)
	state.school = "force"
	state.material_pity_by_tier = {"common": 2, "elite": 1, "boss": 0}
	var data := SaveRepositoryScript.serialize_run(state, [], [])
	var loaded: Dictionary = SaveRepositoryScript.load_run_from_data(data)
	assert_false(loaded.is_empty(), "round trip must load")
	# per-tier counters must persist through serialize/load
	assert_eq_deep((loaded["state"].material_pity_by_tier as Dictionary), {"common": 2, "elite": 1, "boss": 0})
