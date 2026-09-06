extends GutTest


const RelicHookResolverScript = preload("res://scripts/domain/relic_hook_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


# B1 bucket C (2026-09-06): the in-battle relic hooks below were deleted as
# domain debt - relic_hook_resolver fired only inside battle_resolver.gd
# (start/draw/play/end/damage call sites); the V1 engine and facade have no
# relic battle hooks, so the battle-start energy, draw-extra-card, play-gain-
# essence, damage-reduction and battle-end stone-grant legs all died with the
# legacy engine. Run-level relic facts that survive are pinned here:
# feeding_extra/estimate_feeding (hungry_vine_token), catalog validation of
# relic hook schemas, and run-level meta relic rules live in
# test_imprint_expansion.

func test_no_relics_makes_battle_and_feeding_noops() -> void:
	var run := RunState.new_run(101)
	assert_eq(RelicHookResolverScript.feeding_extra(run, catalog), 0)


func test_real_relics_pass_catalog_validation() -> void:
	assert_eq(ContentCatalog.validate(catalog), [])


func test_hungry_vine_token_adds_feeding_pressure_through_query() -> void:
	var run := RunState.new_run(101)
	run.relic_ids = ["hungry_vine_token"]
	assert_eq(RelicHookResolverScript.feeding_extra(run, catalog), 1)
	assert_eq(int(run.estimate_feeding_materials(catalog)["feed_points"]), 2)


func test_validate_rejects_unknown_trigger_and_effect_kind() -> void:
	var bad := catalog.duplicate(true)
	bad["relics"] = [{
		"id": "bad_relic",
		"hooks": [
			{"trigger": "on_unknown", "effect": {"kind": "grant_first_turn_energy", "amount": 1}},
			{"trigger": "on_battle_start", "effect": {"kind": "explode_universe", "amount": 1}},
		],
	}]
	bad["relic_by_id"] = {"bad_relic": bad["relics"][0]}
	var errors := ContentCatalog.validate(bad)
	var joined := "\n".join(errors)
	assert_true(joined.contains("unknown trigger on_unknown"), joined)
	assert_true(joined.contains("unknown effect kind explode_universe"), joined)


func test_validate_rejects_non_integer_effect_amount() -> void:
	var bad := catalog.duplicate(true)
	bad["relics"] = [{
		"id": "bad_relic",
		"hooks": [{"trigger": "on_battle_start", "effect": {"kind": "grant_first_turn_energy", "amount": "one"}}],
	}]
	bad["relic_by_id"] = {"bad_relic": bad["relics"][0]}
	var errors := ContentCatalog.validate(bad)
	assert_true("\n".join(errors).contains("non-negative integer"), "\n".join(errors))
