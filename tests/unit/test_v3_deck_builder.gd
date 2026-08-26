extends GutTest


const DECK_BUILDER_PATH := "res://scripts/domain/deck_builder.gd"


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_deck_hash_is_stable_until_gu_or_card_override_changes() -> void:
	var builder: Script = _load_builder()
	if builder == null:
		return
	var run := RunState.new_run(101)
	var first: String = builder.deck_hash(run, catalog)

	assert_eq(first, builder.deck_hash(run, catalog))
	run.gu_card_overrides["small_light_gu:light_probe"] = {"extra_copies": 1}
	assert_ne(first, builder.deck_hash(run, catalog))


func test_opening_gu_generates_cards_without_hard_coded_deck() -> void:
	var builder: Script = _load_builder()
	if builder == null:
		return
	var run := RunState.new_run(101)
	var cards: Array = builder.build_card_cache(run, catalog)

	assert_eq(cards.map(func(card: Dictionary) -> String: return str(card["definition_id"])), ["light_probe"])
	assert_eq(cards[0]["source_gu_instance_ids"], ["gu_001"])


func test_kill_move_requires_ordered_source_gu_and_pending_state_contract() -> void:
	var definition: Dictionary = catalog.get("card_by_id", {}).get("moonlight_return", {})

	assert_false(definition.is_empty(), "moonlight_return should be loaded as a data-driven card")
	if definition.is_empty():
		return
	assert_eq(definition["kill_move_sequence"], ["moonlight_gu", "small_light_gu"])
	assert_eq(definition["sequence_window"], "same_turn")

func test_catalog_rejects_missing_card_metadata_references() -> void:
	var invalid := catalog.duplicate(true)
	invalid["gu"][0]["feeding_need"] = {"unknown_feed": 1}
	invalid["cards"][0]["source_gu_ids"] = ["missing_gu"]
	invalid["cards"][1].erase("duration_turns")
	invalid["cards"][3]["kill_move_sequence"] = ["missing_gu"]

	var errors := ContentCatalog.validate(invalid)

	assert_true(errors.any(func(error: String) -> bool: return error.contains("unknown feeding material")))
	assert_true(errors.any(func(error: String) -> bool: return error.contains("missing source gu")))
	assert_true(errors.any(func(error: String) -> bool: return error.contains("duration_turns")))
	assert_true(errors.any(func(error: String) -> bool: return error.contains("kill move")))

func _load_builder() -> Script:
	var builder: Script = load(DECK_BUILDER_PATH)
	assert_not_null(builder, "DeckBuilder should exist as a pure domain helper")
	return builder
