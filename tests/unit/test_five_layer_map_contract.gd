extends GutTest


# R-layering 2026-08-27 user ruling:
# 1. A run is exactly five layers (one..five).
# 2. The ascension window is reachable ONLY from final_boss_stand, and the
#    boss stand must be beaten before the window opens (travel hard gate +
#    attempt_ascension reason=boss_undefeated).
# 3. visible_nodes annotates `reachable` so the map can separate travelable
#    neighbors from advisory lookahead (visible != reachable).
# Also pins the wanderer starter pack injected when no school is picked so
# the guaranteed layer-one combat is winnable without a shop detour.

const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")

const BOSS_ID := "final_boss_stand"
const WINDOW_ID := "ascension_window"


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _node_by_id(route: Array, node_id: String) -> Dictionary:
	for node in route:
		if str(node.get("id", "")) == node_id:
			return node
	return {}


func test_route_spans_exactly_five_layers_for_many_seeds() -> void:
	var layer_order: Array[String] = ["one", "two", "three", "four", "five"]
	for seed_value in [1, 2, 7, 18, 42, 99, 20260927]:
		var route: Array = MapGeneratorScript.build(seed_value, false)
		var stages_seen := {}
		for node in route:
			stages_seen[str(node.get("stage", ""))] = true
		for stage in layer_order:
			assert_true(stages_seen.has(stage),
				"seed %d: stage %s present" % [seed_value, stage])
		# Ascension window trails the five real layers as the terminal node.
		assert_eq(str(route[route.size() - 1].get("id", "")), WINDOW_ID,
			"seed %d: window appended last" % seed_value)


func test_ascension_window_only_reachable_through_boss_stand() -> void:
	for seed_value in [1, 2, 7, 18, 42, 99, 20260927]:
		var route: Array = MapGeneratorScript.build(seed_value, false)
		var window := _node_by_id(route, WINDOW_ID)
		assert_false(window.is_empty(), "seed %d has window" % seed_value)
		var boss := {}
		for node in route:
			if int(node.get("layer_boss", 0)) == 5:
				boss = node
		assert_false(boss.is_empty(), "seed %d has the final boss stand" % seed_value)
		assert_true((boss.get("next_ids", []) as Array).has(WINDOW_ID),
			"seed %d: boss leads to window" % seed_value)
		for node in route:
			var node_id := str(node.get("id", ""))
			if node_id == WINDOW_ID or int(node.get("layer_boss", 0)) == 5:
				continue
			assert_false((node.get("next_ids", []) as Array).has(WINDOW_ID),
				"seed %d: %s must not bypass the boss to the window" % [seed_value, node_id])


func test_every_last_layer_node_leads_into_boss_stand() -> void:
	for seed_value in [1, 2, 7, 42, 20260927]:
		var route: Array = MapGeneratorScript.build(seed_value, false)
		var by_id := {}
		for node in route:
			by_id[str(node.get("id", ""))] = node
		var boss := {}
		for node in route:
			if int(node.get("layer_boss", 0)) == 5:
				boss = node
		var boss_id := str(boss.get("id", ""))
		for node in route:
			if int(node.get("layer", 0)) != 5 or str(node.get("id", "")) in [boss_id, WINDOW_ID]:
				continue
			# v2 漏斗语义：第五大层每个节点沿前向边可达关底 Boss。
			var seen := {}
			var queue: Array[String] = [str(node.get("id", ""))]
			var reached := false
			while not queue.is_empty():
				var current: String = queue.pop_front()
				if seen.has(current):
					continue
				seen[current] = true
				if current == boss_id:
					reached = true
					break
				for next_id in by_id.get(current, {}).get("next_ids", []):
					queue.append(str(next_id))
			assert_true(reached,
				"seed %d: last-layer %s converges into the boss" % [seed_value, str(node.get("id", ""))])


