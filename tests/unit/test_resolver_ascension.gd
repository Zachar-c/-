extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_ascension_returns_success_for_prepared_state() -> void:
	var result := Resolver.apply(_prepared_state(), {"type": "attempt_ascension", "choice": "now"}, catalog)
	assert_true(result["result"]["ok"])
	assert_eq(result["result"]["outcome"], "success")


func test_ascension_returns_risky_success_when_requirements_met_with_high_risk() -> void:
	var state := _prepared_state()
	state.pursuit = 2
	var result := Resolver.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)
	assert_eq(result["result"]["outcome"], "risky_success")


func test_ascension_returns_survived_failure_for_missing_heaven_earth_qi() -> void:
	var state := _prepared_state()
	state.ascension.erase("heaven_earth_qi")
	var result := Resolver.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)
	assert_eq(result["result"]["outcome"], "survived_failure")


func test_invalid_command_does_not_mutate_state() -> void:
	var before := RunState.new_run(101)
	var result := Resolver.apply(before, {"type": "invented_command"}, catalog)
	assert_false(result["result"]["ok"])
	assert_eq(result["state"].to_save_data(), before.to_save_data())


func _prepared_state() -> RunState:
	var state := RunState.new_run(101)
	state.ascension = {
		"aperture_foundation": true,
		"heaven_earth_qi": true,
		"site": true,
		"protection": true,
		"external_interference": false,
	}
	return state
