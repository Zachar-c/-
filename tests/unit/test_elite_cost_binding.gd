extends GutTest


# P1a R5.2/R6.9/R13.1 elite reward-cost binding:
# - the elite gu drop is forced to epic (forced_rarity overrides declared
#   weights, which stay in data for compat);
# - every elite victory binds exactly one seeded cost from cost_pool
#   (backlash curse layer or notoriety), logged as one elite_cost_applied
#   event with a "_cost" info payload;
# - non-elite/boss tiers never bind costs;
# - forced drops bypass the pity ladder (an epic result clears it like any
#   non-common rarity); unforced tables keep the R13.1 ladder intact.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const LootResolverScript := preload("res://scripts/domain/loot_resolver.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")
const CurseRegistryScript := preload("res://scripts/domain/curse_registry.gd")
const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")

const ELITE_BATTLE := {"enemy_kind": "ridge_elite_scout"}


func make_state(run_seed: int) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func _cost_events(state: RunState) -> Array:
	var events: Array = []
	for entry in state.event_log:
		if str(entry.get("action", "")) == "elite_cost_applied":
			events.append(entry)
	return events


func test_elite_gu_drops_are_always_epic() -> void:
	var cat := catalog()
	for run_seed in range(1, 41):
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, make_state(run_seed), cat)
		var gu_id := str(rolled["loot"].get("gu_id", ""))
		if gu_id.is_empty():
			continue
		assert_eq(str(cat["gu_by_id"][gu_id]["rarity"]), "epic",
				"seed %d: elite gu %s must be epic" % [run_seed, gu_id])


func test_forced_rarity_overrides_declared_weights_but_keeps_them_in_data() -> void:
	var cat := catalog()
	var elite: Dictionary = cat["loot_tables"]["loot"]["elite"]
	assert_false(str(elite.get("forced_rarity", "")).is_empty(), "elite table declares forced_rarity")
	assert_true(elite["gu_pool"]["weights"].has("common"), "legacy weights remain declared")
	elite["gu_chance_pct"] = 100
	elite["gu_pool"]["weights"] = {"common": 1000, "rare": 0, "epic": 1}
	for run_seed in range(1, 21):
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, make_state(run_seed), cat)
		var gu_id := str(rolled["loot"].get("gu_id", ""))
		assert_ne(gu_id, "", "seed %d must drop with a 100%% gate" % run_seed)
		assert_eq(str(cat["gu_by_id"][gu_id]["rarity"]), "epic",
				"seed %d: weight landslide on common is overridden by forced epic" % run_seed)


func test_every_elite_victory_binds_exactly_one_cost() -> void:
	var cat := catalog()
	for run_seed in range(2026, 2066):
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, make_state(run_seed), cat)
		var events: Array = _cost_events(rolled["state"])
		assert_eq(events.size(), 1, "seed %d: exactly one elite cost event" % run_seed)
		if not events.is_empty():
			assert_eq(str(events[0].get("reason", "")), "elite_cost_applied")
			assert_true((events[0]["after"] as Dictionary).has("_cost"),
					"seed %d: cost event carries the info payload" % run_seed)


func test_both_cost_kinds_occur_across_seeds() -> void:
	var cat := catalog()
	var kinds := {}
	for run_seed in range(2026, 2066):
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, make_state(run_seed), cat)
		for entry in _cost_events(rolled["state"]):
			kinds[str(entry["after"]["_cost"]["kind"])] = true
	assert_true(kinds.has("backlash"), "backlash costs must be reachable")
	assert_true(kinds.has("notoriety"), "notoriety costs must be reachable")


