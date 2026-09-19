extends GutTest


# M0 loot allowlist (2026-09-19): the generic LootResolver.settle_victory
# must never hand an out-of-slice gu to an M0 run. M0 content gu are exactly
# the six in M0RewardResolver.M0_GU_POOL; HP/true_qi/thoughts/shield/stones/
# materials/enmity/reward-choice semantics stay untouched, and the normal
# start_new_run flow is not gated by this filter.


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")
const M0RewardResolverScript = preload("res://scripts/domain/m0_reward_resolver.gd")

const M0_COMMON_BATTLES := [
	{"enemy_kind": "ridge_hound", "layer": 1},
	{"enemy_kind": "iron_hide_boar", "layer": 1},
]
const M0_ELITE_BATTLE := {"enemy_kind": "ridge_elite_scout", "layer": 1}
const M0_BOSS_BATTLE := {"enemy_kind": "miasma_vein_lord", "layer": 1}


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func make_state(run_seed: int, m0_mode: bool) -> RunState:
	var state: RunState = RunStateScript.new_run(run_seed, null)
	if m0_mode:
		state.node_flags["m0_mode"] = true
	return state


func _is_allowed(gu_id: String) -> bool:
	return (M0RewardResolverScript.M0_GU_POOL as Array).has(gu_id)


func test_m0_victory_never_drops_gu_outside_allowlist() -> void:
	var cat := catalog()
	var seen_allowed := 0
	var seen_total := 0
	for run_seed in range(1, 201):
		for battle in M0_COMMON_BATTLES:
			var rolled: Dictionary = LootResolverScript.settle_victory(
					battle, make_state(run_seed, true), cat)
			var gu_id := str(rolled["loot"].get("gu_id", ""))
			assert_true(gu_id.is_empty() or _is_allowed(gu_id),
					"seed %d battle %s: M0 gu %s outside allowlist" % [run_seed, battle["enemy_kind"], gu_id])
			if not gu_id.is_empty():
				seen_allowed += 1
			seen_total += 1
		for battle in [M0_ELITE_BATTLE, M0_BOSS_BATTLE]:
			var rolled: Dictionary = LootResolverScript.settle_victory(
					battle, make_state(run_seed, true), cat)
			var gu_id := str(rolled["loot"].get("gu_id", ""))
			assert_true(gu_id.is_empty() or _is_allowed(gu_id),
					"seed %d battle %s: M0 gu %s outside allowlist" % [run_seed, battle["enemy_kind"], gu_id])
	assert_true(seen_allowed > 0,
			"expected at least one allowed M0 gu across %d common rolls, filter must not swallow everything" % seen_total)


func test_m0_filter_activates_on_a_known_leaking_seed() -> void:
	# Self-calibrating: find a seed where the unfiltered common roll leaks a
	# non-allowlist gu, then prove M0 mode drops exactly that gu to empty
	# while materials and stones settle identically.
	var cat := catalog()
	var leaking_seed := -1
	var leaking_gu := ""
	for run_seed in range(1, 2001):
		var rolled: Dictionary = LootResolverScript.settle_victory(
				M0_COMMON_BATTLES[0], make_state(run_seed, false), cat)
		var gu_id := str(rolled["loot"].get("gu_id", ""))
		if not gu_id.is_empty() and not _is_allowed(gu_id):
			leaking_seed = run_seed
			leaking_gu = gu_id
			break
	assert_true(leaking_seed >= 0,
			"expected at least one leaking seed in range (proves the M0 gap is real)")
	var normal: Dictionary = LootResolverScript.settle_victory(
			M0_COMMON_BATTLES[0], make_state(leaking_seed, false), cat)
	var m0: Dictionary = LootResolverScript.settle_victory(
			M0_COMMON_BATTLES[0], make_state(leaking_seed, true), cat)
	assert_eq(str(normal["loot"].get("gu_id", "")), leaking_gu)
	assert_eq(str(m0["loot"].get("gu_id", "")), "",
			"seed %d: M0 must filter non-allowlist gu %s" % [leaking_seed, leaking_gu])
	assert_eq(str(m0["loot"].get("material_ids", [])), str(normal["loot"].get("material_ids", [])),
			"filter must not touch materials")
	assert_eq(int(m0["loot"].get("stone_reward", -1)), int(normal["loot"].get("stone_reward", -2)),
			"filter must not touch stone production")


func test_m0_materials_and_stones_match_normal_flow_per_seed() -> void:
	var cat := catalog()
	for run_seed in range(1, 61):
		for battle in [M0_COMMON_BATTLES[0], M0_COMMON_BATTLES[1], M0_ELITE_BATTLE, M0_BOSS_BATTLE]:
			var normal: Dictionary = LootResolverScript.settle_victory(
					battle, make_state(run_seed, false), cat)
			var m0: Dictionary = LootResolverScript.settle_victory(
					battle, make_state(run_seed, true), cat)
			assert_eq(str(m0["loot"].get("material_ids", [])), str(normal["loot"].get("material_ids", [])),
					"seed %d: materials must match normal flow" % run_seed)
			assert_eq(int(m0["loot"].get("stone_reward", -1)), int(normal["loot"].get("stone_reward", -2)),
					"seed %d: stones must match normal flow" % run_seed)


func test_m0_filtered_loot_is_seed_deterministic() -> void:
	var cat := catalog()
	for run_seed in [3, 17, 42, 101, 777]:
		var first: Dictionary = LootResolverScript.settle_victory(
				M0_COMMON_BATTLES[0], make_state(run_seed, true), cat)
		var second: Dictionary = LootResolverScript.settle_victory(
				M0_COMMON_BATTLES[0], make_state(run_seed, true), cat)
		assert_eq(str(first["loot"].get("gu_id", "")), str(second["loot"].get("gu_id", "")),
				"seed %d: filtered gu must be deterministic" % run_seed)
		assert_eq(str(first["loot"].get("material_ids", [])), str(second["loot"].get("material_ids", [])),
				"seed %d: materials must be deterministic" % run_seed)
		assert_eq(int(first["loot"].get("stone_reward", -1)), int(second["loot"].get("stone_reward", -2)),
				"seed %d: stones must be deterministic" % run_seed)
