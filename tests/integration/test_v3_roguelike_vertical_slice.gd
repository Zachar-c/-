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
	state.current_node_id = str(node["id"])
	var session := EncounterSessionResolverScript.start(node)
	var card := _card(ActionPreviewServiceScript.preview_actions(state, node, catalog), "node.work")
	var first := EncounterSessionResolverScript.apply(
		state,
		session,
		{"type": "action_card", "action_id": card["id"], "state_version": card["state_version"], "node_id": str(node["id"]), "session_node_id": str(session["node_id"])},
		catalog,
		node
	)
	var second := EncounterSessionResolverScript.apply(
		first["state"],
		first["session"],
		{"type": "action_card", "action_id": card["id"], "state_version": card["state_version"], "node_id": str(node["id"]), "session_node_id": str(session["node_id"])},
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
	# R-opening-fairness: school-less runs now inject the wanderer pack on top
	# of the novice so the guaranteed layer-one combat stays winnable.
	# 802 catalog 重建后自拟新包（缚/守/吸/攻/察，全 rank1 可入 V1 槽位）。
	# refined_gu_ids = RunState 默认 gu_001(small_light_gu) + 注入包（包内
	# small_light_gu 因已有实例去重跳过，顺序以实例投影为准）。
	var expected_pack := ["small_light_gu", "blood_farewell_gu", "stone_shell_gu", "blood_bat_gu", "force_gu"]
	assert_eq(controller.state.refined_gu_ids, expected_pack)


func _work_node() -> Dictionary:
	return {"id": "village_short_work", "type": "market", "choices": ["work"]}


func _card(cards: Array[Dictionary], id: String) -> Dictionary:
	for card in cards:
		if str(card.get("id", "")) == id:
			return card
	push_error("Missing action card: %s" % id)
	return {}
