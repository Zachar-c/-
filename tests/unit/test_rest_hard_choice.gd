extends GutTest


# P1a R8.1 rest hard choice: entering rest_hollow commits to exactly one
# benefit per visit — heal, upgrade one card, or one of the three removals.
# Leaving without consuming the visit is refused (no free skip); the preview
# layer mirrors the rule by disabling the leave card until a choice lands.


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _run_at_rest() -> RunState:
	var run := RunState.new_run(101)
	run.current_node_id = "rest_hollow"
	return run


func _travel_command() -> Dictionary:
	return {"type": "travel", "node_id": "ridge_caravan"}


func test_travel_without_choice_is_rejected_and_state_unchanged() -> void:
	var run := _run_at_rest()
	var result := ResolverScript.apply(run, _travel_command(), catalog)

	assert_false(result["result"]["ok"])
	assert_eq(str(result["result"]["reason"]), "rest_choice_required")
	assert_eq(result["state"].event_log.size(), run.event_log.size())
	assert_eq(str(result["state"].current_node_id), "rest_hollow")
	assert_false(result["state"].node_flags.has("rest_hollow_used"))

func test_travel_after_heal_is_allowed() -> void:
	var run := _run_at_rest()
	var rested: RunState = ResolverScript.apply(run, {"type": "rest"}, catalog)["state"]
	var result := ResolverScript.apply(rested, _travel_command(), catalog)

	assert_true(result["result"]["ok"])
	assert_eq(str(result["state"].current_node_id), "ridge_caravan")


func test_rest_upgrade_mode_upgrades_card_for_free_and_consumes_visit() -> void:
	var run := _run_at_rest()
	var stone_before := int(run.stone)
	var result := ResolverScript.apply(run, {
		"type": "rest", "mode": "upgrade_card", "card_key": "light_probe",
	}, catalog)

	assert_true(result["result"]["ok"])
	var next: RunState = result["state"]
	var override: Dictionary = next.gu_card_overrides.get("light_probe", {})
	assert_eq(int(override.get("upgrade_level", 0)), 1)
	assert_eq(int(next.stone), stone_before)
	assert_eq(str(next.node_flags.get("rest_hollow_used", "")), "used")
	assert_eq(str(next.node_flags.get("rest_hollow_mode", "")), "true")
	assert_eq(str(next.event_log.back()["reason"]), "battle_card_upgraded")


func test_rest_upgrade_matches_standalone_upgrade_accounting() -> void:
	var run := _run_at_rest()
	var standalone := ResolverScript.apply(run, {"type": "upgrade_card", "card_key": "light_probe"}, catalog)
	var rested := ResolverScript.apply(_run_at_rest(), {
		"type": "rest", "mode": "upgrade_card", "card_key": "light_probe",
	}, catalog)

	assert_eq(standalone["state"].gu_card_overrides, rested["state"].gu_card_overrides)
	assert_eq(int(standalone["state"].stone), int(run.stone))
	assert_eq(int(rested["state"].stone), int(run.stone))


