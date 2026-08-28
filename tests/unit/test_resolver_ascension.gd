extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_ascension_grades_special_for_full_preparation_and_low_risk() -> void:
	var result := Resolver.apply(_prepared_state(), {"type": "attempt_ascension", "choice": "now"}, catalog)
	assert_true(result["result"]["ok"])
	assert_eq(result["result"]["outcome"], "ascension_special")


func test_ascension_grades_high_for_full_preparation_with_accumulated_risk() -> void:
	var state := _prepared_state()
	state.pursuit = 2
	var result := Resolver.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)
	assert_eq(result["result"]["outcome"], "ascension_high")


func test_ascension_grades_medium_when_one_condition_missing_with_clean_risk() -> void:
	# 评价制：缺一项不再是失败，而是降档（4/5 条件 + risk<=1 -> 上等边界外的
	# 罚分为 1 时落到 3 分 -> 中等；此处 4 条件 + risk 2 -> 3 分同为中等）。
	var state := _prepared_state()
	state.ascension["heaven_earth_qi"] = false
	state.pursuit = 2
	var result := Resolver.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)
	assert_eq(result["result"]["outcome"], "ascension_medium")


func test_ascension_grades_medium_for_high_risk_even_with_full_preparation() -> void:
	var state := _prepared_state()
	state.pursuit = 5
	var result := Resolver.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)
	assert_eq(result["result"]["outcome"], "ascension_medium")


func test_ascension_grades_low_for_bare_preparation() -> void:
	var state := _prepared_state()
	state.ascension = {"external_interference": true}
	var result := Resolver.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)
	assert_eq(result["result"]["outcome"], "ascension_low")


func test_ascension_records_conditions_and_risk_for_review() -> void:
	var state := _prepared_state()
	state.pursuit = 2
	var result := Resolver.apply(state, {"type": "attempt_ascension", "choice": "now"}, catalog)
	var ascension: Dictionary = result["state"].ascension
	assert_eq(int(ascension.get("risk", -1)), 2, "risk must be recorded for the settlement review")
	assert_eq(int(ascension.get("conditions_met", -1)), 5, "condition count must be recorded")


func test_invalid_command_does_not_mutate_state() -> void:
	var before := RunState.new_run(101)
	var result := Resolver.apply(before, {"type": "invented_command"}, catalog)
	assert_false(result["result"]["ok"])
	assert_eq(result["state"].to_save_data(), before.to_save_data())


func test_claiming_poison_fog_vein_secures_heaven_earth_qi() -> void:
	# Ascension grants are data-driven from nodes.json: the poison fog vein
	# (on_skip=lose_qi) hands heaven-earth qi to whoever claims it in play.
	var state := RunState.new_run(101)
	state.current_node_id = "poison_fog_vein"
	var result := Resolver.apply(state, {"type": "choose_action", "action_id": "claim"}, catalog)
	assert_true(result["result"]["ok"])
	assert_true(bool(result["state"].ascension.get("heaven_earth_qi", false)),
		"claiming the vein must secure heaven-earth qi")
	assert_eq(str(result["state"].event_log.back()["reason"]), "ascension_grant_heaven_earth_qi")


func test_seclusion_ritual_secures_aperture_foundation() -> void:
	# body_imprint_ritual (on_skip=lose_foundation) is the aperture-foundation
	# source: performing its meditate action secures the condition.
	var state := RunState.new_run(101)
	state.current_node_id = "body_imprint_ritual"
	var result := Resolver.apply(state, {"type": "choose_action", "action_id": "meditate"}, catalog)
	assert_true(result["result"]["ok"])
	assert_true(bool(result["state"].ascension.get("aperture_foundation", false)),
		"the seclusion ritual must secure aperture foundation")


func test_ascension_grants_outside_their_nodes_stay_inert() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "toxic_mountain_path"
	var result := Resolver.apply(state, {"type": "choose_action", "action_id": "claim"}, catalog)
	assert_true(result["result"]["ok"])
	assert_false(bool(result["state"].ascension.get("heaven_earth_qi", false)),
		"generic claim elsewhere must not grant heaven-earth qi")


func test_catalog_rejects_unknown_ascension_grant_flag() -> void:
	var bad := catalog.duplicate(true)
	for node_value in bad.get("nodes", []):
		var node: Dictionary = node_value
		if str(node.get("id", "")) == "poison_fog_vein":
			node["ascension_grants"] = {"claim": "invisible_power"}
	var errors := ContentCatalog.validate(bad)
	assert_eq(errors.size(), 1, "an unknown grant flag must fail catalog validation")


func _prepared_state() -> RunState:
	var state := RunState.new_run(101)
	state.node_flags["boss_defeated"] = "true"
	state.ascension = {
		"aperture_foundation": true,
		"heaven_earth_qi": true,
		"site": true,
		"protection": true,
		"external_interference": false,
	}
	return state