func test_backlash_cost_attaches_configured_curse_layer_and_notoriety_cost_adds_stacks() -> void:
	var cat := catalog()
	var saw_backlash := false
	var saw_notoriety := false
	for run_seed in range(2026, 2126):
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, make_state(run_seed), cat)
		var cost: Dictionary = rolled.get("cost", {})
		match str(cost.get("kind", "")):
			"backlash":
				saw_backlash = true
				assert_eq(int(CurseRegistryScript.layers_of(rolled["state"], str(cost["curse_id"]))), 1,
						"seed %d: backlash layer attached" % run_seed)
				assert_eq(str(rolled["state"].cultivator["statuses"][str(cost["curse_id"])]["source"]), "elite_cost")
			"notoriety":
				saw_notoriety = true
				assert_eq(int(rolled["state"].cultivator["notorious"]), int(cost["amount"]),
						"seed %d: notoriety stacks added" % run_seed)
	assert_true(saw_backlash and saw_notoriety, "both kinds must be exercised across the seed sweep")


func test_non_elite_tiers_never_bind_costs() -> void:
	var cat := catalog()
	for enemy_kind in ["ridge_hound", "miasma_vein_lord"]:
		for run_seed in range(1, 16):
			var rolled: Dictionary = LootResolverScript.settle_victory({"enemy_kind": enemy_kind}, make_state(run_seed), cat)
			assert_eq(_cost_events(rolled["state"]).size(), 0,
					"%s seed %d must not bind an elite cost" % [enemy_kind, run_seed])


func test_forced_drops_bypass_the_pity_ladder_without_breaking_it() -> void:
	var cat := catalog()
	for run_seed in range(1, 31):
		var state := make_state(run_seed)
		state.loot_pity = 2
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
		if str(rolled["loot"].get("gu_id", "")).is_empty():
			assert_eq(int(rolled["state"].loot_pity), 2,
					"seed %d: chance-gate failure leaves the ladder untouched" % run_seed)
		else:
			assert_eq(int(rolled["state"].loot_pity), 0,
					"seed %d: forced epic clears the ladder like any non-common drop" % run_seed)


func test_unforced_tables_keep_the_pity_ladder_intact() -> void:
	var cat := catalog()
	var elite: Dictionary = cat["loot_tables"]["loot"]["elite"]
	elite.erase("forced_rarity")
	elite["gu_chance_pct"] = 100
	var advanced_to_threshold := false
	for run_seed in range(3001, 3041):
		var state := make_state(run_seed)
		state.loot_pity = int(cat["loot_tables"]["pity"]["threshold"])
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
		var gu_id := str(rolled["loot"].get("gu_id", ""))
		if gu_id.is_empty():
			continue
		assert_ne(str(cat["gu_by_id"][gu_id]["rarity"]), "common",
				"seed %d: unforced ladder still forces non-common at threshold" % run_seed)
		advanced_to_threshold = true
		break
	assert_true(advanced_to_threshold, "at least one seed must exercise the unforced ladder")


func test_same_seed_replays_identical_loot_and_cost_sequence() -> void:
	var cat := catalog()
	for run_seed in [11, 424242]:
		var runs: Array = []
		for _copy_index in range(2):
			var state := make_state(run_seed)
			var sequence: Array = []
			for _fight in range(12):
				var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, state, cat)
				state = rolled["state"]
				sequence.append({
					"gu_id": str(rolled["loot"].get("gu_id", "")),
					"cost": rolled.get("cost", {}),
					"pity": int(state.loot_pity),
				})
			runs.append({"sequence": sequence, "event_log": state.event_log})
		assert_eq_deep(runs[0], runs[1])


func test_catalog_validates_forced_rarity_and_cost_pool() -> void:
	var errors: Array[String] = ContentCatalogScript.validate(catalog())
	assert_eq(errors, [])

	var bad_rarity := catalog()
	bad_rarity["loot_tables"]["loot"]["elite"]["forced_rarity"] = "superb"
	assert_true(ContentCatalogScript.validate(bad_rarity).any(
			func(e: String) -> bool: return e.contains("invalid forced rarity")))

	var empty_bucket := catalog()
	empty_bucket["loot_tables"]["loot"]["elite"]["by_rarity"] = {}
	empty_bucket["loot_tables"]["loot"]["elite"]["forced_rarity"] = "legendary"
	assert_true(ContentCatalogScript.validate(empty_bucket).any(
			func(e: String) -> bool: return e.contains("empty bucket")))

	var bad_kind := catalog()
	bad_kind["loot_tables"]["loot"]["elite"]["cost_pool"][0]["kind"] = "discount"
	assert_true(ContentCatalogScript.validate(bad_kind).any(
			func(e: String) -> bool: return e.contains("unknown cost kind")))

	var bad_curse := catalog()
	bad_curse["loot_tables"]["loot"]["elite"]["cost_pool"][0]["curse_id"] = "not_a_curse"
	assert_true(ContentCatalogScript.validate(bad_curse).any(
			func(e: String) -> bool: return e.contains("unknown curse")))


