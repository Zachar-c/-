extends "res://addons/gut/test.gd"


# Task S1: soul school overchannel mechanics (R4.7) — benefits scale with
# declared level, mercy clamps the first sub-zero drain to 1, a second is
# rejected outright, non-soul schools ignore the payload, and backlash-to-draw
# conversion runs at double rate for the soul school.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const BattleResolverScript := preload("res://scripts/domain/battle_resolver.gd")
const SchoolRulesScript := preload("res://scripts/domain/school_rules.gd")
const RelicHookResolverScript := preload("res://scripts/domain/relic_hook_resolver.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")

# gen_soul_attack_* 占位蛊于 802 重建删去；以血滴蛊（legacy resolver 硬编码
# 打击 2 的基础锚）承载 overchannel 输入，施放方仍为 soul 校玩家。
const SOUL_ATTACK_GU := "blood_droplet_gu"


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func soul_state(soul: int) -> RunState:
	var state := RunStateScript.new_run(2026)
	state.school = "soul"
	state.cultivator["soul"] = soul
	state.cultivator["soul_max"] = 4
	state.gu_instances["gu_100"] = {
		"instance_id": "gu_100",
		"definition_id": SOUL_ATTACK_GU,
		"state": "refined",
	}
	state.cave_aperture["stored_gu_instance_ids"].append("gu_100")
	state.sync_legacy_gu_projections()
	return state


func test_school_starters_exist_and_match_school() -> void:
	var cat := catalog()
	var schools: Dictionary = cat["schools"]
	assert_true(schools.has("soul"), "soul school present")
	for gu_id in schools["soul"]["starter_gu_ids"]:
		var gu: Dictionary = cat["gu_by_id"][str(gu_id)]
		assert_eq(str(gu["school"]), "soul", "starter %s" % str(gu_id))


func test_overchannel_level_one_pays_soul_and_benefits() -> void:
	var state := soul_state(4)
	var battle := BattleResolverScript.start({"enemy_kind": "ridge_hound", "enemy_hp": 30}, state, catalog())
	var enemy_hp_before := int(battle["enemy_hp"])
	var turn := BattleResolverScript.take_turn(battle,
			{"type": "use_gu", "gu_id": SOUL_ATTACK_GU, "overchannel": 1}, state, catalog())
	assert_eq(str(turn["result"]), "ongoing")
	# base strike 2 + level-1 benefit 2
	assert_eq(enemy_hp_before - int(turn["battle"]["enemy_hp"]), 4)
	var cultivator: Dictionary = turn["state"].cultivator
	assert_eq(int(cultivator["soul"]), 3)


func test_mercy_clamps_first_subzero_and_second_is_rejected() -> void:
	var state := soul_state(1)
	var battle := BattleResolverScript.start({"enemy_kind": "ridge_hound", "enemy_hp": 30}, state, catalog())
	var first := BattleResolverScript.take_turn(battle,
			{"type": "use_gu", "gu_id": SOUL_ATTACK_GU, "overchannel": 3}, state, catalog())
	assert_eq(str(first["result"]), "ongoing")
	assert_true(bool((first["battle"]["flags"] as Array).has("soul_mercy_used")))
	assert_eq(int(first["state"].cultivator["soul"]), 1)
	var events_after_first: int = first["state"].event_log.size()
	var second := BattleResolverScript.take_turn(first["battle"],
			{"type": "use_gu", "gu_id": SOUL_ATTACK_GU, "overchannel": 3}, first["state"], catalog())
	assert_false(bool(second.get("accepted", true)), "second lethal overchannel rejected")
	assert_true((second["feeds"] as Array).has("soul_exhausted"))
	assert_eq(int(second["state"].event_log.size()), events_after_first)


func test_non_soul_school_ignores_overchannel_payload() -> void:
	var state := soul_state(1)
	state.school = "blood"
	state.relic_ids = []
	var battle := BattleResolverScript.start({"enemy_kind": "ridge_hound", "enemy_hp": 30}, state, catalog())
	var turn := BattleResolverScript.take_turn(battle,
			{"type": "use_gu", "gu_id": SOUL_ATTACK_GU, "overchannel": 3}, state, catalog())
	assert_eq(str(turn["result"]), "ongoing")
	assert_eq(int(turn["state"].cultivator["soul"]), 1)
	assert_false(bool((turn["battle"]["flags"] as Array).has("soul_mercy_used")))


func test_backlash_conversion_double_for_soul_school() -> void:
	var relic := {
		"id": "test_converter",
		"hooks": [{"trigger": "on_backlash_gained",
				"effect": {"kind": "convert_backlash_to_draw", "amount": 1}}],
	}
	for school in ["soul", "blood"]:
		var state := RunStateScript.new_run(99)
		state.school = school
		state.relic_ids = ["test_converter"]
		var cat := catalog()
		cat["relic_by_id"]["test_converter"] = relic
		var battle := {"pending_extra_draws": 0}
		var applied: Dictionary = RelicHookResolverScript.apply_backlash_gained(
				battle, state, cat, 1)
		var expected := 2 if school == "soul" else 1
		assert_eq(int(applied["battle"]["pending_extra_draws"]), expected,
				"school %s queued draws" % school)
