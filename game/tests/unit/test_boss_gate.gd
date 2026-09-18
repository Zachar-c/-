extends GutTest


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_ascension_rejected_without_boss_defeated() -> void:
	var state := _prepared_state()
	var result := ResolverScript.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "boss_undefeated")
	assert_eq(result["state"].ascension, state.ascension)


func test_record_boss_defeated_sets_flag_and_logs_event() -> void:
	var result := ResolverScript.apply(RunState.new_run(101), {"type": "record_boss_defeated"}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(str(result["state"].node_flags.get("boss_defeated", "")), "true")
	assert_eq(result["state"].event_log[result["state"].event_log.size() - 2]["reason"], "boss_defeated_recorded")


func test_ascension_allowed_after_boss_defeated() -> void:
	var state := _prepared_state()
	state.node_flags["boss_defeated"] = "true"
	var result := ResolverScript.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)

	assert_true(result["result"]["ok"])
	assert_true(str(result["result"]["outcome"]) in [
		"ascension_special", "ascension_high", "ascension_medium", "ascension_low"])


func test_preview_blocks_ascension_card_without_boss() -> void:
	var node := {"id": "ascension_window", "type": "ascension", "choices": ["attempt_ascension", "prepare", "retreat"]}
	var cards: Array = ActionPreviewServiceScript.preview_actions(_prepared_state(), node, catalog)
	var card := _card(cards, "node.attempt_ascension")

	assert_false(bool(card["executable"]))
	assert_string_contains(str(card["block_reason"]), "终局强敌")

	var cleared := _prepared_state()
	cleared.node_flags["boss_defeated"] = "true"
	var open_cards: Array = ActionPreviewServiceScript.preview_actions(cleared, node, catalog)
	assert_true(bool(_card(open_cards, "node.attempt_ascension")["executable"]))


func _prepared_state() -> RunState:
	var state := RunState.new_run(101)
	state.ascension = {
		"aperture_foundation": true,
		"heaven_earth_qi": true,
		"site": true,
		"protection": true,
		"external_interference": false,
	}
	return state


func _card(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card["id"]) == id:
			return card
	push_error("Missing card %s" % id)
	return {}