extends GutTest


# Night batch R14.5/R14.6 (§16.11): state-adaptive DDA core. Evaluation is
# pure and deterministic; markers live in RunData.meta_rules under sys: keys
# (at most one, newest replaces); the hall toggle snapshots into the run; the
# enemy swap is lever 1 (composition only, never bosses, seeded via SeededRoll).


const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
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


func _first_turn(state: RunState, enemy_kind: String = "ridge_hound") -> Dictionary:
	var battle := BattleResolverScript.start({"enemy_kind": enemy_kind}, state, catalog)
	return BattleResolverScript.take_turn(battle, {"type": "basic_dodge"}, state, catalog)


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


func test_marker_refresh_writes_event_and_swap_happens_next_battle() -> void:
	var state := _peril_state()
	var first := _first_turn(state)
	assert_true(bool(first["finished"]) == false)
	var marked: RunState = first["state"]
	assert_true(marked.meta_rules.has("sys:dda_peril"))
	assert_eq(str(marked.event_log.back()["action"]), "dda_marker")
	assert_eq(str(marked.event_log.back()["reason"]), "dda_peril")

	var second_battle := BattleResolverScript.start({"enemy_kind": "ridge_hound"}, marked, catalog)
	assert_eq(str(second_battle["dda_swapped_from"]), "ridge_hound")
	assert_ne(str(second_battle["enemy_kind"]), "ridge_hound")
	var pool: Array = catalog["dda"]["enemy_swap_pools"]["sys:dda_peril"]
	assert_true(pool.has(str(second_battle["enemy_kind"])))


func test_bosses_are_never_swapped() -> void:
	var state := _peril_state()
	var first := _first_turn(state)
	var marked: RunState = first["state"]
	var boss_battle := BattleResolverScript.start({"enemy_kind": "miasma_vein_lord"}, marked, catalog)
	assert_eq(str(boss_battle["enemy_kind"]), "miasma_vein_lord")
	assert_eq(str(boss_battle.get("dda_swapped_from", "")), "")


func test_toggle_off_disables_evaluation_and_swap() -> void:
	var state := _peril_state()
	state.dda_state_adaptive_enabled = false
	var first := _first_turn(state)
	assert_false(first["state"].meta_rules.has("sys:dda_peril"))
	var battle := BattleResolverScript.start({"enemy_kind": "ridge_hound"}, state, catalog)
	assert_eq(str(battle["enemy_kind"]), "ridge_hound")

	var meta := MetaProgress.new_empty()
	meta.dda_state_adaptive_enabled = false
	var from_meta := RunState.new_run(101, meta)
	assert_false(bool(from_meta.dda_state_adaptive_enabled))


func test_marker_replaces_old_and_player_cap_is_exempt() -> void:
	var state := _peril_state()
	state = _first_turn(state)["state"]
	assert_eq(int(DdaResolverScript.player_rule_count(state.meta_rules)), 0)
	# Escalate into the decay band: marker must replace, never stack.
	var escalated := _decay_state()
	escalated.meta_rules = state.meta_rules.duplicate(true)
	var battle := BattleResolverScript.start({"enemy_kind": "ridge_hound"}, escalated, catalog)
	var second := BattleResolverScript.take_turn(battle, {"type": "basic_dodge"}, escalated, catalog)
	var marked: RunState = second["state"]
	var sys_keys := 0
	for key in marked.meta_rules:
		if str(key).begins_with("sys:"):
			sys_keys += 1
	assert_eq(sys_keys, 1)
	assert_true(marked.meta_rules.has("sys:dda_decay"))
	assert_eq(str(marked.event_log.back()["reason"]), "dda_decay")

	# Player meta cap: sys: keys never count against R4.8's ≤2.
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
	var state := _peril_state()
	state = _first_turn(state)["state"]
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
	var state := _peril_state()
	state = _first_turn(state)["state"]
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


func test_swaps_are_deterministic() -> void:
	var pool: Array = catalog["dda"]["enemy_swap_pools"]["sys:dda_peril"]
	var first_state := _peril_state(424242)
	first_state = _first_turn(first_state)["state"]
	var second_state := _peril_state(424242)
	second_state = _first_turn(second_state)["state"]
	var first_battle := BattleResolverScript.start({"enemy_kind": "ridge_hound"}, first_state, catalog)
	var second_battle := BattleResolverScript.start({"enemy_kind": "ridge_hound"}, second_state, catalog)
	assert_eq(str(first_battle["enemy_kind"]), str(second_battle["enemy_kind"]))
	assert_true(pool.has(str(first_battle["enemy_kind"])))


func _has(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false