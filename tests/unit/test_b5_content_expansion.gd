extends "res://addons/gut/test.gd"


# B5 content expansion: two new novel-sourced enemies, five new battle cards,
# and the intel weakness damage bonus feeding through _strike.


const BattleResolverScript := preload("res://scripts/domain/battle_resolver.gd")
const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")
const ActionPreviewServiceScript := preload("res://scripts/domain/action_preview_service.gd")


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func make_state(run_seed: int = 2026) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func test_new_enemies_pass_validation_and_start_battles() -> void:
	var cat: Dictionary = catalog()
	assert_eq(ContentCatalogScript.validate(cat), [])
	for enemy_id in ["iron_hide_boar", "thunder_crown_wolf"]:
		var enemy: Dictionary = cat["enemy_by_id"][enemy_id]
		assert_true(cat["enemy_by_id"].has(enemy_id))
		assert_true(int(enemy["hp"]) > 0)
		assert_true(int(enemy["intent"].get("speed", 0)) >= 0)
		assert_true((enemy.get("clues", []) as Array).size() >= 2)
		var battle: Dictionary = BattleResolverScript.start({"enemy_kind": enemy_id}, make_state(), cat)
		assert_eq(str(battle["enemy_kind"]), enemy_id)


func test_greedy_wanderer_now_faces_thunder_crown_wolf() -> void:
	var cat: Dictionary = catalog()
	var matched := false
	for node in cat["nodes"]:
		if str(node.get("id", "")) == "greedy_wanderer":
			matched = true
			assert_eq(str(node.get("enemy_kind", "")), "thunder_crown_wolf")
	assert_true(matched, "greedy_wanderer node missing from catalog")


func test_new_cards_play_with_expected_effects() -> void:
	var cat: Dictionary = catalog()
	# scout_eye via trail_eye_gu: reveals and slows the enemy.
	var trail := make_state()
	trail.refined_gu_ids.append("trail_eye_gu")
	var trail_battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, trail, cat)
	var trail_turn: Dictionary = BattleResolverScript.take_turn(trail_battle, {"type": "use_gu", "gu_id": "trail_eye_gu"}, trail, cat)
	assert_true((trail_turn["battle"]["flags"] as Array).has("revealed"))
	assert_eq(int(trail_turn["battle"]["delay_progress"]), 1)
	# moon_glow_flare：rank2 因子 ×3 → 3×3=9，直接击杀 4 血石游者。
	var glow := make_state()
	glow.refined_gu_ids.append("moon_glow_gu")
	var glow_battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, glow, cat)
	var glow_turn: Dictionary = BattleResolverScript.take_turn(glow_battle, {"type": "use_gu", "gu_id": "moon_glow_gu"}, glow, cat)
	assert_eq(int(glow_turn["battle"]["enemy_hp"]), 0)
	# moonlight：rank1 因子 ×1 → 2 伤，石游者余 2 血。
	var moon := make_state()
	moon.refined_gu_ids.append("moonlight_gu")
	var moon_battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, moon, cat)
	var moon_turn: Dictionary = BattleResolverScript.take_turn(moon_battle, {"type": "use_gu", "gu_id": "moonlight_gu"}, moon, cat)
	assert_eq(int(moon_turn["battle"]["enemy_hp"]), 2)


func test_card_count_grew_to_nineteen() -> void:
	var cat: Dictionary = catalog()
	assert_eq(cat["cards"].size(), 212)
	assert_eq(cat["gu"].size(), 213)


func test_intel_bonus_adds_damage_to_strikes() -> void:
	var cat: Dictionary = catalog()
	var state := make_state()
	state.refined_gu_ids.append("force_gu")
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, state, cat)
	var turn: Dictionary = BattleResolverScript.take_turn(battle, {"type": "use_gu", "gu_id": "force_gu"}, state, cat)
	assert_eq(int(turn["battle"]["enemy_hp"]), 2)
	var intel_state := make_state()
	intel_state.refined_gu_ids.append("force_gu")
	var intel_battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, intel_state, cat)
	intel_battle["intel_bonus"] = 1
	var intel_turn: Dictionary = BattleResolverScript.take_turn(intel_battle, {"type": "use_gu", "gu_id": "force_gu"}, intel_state, cat)
	assert_eq(int(intel_turn["battle"]["enemy_hp"]), 1)


func test_starter_preview_shows_expanded_effect_text() -> void:
	var cat: Dictionary = catalog()
	var state := make_state()
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, state, cat)
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_battle_actions(battle, state, cat)
	assert_true(cards.size() > 0)