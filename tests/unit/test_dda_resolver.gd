extends GutTest


# Night batch R14.5/R14.6 (§16.11): state-adaptive DDA core. Evaluation is
# pure and deterministic; markers live in RunData.meta_rules under sys: keys
# (at most one, newest replaces); the hall toggle snapshots into the run.
# NOTE (B1 bucket C 2026-09-06): the battle-integrated levers (marker write
# on turn, enemy swap at battle start, boss-local intent adapt) lived only in
# the legacy battle engine; V1/facade has no DDA hook, so the lever tests were
# removed with battle_resolver.gd and the gap is tracked as domain debt.


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _state(seed_value: int = 101) -> RunState:
	var state := RunState.new_run(seed_value)
	state.current_node_id = "beast_swarm_pass"
	return state


func _peril_state(seed_value: int = 101) -> RunState:
	var state := _state(seed_value)
	state.health = 2
	state.max_health = 6
	state.cultivator["statuses"] = {
		"gu_erosion": {"layers": 1},
		"slot_seal": {"layers": 1},
	}
	return state


func _decay_state(seed_value: int = 101) -> RunState:
	var state := _peril_state(seed_value)
	state.stone = 3
	state.synthesis_fail_streak = 3
	state = state.append_event({"action": "battle_failed_probe", "reason": "battle_failed_probe"})
	state = state.append_event({"action": "battle_failed_probe", "reason": "battle_failed_probe"})
	return state


## A run whose meta says a peril marker fired (fixture stands in for the
## legacy battle-turn hook that used to write it; recap reads event targets).
func _marked_state(seed_value: int = 101) -> RunState:
	var state := _peril_state(seed_value)
	state.meta_rules = {"sys:dda_peril": true}
	return state.append_event({
		"action": "dda_marker", "reason": "dda_peril", "targets": ["sys:dda_peril"],
	})


func test_evaluation_is_deterministic_and_band_edges() -> void:
	var plain := _state()
	var plain_eval := DdaResolverScript.evaluate(plain, catalog)
	assert_eq(int(plain_eval["score"]), 0)
	assert_eq(str(plain_eval["marker"]), "")
	assert_eq(str(plain_eval["label"]), "平稳")

	var peril := _peril_state()
	var peril_eval := DdaResolverScript.evaluate(peril, catalog)
	assert_eq(int(peril_eval["score"]), 6)
	assert_eq(str(peril_eval["marker"]), "sys:dda_peril")
	assert_eq(str(peril_eval["label"]), "险象")

	var decay := _decay_state()
	var decay_eval := DdaResolverScript.evaluate(decay, catalog)
	assert_eq(int(decay_eval["score"]), 10)
	assert_eq(str(decay_eval["marker"]), "sys:dda_decay")
	assert_eq(str(decay_eval["label"]), "衰运")

	assert_eq(DdaResolverScript.evaluate(peril, catalog), DdaResolverScript.evaluate(peril, catalog))


func test_toggle_off_from_meta_disables_dda() -> void:
	var meta := MetaProgress.new_empty()
	meta.dda_state_adaptive_enabled = false
	var from_meta := RunState.new_run(101, meta)
	assert_false(bool(from_meta.dda_state_adaptive_enabled))


func test_sys_markers_never_count_against_player_meta_cap() -> void:
	var meta_relic := ""
	for relic_value in catalog["relics"]:
		var relic: Dictionary = relic_value
		if str(relic.get("grade", "")) == "meta_rule":
			meta_relic = str(relic.get("id", ""))
			break
	assert_false(meta_relic.is_empty())
	var relic_state := _state()
	relic_state.relic_ids = ["other_a", "other_b"]
	relic_state.meta_rules = {"sys:dda_decay": true, "other_a": true, "other_b": true}
	assert_eq(str(ResolverScript._can_gain_relic(relic_state, catalog, meta_relic)), "meta_rule_cap_reached")
	relic_state.meta_rules = {"sys:dda_decay": true, "other_a": true}
	assert_eq(str(ResolverScript._can_gain_relic(relic_state, catalog, meta_relic)), "")


func test_snapshot_anomalies_debug_percentile_and_recap() -> void:
	var state := _marked_state()
	var stub := {
		"state": state,
		"catalog": catalog,
		"current_node": {"id": "beast_swarm_pass", "type": "combat", "choices": []},
		"meta": null,
	}
	var gui: Dictionary = RunSnapshotBuilderScript._gui_state(stub)
	assert_eq((gui["anomalies"] as Array).size(), 1)
	assert_eq(str(gui["anomalies"][0]["id"]), "sys:dda_peril")
	assert_eq(str(gui["anomalies"][0]["label"]), "险象")

	var dbg: Dictionary = RunSnapshotBuilderScript.debug(stub)
	assert_eq(str(dbg["dda_percentile"]), "6/10 险象")

	assert_eq(int(RunSnapshotBuilderScript._dda_trigger_count(state)), 1)
	var recap := RunSnapshotBuilderScript._dda_marker_recap(state, catalog)
	assert_eq(recap.size(), 1)
	assert_eq(str(recap[0]["label"]), "险象")


