extends GutTest


# 2026-08-31 数值重做：essence_max = 10 × 资质因子(甲4/乙3/丙2/丁1) × 修为因子(1:3:9:27:81)。


const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")


func _state(aptitude: String, cultivation: int) -> RunState:
	var state := RunState.new_run(7)
	state.aptitude = aptitude
	state.cultivation = cultivation
	return state


func test_essence_max_multiplies_base_aptitude_and_cultivation() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	assert_eq(EssenceCapacityScript.essence_max_for(_state("bing", 1), catalog, 1), 20, "丙一转 20")
	assert_eq(EssenceCapacityScript.essence_max_for(_state("bing", 2), catalog, 2), 60, "丙二转 60")
	assert_eq(EssenceCapacityScript.essence_max_for(_state("bing", 5), catalog, 5), 1620, "丙五转 1620")
	assert_eq(EssenceCapacityScript.essence_max_for(_state("jia", 5), catalog, 5), 3240, "甲五转 3240")
	assert_eq(EssenceCapacityScript.essence_max_for(_state("ding", 1), catalog, 1), 10, "丁一转 10")


func test_regen_pct_follows_aptitude_ladder() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	assert_eq(EssenceCapacityScript.regen_pct(_state("jia", 1), catalog), 40)
	assert_eq(EssenceCapacityScript.regen_pct(_state("yi", 1), catalog), 30)
	assert_eq(EssenceCapacityScript.regen_pct(_state("bing", 1), catalog), 20)
	assert_eq(EssenceCapacityScript.regen_pct(_state("ding", 1), catalog), 10)


func test_validation_rejects_bad_new_schema() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog["aptitude"]["essence_base"] = 0
	var errors := ContentCatalog.validate(catalog)
	assert_true(errors.size() >= 1)
	var found := false
	for e in errors:
		if str(e).contains("essence_base"):
			found = true
	assert_true(found, "essence_base 校验拦截")

	catalog = ContentCatalog.load_all()
	catalog["aptitude"]["aptitude_factor"].erase("bing")
	errors = ContentCatalog.validate(catalog)
	found = false
	for e in errors:
		if str(e).contains("aptitude_factor"):
			found = true
	assert_true(found, "aptitude_factor 校验拦截")


# ── T13：元石 → 真元（原文元石第二职能「用元石补充真元」） ──────────────
#
# 口径：吸收效率复用 natural_recovery(资质%)（系数 = balance.aptitude_recovery_multiplier）；
# 每颗元石的基准真元 = balance.stone_to_essence_per_stone。丙资质 rate 0.7 → 每颗 3 点。

func test_stone_to_essence_spends_stones_and_is_pure() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var state := _state("bing", 1)
	state.essence = 5
	state.stone = 12
	var plan := EssenceCapacityScript.stone_to_essence(state, 2, catalog)
	assert_true(plan["ok"], "可换：%s" % str(plan))
	assert_eq(int(plan["per_stone"]), 3, "丙资质吸收效率 0.7 → 每颗 3 点真元")
	assert_eq(int(plan["stones_spent"]), 2, "花 2 元石")
	assert_eq(int(plan["essence_gain"]), 6, "得 6 真元")
	assert_eq(int(plan["essence_after"]), 11)
	assert_eq(int(plan["stone_after"]), 10, "元石不为负")
	assert_eq(int(state.stone), 12, "纯函数：不改 state")
	assert_eq(int(state.essence), 5, "纯函数：不改 state")


func test_stone_to_essence_never_exceeds_essence_max() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var state := _state("bing", 1)
	state.essence = 5
	state.stone = 12
	var plan := EssenceCapacityScript.stone_to_essence(state, 12, catalog)
	assert_true(plan["ok"])
	assert_eq(int(plan["essence_after"]), EssenceCapacityScript.essence_max(state, catalog),
		"真元恰好补到 essence_max，不越界")
	assert_eq(int(plan["stones_spent"]), 5, "按容量截断，不浪费元石")
	assert_true(bool(plan["clamped"]), "标记已截断")
	assert_eq(int(plan["stone_after"]), 7)


func test_stone_to_essence_rejects_bad_amounts() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var state := _state("bing", 1)
	state.essence = 5
	state.stone = 3
	assert_eq(str(EssenceCapacityScript.stone_to_essence(state, 0, catalog)["reason"]),
		"invalid_stone_amount", "0 颗拒绝")
	assert_eq(str(EssenceCapacityScript.stone_to_essence(state, 4, catalog)["reason"]),
		"insufficient_stone", "元石不足拒绝（不产生负元石）")
	state.essence = EssenceCapacityScript.essence_max(state, catalog)
	assert_eq(str(EssenceCapacityScript.stone_to_essence(state, 1, catalog)["reason"]),
		"essence_full", "真元已满拒绝")


func test_stone_to_essence_efficiency_follows_aptitude() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var low := _state("ding", 1)
	low.essence = 0
	var high := _state("jia", 1)
	high.essence = 0
	var low_plan := EssenceCapacityScript.stone_to_essence(low, 1, catalog)
	var high_plan := EssenceCapacityScript.stone_to_essence(high, 1, catalog)
	assert_gt(int(high_plan["per_stone"]), int(low_plan["per_stone"]),
		"资质越高吸收越充分（复用 aptitude_recovery_multiplier 钩子）")
	assert_eq(int(high_plan["essence_after"]), int(high_plan["per_stone"]), "甲资质 1 颗换满 4 点")
