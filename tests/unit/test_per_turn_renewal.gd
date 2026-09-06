extends GutTest


# 行动点（念头）+ 真元回复台账（2026-08-31 数值重做后）：
# - 每回合行动次数 = actions_per_turn(魂魄底蕴)：1/10/100/1000/10000+ → 2/3/4/5/6，封顶 6。
# - 真元回复 = 真元上限 × 资质回复比（甲40/乙30/丙20/丁10），上限 clamp。
# - 行动点不再抵扣真元：催动蛊只花真元，拳脚/闪避零真元耗 1 行动。


const BattleScript = preload("res://scripts/domain/battle_resolver.gd")
# 分档表唯一真源：action_points.gd（legacy actions_per_turn 只是其薄委托，
# B1-5 桶 A 2026-09-06：断言直接钉真源）。
const ActionPointsScript = preload("res://scripts/domain/action_points.gd")


func _make_battle(aptitude: String, soul: int = 1) -> Dictionary:
	var catalog: Dictionary = ContentCatalog.load_all()
	var state := RunState.new_run(7)
	state.aptitude = aptitude
	state.cultivator["soul"] = soul
	state.health = 200
	state.max_health = 200
	state.essence = 0
	state.cave_aperture["essence_max"] = state.essence_capacity
	var battle := BattleScript.start({"enemy_kind": "ridge_hound", "first_mover": "player"}, state, catalog)
	return {"catalog": catalog, "state": state, "battle": battle}


func _end_turn(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	return BattleScript.take_turn(battle.duplicate(true), {"type": "end_turn"}, state, catalog, int(state.event_log.size()), "player")


func test_actions_per_turn_tiers() -> void:
	assert_eq(ActionPointsScript.per_turn(1), 2)
	assert_eq(ActionPointsScript.per_turn(9), 2)
	assert_eq(ActionPointsScript.per_turn(10), 3)
	assert_eq(ActionPointsScript.per_turn(99), 3)
	assert_eq(ActionPointsScript.per_turn(100), 4)
	assert_eq(ActionPointsScript.per_turn(1000), 5)
	assert_eq(ActionPointsScript.per_turn(10000), 6)
	assert_eq(ActionPointsScript.per_turn(999999), 6, "超过 10000 不再增加")


func test_battle_start_seeds_action_pool_by_soul() -> void:
	var ctx := _make_battle("bing", 1)
	assert_eq(int(ctx["battle"].get("actions_max", -1)), 2, "魂魄 1 → 每回合 2 行动")
	assert_eq(int(ctx["battle"].get("actions_left", -1)), 2)
	var ctx2 := _make_battle("bing", 100)
	assert_eq(int(ctx2["battle"].get("actions_max", -1)), 4, "魂魄 100 → 每回合 4 行动")


func test_action_pool_refreshes_on_end_turn() -> void:
	var ctx := _make_battle("bing", 1)
	var battle: Dictionary = ctx["battle"]
	var state: RunState = ctx["state"]
	var catalog: Dictionary = ctx["catalog"]
	battle["actions_left"] = 0
	var res := _end_turn(battle, state, catalog)
	assert_true(bool(res.get("accepted", false)), "end_turn OK")
	assert_eq(int(res["battle"].get("actions_left", -1)), 2, "行动点回满 2")


func test_essence_regen_uses_regen_pct_table() -> void:
	# 丙等 20% × 上限 20 = 4/回合
	var ctx := _make_battle("bing", 1)
	var res := _end_turn(ctx["battle"], ctx["state"], ctx["catalog"])
	assert_eq(int(res["state"].essence), 4, "丙 20% 回 4")
	# 甲等 40%
	var ctx2 := _make_battle("jia", 1)
	ctx2["state"].essence = 0
	var res2 := _end_turn(ctx2["battle"], ctx2["state"], ctx2["catalog"])
	assert_eq(int(res2["state"].essence), 8, "甲 40% 回 8")
	# 丁等 10%
	var ctx3 := _make_battle("ding", 1)
	ctx3["state"].essence = 0
	var res3 := _end_turn(ctx3["battle"], ctx3["state"], ctx3["catalog"])
	assert_eq(int(res3["state"].essence), 2, "丁 10% 回 2")


func test_essence_never_exceeds_capacity_after_multi_turns() -> void:
	var ctx := _make_battle("bing", 1)
	var cur_battle: Dictionary = ctx["battle"]
	var cur_state: RunState = ctx["state"]
	var catalog: Dictionary = ctx["catalog"]
	for turn in 5:
		var res := _end_turn(cur_battle, cur_state, catalog)
		cur_state = res["state"]
		cur_battle = res["battle"]
		assert_true(int(cur_state.essence) <= int(cur_state.essence_capacity), "T%d essence 上限 clamp" % turn)
	assert_eq(int(cur_state.essence), int(cur_state.essence_capacity), "多回合后回满")


func test_playing_gu_costs_essence_not_actions_substitute() -> void:
	# 行动点不再抵扣真元：真元不足时催动被拒（即使行动点尚余）。
	var ctx := _make_battle("bing", 1)
	var battle: Dictionary = ctx["battle"]
	var state: RunState = ctx["state"]
	var catalog: Dictionary = ctx["catalog"]
	state.essence = 0
	var res := BattleScript.take_turn(battle.duplicate(true), {"type": "use_gu", "gu_id": "small_light_gu"}, state, catalog, int(state.event_log.size()), "player")
	assert_true((res.get("feeds", []) as Array).has("insufficient_essence"), "零真元催动被拒")


func test_no_backlash_on_high_rank_gu() -> void:
	# 2026-08-31 裁定：移除所有蛊虫负面效果——催动高转蛊不再反噬扣魂魄/气血。
	var ctx := _make_battle("bing", 1)
	var battle: Dictionary = ctx["battle"]
	var state: RunState = ctx["state"]
	var catalog: Dictionary = ctx["catalog"]
	state.refined_gu_ids = ["moonlight_gu"]
	state.gu_ids = ["moonlight_gu"]
	state.gu_instances = {"gu_009": {"instance_id": "gu_009", "definition_id": "moonlight_gu", "state": "refined"}}
	state.cave_aperture["stored_gu_instance_ids"] = ["gu_009"]
	state.essence = 200
	state.essence_capacity = 200
	var soul_before := int(state.cultivator["soul"])
	var hp_before := int(state.health)
	battle["hand"] = [{
		"instance_id": "probe_moon_1",
		"definition_id": "moonlight_strike",
		"source_gu_instance_ids": ["gu_009"],
	}]
	var res := BattleScript.take_turn(battle.duplicate(true), {"type": "use_gu", "gu_id": "moonlight_gu", "target_id": _living(battle)}, state, catalog, int(state.event_log.size()), "player")
	assert_true(bool(res.get("accepted", false)), "月光催动 OK")
	assert_eq(int(res["state"].cultivator["soul"]), soul_before, "魂魄无损（无反噬）")
	assert_eq(int(res["state"].health), hp_before, "气血无损（无反噬）")


func _living(battle: Dictionary) -> String:
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", false)):
			return str(enemy.get("enemy_id", ""))
	return ""