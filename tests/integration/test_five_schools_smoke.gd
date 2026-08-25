extends GutTest


# S2-S5 five-school cross-cut smoke: every school must survive the minimal
# closed loop — starter injection, battle action, victory loot, (refine:
# battle synthesis), death finalization, hall reset. All rolls are seeded.


const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
const LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")
const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")

const SCHOOLS := ["blood", "qi", "force", "soul", "refine"]


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_every_school_runs_the_minimal_closed_loop() -> void:
	for school_id in SCHOOLS:
		for run_seed in range(2026, 2036):
			var controller: RunController = autofree(RUN_CONTROLLER.new())
			controller.start_new_run(run_seed, school_id)
			# Leg 1: novice + five school starters are injected.
			_assert_school_starters(controller.state, school_id,
					"%s seed %d: starters injected" % [school_id, run_seed])
			# Leg 2: a battle starts and a basic action is accepted.
			var battle := BattleResolverScript.start(
				{"enemy_kind": "ridge_hound", "enemy_hp": 12}, controller.state, catalog)
			var turned := BattleResolverScript.take_turn(
				battle, {"type": "basic_attack"}, controller.state, catalog)
			assert_true(bool(turned.get("accepted", false)),
					"%s seed %d: basic action accepted" % [school_id, run_seed])
			# Leg 3: victory loot resolves on the school-pool filter.
			var looted := LootResolverScript.settle_victory(battle, controller.state, catalog)
			var loot_ids: Array = looted["loot"].get("material_ids", [])
			assert_true(not loot_ids.is_empty() or str(looted["loot"].get("gu_id", "")) != "",
					"%s seed %d: loot resolves" % [school_id, run_seed])
			# Leg 4: refine school can synthesize in battle with materials.
			if school_id == "refine":
				var refine_state: RunState = looted["state"]
				refine_state.materials["venom_sac"] = 1
				var synth := BattleResolverScript.take_turn(
					battle, {"type": "refine", "recipe_id": "battle_venom_coat"}, refine_state, catalog)
				assert_true(bool(synth.get("accepted", false)),
						"%s seed %d: battle synthesis accepted" % [school_id, run_seed])
			# Leg 5: death finalizes; a fresh run re-injects the same starters
			# (run-end cleanup plus per-run deck rebuild).
			controller.force_death_for_test("smoke_blow")
			assert_eq(str(controller.state.terminal_state), "dead",
					"%s seed %d: death finalizes" % [school_id, run_seed])
			controller.start_new_run(run_seed + 1, school_id)
			_assert_school_starters(controller.state, school_id,
					"%s seed %d: new run re-injects starters" % [school_id, run_seed])


func _assert_school_starters(state: RunState, school_id: String, label: String) -> void:
	var starters: Array = catalog["schools"][school_id]["starter_gu_ids"]
	assert_true(state.refined_gu_ids.has("small_light_gu"), "%s: novice present" % label)
	for starter in starters:
		assert_true(state.refined_gu_ids.has(str(starter)), "%s: starter %s present" % [label, starter])
	# A school whose starter set includes the novice gu injects one fewer entry.
	var expected_size := starters.size() + 1
	if starters.has("small_light_gu"):
		expected_size -= 1
	assert_eq(state.refined_gu_ids.size(), expected_size, "%s: unique inject count" % label)
	assert_eq(str(state.refined_gu_ids[0]), "small_light_gu", "%s: novice preserved first" % label)


func test_school_exclusive_pools_are_distinct_across_schools() -> void:
	var pools: Dictionary = catalog["school_pools"]
	var seen := {}
	for school_id in SCHOOLS:
		for gu_id_value in pools[school_id]:
			var gu_id := str(gu_id_value)
			assert_false(seen.has(gu_id), "pool entry %s must be unique" % gu_id)
			seen[gu_id] = true