class_name DeckCapacity
extends RefCounted

# Pure deck-size projection. Deck size equals the battle card cache size;
# capacity limits net gains so buying/rewards cannot silently overflow.

const DeckBuilderScript = preload("res://scripts/domain/deck_builder.gd")


static func capacity(catalog: Dictionary) -> int:
	return int(catalog.get("deck", {}).get("capacity", 12))


# R4.9 imprint slots cap owned relics (imprints); separate from card capacity.
# Validation enforces the field exists, so this default only guards tuned
# in-memory catalogs built by tests.
static func imprint_capacity(catalog: Dictionary) -> int:
	return int(catalog.get("deck", {}).get("imprint_capacity", 4))


static func card_count(state: RunState, catalog: Dictionary) -> int:
	return DeckBuilderScript.build_card_cache(state, catalog).size()


static func cards_for_gu(state: RunState, catalog: Dictionary, gu_id: String) -> int:
	var gu: Dictionary = catalog.get("gu_by_id", {}).get(gu_id, {})
	var copies := 0
	for card_id_value in gu.get("card_blueprint_ids", []):
		var card_id := str(card_id_value)
		var override_key := "%s:%s" % [gu_id, card_id]
		var override: Dictionary = state.gu_card_overrides.get(override_key, {})
		copies += 1 + int(override.get("extra_copies", 0))
	return copies


static func projected_count(state: RunState, catalog: Dictionary, added_gu_ids: Array, removed_gu_ids: Array) -> int:
	var base := card_count(state, catalog)
	for gu_id_value in removed_gu_ids:
		base = maxi(0, base - cards_for_gu(state, catalog, str(gu_id_value)))
	for gu_id_value in added_gu_ids:
		base += cards_for_gu(state, catalog, str(gu_id_value))
	return base


static func would_exceed(state: RunState, catalog: Dictionary, extra_cards: int) -> bool:
	return card_count(state, catalog) + extra_cards > capacity(catalog)