func test_rest_upgrade_requires_card_key_without_consuming_visit() -> void:
	var run := _run_at_rest()
	var result := ResolverScript.apply(run, {"type": "rest", "mode": "upgrade_card"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(str(result["result"]["reason"]), "missing_card_key")
	assert_eq(str(result["state"].node_flags.get("rest_hollow_used", "")), "")
	assert_eq(str(result["state"].node_flags.get("rest_hollow_mode", "")), "")


func test_each_mode_consumes_the_single_visit_exactly_once() -> void:
	var heal := ResolverScript.apply(_run_at_rest(), {"type": "rest"}, catalog)
	assert_true(heal["result"]["ok"])
	var heal_again := ResolverScript.apply(heal["state"], {"type": "rest", "mode": "remove_curse", "curse_id": "gu_erosion"}, catalog)
	assert_false(heal_again["result"]["ok"])

	var upgraded := ResolverScript.apply(_run_at_rest(), {
		"type": "rest", "mode": "upgrade_card", "card_key": "light_probe",
	}, catalog)
	assert_true(upgraded["result"]["ok"])
	var upgrade_then_heal := ResolverScript.apply(upgraded["state"], {"type": "rest"}, catalog)
	assert_false(upgrade_then_heal["result"]["ok"])
	assert_true(["rest_already_used", "rest_mode_already_used"].has(str(upgrade_then_heal["result"]["reason"])),
			"a consumed visit must refuse every later choice")

	var removal := ResolverScript.apply(_run_at_rest(), {
		"type": "rest", "mode": "remove_card", "instance_id": "gu_001",
	}, catalog)
	assert_true(removal["result"]["ok"])
	var removal_then_upgrade := ResolverScript.apply(removal["state"], {
		"type": "rest", "mode": "upgrade_card", "card_key": "light_probe",
	}, catalog)
	assert_false(removal_then_upgrade["result"]["ok"])
	assert_true(["rest_already_used", "rest_mode_already_used"].has(str(removal_then_upgrade["result"]["reason"])),
			"a consumed visit must refuse every later choice")


func test_travel_gate_rejects_after_entering_via_removal_target_validation() -> void:
	# Invalid removal targets must not consume the visit; the leave gate stays shut.
	var run := _run_at_rest()
	run = CurseRegistryScript.gain_curse(run, "gu_erosion", "test")
	var bad := ResolverScript.apply(run, {"type": "rest", "mode": "remove_curse", "curse_id": "essence_bloat"}, catalog)
	assert_false(bad["result"]["ok"])
	var travel := ResolverScript.apply(bad["state"], _travel_command(), catalog)
	assert_false(travel["result"]["ok"])
	assert_eq(str(travel["result"]["reason"]), "rest_choice_required")

	var good := ResolverScript.apply(run, {"type": "rest", "mode": "remove_curse", "curse_id": "gu_erosion"}, catalog)
	assert_true(good["result"]["ok"])
	var free_to_go := ResolverScript.apply(good["state"], _travel_command(), catalog)
	assert_true(free_to_go["result"]["ok"])


const REST_NODE := {"id": "rest_hollow", "type": "rest", "choices": ["rest", "leave"]}


func _session_at_rest(run_seed: int = 101) -> Dictionary:
	var run := RunState.new_run(run_seed)
	run.current_node_id = "rest_hollow"
	var session: Dictionary = EncounterSessionResolverScript.start({"id": "rest_hollow", "type": "rest"})
	return {"run": run, "session": session}


func test_session_leave_without_choice_is_rejected_and_nothing_changes() -> void:
	var setup := _session_at_rest()
	var run: RunState = setup["run"]
	var result: Dictionary = EncounterSessionResolverScript.apply(
		run, setup["session"], {"type": "leave_node"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(str(result["result"]["reason"]), "rest_choice_required")
	# The session stays open and the state is untouched: the player can still choose.
	assert_false(result["session"]["completed"])
	assert_eq(str(result["session"]["completion_reason"]), "")
	assert_eq(int(result["state"].event_log.size()), int(run.event_log.size()))
	assert_false(result["state"].node_flags.has("rest_hollow_used"))
	assert_eq(str(result["state"].current_node_id), "rest_hollow")


func test_session_leave_after_consuming_the_visit_succeeds() -> void:
	var setup := _session_at_rest()
	var rested: Dictionary = EncounterSessionResolverScript.apply(
		setup["run"], setup["session"], {"type": "rest"}, catalog)
	assert_true(rested["result"]["ok"])

	var left: Dictionary = EncounterSessionResolverScript.apply(
		rested["state"], rested["session"], {"type": "leave_node"}, catalog)

	assert_true(left["result"]["ok"])
	assert_true(left["session"]["completed"])
	assert_eq(str(left["session"]["completion_reason"]), "player_left")


func test_preview_cards_carry_expects_target_for_targeted_options() -> void:
	var run := _run_at_rest()
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, REST_NODE, catalog)

	assert_true(cards.all(func(card: Dictionary) -> bool: return card.has("expects_target")),
			"every action card exposes the expects_target key")
	assert_eq(str(_card(cards, "node.rest_upgrade")["expects_target"]), "card_key")
	assert_eq(str(_card(cards, "node.rest_remove_card")["expects_target"]), "instance_id")
	assert_eq(str(_card(cards, "node.rest_remove_imprint")["expects_target"]), "relic_id")
	assert_eq(str(_card(cards, "node.rest_remove_curse")["expects_target"]), "curse_id")
	assert_eq(str(_card(cards, "node.rest_heal")["expects_target"]), "")
	assert_eq(str(_card(cards, "node.leave")["expects_target"]), "")


func test_preview_blocks_leave_until_a_choice_is_made() -> void:
	var run := _run_at_rest()
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, REST_NODE, catalog)
	var leave := _card(cards, "node.leave")

	assert_false(bool(leave["executable"]))
	assert_ne(str(leave["block_reason"]), "")

	for option_id in ["node.rest_heal", "node.rest_upgrade", "node.rest_remove_card", "node.rest_remove_imprint", "node.rest_remove_curse"]:
		assert_true(cards.any(func(card: Dictionary) -> bool: return str(card["id"]) == option_id),
				"missing rest option card %s" % option_id)
	assert_true(bool(_card(cards, "node.rest_heal")["executable"]))


func test_preview_option_executable_rules_mirror_domain_preconditions() -> void:
	var run := _run_at_rest()
	var bare: Array = ActionPreviewServiceScript.preview_actions(run, REST_NODE, catalog)

	assert_false(bool(_card(bare, "node.rest_remove_imprint")["executable"]),
			"no relic owned yet")
	assert_false(bool(_card(bare, "node.rest_remove_curse")["executable"]),
			"no curse attached yet")
	assert_true(bool(_card(bare, "node.rest_remove_card")["executable"]),
			"default novice gu is removable")
	assert_true(bool(_card(bare, "node.rest_upgrade")["executable"]))

	var with_relic: RunState = ResolverScript.apply(run, {"type": "gain_relic", "relic_id": "hungry_vine_token"}, catalog)["state"]
	with_relic = CurseRegistryScript.gain_curse(with_relic, "essence_bloat", "test")
	var rich: Array = ActionPreviewServiceScript.preview_actions(with_relic, REST_NODE, catalog)
	assert_true(bool(_card(rich, "node.rest_remove_imprint")["executable"]))
	assert_true(bool(_card(rich, "node.rest_remove_curse")["executable"]))


func test_preview_flips_executability_after_the_choice() -> void:
	var run := _run_at_rest()
	var consumed: RunState = ResolverScript.apply(run, {"type": "rest"}, catalog)["state"]
	var cards: Array = ActionPreviewServiceScript.preview_actions(consumed, REST_NODE, catalog)

	assert_true(bool(_card(cards, "node.leave")["executable"]))
	assert_eq(str(_card(cards, "node.leave")["block_reason"]), "")
	for option_id in ["node.rest_heal", "node.rest_upgrade", "node.rest_remove_card", "node.rest_remove_imprint", "node.rest_remove_curse"]:
		assert_false(bool(_card(cards, option_id)["executable"]),
				"%s must lock after the visit is consumed" % option_id)


func _card(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card["id"]) == id:
			return card
	push_error("Missing card %s" % id)
	return {}
