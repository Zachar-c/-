extends GutTest


# 回合行动预算（2026-08-31 数值重做后）：
# - 每回合行动次数 = actions_per_turn(魂魄底蕴)：1/10/100/1000/10000+ → 2/3/4/5/6，封顶 6。
# - V1 战斗把该预算落成 player.thoughts（start 初始值 = 每回合开始回复值）。
# legacy 的 essence/actions_max/actions_left 经济腿随 battle_resolver.gd 退役
# （B1 桶 C）；V1 的 true_qi/regen/门槛数值口径由 test_v1_battle_resolver 与
# test_battle_command_facade 覆盖。


# 分档表唯一真源：action_points.gd（legacy actions_per_turn 只是其薄委托，
# B1-5 桶 A 2026-09-06：断言直接钉真源）。
const ActionPointsScript = preload("res://scripts/domain/action_points.gd")
const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")


func _v1_start_battle(soul: int) -> Dictionary:
	var catalog: Dictionary = ContentCatalog.load_all()
	var state := RunState.new_run(7)
	state.cultivator["soul"] = soul
	state.health = 200
	state.max_health = 200
	return {
		"catalog": catalog,
		"state": state,
		"battle": FacadeScript.start({"enemy_kind": "ridge_hound"}, state, catalog),
	}


func test_actions_per_turn_tiers() -> void:
	assert_eq(ActionPointsScript.per_turn(1), 2)
	assert_eq(ActionPointsScript.per_turn(9), 2)
	assert_eq(ActionPointsScript.per_turn(10), 3)
	assert_eq(ActionPointsScript.per_turn(99), 3)
	assert_eq(ActionPointsScript.per_turn(100), 4)
	assert_eq(ActionPointsScript.per_turn(1000), 5)
	assert_eq(ActionPointsScript.per_turn(10000), 6)
	assert_eq(ActionPointsScript.per_turn(999999), 6, "超过 10000 不再增加")


func test_v1_battle_start_seeds_thoughts_by_soul() -> void:
	var ctx := _v1_start_battle(1)
	assert_eq(int(ctx["battle"]["player"]["thoughts"]), 2, "魂魄 1 → 每回合 2 念头")
	var ctx2 := _v1_start_battle(100)
	assert_eq(int(ctx2["battle"]["player"]["thoughts"]), 4, "魂魄 100 → 每回合 4 念头")
