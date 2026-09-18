extends "res://addons/gut/test.gd"


# B2 loot loop: victory drops (materials/gu), boss scavenge unlocks the
# recipe into the global codex, materials can be sold and fed into refining.
# All rolls are seeded and reproducible from the run seed.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const LootResolverScript := preload("res://scripts/domain/loot_resolver.gd")
const ResolverScript := preload("res://scripts/domain/resolver.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")


func make_state(run_seed: int = 2026) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


## 材料数由 pacing 大层裁定表说了算（2026-09-08 各层 +1）；测试只跟随，不写死。
static func _pacing_material_count(layer: int) -> int:
	var path := "res://data/pacing.json"
	if not FileAccess.file_exists(path):
		return 1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return 1
	var layer_cfg: Dictionary = (parsed as Dictionary).get("layers", {}).get(str(layer), {})
	return maxi(0, int((layer_cfg.get("loot", {}) as Dictionary).get("material_count", 1)))


func test_real_loot_tables_pass_catalog_validation() -> void:
	var errors: Array[String] = ContentCatalogScript.validate(catalog())
	assert_eq(errors, [])


func test_common_victory_grants_the_layer_material_count() -> void:
	var battle := {"enemy_kind": "ridge_hound"}
	var one: Dictionary = LootResolverScript.settle_victory(battle, make_state(), catalog())
	var two: Dictionary = LootResolverScript.settle_victory(battle, make_state(), catalog())
	assert_eq(one["loot"].get("material_ids", []).size(), _pacing_material_count(1))
	assert_eq(str(one["loot"].get("gu_id", "")), "")
	assert_eq_deep(one["loot"], two["loot"])


func test_same_seed_same_position_yields_identical_loot() -> void:
	var battle := {"enemy_kind": "ridge_elite_scout"}
	var one: Dictionary = LootResolverScript.settle_victory(battle, make_state(424242), catalog())
	var two: Dictionary = LootResolverScript.settle_victory(battle, make_state(424242), catalog())
	assert_eq_deep(one["loot"], two["loot"])


func test_multi_enemy_common_only_resolves_common() -> void:
	# Multi-enemy battles carry only battle["enemy_kinds"] (facade leaves
	# battle["enemy_kind"] empty); all-common kinds must settle the common tier.
	var multi := {"enemy_kind": "", "enemy_kinds": ["ridge_hound", "neutral_stone_wanderer"]}
	var single := {"enemy_kind": "ridge_hound"}
	var multi_rolled: Dictionary = LootResolverScript.settle_victory(multi, make_state(), catalog())
	var single_rolled: Dictionary = LootResolverScript.settle_victory(single, make_state(), catalog())
	assert_eq_deep(multi_rolled["loot"], single_rolled["loot"])
	assert_false(multi_rolled.has("cost"), "common settlement binds no elite cost")


func test_multi_enemy_common_plus_elite_resolves_elite() -> void:
	# Any elite in enemy_kinds upgrades the settlement to the elite tier.
	var multi := {"enemy_kind": "", "enemy_kinds": ["ridge_hound", "ridge_elite_scout"]}
	var single := {"enemy_kind": "ridge_elite_scout"}
	var multi_rolled: Dictionary = LootResolverScript.settle_victory(multi, make_state(), catalog())
	var single_rolled: Dictionary = LootResolverScript.settle_victory(single, make_state(), catalog())
	assert_eq_deep(multi_rolled["loot"], single_rolled["loot"])
	assert_true(multi_rolled.has("cost"), "elite settlement must bind the seeded cost")


func test_multi_enemy_boss_takes_precedence() -> void:
	# Any boss in enemy_kinds wins over elite and common, regardless of order.
	var single := {"enemy_kind": "miasma_vein_lord"}
	var single_rolled: Dictionary = LootResolverScript.settle_victory(single, make_state(), catalog())
	for kinds in [
		["ridge_hound", "ridge_elite_scout", "miasma_vein_lord"],
		["miasma_vein_lord", "ridge_hound"],
		["ridge_elite_scout", "miasma_vein_lord"],
	]:
		var multi := {"enemy_kind": "", "enemy_kinds": kinds}
		var multi_rolled: Dictionary = LootResolverScript.settle_victory(multi, make_state(), catalog())
		assert_true(multi_rolled["loot"] == single_rolled["loot"],
				"kinds %s must settle the boss tier" % str(kinds))
		assert_false(multi_rolled.has("cost"), "boss settlement binds no elite cost")