func test_save_round_trip_keeps_marker_and_toggle() -> void:
	var state := _marked_state()
	var data := SaveRepositoryScript.serialize_run(state, [], [])
	var loaded: Dictionary = SaveRepositoryScript.load_run_from_data(data)
	var restored: RunState = loaded["state"]
	assert_true(restored.meta_rules.has("sys:dda_peril"))
	assert_true(bool(restored.dda_state_adaptive_enabled))

	var meta := MetaProgress.new_empty()
	meta.dda_state_adaptive_enabled = false
	var meta_data := SaveRepositoryScript.serialize_meta(meta)
	var meta_loaded := SaveRepositoryScript.load_meta_from_data(meta_data)
	assert_false(bool(meta_loaded.dda_state_adaptive_enabled))


func test_validation_rejects_bad_dda_config() -> void:
	assert_true(ContentCatalogScript.validate(catalog).is_empty())
	var tuned := catalog.duplicate(true)
	var bad := (catalog["dda"] as Dictionary).duplicate(true)
	bad["bands"] = [
		{"min_score": 9, "marker": "sys:dda_decay", "label": "衰运"},
		{"min_score": 0, "marker": "", "label": "平稳"},
	]
	tuned["dda"] = bad
	var errors := ContentCatalogScript.validate(tuned)
	assert_true(_has(errors, "ascend strictly"))

	bad = (catalog["dda"] as Dictionary).duplicate(true)
	bad["bands"] = [{"min_score": 0, "marker": "plain_marker", "label": "X"}]
	tuned["dda"] = bad
	errors = ContentCatalogScript.validate(tuned)
	assert_true(_has(errors, "must start with sys:"))

	bad = (catalog["dda"] as Dictionary).duplicate(true)
	bad["enemy_swap_pools"] = {"sys:dda_peril": ["ghost_enemy"]}
	tuned["dda"] = bad
	errors = ContentCatalogScript.validate(tuned)
	assert_true(_has(errors, "unknown enemy"))

	bad = (catalog["dda"] as Dictionary).duplicate(true)
	bad["weights"] = {"low_health": 0}
	tuned["dda"] = bad
	errors = ContentCatalogScript.validate(tuned)
	assert_true(_has(errors, "weights"))


func test_low_health_plus_poor_stone_reaches_peril() -> void:
	# 修复 3：低血(3) + 贫石(2) 必须够到险象门槛 5（此前 3+1=4 落回平稳）。
	var state := _state()
	state.health = 2
	state.max_health = 6
	state.stone = 0
	var eval_result := DdaResolverScript.evaluate(state, catalog)
	assert_eq(int(eval_result["score"]), 5, "低血+贫石必须达到险象门槛 5")
	assert_eq(str(eval_result["marker"]), "sys:dda_peril")


func test_retreats_and_wounded_departures_count_as_recent_losses() -> void:
	# 修复 3：撤退与连续带伤离场计入近期败势（此前只认 battle_ 且 failed/dead）。
	var state := _state()
	state = state.append_event({"action": "battle_retreat", "reason": "battle_retreat"})
	state = state.append_event({"action": "battle_retreat", "reason": "battle_retreat"})
	state = state.append_event({"action": "encounter_session", "reason": "encounter_left_wounded"})
	state = state.append_event({"action": "encounter_session", "reason": "encounter_left_wounded"})
	var eval_result := DdaResolverScript.evaluate(state, catalog)
	assert_eq(int(eval_result["score"]), int(catalog["dda"]["weights"]["recent_losses"]), "两次败势（撤退/带伤离场）必须触发 recent_losses 权重")

	var single := _state()
	single = single.append_event({"action": "battle_retreat", "reason": "battle_retreat"})
	assert_eq(int(DdaResolverScript.evaluate(single, catalog)["score"]), 0, "单次败势不触发")


func test_battle_summary_window_ignores_unrelated_events() -> void:
	# 修复 3：窗口只统计战斗摘要事件——6 条购买事件夹在两条败仗中间，
	# 旧“最后 6 条任意事件”实现会丢掉连败计数，新窗口不受稀释。
	var state := _state()
	for i in range(6):
		state = state.append_event({"action": "shop_purchase", "reason": "bought_gu"})
	state = state.append_event({"action": "battle_failed_probe", "reason": "battle_failed_probe"})
	state = state.append_event({"action": "battle_failed_probe", "reason": "battle_failed_probe"})
	var eval_result := DdaResolverScript.evaluate(state, catalog)
	assert_eq(int(eval_result["score"]), int(catalog["dda"]["weights"]["recent_losses"]), "战斗摘要窗口：无关事件不得稀释连败计数")


func test_victory_breaks_the_loss_window() -> void:
	# 修复 3：最近一场战斗是胜利时，败势窗口重置。
	var state := _state()
	state = state.append_event({"action": "battle_failed_probe", "reason": "battle_failed_probe"})
	state = state.append_event({"action": "battle_failed_probe", "reason": "battle_failed_probe"})
	state = state.append_event({"action": "battle_finished", "reason": "battle_victory"})
	assert_eq(int(DdaResolverScript.evaluate(state, catalog)["score"]), 0, "最近胜利必须打断连败窗口")


func _has(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false