func test_travel_into_window_refused_until_boss_defeated() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = BOSS_ID
	run.node_flags[BOSS_ID] = "visited"
	assert_eq(str(run.node_flags.get("boss_defeated", "")), "")

	var refused := ResolverScript.apply(run, {"type": "travel", "node_id": WINDOW_ID}, catalog)
	assert_false(bool(refused["result"]["ok"]))
	assert_eq(str(refused["result"]["reason"]), "boss_undefeated")

	var flags := run.node_flags.duplicate(true)
	flags["boss_defeated"] = "true"
	run.node_flags = flags
	var allowed := ResolverScript.apply(refused["state"], {"type": "travel", "node_id": WINDOW_ID}, catalog)
	assert_true(bool(allowed["result"]["ok"]),
		str(allowed["result"].get("reason", "")))


func test_visible_nodes_annotate_reachable_vs_advisory() -> void:
	var route: Array = MapGeneratorScript.build(101, false)
	var state := RunState.new_run(101)
	var shown: Array = MapGeneratorScript.visible_nodes(route, state, 2)
	# At trailhead only start nodes are travelable.
	for node in shown:
		var node_id := str(node.get("id", ""))
		var is_start: bool = bool(node.get("start", false))
		assert_eq(bool(node.get("reachable", !is_start)), is_start,
			"trailhead: %s reachable flag=%s matches start=%s" % [
				node_id, str(node.get("reachable")), str(is_start)])


func test_boss_battle_closes_retreat_for_good() -> void:
	# R-boss-no-retreat 2026-08-27: the window only exists behind this fight,
	# so boss-tier battles refuse retreat at resolver level and the preview
	# card is disabled with an explicit reason (SS16.5, no silent blocks).
	var run := RunState.new_run(101)
	var boss := BattleResolver.start({"enemy_kind": "miasma_vein_lord"}, run, catalog)
	assert_true(BattleResolver.boss_blocks_retreat(boss))
	var refused := BattleResolver.take_turn(boss, {"type": "retreat"}, run, catalog)
	assert_false(bool(refused.get("finished", false)),
			"retreat must not resolve in a boss battle")
	assert_eq(str(refused.get("result", "")), "ongoing")
	assert_eq(int(refused["battle"].get("enemy_hp", -1)), int(boss.get("enemy_hp", 0)),
			"refused retreat leaves the battle untouched")

	var common := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	assert_false(BattleResolver.boss_blocks_retreat(common))

	var preview := ActionPreviewService.preview_battle_actions(boss, run, catalog)
	var retreat_card := {}
	for card in preview:
		if str(card.get("id", "")) == "battle.retreat":
			retreat_card = card
			break
	assert_false(retreat_card.is_empty())
	assert_false(bool(retreat_card.get("executable", true)),
			"boss battle preview shows retreat as blocked")
	assert_string_contains(str(retreat_card.get("block_reason", "")), "退无可退")


func test_wanderer_pack_injected_when_no_school_picked() -> void:
	# The controller injects via its private path; here we pin the contract on
	# RunState directly by replaying what the hall does for school="" runs.
	var pack := ["thorn_whip_gu", "stone_shell_gu", "bear_strength_gu", "trail_eye_gu", "mist_step_gu"]
	var run := RunState.new_run(101)
	var index := 0
	for gu_id in pack:
		var instance_id := "gu_%03d" % (index + 2)
		index += 1
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": gu_id,
			"state": "refined",
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()
	# Deck built from wanderer pack + novice covers anti-reaction play:
	# stone_guard grants the guarded flag, thorn bind grants enemy_bound.
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var definition_ids: Array = []
	for card in battle.get("deck_cache", []):
		definition_ids.append(str(card.get("definition_id", "")))
	assert_true(definition_ids.has("stone_guard"),
		"wanderer deck contains the guard counter against guarded reactions")
	assert_true((battle.get("available_gu_ids", []) as Array).size() >= 5,
		"wanderer run has a full starting gu roster")
