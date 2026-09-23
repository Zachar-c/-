extends GutTest


# Spec-v4 phase-2 (T9.2): the fifteen v2 commands each have at least one
# rejection path, and every rejection returns the untouched state (preflight
# = execution same-source, 17.3): before/after RunState snapshots must be
# field-identical.


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _state() -> RunState:
	var state: RunState = RunStateScript.new_run(43)
	return state


func _run(type_name: String, fields: Dictionary) -> Dictionary:
	var command := {"type": type_name}
	for key in fields:
		command[key] = fields[key]
	return ResolverScript.apply(_state(), command, catalog)


func _run_on(state, type_name: String, fields: Dictionary) -> Dictionary:
	var command := {"type": type_name}
	for key in fields:
		command[key] = fields[key]
	return ResolverScript.apply(state, command, catalog)


func test_confirm_core_rejects_before_midpoint_unchanged() -> void:
	var before := _state()
	var out := _run_on(before, "confirm_core", {"instance_id": "gu_001"})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "too_early_first_layer")
	assert_eq(out["state"], before, "rejection must not mutate state")


func test_replace_core_rejects_on_missing_instances_unchanged() -> void:
	var before := _state()
	var out := _run_on(before, "replace_core", {
		"old_instance_id": "gu_999", "new_instance_id": "gu_998", "cost": {"certificate": 1}})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "instance_missing")
	assert_eq(out["state"], before)


func test_replace_core_hard_cap_rejection() -> void:
	var state := _state()
	state.node_flags["core_replace_count"] = 1
	var out := ResolverScript.apply(state, {
		"type": "replace_core", "old_instance_id": "gu_001", "new_instance_id": "gu_002",
		"cost": {"certificate": 1}}, catalog)
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "replace_limit_reached")
	assert_eq(out["state"], state)


func test_feed_instance_rejects_missing_instance_unchanged() -> void:
	var before := _state()
	var out := _run_on(before, "feed_instance", {"instance_id": "gu_404"})
	assert_eq(str(out["result"]["reason"]), "instance_missing")
	assert_eq(out["state"], before)


func test_release_gu_rejects_missing_instance() -> void:
	var before := _state()
	var out := _run_on(before, "release_gu", {"instance_id": "gu_501"})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "instance_missing")
	assert_eq(out["state"], before)


func test_sell_info_rejects_a_buyer_who_already_paid() -> void:
	var before := _state()
	# L0 2026-09-22：sold_to/spread 以 RunState.info_sales 为准，禁止命令自带。
	before.info_sales = {"secret_001": {"sold_to": {"buyer_a": true}, "spread_count": 1}}
	var out := _run_on(before, "sell_info", {
		"info": {"id": "secret_001", "base_value": 5.0},
		"buyer_id": "buyer_a"})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "buyer_already_paid")
	assert_eq(out["state"], before)


## L0 2026-09-22：成交入元石并记 info_sales；卖方保留 known_facts。
func test_sell_info_credits_stone_and_records_ledger() -> void:
	var state := _state()
	var before_stone := int(state.stone)
	var out := _run_on(state, "sell_info", {
		"info": {"id": "secret_ledger", "base_value": 10.0},
		"buyer_id": "buyer_a"})
	assert_true(bool(out["result"]["ok"]), str(out["result"]))
	assert_eq(int(out["result"]["price"]), 10, "spread=0 时按 base_value 成交")
	assert_eq(int(out["state"].stone), before_stone + 10)
	assert_true(bool(out["state"].info_sales["secret_ledger"]["sold_to"]["buyer_a"]))
	assert_eq(int(out["state"].info_sales["secret_ledger"]["spread_count"]), 1)
	assert_true(out["state"].known_facts.has("secret_ledger"), "卖方保留知识")


## L0 2026-09-22：二次转售衰减；同一买家不重付。
func test_sell_info_decays_spread_and_blocks_repeat_buyer() -> void:
	var state := _state()
	var first := _run_on(state, "sell_info", {
		"info": {"id": "secret_decay", "base_value": 10.0}, "buyer_id": "buyer_a"})
	assert_true(bool(first["result"]["ok"]))
	var second := _run_on(first["state"], "sell_info", {
		"info": {"id": "secret_decay", "base_value": 10.0}, "buyer_id": "buyer_b"})
	assert_true(bool(second["result"]["ok"]))
	assert_eq(int(second["result"]["price"]), 5, "spread=1 时对半衰减")
	var repeat := _run_on(second["state"], "sell_info", {
		"info": {"id": "secret_decay", "base_value": 10.0}, "buyer_id": "buyer_a"})
	assert_false(bool(repeat["result"]["ok"]))
	assert_eq(str(repeat["result"]["reason"]), "buyer_already_paid")


