extends GutTest


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_kill_neutral_npc_gains_two_notoriety_through_event_log() -> void:
	var run := RunState.new_run(101)
	var result := ResolverScript.apply(run, {"type": "record_neutral_npc_kill"}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(int(result["state"].cultivator["notorious"]), 2)
	var event: Dictionary = result["state"].event_log.back()
	assert_eq(event["reason"], "notoriety_gained")
	assert_eq(event["targets"], ["kill_neutral_npc"])


func test_breaking_trust_on_leave_gains_one_notoriety() -> void:
	var run := RunState.new_run(101)
	run = ResolverScript.apply(run, {"type": "travel", "node_id": "ridge_caravan"}, catalog)["state"]
	run.known_facts.append("caravan_favor_debt")
	var session := EncounterSessionResolverScript.start({"id": "ridge_caravan", "type": "caravan"})
	var result := EncounterSessionResolverScript.apply(run, session, {"type": "leave_node"}, catalog)

	assert_eq(int(result["state"].cultivator["notorious"]), 1)


func test_clean_leave_gains_no_notoriety() -> void:
	var run := RunState.new_run(101)
	run = ResolverScript.apply(run, {"type": "travel", "node_id": "ridge_caravan"}, catalog)["state"]
	var session := EncounterSessionResolverScript.start({"id": "ridge_caravan", "type": "caravan"})
	var result := EncounterSessionResolverScript.apply(run, session, {"type": "leave_node"}, catalog)

	assert_eq(int(result["state"].cultivator["notorious"]), 0)


func test_price_rises_ten_percent_per_point_capped_at_sixty_percent() -> void:
	var two := RunState.new_run(101)
	two.cultivator["notorious"] = 2
	var purchase := ResolverScript.apply(two, {"type": "shop_purchase", "offer_id": "purchase_moonlight"}, catalog)
	assert_true(purchase["result"]["ok"])
	assert_eq(purchase["state"].stone, 12 - 8)

	var six := RunState.new_run(101)
	six.cultivator["notorious"] = 6
	var capped := ResolverScript.apply(six, {"type": "shop_purchase", "offer_id": "purchase_moonlight"}, catalog)
	assert_true(capped["result"]["ok"])
	assert_eq(capped["state"].stone, 12 - 10)

	var eight := RunState.new_run(101)
	eight.cultivator["notorious"] = 8
	var hard_capped := ResolverScript.apply(eight, {"type": "shop_purchase", "offer_id": "purchase_moonlight"}, catalog)
	assert_true(hard_capped["result"]["ok"])
	assert_eq(hard_capped["state"].stone, 12 - 10)


func test_hostile_stance_roll_is_guaranteed_at_high_notoriety_and_absent_at_zero() -> void:
	var run := RunState.new_run(101)
	run.cultivator["notorious"] = 7
	var begun := EncounterSessionResolverScript.begin(run, {"id": "neutral_wanderer", "type": "contact"}, catalog)
	# High notoriety guarantees a hostile or extreme stance (never neutral).
	assert_true(bool(begun["session"]["flags"].get("reputation_hostile", false)) or bool(begun["session"]["flags"].get("reputation_extreme", false)))

	var clean := EncounterSessionResolverScript.begin(RunState.new_run(101), {"id": "neutral_wanderer", "type": "contact"}, catalog)
	assert_false(bool(clean["session"]["flags"].get("reputation_hostile", false)))
	assert_false(bool(clean["session"]["flags"].get("reputation_extreme", false)))


func test_battle_marks_first_mover_and_enemy_strikes_first() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound", "first_mover": "enemy"}, run, catalog)
	assert_eq(str(battle["first_mover"]), "enemy")

	var pre := BattleResolver.apply_enemy_pre_turn(battle, run, catalog)
	assert_false(pre["finished"])
	assert_true(pre["feeds"].has("enemy_first_move"))
	assert_lt(int(pre["state"].health), 6)
	assert_eq(pre["battle"]["log"].back()["source"], "enemy")

	var normal := BattleResolver.start({"enemy_kind": "ridge_hound"}, RunState.new_run(101), catalog)
	assert_eq(str(normal["first_mover"]), "player")


func test_enemy_pre_turn_can_kill_and_finalizes_death() -> void:
	var run := RunState.new_run(101)
	run.health = 2
	var battle := BattleResolver.start({"enemy_kind": "resolute_elite", "first_mover": "enemy"}, run, catalog)
	var pre := BattleResolver.apply_enemy_pre_turn(battle, run, catalog)

	assert_true(pre["finished"])
	assert_eq(pre["result"], "death")
	assert_true(pre["feeds"].has("player_dead"))
	assert_eq(str(pre["state"].terminal_state), "dead")


func test_wash_notoriety_pays_lifespan_and_reduces_notoriety() -> void:
	var run := RunState.new_run(101)
	run.cultivator["notorious"] = 4
	var result := ResolverScript.apply(run, {"type": "wash_notoriety"}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(int(result["state"].cultivator["notorious"]), 2)
	assert_eq(int(result["state"].cultivator["lifespan"]), 50)
	assert_eq(result["state"].event_log.back()["reason"], "notoriety_washed")


func test_wash_notoriety_respects_trade_precheck_and_nothing_to_wash() -> void:
	var run := RunState.new_run(101)
	run.cultivator["lifespan"] = 5
	run.cultivator["notorious"] = 4
	var blocked := ResolverScript.apply(run, {"type": "wash_notoriety"}, catalog)
	assert_false(blocked["result"]["ok"])
	assert_eq(blocked["result"]["reason"], "lifespan_trade_warning")

	var clean := ResolverScript.apply(RunState.new_run(101), {"type": "wash_notoriety"}, catalog)
	assert_false(clean["result"]["ok"])
	assert_eq(clean["result"]["reason"], "nothing_to_wash")


func test_shop_preview_shows_uplifted_price_and_wash_card() -> void:
	var run := RunState.new_run(101)
	run.cultivator["notorious"] = 2
	var node := {"id": "ridge_black_market", "type": "shop", "choices": []}
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, node, catalog)
	var purchase := _card(cards, "shop.purchase.moonlight")
	assert_eq(int(purchase["cost"]["stone"]), 8)
	var wash := _card(cards, "shop.wash.notoriety")
	assert_true(bool(wash["executable"]))
	assert_eq(int(wash["cost"]["lifespan"]), 10)

	var clean_cards: Array = ActionPreviewServiceScript.preview_actions(RunState.new_run(101), node, catalog)
	var clean_wash := _card(clean_cards, "shop.wash.notoriety")
	assert_false(bool(clean_wash["executable"]))


func _card(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card["id"]) == id:
			return card
	push_error("Missing card %s" % id)
	return {}