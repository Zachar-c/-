class_name DeckBuilder
extends RefCounted


# Pure Gu-to-card projection. It does not mutate RunState or consume RNG.
static func deck_hash(run: RunState, _catalog: Dictionary) -> String:
	var sources: Array[Dictionary] = []
	for instance in _refined_instances_with_legacy_fallback(run):
		sources.append({
			"instance_id": str(instance.get("instance_id", "")),
			"definition_id": str(instance.get("definition_id", "")),
			"state": str(instance.get("state", "")),
		})
	return JSON.stringify({
		"gu": sources,
		"overrides": run.gu_card_overrides,
	}).sha256_text()


static func build_card_cache(run: RunState, catalog: Dictionary) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	var card_by_id: Dictionary = catalog.get("card_by_id", {})
	for instance in _refined_instances_with_legacy_fallback(run):
		var definition_id := str(instance.get("definition_id", ""))
		var gu: Dictionary = gu_by_id.get(definition_id, {})
		for card_id in gu.get("card_blueprint_ids", []):
			var card_definition: Dictionary = card_by_id.get(str(card_id), {})
			if card_definition.is_empty():
				continue
			var override_key := "%s:%s" % [definition_id, str(card_id)]
			var override: Dictionary = run.gu_card_overrides.get(override_key, {})
			if bool(override.get("disabled_for_run", false)):
				continue
			var copies := 1 + int(override.get("extra_copies", 0))
			for copy_index in range(maxi(0, copies)):
				cards.append(_card_instance(card_definition, instance, copy_index, override))
	return cards


static func build_battle_deck(run: RunState, catalog: Dictionary, expected_hash: String = "") -> Array[Dictionary]:
	if not expected_hash.is_empty() and expected_hash != deck_hash(run, catalog):
		return []
	return build_card_cache(run, catalog)


static func _card_instance(definition: Dictionary, source_instance: Dictionary, copy_index: int, override: Dictionary) -> Dictionary:
	var source_id := str(source_instance.get("instance_id", ""))
	var definition_id := str(definition.get("id", ""))
	return {
		"instance_id": "%s:%s:%d" % [source_id, definition_id, copy_index],
		"definition_id": definition_id,
		"source_gu_instance_ids": [source_id],
		"upgrade_level": int(override.get("upgrade_level", 0)),
	}


static func _refined_instances_with_legacy_fallback(run: RunState) -> Array[Dictionary]:
	var structured := run.refined_instances()
	if not structured.is_empty():
		return structured
	var fallback: Array[Dictionary] = []
	for index in run.refined_gu_ids.size():
		fallback.append({
			"instance_id": "legacy_%03d" % index,
			"definition_id": str(run.refined_gu_ids[index]),
			"state": "refined",
		})
	return fallback
