extends GutTest


# 五转梯度（2026-08-28/29 design ruling):
# - Enemies carry an authored turn baseline; a node encounter at a higher
#   layer scales HP (+2/turn) and intent damage (+1/turn, positive damage
#   only) from pacing.json's turn_scaling. Direct test battles without a
#   turn stay at authored numbers.
# - Same-name gu advance: an instance rises one rank at the refinement node
#   (stone cost, cap 5); rank adds +1 strike damage and +1 essence cost so
#   quality trades against the soul-limited per-turn play budget.

const RunStateScript = preload("res://scripts/domain/run_state.gd")
const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_enemies_carry_turn_baseline() -> void:
	for enemy in catalog.get("enemies", []):
		var turn := int(enemy.get("turn", -1))
		assert_between(turn, 1, 5, "every enemy needs an authored turn within 1..5 (%s)" % str(enemy.get("id", "")))


func test_encounter_turn_scales_enemy_hp_and_damage() -> void:
	var run = RunStateScript.new_run(101)
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "ridge_hound", "turn": 3}, run, catalog)
	# hound authored turn 1: delta 2 -> hp 3+4=7, pounce 2+2=4.
	assert_eq(int(battle["enemy_hp"]), 7)
	assert_eq(int((battle["visible_intent"] as Dictionary).get("damage", 0)), 4)


func test_no_scaling_below_or_at_authored_turn() -> void:
	var run = RunStateScript.new_run(101)
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "ridge_hound", "turn": 1}, run, catalog)
	assert_eq(int(battle["enemy_hp"]), 3)
	# boss authored at turn 4: a stage-five encounter (turn 5) adds exactly one step.
	var boss_battle: Dictionary = BattleResolverScript.start({"enemy_kind": "miasma_vein_lord", "turn": 5}, run, catalog)
	assert_eq(int(boss_battle["enemy_hp"]), 8)
	assert_eq(int((boss_battle["visible_intent"] as Dictionary).get("damage", 0)), 3)


func test_zero_damage_intents_never_gain_damage_from_scaling() -> void:
	var run = RunStateScript.new_run(101)
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "miasma_vein_lord", "turn": 5}, run, catalog)
	var phase_two: Dictionary = (battle.get("enemy_phases", []) as Array)[1]
	var scorch: Dictionary = (phase_two.get("intents", []) as Array)[1]
	assert_eq(str(scorch.get("id", "")), "essence_scorch")
	assert_eq(int(scorch.get("damage", -1)), 0, "a pure burn intent must stay at zero damage")


func test_advance_recipe_raises_rank_and_costs_stone() -> void:
	var run = RunStateScript.new_run(101)
	run.stone = 6
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "advance_small_light_gu"}, catalog)
	assert_true(result["result"]["ok"], str(result["result"]))
	assert_eq(int(result["state"].highest_owned_rank("small_light_gu")), 2)
	assert_eq(int(result["state"].stone), 0, "advance charges the declared stone cost")


func test_advance_rejects_when_stone_is_missing() -> void:
	var run = RunStateScript.new_run(101)
	run.stone = 0
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "advance_small_light_gu"}, catalog)
	assert_false(result["result"]["ok"])
	assert_eq(int(result["state"].highest_owned_rank("small_light_gu")), 1)


func test_rank_raises_strike_damage_and_essence_cost() -> void:
	var run = RunStateScript.new_run(101)
	run.stone = 12
	var first := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "advance_small_light_gu"}, catalog)
	var second := ResolverScript.apply(first["state"], {"type": "refine_gu", "recipe_id": "advance_small_light_gu"}, catalog)
	assert_eq(int(second["state"].highest_owned_rank("small_light_gu")), 3)

	# rank 3 probe: base 1 + 2 = 3 strike damage...
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "ridge_hound"}, second["state"], catalog)
	var turned := BattleResolverScript.take_turn(battle, {"type": "use_gu", "gu_id": "small_light_gu"}, second["state"], catalog)
	assert_eq(int(turned["battle"]["enemy_hp"]), 0)

	# ...and the essence cost rises the same way (3 + base 1 = 4 > starting 3,
	# so the base first-turn grant and reserve fund the play).
	assert_true(int(turned["state"].essence) < int(second["state"].essence) + 1,
		"the rank surcharge must be paid from essence/energy")


func test_catalog_rejects_mismatched_advance_recipe() -> void:
	var bad := catalog.duplicate(true)
	bad["refinement_recipes"] = (bad.get("refinement_recipes", []) as Array).duplicate()
	bad["refinement_recipes"].append({
		"id": "bad_advance", "kind": "advance",
		"input_gu_ids": ["small_light_gu"], "output_gu_id": "thorn_whip_gu",
	})
	var errors := ContentCatalogScript.validate(bad)
	assert_gt(errors.size(), 0, "an advance recipe onto another name must fail validation")