## L0 2026-09-22：需求收购报价入账，advance_demand 扣量/关单。
func test_fulfill_demand_pays_quote_and_closes_when_empty() -> void:
	var state := _state()
	state.materials["beast_bone"] = 3
	state.npc_demands = {
		"d1": {"npc_id": "wandering_peddler", "material_id": "beast_bone", "quantity": 2, "tier": 1},
	}
	var out := _run_on(state, "fulfill_demand", {"demand_id": "d1", "amount": 2})
	assert_true(bool(out["result"]["ok"]), str(out["result"]))
	assert_true(int(out["result"]["price"]) > 0, "按 demand_quote 入账")
	assert_eq(int(out["state"].materials["beast_bone"]), 1)
	assert_true(bool(out["state"].npc_demands["d1"]["closed"]), "履约完毕必须关单防刷")


func test_enact_rejects_repeat_activation() -> void:
	# T10.1-6: the ledger lives in the domain state now - no client-passed
	# ledger anymore.
	var before := _state()
	before.battle2_ledger = {
		"phase": "declare", "thoughts_left": 5, "thought_used": 0, "reserved": 0,
		"gu_used": {"gu_001": true},
		"actions_used": {"move": false, "strike": false, "dodge": false, "grapple": false},
		"maintained": [], "ongoing": []}
	var out := _run_on(before, "enact",
		{"proposal": {"kind": "activate_gu", "instance_id": "gu_001", "thought": 1}})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "gu_already_used_this_turn")
	assert_eq(out["state"], before)


func test_enact_rejects_when_battle2_not_started_unchanged() -> void:
	var before := _state()
	var out := _run_on(before, "enact",
		{"proposal": {"kind": "basic_action", "action": "strike", "thought": 1}})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "battle2_not_started")
	assert_eq(out["state"], before, "an empty ledger must not fabricate a fresh turn")


func test_dodge_rejects_without_thought() -> void:
	var out := _run("dodge", {"conditions": {"allow_dodge": true, "window_open": true,
			"grappled": false, "bound": false, "restricted": false}, "has_thought": false})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "no_thought")


func test_grapple_rejects_outside_contact() -> void:
	var out := _run("grapple", {"attacker_distance": "close", "target_distance": "touch",
			"has_thought": true, "attacker_strength": 10.0, "target_strength": 8.0, "target_resists": false})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "not_at_contact")


func test_respond_rejects_without_reserved_thought() -> void:
	var out := _run("respond", {"has_reserved_thought": false, "action": "grapple"})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "no_reserved_thought")


func test_bloodlet_rejects_insufficient_health() -> void:
	var state := _state()
	state.health = 5
	var out := ResolverScript.apply(state, {"type": "bloodlet", "target_rank": 1, "amount": 51.0}, catalog)
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "insufficient_health")
	assert_eq(out["state"], state)


func test_bloodlet_rejects_rank_above_cultivator() -> void:
	var out := _run("bloodlet", {"target_rank": 9, "amount": 5.0})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "bleed_rank_exceeds_cultivator")


func test_absorb_soul_rejects_without_declared_means() -> void:
	var before := _state()
	var out := _run_on(before, "absorb_soul", {"target": {"has_soul": true, "soul_weight": 2.0}, "means": {}})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "no_means_declared")
	assert_eq(out["state"], before)


func test_bloodlet_lethal_marker_is_never_swallowed() -> void:
	# The lethal confirmation travels on the result; the command does not
	# silently execute a lethal bleed.
	var state := _state()
	state.health = 30
	var out := ResolverScript.apply(state, {"type": "bloodlet", "target_rank": 1, "amount": 30.0}, catalog)
	assert_true(bool(out["result"]["ok"]))
	assert_true(bool(out["result"].get("lethal_confirm_required", false)))
	assert_eq(str(out["result"].get("cause", "")), "self_bleed")
	assert_eq(out["state"], state, "a lethal bleed waits for the second confirmation")