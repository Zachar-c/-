extends GutTest


# 2026-08-31 数值重做：蛊虫消耗/伤害同用转数因子 1:3:9:27:81（双曲线钉死）。
# 表在 data/aptitude.json cultivation_factor；battle_resolver.rank_factor 只是
# 查表薄封装（2026-09-06 B1 退役），此处直接钉数据表保留同一数值契约。


func test_rank_factor_table() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var factors: Dictionary = catalog.get("aptitude", {}).get("cultivation_factor", {})
	for rank in [1, 2, 3, 4, 5]:
		var expected := 1
		for _i in range(1, rank):
			expected *= 3
		assert_eq(int(factors.get(str(rank), -1)), expected, "rank %d factor" % rank)


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
