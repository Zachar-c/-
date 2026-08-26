extends GutTest


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_rest_recovers_health_and_essence_without_lifespan() -> void:
	var state := RunState.new_run(101)
	state.health = 4
	state.essence = 2
	state.current_node_id = "rest_hollow"
	var result := ResolverScript.apply(state, {"type": "rest"}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(result["state"].health, 6)
	assert_eq(result["state"].essence, 4)
	assert_eq(int(result["state"].cultivator["lifespan"]), 60)
	assert_eq(result["state"].event_log.back()["reason"], "rest_recovered")


func test_rest_recovers_only_once_per_node() -> void:
	var state := RunState.new_run(101)
	state.health = 4
	state.current_node_id = "rest_hollow"
	var first := ResolverScript.apply(state, {"type": "rest"}, catalog)
	var second := ResolverScript.apply(first["state"], {"type": "rest"}, catalog)

	assert_false(second["result"]["ok"])
	assert_eq(second["result"]["reason"], "rest_already_used")
	assert_eq(second["state"].health, 6)


func test_rest_is_rejected_outside_rest_node() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "ridge_caravan"
	var result := ResolverScript.apply(state, {"type": "rest"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "not_rest_node")


func test_rest_preview_shows_card_and_blocks_after_use() -> void:
	var node := {"id": "rest_hollow", "type": "rest", "choices": ["rest", "leave"]}
	var state := RunState.new_run(101)
	state.health = 4
	state.current_node_id = "rest_hollow"
	var cards: Array = ActionPreviewServiceScript.preview_actions(state, node, catalog)
	var card := _card(cards, "node.rest")

	assert_true(bool(card["executable"]))
	assert_eq(str(card["block_reason"]), "")

	var used: RunState = ResolverScript.apply(state, {"type": "rest"}, catalog)["state"]
	var after_cards: Array = ActionPreviewServiceScript.preview_actions(used, node, catalog)
	assert_false(bool(_card(after_cards, "node.rest")["executable"]))


func _card(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card["id"]) == id:
			return card
	push_error("Missing card %s" % id)
	return {}