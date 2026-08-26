extends GutTest


const EnemyCatalogScript = preload("res://scripts/domain/enemy_catalog.gd")


func test_catalog_loads_the_two_readable_common_enemies() -> void:
	var catalog: Dictionary = EnemyCatalogScript.load_all()

	assert_true(catalog["enemy_by_id"].has("neutral_stone_wanderer"))
	assert_true(catalog["enemy_by_id"].has("ridge_hound"))
	assert_eq(catalog["enemy_by_id"]["neutral_stone_wanderer"]["tier"], "common")


func test_validation_rejects_a_reaction_without_a_counter_status() -> void:
	var entries: Array = [
		{
			"id": "broken_enemy",
			"reactions": [{"clue": "dust", "window": "before_damage", "trigger": "direct_strike"}],
		},
	]

	assert_eq(EnemyCatalogScript.validate(entries), ["enemy broken_enemy reaction 0 missing counter_status"])


func test_catalog_loads_elite_and_boss_enemies() -> void:
	var catalog: Dictionary = EnemyCatalogScript.load_all()

	assert_true(catalog["enemy_by_id"].has("ridge_elite_scout"))
	assert_true(catalog["enemy_by_id"].has("miasma_vein_lord"))
	assert_eq(catalog["enemy_by_id"]["ridge_elite_scout"]["tier"], "elite")
	assert_eq(catalog["enemy_by_id"]["miasma_vein_lord"]["tier"], "boss")


func test_validation_rejects_unknown_tier() -> void:
	var entries: Array = [{"id": "mythical_enemy", "tier": "mythic", "reactions": []}]

	assert_eq(EnemyCatalogScript.validate(entries), ["enemy mythical_enemy has invalid tier mythic"])


func test_real_catalog_passes_tier_validation() -> void:
	assert_eq(EnemyCatalogScript.validate(ContentCatalog.load_all()["enemies"]), [])