func test_multi_enemy_loot_is_deterministic() -> void:
	var multi := {"enemy_kind": "", "enemy_kinds": ["ridge_hound", "ridge_elite_scout"]}
	var one: Dictionary = LootResolverScript.settle_victory(multi, make_state(424242), catalog())
	var two: Dictionary = LootResolverScript.settle_victory(multi, make_state(424242), catalog())
	assert_eq_deep(one["loot"], two["loot"])


func test_elite_loot_grants_material_and_may_be_gu() -> void:
	var battle := {"enemy_kind": "ridge_elite_scout"}
	var table: Dictionary = catalog().get("loot_tables", {}).get("loot", {}).get("elite", {})
	var rolled: Dictionary = LootResolverScript.settle_victory(battle, make_state(), catalog())
	var loot: Dictionary = rolled["loot"]
	assert_eq(loot.get("material_ids", []).size(), _pacing_material_count(1))
	var gu_id := str(loot.get("gu_id", ""))
	if not gu_id.is_empty():
		var pool: Dictionary = table.get("gu_pool", {})
		var found := false
		for rarity_id in pool.get("by_rarity", {}):
			if (pool["by_rarity"][rarity_id] as Array).has(gu_id):
				found = true
		assert_true(found, "rolled gu %s belongs to a declared bucket" % gu_id)


func test_same_school_reward_roll_leans_on_exclusive_pool() -> void:
	# Bucket mixes a force gu (force_gu, in the force pool) with a blood gu
	# (blood_droplet_gu, in the blood pool): each school must only draw its own.
	var cat := catalog()
	var tables: Dictionary = cat["loot_tables"]
	var elite: Dictionary = tables["loot"]["elite"]
	elite.erase("forced_rarity")
	elite["gu_chance_pct"] = 100
	elite["gu_pool"]["weights"] = {"common": 1}
	elite["gu_pool"]["by_rarity"] = {"common": ["force_gu", "blood_droplet_gu"]}
	var battle := {"enemy_kind": "ridge_elite_scout"}
	for seed_value in range(1, 13):
		var force_state := make_state(seed_value)
		force_state.school = "force"
		var force_roll: Dictionary = LootResolverScript.settle_victory(battle, force_state, cat)
		assert_eq(str(force_roll["loot"].get("gu_id", "")), "force_gu",
				"force school seed %d must draw its exclusive pool entry" % seed_value)
		var blood_state := make_state(seed_value)
		blood_state.school = "blood"
		var blood_roll: Dictionary = LootResolverScript.settle_victory(battle, blood_state, cat)
		assert_eq(str(blood_roll["loot"].get("gu_id", "")), "blood_droplet_gu",
				"blood school seed %d must draw its exclusive pool entry" % seed_value)


func test_school_roll_uses_school_pool_when_bucket_has_no_entry() -> void:
	# bucket 里没有本流派蛊 ⇒ 退到 school_pools 中同稀有度的本流派蛊。
	# 旧行为是退回 bucket 全池（气道局会掉力道/血道蛊），已按「本流派局掉
	# 本流派蛊」修订。
	var cat := catalog()
	var elite: Dictionary = cat["loot_tables"]["loot"]["elite"]
	elite.erase("forced_rarity")
	elite["gu_chance_pct"] = 100
	elite["gu_pool"]["weights"] = {"common": 1}
	elite["gu_pool"]["by_rarity"] = {"common": ["force_gu", "blood_droplet_gu"]}
	var gu_by_id: Dictionary = cat["gu_by_id"]
	var qi_common: Array = []
	for gu_id_value in cat["school_pools"]["qi"]:
		if str(gu_by_id.get(str(gu_id_value), {}).get("rarity", "common")) == "common":
			qi_common.append(str(gu_id_value))
	assert_false(qi_common.is_empty(), "气道池有 common 蛊可兜底")
	var battle := {"enemy_kind": "ridge_elite_scout"}
	var state := make_state(7)
	state.school = "qi"
	var rolled: Dictionary = LootResolverScript.settle_victory(battle, state, cat)
	assert_true(qi_common.has(str(rolled["loot"].get("gu_id", ""))),
			"bucket 无本流派蛊时退到 school_pools 同稀有度；实际=%s"
			% str(rolled["loot"].get("gu_id", "")))


