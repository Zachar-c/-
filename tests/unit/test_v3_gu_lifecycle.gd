extends GutTest


const DeckBuilderScript = preload("res://scripts/domain/deck_builder.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_many_gu_are_allowed_but_feeding_need_scales_by_instances() -> void:
	var run := RunState.new_run(101)
	for index in range(1, 12):
		var instance_id := "gu_%03d" % (index + 1)
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": "small_light_gu",
			"state": "refined",
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)

	if not run.has_method("estimate_feeding_materials"):
		fail_test("RunState should expose instance-based feeding material estimates")
		return
	var estimate: Dictionary = run.call("estimate_feeding_materials", catalog)
	assert_eq(estimate["feed_points"], 12)


func test_unfed_gu_becomes_weakened_then_dies_deterministically() -> void:
	var run := RunState.new_run(101)
	var first := Resolver.apply(run, {"type": "settle_node_feeding"}, catalog)

	assert_true(first["result"]["ok"])
	assert_eq(first["state"].gu_instances["gu_001"]["state"], "weakened")

	var second := Resolver.apply(first["state"], {"type": "settle_node_feeding"}, catalog)
	assert_true(second["result"]["ok"])
	assert_eq(second["state"].gu_instances["gu_001"]["state"], "dead")


func test_disabling_battle_card_keeps_source_gu_but_destroying_gu_removes_future_cards() -> void:
	var run := RunState.new_run(101)
	var disabled_result: Dictionary = Resolver.apply(run, {
		"type": "disable_card",
		"card_key": "small_light_gu:light_probe",
	}, catalog)
	var disabled: RunState = disabled_result["state"]

	assert_true(disabled.gu_instances.has("gu_001"))
	assert_true(DeckBuilderScript.build_card_cache(disabled, catalog).is_empty())

	var destroyed_result: Dictionary = Resolver.apply(disabled, {
		"type": "destroy_gu",
		"instance_id": "gu_001",
	}, catalog)
	var destroyed: RunState = destroyed_result["state"]
	assert_eq(destroyed.gu_instances["gu_001"]["state"], "dead")
	assert_true(DeckBuilderScript.build_card_cache(destroyed, catalog).is_empty())


func test_lifespan_depletion_marks_run_dead_and_discards_temporary_assets() -> void:
	var run := RunState.new_run(101)
	run.cultivator["lifespan"] = 1
	run.materials["feed_points"] = 9
	run.relic_ids.append("temporary_relic")
	run.gu_card_overrides["small_light_gu:light_probe"] = {"disabled_for_run": true}

	var result := Resolver.apply(run, {"type": "spend_lifespan", "amount": 1}, catalog)
	var dead: RunState = result["state"]

	assert_true(result["result"]["ok"])
	assert_eq(dead.terminal_state, "dead")
	assert_true(dead.gu_instances.is_empty())
	assert_true(dead.cave_aperture["stored_gu_instance_ids"].is_empty())
	assert_true(dead.gu_card_overrides.is_empty())
	assert_true(dead.materials.is_empty())
	assert_eq(dead.relic_ids, [])
	assert_false(dead.event_log.is_empty())
	assert_eq(dead.event_log.back()["reason"], "run_ended")

	var rejected := Resolver.apply(dead, {"type": "spend_lifespan", "amount": 1}, catalog)
	assert_false(rejected["result"]["ok"])
	assert_eq(rejected["result"]["reason"], "terminal_run")

func test_terminal_run_produces_no_action_cards() -> void:
	var run := RunState.new_run(101)
	run.terminal_state = "dead"
	var node := {"id": "village_short_work", "type": "work", "choices": ["work"]}

	assert_true(ActionPreviewServiceScript.preview_actions(run, node, catalog).is_empty())


func test_battle_death_finalizes_run_and_clears_temporary_assets() -> void:
	var run := RunState.new_run(101)
	run.health = 1
	run.cultivator["health"] = 1
	run.materials["feed_points"] = 3
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)

	var resolved := BattleResolver.take_turn(battle, {"type": "end_turn"}, run, catalog)
	var dead: RunState = resolved["state"]

	assert_eq(resolved["result"], "death")
	assert_eq(dead.terminal_state, "dead")
	assert_true(dead.gu_instances.is_empty())
	assert_true(dead.cave_aperture["stored_gu_instance_ids"].is_empty())
	assert_false(dead.event_log.is_empty())
	assert_eq(dead.event_log.back()["reason"], "run_ended")

	assert_true(ActionPreviewServiceScript.preview_battle_actions(resolved["battle"], dead, catalog).is_empty())
	var rejected := BattleResolver.apply_action_card(resolved["battle"], dead, {
		"type": "action_card",
		"action_id": "battle.end_turn",
		"state_version": int(resolved["battle"]["hand_version"]),
	}, catalog)
	assert_false(rejected["accepted"])
	assert_eq(rejected["feeds"], ["terminal_run"])


func test_high_rank_gu_no_longer_backlashes_at_low_cultivation() -> void:
	# 2026-08-31 数值重做：反噬系统整体移除，高转蛊在低修为下可以正常催动。
	var tuned_catalog: Dictionary = catalog.duplicate(true)
	tuned_catalog["gu_by_id"]["small_light_gu"]["rank"] = 2
	var run := RunState.new_run(101)
	run.health = 2
	var battle := BattleResolver.start({"enemy_kind": "beast_swarm"}, run, tuned_catalog)

	var result := BattleResolver.apply_action_card(battle, run, _command_for_definition(battle, "light_probe"), tuned_catalog)

	assert_true(bool(result.get("accepted", false)), "高转蛊可催动")
	assert_eq(result["state"].health, 2)
	assert_ne(result["state"].terminal_state, "dead")


func _command_for_definition(battle: Dictionary, definition_id: String) -> Dictionary:
	for instance in battle["hand"]:
		if str(instance["definition_id"]) == definition_id:
			return {
				"type": "action_card",
				"action_id": "battle.%s.%s" % [str(battle["battle_id"]), str(instance["instance_id"])],
				"state_version": int(battle["hand_version"]),
			}
	push_error("Missing card definition in hand: %s" % definition_id)
	return {}
