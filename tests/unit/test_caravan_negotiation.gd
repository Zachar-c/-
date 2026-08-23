extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_caravan_can_resolve_without_battle_using_evidence_and_trade() -> void:
	var state := _caravan_state()
	state = _act(state, "probe")["state"]
	var result := _act(state, "trade", {"offer": "ledger_evidence"})
	assert_true(result["result"]["ok"])
	assert_eq(result["state"].relations["caravan_steward"]["stance"], "helpful")
	assert_true(result["state"].known_facts.has("earth_vein_entry"))
	assert_eq(result["state"].event_log.back()["reason"], "caravan_trade_evidence")


func test_injury_reaction_exploit_changes_offer_but_not_will_gate() -> void:
	var state := _caravan_state()
	state.injury = 2
	var result := _act(state, "pressure")
	assert_eq(result["result"]["npc_reaction"], "exploit")
	assert_false(result["result"]["surrendered"])


func test_leaving_caravan_preserves_life_and_adds_suspicion() -> void:
	var result := _act(_caravan_state(), "leave")
	assert_true(result["result"]["ok"])
	assert_eq(result["state"].relations["caravan_steward"]["stance"], "suspicious")
	assert_true(result["state"].known_facts.has("caravan_suspicion"))


func test_three_caravan_actions_trigger_reinforcement_outcome() -> void:
	var state := _caravan_state()
	state = _act(state, "probe")["state"]
	state = _act(state, "pressure")["state"]
	var result := _act(state, "leave")
	assert_true(result["state"].known_facts.has("caravan_reinforcements_arrived"))
	assert_eq(result["state"].relations["caravan_steward"]["deadline_days"], 0)


func test_social_resolution_does_not_embed_dialogue_payload() -> void:
	var state := _caravan_state()
	var result := _act(state, "probe")
	assert_true(result["result"]["ok"])
	assert_eq(result["result"]["action_id"], "probe")
	assert_false(result["result"].has("dialogue"))


func test_template_gateway_rejects_unknown_intent() -> void:
	var gateway := TemplateDialogueGateway.new()
	var response := gateway.respond({"intent": "invalid", "disposition": "neutral"})
	assert_eq(response["intent"], "clarify")
	assert_true(response["needs_clarification"])


func _act(state: RunState, action: String, extra: Dictionary = {}) -> Dictionary:
	var command := {"type": "choose_action", "action_id": action, "npc_id": "caravan_steward"}
	for key in extra:
		command[key] = extra[key]
	return Resolver.apply(state, command, catalog)


func _caravan_state() -> RunState:
	var state := RunState.new_run(101)
	state.current_node_id = "caravan_missing_goods"
	state.known_facts = ["ledger_evidence"]
	return state