func test_school_roll_keeps_bucket_when_no_school_pool() -> void:
	# 流派未登记 school_pools ⇒ 无兜底可用，才退回原 bucket（保持旧行为）。
	var cat := catalog()
	var elite: Dictionary = cat["loot_tables"]["loot"]["elite"]
	elite.erase("forced_rarity")
	elite["gu_chance_pct"] = 100
	elite["gu_pool"]["weights"] = {"common": 1}
	elite["gu_pool"]["by_rarity"] = {"common": ["force_gu", "blood_droplet_gu"]}
	var battle := {"enemy_kind": "ridge_elite_scout"}
	var state := make_state(7)
	state.school = "unknown_school"
	var rolled: Dictionary = LootResolverScript.settle_victory(battle, state, cat)
	assert_true(["force_gu", "blood_droplet_gu"].has(str(rolled["loot"].get("gu_id", ""))),
			"no school pool keeps the unfiltered bucket")


func test_sword_run_drops_sword_gu() -> void:
	# 剑道 40 只全部不在 loot_tables 内：旧逻辑会退回落表全池，剑道局永远
	# 掉光道/气道蛊，成长链断裂（真机验收反馈）。新逻辑走 school_pools 兜底。
	var cat := catalog()
	var elite: Dictionary = cat["loot_tables"]["loot"]["elite"]
	elite.erase("forced_rarity")
	elite["gu_chance_pct"] = 100
	elite["gu_pool"]["weights"] = {"common": 1}
	elite["gu_pool"]["by_rarity"] = {"common": ["small_light_gu", "qi_atk_1_01_gu"]}
	var battle := {"enemy_kind": "ridge_elite_scout"}
	for seed_value in [7, 21, 99]:
		var state := make_state(seed_value)
		state.school = "sword"
		var rolled: Dictionary = LootResolverScript.settle_victory(battle, state, cat)
		var gu_id := str(rolled["loot"].get("gu_id", ""))
		assert_true(gu_id.begins_with("sword_"),
				"剑道局 seed %d 必须掉剑道蛊；实际=%s" % [seed_value, gu_id])


func test_boss_loot_follows_the_layer_ruling() -> void:
	# 统一裁定表：Boss 掉落材料数按大层走 pacing（L1=2，L5=4），依旧不出蛊。
	var battle_l1 := {"enemy_kind": "miasma_vein_lord", "layer": 1}
	var rolled_l1: Dictionary = LootResolverScript.settle_victory(battle_l1, make_state(), catalog())
	assert_eq(rolled_l1["loot"].get("material_ids", []).size(), _pacing_material_count(1))
	assert_eq(str(rolled_l1["loot"].get("gu_id", "")), "")

	var battle_l5 := {"enemy_kind": "miasma_vein_lord", "layer": 5}
	var rolled_l5: Dictionary = LootResolverScript.settle_victory(battle_l5, make_state(), catalog())
	assert_eq(rolled_l5["loot"].get("material_ids", []).size(), _pacing_material_count(5))
	assert_eq(str(rolled_l5["loot"].get("gu_id", "")), "")


func test_loot_materials_are_added_to_state_and_logged() -> void:
	var battle := {"enemy_kind": "ridge_hound"}
	var before: RunState = make_state()
	var rolled: Dictionary = LootResolverScript.settle_victory(battle, before, catalog())
	var after: RunState = rolled["state"]
	var gained: Array = rolled["loot"].get("material_ids", [])
	assert_true(int(after.materials.get(str(gained[0]), 0)) > 0)
	# Q8-G 1-C：胜利结算现在固定追加一条产石事件（loot_stone_gained），
	# 加上材料事件共 +2。
	assert_eq(after.event_log.size(), before.event_log.size() + 2)


func test_scavenge_requires_boss_defeated() -> void:
	var resolved: Dictionary = ResolverScript.apply(
		make_state(),
		{"type": "scavenge", "node_id": "final_boss_stand"},
		catalog()
	)
	assert_false(bool(resolved["result"].get("ok", false)))
	assert_eq(str(resolved["result"].get("reason", "")), "boss_undefeated")


func test_scavenge_unlocks_recipe_in_global_codex() -> void:
	var state := make_state()
	state.node_flags["boss_defeated"] = "true"
	var resolved: Dictionary = ResolverScript.apply(
		state,
		{"type": "scavenge", "node_id": "final_boss_stand"},
		catalog()
	)
	assert_true(bool(resolved["result"].get("ok", false)))
	assert_true(resolved["state"].global_codex_ids.has("moon_shadow_locked"))
	assert_true(resolved["state"].global_codex_ids.has("blood_moon_forged"))
	assert_eq(str(resolved["state"].event_log.back().get("reason", "")), "scavenge_recipe_unlocked")


