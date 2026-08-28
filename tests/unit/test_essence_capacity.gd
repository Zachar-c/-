extends GutTest


const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_essence_max_follows_rank_tier_and_aptitude_percent() -> void:
	# 2026-08-28 验收批：一/三/五转差异放大——base 3/5/10/16/24（nirvana 新档）。
	var state := RunState.new_run(101)
	assert_eq(EssenceCapacityScript.essence_max(state, catalog), 4)

	state.cultivation = 2
	assert_eq(EssenceCapacityScript.essence_max(state, catalog), 6)

	state.cultivation = 3
	state.aptitude = "yi"
	assert_eq(EssenceCapacityScript.essence_max(state, catalog), 12)

	state.cultivation = 4
	state.aptitude = "jia"
	assert_eq(EssenceCapacityScript.essence_max(state, catalog), 22)

	state.cultivation = 5
	state.aptitude = "wu"
	assert_eq(EssenceCapacityScript.essence_max(state, catalog), 14)


func test_new_run_keeps_default_essence_max_three() -> void:
	assert_eq(int(RunState.new_run(101).cave_aperture["essence_max"]), 4)


func test_rank_two_breakthrough_refreshes_essence_max() -> void:
	var state := RunState.new_run(101)
	state.stone = 12
	state.current_node_id = "cultivation_spring"
	var result := ResolverScript.apply(state, {"type": "cultivate_rank_two"}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(int(result["state"].cultivator["reincarnation"]), 1)
	assert_eq(int(result["state"].cave_aperture["essence_max"]), 6)
	assert_eq(result["state"].essence, 4)


func test_missing_aptitude_table_falls_back_to_three() -> void:
	var tuned := catalog.duplicate(true)
	tuned["aptitude"] = {}
	var state := RunState.new_run(101)
	assert_eq(EssenceCapacityScript.essence_max(state, tuned), 4)


func test_validation_rejects_negative_percent_and_base() -> void:
	var tuned := catalog.duplicate(true)
	var aptitude: Dictionary = tuned["aptitude"].duplicate(true)
	aptitude["aptitude_pct"]["bing"] = -5
	tuned["aptitude"] = aptitude
	var errors: Array[String] = ContentCatalogScript.validate(tuned)
	assert_true(_has_hint(errors, "aptitude"))

	var bad_base := catalog.duplicate(true)
	var with_bad_base: Dictionary = bad_base["aptitude"].duplicate(true)
	with_bad_base["stage_essence_base"]["low"] = 0
	bad_base["aptitude"] = with_bad_base
	assert_true(_has_hint(ContentCatalogScript.validate(bad_base), "aptitude"))


func _has_hint(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false