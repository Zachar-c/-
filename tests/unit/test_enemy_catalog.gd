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
