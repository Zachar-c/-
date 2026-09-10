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
			"theme": "beast",   # 主题合法，使断言只聚焦 reaction 字段
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
	var entries: Array = [{"id": "mythical_enemy", "tier": "mythic", "theme": "beast", "reactions": []}]

	assert_eq(EnemyCatalogScript.validate(entries), ["enemy mythical_enemy has invalid tier mythic"])


func test_real_catalog_passes_tier_validation() -> void:
	assert_eq(EnemyCatalogScript.validate(ContentCatalog.load_all()["enemies"]), [])


func test_validation_rejects_missing_or_unknown_theme() -> void:
	assert_eq(EnemyCatalogScript.validate([{"id": "no_theme_enemy", "tier": "common", "reactions": []}]),
			["enemy no_theme_enemy missing theme"])
	assert_eq(EnemyCatalogScript.validate([{"id": "odd_enemy", "tier": "common", "theme": "moon", "reactions": []}]),
			["enemy odd_enemy has unknown theme moon"])


func test_theme_index_groups_every_enemy_and_pool_never_returns_empty() -> void:
	var catalog: Dictionary = EnemyCatalogScript.load_all()
	var ids_by_theme: Dictionary = catalog["enemy_ids_by_theme"]
	var total := 0
	for theme in EnemyCatalogScript.THEMES:
		total += (ids_by_theme[theme] as Array).size()
	assert_eq(total, (catalog["enemies"] as Array).size(), "每个敌人都必须落进某个主题")

	# 池取：已知主题返回该主题成员；未知主题/空池回退到 fallback
	var beast_pool := EnemyCatalogScript.enemy_pool(catalog, "beast", ["ridge_hound"])
	assert_true(beast_pool.has("ridge_hound"))
	var fallback_pool := EnemyCatalogScript.enemy_pool(catalog, "no_such_theme", ["ridge_hound"])
	assert_eq(fallback_pool, ["ridge_hound"], "未知主题必须回退，不得返回空池")
