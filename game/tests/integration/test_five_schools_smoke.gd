extends GutTest


# S2-S5 five-school cross-cut smoke: every school must survive the minimal
# closed loop — starter injection, battle action, victory loot, death
# finalization, hall reset. All rolls are seeded. In-battle refine synthesis
# was legacy-engine-only and died with the V1 convergence (B1 bucket C).
#
# 2026-09-12：加入剑道（sword）。此前只覆盖 5 流派，剑道从未跑过端到端闭环。


const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")
const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")

const SCHOOLS := ["blood", "qi", "force", "soul", "refine", "sword"]


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
			var battle: Dictionary = FacadeScript.start(
				{"enemy_kind": "ridge_hound"}, controller.state, catalog)
			var turned: Dictionary = FacadeScript.apply_turn(
				battle, controller.state, {"type": "basic_attack"}, catalog)
			assert_true(bool(turned.get("accepted", false)),
					"%s seed %d: basic action accepted" % [school_id, run_seed])
			controller.state = turned["state"]
			# Leg 3: victory loot resolves. When the basic action already
			# flipped the fight to victory, the facade auto-settled loot onto
			# the battle (same LootResolver 口径); otherwise settle explicitly.
			if str(turned.get("result", "")) == "victory":
				var loot: Dictionary = (turned.get("battle", {}) as Dictionary).get("loot", {})
				var auto_ids: Array = loot.get("material_ids", [])
				assert_true(not auto_ids.is_empty() or str(loot.get("gu_id", "")) != "",
						"%s seed %d: loot resolves" % [school_id, run_seed])
			else:
				var looted := LootResolverScript.settle_victory(turned.get("battle", battle), controller.state, catalog)
				var loot_ids: Array = looted["loot"].get("material_ids", [])
				assert_true(not loot_ids.is_empty() or str(looted["loot"].get("gu_id", "")) != "",
						"%s seed %d: loot resolves" % [school_id, run_seed])
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