extends "res://addons/gut/test.gd"


# T1 rarity data model: gu/cards/relics declare a four-tier rarity; loot
# tables roll tiered weighted pools (lockdown spec R4.5/R13.1/16.4:
# legendary exists as a slot but carries zero weight in early layers).
# All rolls stay seeded and reproducible from the run seed.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const LootResolverScript := preload("res://scripts/domain/loot_resolver.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")

const RARITIES := ["common", "rare", "epic", "legendary"]


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func test_every_gu_declares_valid_rarity() -> void:
	for gu in catalog()["gu"]:
		assert_true(RARITIES.has(str(gu.get("rarity", ""))), "gu %s needs valid rarity" % gu["id"])


func test_every_card_declares_valid_rarity() -> void:
	for card in catalog()["cards"]:
		assert_true(RARITIES.has(str(card.get("rarity", ""))), "card %s needs valid rarity" % card["id"])


func test_every_relic_declares_valid_rarity() -> void:
	for relic in catalog()["relics"]:
		assert_true(RARITIES.has(str(relic.get("rarity", ""))), "relic %s needs valid rarity" % relic["id"])


func test_validate_rejects_missing_rarity() -> void:
	var fake := catalog()
	fake["gu"][0].erase("rarity")
	var errors: Array[String] = ContentCatalogScript.validate(fake)
	assert_true(errors.any(func(e: String) -> bool: return e.contains("missing rarity")))


func test_validate_rejects_unknown_rarity() -> void:
	var fake := catalog()
	fake["gu"][0]["rarity"] = "superb"
	var errors: Array[String] = ContentCatalogScript.validate(fake)
	assert_true(errors.any(func(e: String) -> bool: return e.contains("invalid rarity")))


func test_validate_rejects_loot_bucket_rarity_mismatch() -> void:
	var fake := catalog()
	var elite: Dictionary = fake["loot_tables"]["loot"]["elite"]
	elite["gu_pool"]["by_rarity"]["common"].append("moonlight_gu")
	var errors: Array[String] = ContentCatalogScript.validate(fake)
	assert_true(errors.any(func(e: String) -> bool: return e.contains("rarity mismatch")))


func test_validate_rejects_positive_weight_on_empty_bucket() -> void:
	var fake := catalog()
	var elite: Dictionary = fake["loot_tables"]["loot"]["elite"]
	elite["gu_pool"]["by_rarity"]["legendary"] = []
	elite["gu_pool"]["weights"]["legendary"] = 5
	var errors: Array[String] = ContentCatalogScript.validate(fake)
	assert_true(errors.any(func(e: String) -> bool: return e.contains("empty bucket")))


func test_elite_pool_buckets_match_declared_rarity() -> void:
	var cat := catalog()
	var gu_by_id: Dictionary = cat["gu_by_id"]
	var pool: Dictionary = cat["loot_tables"]["loot"]["elite"]["gu_pool"]
	for rarity in pool["by_rarity"]:
		assert_true(RARITIES.has(str(rarity)), "bucket %s is a known rarity" % rarity)
		for gu_id in pool["by_rarity"][rarity]:
			assert_eq(str(gu_by_id[str(gu_id)]["rarity"]), str(rarity))


func test_elite_weights_lock_legendary_at_zero() -> void:
	var weights: Dictionary = catalog()["loot_tables"]["loot"]["elite"]["gu_pool"]["weights"]
	assert_false(weights.has("legendary") and int(weights["legendary"]) > 0,
			"early-layer legendary weight must be zero or absent")


func test_tiered_roll_stays_within_positive_weight_buckets() -> void:
	var cat := catalog()
	var pool: Dictionary = cat["loot_tables"]["loot"]["elite"]["gu_pool"]
	var allowed := {}
	for rarity in pool["weights"]:
		if int(pool["weights"][rarity]) > 0:
			for gu_id in pool["by_rarity"].get(rarity, []):
				allowed[str(gu_id)] = true
	assert_false(allowed.is_empty())
	for seed_value in [1, 2, 3, 2026, 424242, 999983]:
		var rolled: Dictionary = LootResolverScript.settle_victory(
			{"enemy_kind": "ridge_elite_scout"},
			RunStateScript.new_run(seed_value, null),
			cat
		)["loot"]
		var gu_id := str(rolled.get("gu_id", ""))
		if not gu_id.is_empty():
			assert_true(allowed.has(gu_id),
					"seed %d produced off-pool gu %s" % [seed_value, gu_id])


func test_same_seed_yields_identical_tiered_roll() -> void:
	var one: Dictionary = LootResolverScript.settle_victory(
		{"enemy_kind": "ridge_elite_scout"}, RunStateScript.new_run(777, null), catalog())["loot"]
	var two: Dictionary = LootResolverScript.settle_victory(
		{"enemy_kind": "ridge_elite_scout"}, RunStateScript.new_run(777, null), catalog())["loot"]
	assert_eq_deep(one, two)
