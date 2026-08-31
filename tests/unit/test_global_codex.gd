extends GutTest


const MetaProgressScript = preload("res://scripts/domain/meta_progress.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_locked_recipe_refines_when_codex_has_recipe_id() -> void:
	var run := _run_with_gu_definitions(["moon_glow_gu", "shadow_veil_gu"])
	run.global_codex_ids = ["phantom_moon_locked"]
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "phantom_moon_locked"}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(result["result"].get("reason", ""), "")


func test_locked_recipe_stays_rejected_without_codex() -> void:
	var run := _run_with_gu_definitions(["moon_glow_gu", "shadow_veil_gu"])
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "phantom_moon_locked"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "refinement_recipe_locked")


func test_locked_recipe_refines_when_codex_has_output_gu() -> void:
	var run := _run_with_gu_definitions(["moon_glow_gu", "shadow_veil_gu"])
	run.global_codex_ids = ["phantom_moon_gu"]
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "phantom_moon_locked"}, catalog)

	assert_true(result["result"]["ok"])


func test_new_run_snapshots_meta_codex() -> void:
	var meta: Variant = MetaProgress.new()
	meta.recipe_codex_ids.assign(["phantom_moon_locked"])
	meta.gu_codex_ids.assign(["phantom_moon_gu"])
	var run := RunState.new_run(101, meta)

	assert_true(run.global_codex_ids.has("phantom_moon_locked"))
	assert_true(run.global_codex_ids.has("phantom_moon_gu"))
	assert_true(RunState.new_run(101).global_codex_ids.is_empty())


func test_global_codex_survives_save_data_and_state_copy() -> void:
	var run := RunState.new_run(101)
	run.global_codex_ids = ["phantom_moon_locked"]
	var data: Dictionary = run.to_save_data()
	assert_eq(data["global_codex_ids"], ["phantom_moon_locked"])
	var copied := run.append_event({
		"action": "probe_state",
		"after": {},
		"reason": "probe",
		"targets": [],
	})
	assert_eq(copied.global_codex_ids, ["phantom_moon_locked"])


func test_refine_success_records_recipe_into_meta_codex_at_run_end() -> void:
	var run := _run_with_gu_definitions(["moonlight_gu", "small_light_gu", "small_light_gu"])
	run.cultivator["soul"] = 4  # 月芒蛊方 3 件输入，需并发上限 ≥3
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "moon_glow_fixed"}, catalog)
	assert_true(result["result"]["ok"])
	assert_true(result["state"].event_log.back()["targets"].has("recipe:moon_glow_fixed"))

	var meta: Variant = MetaProgress.new()
	var recorded = meta.record_run_end(result["state"], "won")
	assert_true(recorded.recipe_codex_ids.has("moon_glow_fixed"))
	assert_true(recorded.gu_codex_ids.has("moon_glow_gu"))


func test_locked_recipe_becomes_visible_in_preview_after_codex_unlock() -> void:
	var run := _run_with_gu_definitions(["moon_glow_gu", "shadow_veil_gu"])
	run.global_codex_ids = ["phantom_moon_locked"]
	var node := {"id": "refinement_hollow", "type": "refinement"}
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, node, catalog)
	var card := _card(cards, "refine.phantom_moon_locked")

	assert_true(bool(card["executable"]))

	var blocked := ActionPreviewServiceScript.preview_actions(
		_run_with_gu_definitions(["moon_glow_gu", "shadow_veil_gu"]),
		node,
		catalog
	)
	assert_false(bool(_card(blocked, "refine.phantom_moon_locked")["executable"]))


func _run_with_gu_definitions(definition_ids: Array[String]) -> RunState:
	var run := RunState.new_run(101)
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


func _card(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card["id"]) == id:
			return card
	push_error("Missing card %s" % id)
	return {}