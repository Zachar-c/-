extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_fixed_scenarios_cover_all_three_outcomes_without_llm() -> void:
	assert_eq(_play_scenario("prepared"), "success")
	assert_eq(_play_scenario("hunted"), "risky_success")
	assert_eq(_play_scenario("missing_qi"), "survived_failure")


func _play_scenario(scenario: String) -> String:
	var state := RunState.new_run(101)
	state.ascension = {
		"aperture_foundation": true,
		"heaven_earth_qi": scenario != "missing_qi",
		"site": true,
		"protection": true,
		"external_interference": false,
	}
	if scenario == "hunted":
		state.pursuit = 2
	var result := Resolver.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)
	var journal := JournalBuilder.build(result["state"], result["result"])
	assert_gt(journal.size(), 0)
	return result["result"]["outcome"]
