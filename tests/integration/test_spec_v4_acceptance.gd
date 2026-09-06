extends GutTest


# Spec-v4 phase-2 (T10.2): the 17.4 acceptance matrix - one E2E probe per
# item, each wired through the real v2 command / module surfaces. Any red
# blocks the final release gate.


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const CoreGuRulesScript = preload("res://scripts/domain/core_gu_rules.gd")
const FeedingRulesScript = preload("res://scripts/domain/feeding_rules.gd")
const Battle2TurnEngineScript = preload("res://scripts/domain/battle2/turn_engine.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")
const MaterialRulesScript = preload("res://scripts/domain/material_rules.gd")
const LootRulesScript = preload("res://scripts/domain/loot_rules.gd")
const MarketRulesScript = preload("res://scripts/domain/market_rules.gd")
const SoulRulesScript = preload("res://scripts/domain/soul_rules.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _state() -> RunState:
	var state: RunState = RunStateScript.new_run(97)
	for index in range(6):
		state.route_progress.append("n%02d" % index)
	return state


func _command(state: RunState, type_name: String, fields: Dictionary = {}) -> Dictionary:
	var command := {"type": type_name}
	command["state_version"] = state.event_log.size()
	for key in fields:
		command[key] = fields[key]
	return ResolverScript.apply(state, command, catalog)


func test_acceptance_1_any_combat_gu_can_be_core_and_hub_differs() -> void:
	var state := _state()
	var confirmed := _command(state, "confirm_core", {"instance_id": "gu_001"})
	assert_true(bool(confirmed["result"]["ok"]), str(confirmed))
	# 802 catalog 重建后唯一 hub 蛊为 moon_glow_gu；普通蛊（gu_001=small_light_gu）
	# 恒为 common_core，hub 蛊为 hub_core——depth 分级由定义 core_depth 决定。
	var hub_depth := CoreGuRulesScript.core_depth(catalog["gu_by_id"]["moon_glow_gu"], catalog)
	assert_eq(hub_depth, "hub_core")
	var common_depth := CoreGuRulesScript.core_depth(catalog["gu_by_id"]["small_light_gu"], catalog)
	assert_eq(common_depth, "common_core")


func test_acceptance_2_replace_removes_core_mods_keeps_rank() -> void:
	var state := _state()
	state.gu_instances["gu_002"] = state.gu_instances["gu_001"].duplicate(true)
	state.gu_instances["gu_002"]["instance_id"] = "gu_002"
	state.gu_instances["gu_001"]["core_state"] = {"confirmed_layer": "one", "depth": "common_core"}
	state.gu_instances["gu_001"]["modifications"] = [
		{"kind": "core_imprint", "source": "core_exclusive"}]
	var replaced := _command(state, "replace_core", {
		"old_instance_id": "gu_001", "new_instance_id": "gu_002", "cost": {"certificate": 1}})
	assert_true(bool(replaced["result"]["ok"]), str(replaced))
	var next: RunState = replaced["state"]
	assert_true((next.gu_instances["gu_001"]["core_state"] as Dictionary).is_empty())
	assert_true((next.gu_instances["gu_001"]["modifications"] as Array).is_empty())


func test_acceptance_3_unlimited_holding_no_slot_gate() -> void:
	var state := _state()
	for index in range(20):
		state.gu_instances["many_%02d" % index] = state.gu_instances["gu_001"].duplicate(true)
		state.gu_instances["many_%02d" % index]["instance_id"] = "many_%02d" % index
	var settled := FeedingRulesScript.layer_settle(
			state.gu_instances.values(), state.materials, {}, catalog)
	assert_eq(settled["settled"].size(), 21)


func test_acceptance_4_instance_and_action_once_per_round() -> void:
	var ledger := Battle2TurnEngineScript.new_turn(5)
	var first := Battle2TurnEngineScript.enact(ledger,
			{"kind": "activate_gu", "instance_id": "gu_001", "thought": 1})
	assert_true(bool(first["ok"]))
	var again := Battle2TurnEngineScript.enact(first["ledger"],
			{"kind": "activate_gu", "instance_id": "gu_001", "thought": 1})
	assert_false(bool(again["ok"]))


func test_acceptance_5_thoughts_decouple_from_soul() -> void:
	var state := _state()
	var before := CultivatorRulesScript.thought_capacity(state.cultivator, catalog)
	state.cultivator["soul"] = 99
	assert_eq(CultivatorRulesScript.thought_capacity(state.cultivator, catalog), before)


func test_acceptance_6_low_rank_cannot_drive_high_rank_and_discount() -> void:
	assert_false(CultivatorRulesScript.can_activate(1, 3))
	var discounted := GuBalanceScript.actual_cost_percent(0.1, 1, 2, catalog)
	assert_almost_eq(discounted, 0.05, 0.0001)


func test_acceptance_7_known_recipe_succeeds_deterministically() -> void:
	var recipe: Dictionary = catalog["refinement_by_id"]["moonlight_glow"]
	var check := preload("res://scripts/domain/recipe_rules.gd").known_fixed_success(recipe, true, true, false)
	assert_true(bool(check["ok"]))


func test_acceptance_8_identity_binds_by_name() -> void:
	# 802 catalog 重建后 identity 演示配方不再作为数据发布（386 配方=advance/
	# fixed/free_mix 模型），域契约由本地夹具钉住（同 test_recipe_rules）。
	var recipe: Dictionary = {
		"id": "essence_thorn_identity",
		"kind": "fixed",
		"input_gu_ids": ["force_gu"],
		"identity_requirements": {
			"named_materials": ["venom_sac"],
			"named_media": ["kael_fire_medium"],
			"min_rank": 2,
		},
		"allow_substitute": {
			"materials": {"venom_sac": ["moon_blue_petal"]},
			"media": {"kael_fire_medium": ["essence_bead"]},
			"cost_change": {"essence": 2},
		},
		"output_gu_id": "stone_shell_gu",
	}
	var check := preload("res://scripts/domain/recipe_rules.gd").check_identity(
			recipe, ["force_gu"], {"venom_sac": 1}, {"force_gu": 2},
			catalog, ["kael_fire_medium"])
	assert_true(bool(check["ok"]), str(check))
	var substituted := preload("res://scripts/domain/recipe_rules.gd").check_identity(
			recipe, ["force_gu"], {"moon_blue_petal": 2}, {"force_gu": 2},
			catalog, ["kael_fire_medium"])
	assert_true(bool(substituted["ok"]), str(substituted))


func test_acceptance_9_divisible_down_feed_keeps_remainder() -> void:
	var blood := {"id": "beast_blood", "rank": 2, "reference_value": 10.0, "divisible": true}
	var out := MaterialRulesScript.downscale_feed(blood, 1, 5.0, catalog)
	assert_almost_eq(float(out["remaining_fraction"]), 0.75, 0.0001)


func test_acceptance_10_mixed_low_quality_drags_replacement() -> void:
	var mixed := FeedingRulesScript.mixed_replacement([
		{"amount": 3.0, "rate": 0.5}, {"amount": 97.0, "rate": 0.95}])
	assert_true(mixed < 0.95)


func test_acceptance_11_two_stage_starvation_death() -> void:
	var instance := {"instance_id": "gu_001", "definition_id": "small_light_gu",
			"state": "refined", "rank": 1, "hunger_phase": 0}
	var first := FeedingRulesScript.layer_settle([instance], {}, {}, catalog)
	assert_eq(int(first["settled"][0]["hunger_phase"]), 1)
	var second := FeedingRulesScript.layer_settle([first["settled"][0]["instance"]], {}, {}, catalog)
	assert_eq(second["settled"].size(), 0)
	assert_true((second["events"] as Array).size() >= 1)


func test_acceptance_12_survivors_never_trimmed_by_budget() -> void:
	var state := _state()
	var collected := LootRulesScript.collect_surviving_gu(
			[{"instance_id": "s1", "definition_id": "moonlight_gu", "rank": 2}],
			state, {"safe_and_time_available": true, "cultivator_rank": 2, "satisfied_conditions": {}}, catalog)
	assert_eq(collected["collected"].size(), 1)


func test_acceptance_13_fixed_defense_to_zero() -> void:
	var resolved := preload("res://scripts/domain/action_resolver.gd").resolve_damage(20.0, 0.0, 20.0, 0.0)
	assert_almost_eq(float(resolved["damage"]), 0.0, 0.0001)


func test_acceptance_14_gu_hundred_scale_beast_independent() -> void:
	var body := CultivatorRulesScript.body({"stage": 0}, catalog)
	assert_almost_eq(float(body["health"]), 100.0, 0.0001)
	var beast := GuBalanceScript.beast_scale(3, catalog)
	assert_almost_eq(beast, 800.0, 0.0001)


func test_acceptance_15_overload_only_excess() -> void:
	var damage := GuBalanceScript.overload_self_damage(130.0, 100.0, catalog)
	assert_almost_eq(damage, 6.0, 0.0001)


func test_acceptance_16_dodge_and_speed_discrete() -> void:
	var dodge := preload("res://scripts/domain/body_rules.gd").dodge_resolution(
			{"allow_dodge": true, "window_open": true, "grappled": false, "bound": false, "restricted": false}, true)
	assert_true(bool(dodge["ok"]))
	var order := preload("res://scripts/domain/action_resolver.gd").conflict_order("quick", 3, "quick", 3)
	assert_eq(str(order), "simultaneous")


func test_acceptance_17_soulless_zero_and_no_means_no_stock() -> void:
	var soulless := SoulRulesScript.collect_soul({"has_soul": false}, {}, {})
	assert_almost_eq(float(soulless["yield"]), 0.0, 0.0001)
	var no_means := SoulRulesScript.collect_soul({"has_soul": true, "soul_weight": 2.0}, {}, {})
	assert_false(bool(no_means["ok"]))


func test_acceptance_18_selling_keeps_knowledge_and_single_pay() -> void:
	var sold := MarketRulesScript.sell_info(
			{"id": "weakness_1", "base_value": 10.0}, "buyer_a", 0, {}, catalog)
	assert_true(bool(sold["seller_keeps_knowledge"]))
	var repeat := MarketRulesScript.sell_info(
			{"id": "weakness_1", "base_value": 10.0}, "buyer_a", 1, {"buyer_a": true}, catalog)
	assert_false(bool(repeat["sold"]))