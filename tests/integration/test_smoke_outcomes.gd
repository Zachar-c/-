extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_fixed_scenarios_cover_the_grading_band_without_llm() -> void:
	assert_eq(_play_scenario("prepared"), "ascension_special")
	assert_eq(_play_scenario("hunted"), "ascension_high")
	# 评价制：缺一项不再是失败——干净风险下 4/5 条件仍为上等。
	assert_eq(_play_scenario("missing_qi"), "ascension_high")
	# 裸奔冲仙（1/5 条件 + 高风险）落在下等。
	assert_eq(_play_scenario("barely"), "ascension_low")


func _play_scenario(scenario: String) -> String:
	var state := RunState.new_run(101)
	state.node_flags["boss_defeated"] = "true"
	state.ascension = {
		"aperture_foundation": true,
		"heaven_earth_qi": scenario != "missing_qi",
		"site": true,
		"protection": true,
		"external_interference": false,
	}
	if scenario == "hunted":
		state.pursuit = 2
	if scenario == "barely":
		state.ascension = {"heaven_earth_qi": true, "external_interference": true}
		state.pursuit = 5
	var result := Resolver.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)
	var journal := JournalBuilder.build(result["state"], result["result"])
	assert_gt(journal.size(), 0)
	return result["result"]["outcome"]
