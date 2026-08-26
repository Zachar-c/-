extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const RUN_CONTROLLER := preload("res://scripts/presentation/run_controller.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_duplicate_action_card_submission_is_atomic() -> void:
	var state := RunState.new_run(101)
	var node := _work_node()
	var session := EncounterSessionResolverScript.start(node)
	var card := _card(ActionPreviewServiceScript.preview_actions(state, node, catalog), "node.work")
	var first := EncounterSessionResolverScript.apply(
		state,
		session,
		{"type": "action_card", "action_id": card["id"], "state_version": card["state_version"]},
		catalog,
		node
	)
	var second := EncounterSessionResolverScript.apply(
		first["state"],
		first["session"],
		{"type": "action_card", "action_id": card["id"], "state_version": card["state_version"]},
		catalog,
		node
	)
	assert_true(first["result"]["ok"])
	assert_false(second["result"]["ok"])
	assert_eq(int(second["state"].stone), int(first["state"].stone))


func test_first_vertical_slice_travels_fogged_route_to_boss_and_resets_after_death() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(101)
	assert_true(controller.visible_route_nodes().size() < controller.route.size())
	controller.force_death_for_test("test_blow")
	assert_eq(str(controller.state.terminal_state), "dead")
	controller.start_new_run(101)
	assert_eq(controller.state.refined_gu_ids, ["small_light_gu"])


func _work_node() -> Dictionary:
	return {"id": "village_short_work", "type": "market", "choices": ["work"]}


func _card(cards: Array[Dictionary], id: String) -> Dictionary:
	for card in cards:
		if str(card.get("id", "")) == id:
			return card
	push_error("Missing action card: %s" % id)
	return {}
