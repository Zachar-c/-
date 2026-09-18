extends GutTest


# Spec-v4 phase-2 (T2.2): content tier schema (spec §17.1 last paragraph).
# Content tables declare tiers (rank / tier / value_tier) instead of copying
# central final values out of GuBalance; entries that really need a literal
# override must state override_reason. ContentCatalog.validate rejects
# non-override entries that replicate a central beast-scale hp literal (e.g. a
# rank-5 beast writing hp 3200 by hand).


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_enemy_without_override_replicating_beast_hp_is_rejected() -> void:
	# A rank-5 beast whose hp is the central beast_scale(5) value 3200 copies a
	# central final value: §14.3 says the table is generated from balance.json,
	# never re-written per enemy.
	var tuned := catalog.duplicate(true)
	var enemies: Array = (catalog["enemies"] as Array).duplicate(true)
	enemies.append(_fake_enemy(5, 3200, {}))
	tuned["enemies"] = enemies
	var errors := ContentCatalogScript.validate(tuned)
	assert_true(_contains(errors, "replicates central beast-scale hp"), str(errors))


func test_enemy_with_override_reason_may_replicate_beast_hp() -> void:
	# §14.3 species corrections are the sanctioned exception and need the reason.
	var tuned := catalog.duplicate(true)
	var enemies: Array = (catalog["enemies"] as Array).duplicate(true)
	enemies.append(_fake_enemy(5, 3200, {"override_reason": "species correction"}))
	tuned["enemies"] = enemies
	var errors := ContentCatalogScript.validate(tuned)
	assert_false(_contains(errors, "replicates central beast-scale hp"), str(errors))


func test_enemy_missing_rank_is_rejected() -> void:
	# §17.1: enemies declare their beast-model rank instead of copying values.
	var tuned := catalog.duplicate(true)
	var enemies: Array = (catalog["enemies"] as Array).duplicate(true)
	enemies.append(_fake_enemy(3, 21, {}))
	(enemies.back() as Dictionary).erase("rank")
	tuned["enemies"] = enemies
	var errors := ContentCatalogScript.validate(tuned)
	assert_true(_contains(errors, "rank must be an integer in 0..5"), str(errors))


func test_real_content_tables_declare_tiers_cleanly() -> void:
	# Green condition: after the tier annotations land, every table passes.
	var errors := ContentCatalogScript.validate(catalog)
	assert_eq(errors, [] as Array[String], str(errors))


func _fake_enemy(beast_rank: int, hp: int, extra: Dictionary) -> Dictionary:
	var entry := {
		"id": "fake_tier_check_beast",
		"theme": "beast",
		"grade": "beast",
		"tier": "boss",
		"rank": beast_rank,
		"hp": hp,
		"clues": ["fake_clue"],
		"intent": {"id": "fake_strike", "label": "假意蓄势", "damage": 1, "speed": 1},
		"reactions": [],
	}
	for key in extra:
		entry[key] = extra[key]
	return entry


func _contains(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false