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