func test_scavenge_is_once_only() -> void:
	var state := make_state()
	state.node_flags["boss_defeated"] = "true"
	var first: Dictionary = ResolverScript.apply(state, {"type": "scavenge", "node_id": "final_boss_stand"}, catalog())
	var second: Dictionary = ResolverScript.apply(first["state"], {"type": "scavenge", "node_id": "final_boss_stand"}, catalog())
	assert_true(bool(first["result"].get("ok", false)))
	assert_false(bool(second["result"].get("ok", false)))
	assert_eq(str(second["result"].get("reason", "")), "scavenge_already_done")


func test_sell_material_pays_stone_and_consumes() -> void:
	var state := make_state()
	state.materials["beast_blood"] = 2
	var resolved: Dictionary = ResolverScript.apply(
		state,
		{"type": "sell_material", "material_id": "beast_blood"},
		catalog()
	)
	assert_true(bool(resolved["result"].get("ok", false)))
	assert_eq(resolved["state"].stone, state.stone + 4)
	assert_eq(int(resolved["state"].materials.get("beast_blood", 0)), 0)


func test_sell_material_respects_notoriety_discount() -> void:
	var state := make_state()
	state.materials["beast_blood"] = 2
	state.cultivator["notorious"] = 5
	var resolved: Dictionary = ResolverScript.apply(
		state,
		{"type": "sell_material", "material_id": "beast_blood"},
		catalog()
	)
	# base 2, uplift capped at 50% -> floor(2 * 0.5) = 1 per unit.
	assert_eq(resolved["state"].stone, state.stone + 2)


func test_sell_material_rejects_empty() -> void:
	var resolved: Dictionary = ResolverScript.apply(
		make_state(),
		{"type": "sell_material", "material_id": "beast_blood"},
		catalog()
	)
	assert_false(bool(resolved["result"].get("ok", false)))


func test_refinement_consumes_materials_and_respects_capacity() -> void:
	var cat: Dictionary = catalog()
	var recipe: Dictionary = cat["refinement_by_id"]["moon_glow_fixed"]
	recipe["materials"] = {"beast_blood": 1}
	# Soul 4 -> craft cap 3; three gu inputs plus one material piece = 4 > 3.
	var state := make_state()
	state.materials["beast_blood"] = 1
	_state_gu_instances(state)
	var blocked: Dictionary = ResolverScript.apply(state, {
		"type": "refine_gu",
		"recipe_id": "moon_glow_fixed",
		"input_instance_ids": ["gu_001", "gu_002", "gu_003"],
	}, cat)
	assert_eq(str(blocked["result"].get("reason", "")), "refinement_capacity_exceeded")
	# Soul 5 -> craft cap 4; now the same refine passes and spends the material.
	state.cultivator["soul"] = 5
	state.materials["beast_blood"] = 1
	var passed: Dictionary = ResolverScript.apply(state, {
		"type": "refine_gu",
		"recipe_id": "moon_glow_fixed",
		"input_instance_ids": ["gu_001", "gu_002", "gu_003"],
	}, cat)
	assert_true(bool(passed["result"].get("ok", false)))
	assert_eq(int(passed["state"].materials.get("beast_blood", 0)), 0)


func test_refinement_missing_material_is_rejected() -> void:
	var cat: Dictionary = catalog()
	var recipe: Dictionary = cat["refinement_by_id"]["moon_glow_fixed"]
	recipe["materials"] = {"beast_blood": 1}
	var state := make_state()
	state.cultivator["soul"] = 5
	_state_gu_instances(state)
	var resolved: Dictionary = ResolverScript.apply(state, {
		"type": "refine_gu",
		"recipe_id": "moon_glow_fixed",
		"input_instance_ids": ["gu_001", "gu_002", "gu_003"],
	}, cat)
	assert_false(bool(resolved["result"].get("ok", false)))
	assert_eq(str(resolved["result"].get("reason", "")), "missing_refinement_material")


func _state_gu_instances(state: RunState) -> void:
	# new_run seeds one small_light_gu instance (gu_001). Add one more
	# small_light and one moonlight so moon_glow_fixed inputs are satisfied.
	var second := _add_instance(state, "small_light_gu")
	var third := _add_instance(state, "moonlight_gu")
	assert_ne(second, third)


func _add_instance(state: RunState, definition_id: String) -> String:
	var instance_id := "gu_%03d" % (state.gu_instances.size() + 1)
	state.gu_instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"state": "refined",
	}
	state.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	state.sync_legacy_gu_projections()
	return instance_id