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
			"grade": "beast",
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
	var entries: Array = [{"id": "mythical_enemy", "tier": "mythic", "theme": "beast",
			"grade": "beast", "reactions": []}]

	assert_eq(EnemyCatalogScript.validate(entries), ["enemy mythical_enemy has invalid tier mythic"])


func test_real_catalog_passes_tier_validation() -> void:
	assert_eq(EnemyCatalogScript.validate(ContentCatalog.load_all()["enemies"]), [])


func test_validation_rejects_missing_or_unknown_theme() -> void:
	assert_eq(EnemyCatalogScript.validate([{"id": "no_theme_enemy", "tier": "common",
			"grade": "beast", "reactions": []}]),
			["enemy no_theme_enemy missing theme"])
	assert_eq(EnemyCatalogScript.validate([{"id": "odd_enemy", "tier": "common", "theme": "moon",
			"grade": "beast", "reactions": []}]),
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


# ---------------------------------------------------------------------------
# 战力阶梯（用户裁定 2026-09-10）：凡人 < 普通野兽 < 一转蛊修 < …… < 五转
# **蛊修最低一转**，故 rank 0 只可能是普通野兽 / 凡人 / 不入转的异变体。
# ---------------------------------------------------------------------------

func test_validation_rejects_a_cultivator_at_the_uninitiated_rank() -> void:
	var entries: Array = [{"id": "rank0_adept", "theme": "cultivator", "grade": "cultivator",
			"tier": "common", "rank": 0, "reactions": []}]
	var errors := EnemyCatalogScript.validate(entries)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].contains("蛊修最低一转"), str(errors))


func test_validation_rejects_missing_or_unknown_grade() -> void:
	assert_eq(EnemyCatalogScript.validate([{"id": "no_grade_enemy", "theme": "beast",
			"tier": "common", "reactions": []}]),
			["enemy no_grade_enemy missing grade"])
	assert_eq(EnemyCatalogScript.validate([{"id": "odd_grade_enemy", "theme": "beast",
			"tier": "common", "grade": "spirit", "reactions": []}]),
			["enemy odd_grade_enemy has unknown grade spirit"])


## 真实数据必须守住阶梯：蛊修一律 rank >= 1；rank 0 一律非蛊修。
func test_real_catalog_keeps_the_cultivator_floor_at_one_turn() -> void:
	var enemies: Array = ContentCatalog.load_all()["enemies"]
	var offenders: Array[String] = []
	var uninitiated: Array[String] = []
	for entry_value in enemies:
		var entry: Dictionary = entry_value
		var enemy_id := str(entry.get("id", ""))
		var grade := str(entry.get("grade", ""))
		var rank := int(entry.get("rank", 0))
		if grade == "cultivator" and rank < 1:
			offenders.append(enemy_id)
		if rank == 0:
			uninitiated.append(enemy_id)
			if grade == "cultivator":
				offenders.append(enemy_id)
	assert_eq(offenders, [] as Array[String], "蛊修不得落在未入转档")
	assert_true(EnemyCatalogScript.GRADES.has("mortal") and EnemyCatalogScript.GRADES.has("beast"),
			"未入转档必须同时有普通野兽与凡人的位置")
	# rank 0 = 未入转：普通野兽与凡人都在其下（用户裁定的次序）。
	var rank0_grades: Array[String] = []
	for enemy_id in uninitiated:
		for entry_value in enemies:
			var entry: Dictionary = entry_value
			if str(entry["id"]) == enemy_id:
				rank0_grades.append(str(entry["grade"]))
	assert_true(rank0_grades.has("beast") or rank0_grades.has("mortal"),
			"未入转档应有普通野兽或凡人，实际=%s" % str(rank0_grades))
