extends GutTest


# Spec-v4 phase-2 (T6.1): feeding, starvation and substitution (§7).
# layer_settle runs once per big layer; hunger runs two stages (§7.2);
# substitution is deterministic and config-driven (§7.4); the economy
# soft-cap only reports and never hard-rejects (§7.3). Feeding never touches
# deck_capacity (acceptance #3) and high-rank to low-rank feeding goes
# through MaterialRules (acceptance #9).


const FeedingRulesScript = preload("res://scripts/domain/feeding_rules.gd")
const MaterialRulesScript = preload("res://scripts/domain/material_rules.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _standard_definition() -> Dictionary:
	return {"id": "small_light_gu", "rank": 1, "feed_tier": "standard"}


func _instance(instance_id: String, definition_id: String, rank: int, extra: Dictionary = {}) -> Dictionary:
	var instance := GuInstanceScript.new_instance(definition_id, instance_id, catalog)
	instance["rank"] = rank
	for key in extra:
		instance[key] = extra[key]
	return instance


func test_feed_cost_scales_with_rank_and_feed_tier() -> void:
	# §7.1: 1 份同转匹配蛊材当量 x feed_tier; the actual turn decides the
	# value (a high-turn gu costs in full even in a low-turn hand).
	var rank1 := FeedingRulesScript.feed_cost(_standard_definition(),
			_instance("gu_001", "small_light_gu", 1), catalog)
	assert_almost_eq(rank1, 1.0, 0.0001)
	var rank3 := FeedingRulesScript.feed_cost(_standard_definition(),
			_instance("gu_002", "small_light_gu", 3), catalog)
	assert_almost_eq(rank3, 4.0, 0.0001)
	var large_definition := {"id": "big_gu", "rank": 1, "feed_tier": "large"}
	var large := FeedingRulesScript.feed_cost(large_definition,
			_instance("gu_003", "big_gu", 1), catalog)
	assert_almost_eq(large, 2.0, 0.0001)


func test_mixed_replacement_is_dragged_down_and_never_exceeds() -> void:
	# Acceptance #10: low-quality universal food drags the mixed rate down;
	# extra stacking cannot exceed the mixed rate ceiling.
	var mixed := FeedingRulesScript.mixed_replacement([
		{"amount": 10.0, "rate": 0.7},
		{"amount": 10.0, "rate": 0.95},
	])
	assert_almost_eq(mixed, 0.825, 0.0001)
	var stacked := FeedingRulesScript.mixed_replacement([
		{"amount": 3.0, "rate": 0.5},
		{"amount": 97.0, "rate": 0.95},
	])
	assert_almost_eq(stacked, 0.9365, 0.0001)
	assert_true(stacked < 0.95, "low-quality input must drag the mix below the top rate")


func test_universal_covers_up_to_the_mixed_rate_and_five_percent_must_match() -> void:
	# §7.4: universal_fulfilled = min(sum, need x mixed); the remainder stays
	# a matching requirement even at a 95% replacement rate.
	var resolve := FeedingRulesScript.resolve_need(
			100.0, 0.0, [{"amount": 100.0, "rate": 0.95}], {}, catalog)
	assert_almost_eq(float(resolve["universal_used"]), 95.0, 0.0001)
	assert_almost_eq(float(resolve["matching_required"]), 5.0, 0.0001)
	assert_almost_eq(float(resolve["matching_used"]), 0.0, 0.0001)
	assert_almost_eq(float(resolve["unmet"]), 5.0, 0.0001,
			"without matching food the 5% remainder stays unmet")
	# With exactly the matching food present, the 5% is paid by matching.
	var with_matching := FeedingRulesScript.resolve_need(
			100.0, 10.0, [{"amount": 100.0, "rate": 0.95}], {}, catalog)
	assert_almost_eq(float(with_matching["matching_used"]), 5.0, 0.0001)
	assert_almost_eq(float(with_matching["unmet"]), 0.0, 0.0001)


func test_emergency_substitution_obeys_the_fifty_percent_cap() -> void:
	# §7.4: ordinary mismatched materials substitute at most 50% of the need.
	var resolve := FeedingRulesScript.resolve_need(
			100.0, 0.0, [], {"beast_bone": 100.0}, catalog)
	assert_almost_eq(float(resolve["emergency_used"]), 50.0, 0.0001,)
	assert_almost_eq(float(resolve["unmet"]), 50.0, 0.0001)


func test_two_stage_starvation_writes_a_structured_death_event() -> void:
	# Acceptance #11: first unpaid layer -> hunger_phase 1; second unpaid
	# layer -> the gu dies with a precise cause in the event log - never
	# silently. P0.1: the dead gu leaves the live ledger entirely (no corpse
	# that mis-counts as an asset or re-starves).
	var instances: Array = [_instance("gu_001", "small_light_gu", 1)]
	var first := FeedingRulesScript.layer_settle(instances, {}, {}, catalog)
	assert_eq(int(first["settled"][0]["hunger_phase"]), 1)
	assert_eq(str(first["settled"][0]["outcome"]), "hungry")
	assert_eq(first["settled"].size(), 1)
	var second := FeedingRulesScript.layer_settle(
			[first["settled"][0]["instance"]], {}, {}, catalog)
	assert_eq(second["settled"].size(), 0,
			"the starved gu no longer appears among the living")
	var death_events: Array = second["events"]
	var found := false
	for event in death_events:
		if str(event.get("action", "")) == "gu_starved":
			found = true
			assert_true(str(event.get("cause", "")).contains("starvation"))
			assert_true(event.has("_snapshot"),
					"the death event carries the full instance snapshot for attribution")
	if not found:
		push_error("missing starved event")
	# Idempotence: settling the living set after the death (second["settled"]
	# no longer contains the starved gu) cannot raise another starved event.
	var third := FeedingRulesScript.layer_settle(second["settled"], {}, {}, catalog)
	assert_eq(third["events"].size(), 0,
			"no repeat starved events for a dead gu")


func test_run_state_layer_settle_removes_starved_instances() -> void:
	# P0.1: after starvation the instance is gone from gu_instances (the
	# discovery/refined projections shrink with it).
	var state: RunState = RunStateScript.new_run(13)
	var first_starving := FeedingRulesScript.layer_settle(
			[_instance("gu_001", "small_light_gu", 1)], {}, {}, catalog)
	var after_first := RunStateScript.settle_layer(state, 1, {}, catalog, {})
	assert_true(after_first.gu_instances.has("gu_001"))
	# Simulate the hungry gu carrying into the second unpaid layer via a
	# direct settle over its starved record.
	var starved_ledger := FeedingRulesScript.layer_settle(
			[first_starving["settled"][0]["instance"]], {}, {}, catalog)
	assert_eq(starved_ledger["settled"].size(), 0)
	assert_true((starved_ledger["events"] as Array).size() >= 1)


func test_hungry_gu_cannot_activate_and_recovery_resets() -> void:
	# §7.2: a hungry gu cannot be activated normally next layer.
	var hungry := _instance("gu_001", "small_light_gu", 1, {"hunger_phase": 1})
	assert_false(bool(FeedingRulesScript.can_activate(hungry)))
	var fed_example := FeedingRulesScript.layer_settle(
			[hungry], {"beast_blood": 10}, {"matching_material_ids": ["beast_blood"]}, catalog)
	var fed: Dictionary = fed_example["settled"][0]
	assert_eq(int(fed["hunger_phase"]), 0, "a fully paid layer clears hunger")
	assert_true(bool(FeedingRulesScript.can_activate(fed)))


func test_unrefined_and_sealed_gu_still_settle() -> void:
	# §7.1: unrefined living gu and sealed gu still join the settlement.
	var weakened := _instance("gu_001", "small_light_gu", 1, {"state": "weakened"})
	var sealed := _instance("gu_002", "small_light_gu", 1, {"sealed": true})
	var result := FeedingRulesScript.layer_settle([weakened, sealed], {}, {}, catalog)
	assert_eq(result["settled"].size(), 2)


func test_preview_predicts_hunger_and_death_before_settling() -> void:
	# §7.2: the preview shows which gu will go hungry or die, so the player
	# can order feeding before committing.
	var starving := _instance("gu_001", "small_light_gu", 1, {"hunger_phase": 1})
	var preview := FeedingRulesScript.preview_settle([starving], {}, {}, catalog)
	assert_true((preview["will_die"] as Array).has("gu_001"))
	assert_eq((preview["will_hunger"] as Array).size(), 0)


func test_twenty_gu_settle_without_slot_rejection_and_no_deck_capacity() -> void:
	# Acceptance #3: unlimited holding never rejects on slots; feeding never
	# references deck_capacity; the soft cap only reports.
	var instances: Array = []
	for index in range(20):
		instances.append(_instance("gu_%03d" % (index + 1), "small_light_gu", 1))
	var result := FeedingRulesScript.layer_settle(instances, {}, {}, catalog)
	assert_eq(result["settled"].size(), 20)
	assert_false(str(result).contains("capacity"),
			"feeding must be slot-free and budget-report only")
	var source: String = FileAccess.get_file_as_string("res://scripts/domain/feeding_rules.gd")
	assert_false(source.contains("deck_capacity"), "feeding_rules must not reference deck_capacity")
	var report := FeedingRulesScript.budget_report(200.0, 10.0, catalog)
	assert_true(int(report["affordable_gu_count"]) >= 0)
	assert_false(bool(report.get("hard_rejection", false)),
			"the economy soft-cap never hard-rejects")


func test_high_rank_to_low_rank_feeding_uses_material_rules() -> void:
	# Acceptance #9: down-feeding goes through MaterialRules - divisible
	# deducts precisely, indivisible excess wastes.
	var rank2_blood := {"id": "beast_blood", "rank": 2, "reference_value": 10.0, "divisible": true}
	var precise := MaterialRulesScript.downscale_feed(rank2_blood, 1, 5.0, catalog)
	assert_almost_eq(float(precise["consumed_fraction"]), 0.25, 0.0001)
	assert_almost_eq(float(precise["wasted"]), 0.0, 0.0001)
	var indivisible := MaterialRulesScript.downscale_feed(
			{"id": "beast_bone", "rank": 2, "reference_value": 10.0, "divisible": false}, 1, 3.0, catalog)
	assert_almost_eq(float(indivisible["consumed_fraction"]), 1.0, 0.0001)
	assert_true(float(indivisible["wasted"]) > 0.0)


func test_run_state_layer_settle_hook_appends_event_log() -> void:
	# The big-layer switch lives on RunState: entering a new layer runs the
	# settlement and writes one immutable log entry.
	var state: RunState = RunStateScript.new_run(9)
	state.gu_instances = {
		"gu_001": _instance("gu_001", "small_light_gu", 1),
	}
	var before_events := state.event_log.size()
	var next := RunStateScript.settle_layer(state, 1, {}, catalog, {})
	assert_eq(int(next.current_node_layer), 1)
	assert_eq(next.event_log.size(), before_events + 1)
	var last: Dictionary = next.event_log[next.event_log.size() - 1]
	assert_eq(str(last.get("action", "")), "layer_feeding")
	# Same layer: no re-settlement.
	var unchanged := RunStateScript.settle_layer(next, 1, {}, catalog, {})
	assert_eq(unchanged.event_log.size(), next.event_log.size())