func test_elite_costs_apply_on_real_battle_victories() -> void:
	var cat := catalog()
	var run := make_state(2026)
	var battle := BattleResolver.start({"enemy_kind": "ridge_elite_scout"}, run, cat)
	# The scout's before_damage reaction swallows unbound direct strikes, so the
	# scripted kill binds the enemy first and leaves one hit to finish it.
	battle["enemy_hp"] = 1
	battle["flags"] = ["enemy_bound"]
	var turn := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, cat)
	assert_eq(str(turn.get("result", "")), "victory")
	assert_eq(_cost_events(turn["state"]).size(), 1,
			"one elite victory binds exactly one cost through the battle funnel")


func test_settled_cost_contract_carries_kind_and_layers_or_amount() -> void:
	var cat := catalog()
	for run_seed in range(2026, 2066):
		var rolled: Dictionary = LootResolverScript.settle_victory(ELITE_BATTLE, make_state(run_seed), cat)
		var cost: Dictionary = rolled.get("cost", {})
		assert_false(cost.is_empty(), "seed %d must bind a cost" % run_seed)
		assert_true(["backlash", "notoriety"].has(str(cost["kind"])),
				"seed %d: normalized cost kind" % run_seed)
		match str(cost["kind"]):
			"backlash":
				assert_true(cost.has("layers"), "seed %d: backlash exposes layers" % run_seed)
				assert_true(cost.has("curse_id"), "seed %d: backlash names its curse" % run_seed)
			"notoriety":
				assert_true(cost.has("amount"), "seed %d: notoriety exposes amount" % run_seed)


func test_finished_victory_battle_carries_cost_and_controller_feeds_it_to_the_player() -> void:
	var cat := catalog()
	var run := make_state(2026)
	run.health = maxi(int(run.health), 30)
	run.current_node_id = "elite_ambush"
	var battle := BattleResolver.start({"enemy_kind": "ridge_elite_scout"}, run, cat)
	battle["enemy_hp"] = 1
	battle["flags"] = ["enemy_bound"]
	var turn := BattleResolver.take_turn(battle, {"type": "basic_attack"}, run, cat)
	assert_eq(str(turn.get("result", "")), "victory")
	var bound_cost: Dictionary = turn["battle"].get("cost", {})
	assert_false(bound_cost.is_empty(), "the finished victory battle carries the bound cost")

	# Equivalent controller invocation (off-tree): the settlement funnel must
	# surface the cost as a player-visible feed with exact numbers.
	var controller: Node = autofree(RunControllerScript.new())
	controller.catalog = cat
	controller.state = turn["state"]
	controller.current_battle = turn["battle"]
	controller.current_session = {"node_id": "elite_ambush", "kind": "combat", "phase": "active"}
	controller._finish_battle_in_session("victory")

	var surfaced := false
	for feed_value in controller.state.encounter_results:
		var feed: Dictionary = feed_value
		if str(feed.get("text_key", "")) != "elite_cost_applied":
			continue
		surfaced = true
		var text := str((feed["changes"] as Dictionary).get("cost_display", ""))
		assert_ne(text, "", "the cost feed carries concrete wording")
		match str(bound_cost["kind"]):
			"backlash":
				assert_true(text.contains("蛊蚀"), text)
				assert_true(text.contains("1 层"), text)
			"notoriety":
				assert_true(text.contains("恶名增加 2 点"), text)
	assert_true(surfaced, "the controller must append a visible elite cost feed")
