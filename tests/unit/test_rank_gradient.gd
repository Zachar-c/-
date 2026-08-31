extends GutTest


# 2026-08-31 数值重做：蛊虫消耗/伤害同用转数因子 1:3:9:27:81（双曲线钉死）。


const BattleScript = preload("res://scripts/domain/battle_resolver.gd")


func test_rank_factor_table() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	assert_eq(BattleScript.rank_factor(catalog, 1), 1)
	assert_eq(BattleScript.rank_factor(catalog, 2), 3)
	assert_eq(BattleScript.rank_factor(catalog, 3), 9)
	assert_eq(BattleScript.rank_factor(catalog, 4), 27)
	assert_eq(BattleScript.rank_factor(catalog, 5), 81)


func test_player_capacity_follows_same_curve() -> void:
	# 玩家真元总量与蛊虫消耗同曲线（丙等）。
	var catalog: Dictionary = ContentCatalog.load_all()
	var state := RunState.new_run(7)
	state.aptitude = "bing"
	for rank in [1, 2, 3, 4, 5]:
		state.cultivation = rank
		var expected := 20
		for _i in range(1, rank):
			expected *= 3
		assert_eq(EssenceCapacity.essence_max_for(state, catalog, rank), expected, "rank %d" % rank)
