extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_poison_combo_shows_rule_hint_when_unknown() -> void:
	var run := _run_with_gu_definitions(["venom_thread_gu", "small_light_gu"])
	var node := {"id": "refinement_den", "type": "refinement", "choices": []}
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, node, catalog)
	var card := _card(cards, "refine.free_mix")

	assert_string_contains(str(card["unknown_note"]), "腥气")


func test_moon_combo_shows_moon_hint() -> void:
	var run := _run_with_gu_definitions(["moonlight_gu", "small_light_gu"])
	var node := {"id": "refinement_den", "type": "refinement", "choices": []}
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, node, catalog)

	assert_string_contains(str(_card(cards, "refine.free_mix")["unknown_note"]), "月息")


func test_plain_combo_keeps_default_vague_text() -> void:
	var run := _run_with_gu_definitions(["small_light_gu", "trail_eye_gu"])
	var node := {"id": "refinement_den", "type": "refinement", "choices": []}
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, node, catalog)

	assert_string_contains(str(_card(cards, "refine.free_mix")["unknown_note"]), "结果未明")


func test_known_outcomes_override_rule_hints() -> void:
	var run := _run_with_gu_definitions(["venom_thread_gu", "small_light_gu"])
	var node := {"id": "refinement_den", "type": "refinement", "choices": []}
	var knowledge := {"small_light_gu+venom_thread_gu": ["mutation_venom"]}
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, node, catalog, knowledge)
	var card := _card(cards, "refine.free_mix")

	assert_string_contains(str(card["known_risk"]), "畸变")
	assert_eq(str(card["unknown_note"]), "")


func test_validation_rejects_unknown_risk_hint_tag() -> void:
	var tuned := catalog.duplicate(true)
	var hint := {"tags": ["beast"], "text": "兽性躁动。"}
	for recipe in tuned["refinement_recipes"]:
		if recipe["id"] == "free_mix":
			recipe["risk_hints"] = [hint]
	for recipe_id in tuned["refinement_by_id"]:
		if recipe_id == "free_mix":
			tuned["refinement_by_id"][recipe_id]["risk_hints"] = [hint]

	var errors: Array[String] = ContentCatalogScript.validate(tuned)
	var hit := false
	for error in errors:
		if error.contains("risk hint references unknown tag beast"):
			hit = true
	assert_true(hit)


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