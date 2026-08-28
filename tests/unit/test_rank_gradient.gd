extends GutTest


# 2026-08-28 验收批：一转/三转/五转蛊师数值差异放大。
# 双曲线钉死——玩家转数抬真元上限（aptitude.json rank_tier/stage_essence_base，
# 遵守「转数只抬真元上限」设计点），同名蛊升阶抬打击加成
# （pacing.advance_bonus_by_rank 超线性阶梯 0/1/3/6/10）。


const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")


func test_essence_capacity_gradient_one_three_five() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	assert_eq(EssenceCapacityScript.essence_max(state, catalog), 4, "rank one")
	state.cultivation = 3
	assert_eq(EssenceCapacityScript.essence_max(state, catalog), 10, "rank three")
	state.cultivation = 5
	assert_eq(EssenceCapacityScript.essence_max(state, catalog), 24, "rank five")


func test_advance_bonus_table_is_superlinear() -> void:
	var catalog := ContentCatalog.load_all()
	var table: Dictionary = catalog.get("pacing", {}).get("advance_bonus_by_rank", {})
	assert_eq(int(table.get("1", -1)), 0)
	assert_eq(int(table.get("2", -1)), 1)
	assert_eq(int(table.get("3", -1)), 3)
	assert_eq(int(table.get("4", -1)), 6)
	assert_eq(int(table.get("5", -1)), 10)
	assert_true(int(table["5"]) > int(table["3"]) * 2,
			"rank-five bonus must more than double rank-three (amplified gradient)")


func test_rank_five_strike_uses_bonus_table() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	state.essence = 30
	state.gu_instances = {
		"gu_001": {"instance_id": "gu_001", "definition_id": "small_light_gu", "state": "refined", "rank": 5},
	}
	state.gu_ids = ["small_light_gu"]
	state.refined_gu_ids = ["small_light_gu"]
	# small_light 无反应门（ridge_hound 的 counter_bite 会把直接打击转为
	# 揭示反应），是加成数值的直接探针。
	var battle: Dictionary = BattleResolverScript.start(
		{"enemy_kind": "ridge_hound", "enemy_hp": 20}, state, catalog)
	var turned: Dictionary = BattleResolverScript.take_turn(
		battle, {"type": "use_gu", "gu_id": "small_light_gu"}, state, catalog)
	# small_light 基伤 1 + 五阶加成 10 = 11；血量 20 的敌犬应剩 9。
	assert_eq(int(turned["battle"]["enemy_hp"]), 9,
			"rank-five strike must apply the amplified bonus table")
