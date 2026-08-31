extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const MetaProgressScript = preload("res://scripts/domain/meta_progress.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_fixed_moonlight_recipe_consumes_input_instances_and_outputs_moon_glow() -> void:
	var run := _run_with_gu_definitions(["moonlight_gu", "small_light_gu", "small_light_gu"])

	var result := Resolver.apply(run, {"type": "refine_gu", "recipe_id": "moon_glow_fixed"}, catalog)
	var refined: RunState = result["state"]

	assert_true(result["result"]["ok"])
	assert_eq(refined.refined_gu_ids.count("moon_glow_gu"), 1)
	assert_eq(refined.refined_gu_ids.count("small_light_gu"), 0)
	assert_eq(refined.refined_gu_ids.count("moonlight_gu"), 0)

	var live_ids: Array = refined.cave_aperture["stored_gu_instance_ids"]
	assert_eq(live_ids.size(), 1)
	assert_eq(str(refined.gu_instances[str(live_ids[0])]["definition_id"]), "moon_glow_gu")
	assert_eq(refined.event_log.back()["reason"], "refinement_succeeded")


func test_fixed_recipe_rejects_without_all_input_instances() -> void:
	var run := _run_with_gu_definitions(["moonlight_gu", "small_light_gu"])

	var result := Resolver.apply(run, {"type": "refine_gu", "recipe_id": "moon_glow_fixed"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "missing_refinement_input")
	assert_true(result["state"].gu_instances.has("gu_001"))


func test_free_mix_preview_is_vague_before_discovery_and_exact_after_discovery() -> void:
	var run := _run_with_gu_definitions(["small_light_gu", "trail_eye_gu"])
	var node := {"id": "refinement_den", "type": "refinement", "choices": []}

	var unknown := ActionPreviewServiceScript.preview_actions(run, node, catalog)
	assert_string_contains(str(_card(unknown, "refine.free_mix")["unknown_note"]), "结果未明")

	var knowledge := {"small_light_gu+trail_eye_gu": ["mutation_venom"]}
	var known := ActionPreviewServiceScript.preview_actions(run, node, catalog, knowledge)
	assert_string_contains(str(_card(known, "refine.free_mix")["known_risk"]), "畸变")


func test_free_mix_resolves_seeded_outcome_and_never_accepts_ui_roll() -> void:
	var run := _run_with_gu_definitions(["small_light_gu", "trail_eye_gu"])

	var result := Resolver.apply(run, {
		"type": "refine_gu",
		"recipe_id": "free_mix",
		"input_instance_ids": _instance_ids(run),
		"roll": 100,
	}, catalog)

	assert_true(result["result"]["ok"])
	assert_false(result["result"].has("roll"))
	assert_true(result["state"].event_log.back()["reason"] in [
		"free_mix_destroyed", "free_mix_mutation", "free_mix_explosion"
	])

	var repeat := _run_with_gu_definitions(["small_light_gu", "trail_eye_gu"])
	var repeat_result := Resolver.apply(repeat, {
		"type": "refine_gu",
		"recipe_id": "free_mix",
		"input_instance_ids": _instance_ids(repeat),
	}, catalog)
	assert_eq(
		repeat_result["state"].event_log.back()["reason"],
		result["state"].event_log.back()["reason"]
	)


func test_observed_outcomes_accumulate_in_meta_progress_without_duplicates() -> void:
	var meta = MetaProgressScript.new_empty()
	var once = meta.record_random_outcome("small_light_gu+trail_eye_gu", "mutation_venom")
	var twice = once.record_random_outcome("small_light_gu+trail_eye_gu", "mutation_venom")

	assert_eq(twice.unlocked_random_outcomes["small_light_gu+trail_eye_gu"], ["mutation_venom"])
	assert_eq(meta.unlocked_random_outcomes, {})


func _run_with_gu_definitions(definition_ids: Array[String]) -> RunState:
	var run := RunState.new_run(101)
	# 2026-08-31 数值重做：魂魄底蕴 1 → 炼蛊并发上限 2；本文件配方需 3 输入，
	# 夹具抬到魂魄 5（上限 4）以隔离测炼蛊语义本身。
	run.cultivator["soul"] = 5
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	for index in definition_ids.size():
		var instance_id := "gu_%03d" % (index + 1)
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": definition_ids[index],
			"state": "refined",
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()
	return run


func _instance_ids(run: RunState) -> Array:
	return run.cave_aperture["stored_gu_instance_ids"].duplicate()


func _card(cards: Array[Dictionary], id: String) -> Dictionary:
	for card in cards:
		if str(card.get("id", "")) == id:
			return card
	push_error("Missing action card: %s" % id)
	return {}
