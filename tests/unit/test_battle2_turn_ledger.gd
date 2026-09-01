extends GutTest


# Spec-v4 phase-2 (T4.1): battle2 turn engine - round phases (§12.4), the
# thought pool (§12.1/§12.2) and the per-turn usage ledger (§12.3).
# Pure domain: no UI, no randomness, no shared mutable state; every function
# takes the ledger as a parameter and returns a new ledger. can_enact is the
# single source for both preflight and execution (§17.3).


const TurnEngineScript = preload("res://scripts/domain/battle2/turn_engine.gd")


func test_phase_sequence_follows_spec_12_4() -> void:
	var phase := TurnEngineScript.PHASE_DECLARE
	var expected := ["declare", "instant", "quick", "standard", "windup", "end"]
	for label in expected:
		assert_eq(phase, label)
		phase = TurnEngineScript.next_phase(phase)
	assert_eq(phase, "end")


func test_thought_pool_resets_each_round_and_maintenance_claims_first() -> void:
	# §12.1: spent thoughts clear at round start and the pool resets to the
	# capacity; §12.4 maintenance claims its cost before anything else.
	var ledger := TurnEngineScript.new_turn(3)
	ledger = TurnEngineScript.consume(ledger, 2)
	assert_eq(int(TurnEngineScript.thoughts_left(ledger)), 1)
	ledger = TurnEngineScript.start_turn(ledger, 3)
	assert_eq(int(TurnEngineScript.thoughts_left(ledger)), 3)
	assert_eq(int(TurnEngineScript.thought_used(ledger)), 0)

	ledger = TurnEngineScript.new_turn(3)
	ledger = TurnEngineScript.add_maintenance(ledger, "gu_001", 1)
	ledger = TurnEngineScript.add_maintenance(ledger, "gu_002", 1)
	ledger = TurnEngineScript.start_turn(ledger, 3)
	assert_eq(int(TurnEngineScript.thoughts_left(ledger)), 1,
			"maintenance claims its thought before the pool is playable")


func test_thought_complexity_tiers_deduct_correctly() -> void:
	# §12.2: gu complexity tiers 1/2/3 are paid up front and never refunded;
	# instant effects do not keep occupying but the spent thought stays spent.
	var ledger := TurnEngineScript.new_turn(7)
	var spent := 0
	for tier in [1, 2, 3]:
		var out := TurnEngineScript.enact(ledger,
				{"kind": "activate_gu", "instance_id": "gu_%03d" % tier, "thought": tier})
		assert_true(bool(out["ok"]), str(out))
		ledger = out["ledger"]
		spent += tier
		assert_eq(int(TurnEngineScript.thought_used(ledger)), spent)
		assert_eq(int(TurnEngineScript.thoughts_left(ledger)), 7 - spent)


func test_same_instance_cannot_activate_twice_same_round() -> void:
	# Acceptance #4: one active activation per instance per round.
	var ledger := TurnEngineScript.new_turn(5)
	var first := TurnEngineScript.can_enact(ledger,
			{"kind": "activate_gu", "instance_id": "gu_001", "thought": 1})
	assert_true(bool(first["ok"]), str(first))
	var after := TurnEngineScript.enact(ledger,
			{"kind": "activate_gu", "instance_id": "gu_001", "thought": 1})
	assert_true(bool(after["ok"]), str(after))
	var second := TurnEngineScript.can_enact(after["ledger"],
			{"kind": "activate_gu", "instance_id": "gu_001", "thought": 1})
	assert_false(bool(second["ok"]))
	assert_eq(str(second["reason"]), "gu_already_used_this_turn")
	# The same rejection is hit on the enact path (same source of truth).
	var second_enact := TurnEngineScript.enact(after["ledger"],
			{"kind": "activate_gu", "instance_id": "gu_001", "thought": 1})
	assert_false(bool(second_enact["ok"]))
	assert_eq(str(second_enact["reason"]), "gu_already_used_this_turn")


func test_same_named_gu_instances_may_each_activate_once() -> void:
	# Acceptance #4: two instances of the same gu are two entities.
	var ledger := TurnEngineScript.new_turn(5)
	for instance_id in ["gu_001", "gu_002"]:
		var out := TurnEngineScript.enact(ledger,
				{"kind": "activate_gu", "instance_id": instance_id, "thought": 1})
		assert_true(bool(out["ok"]), "%s must be allowed" % instance_id)
		ledger = out["ledger"]


func test_maintained_gu_cannot_be_re_activated_this_round() -> void:
	# §12.3: an actively maintained gu counts as operating; no repeat activation.
	var ledger := TurnEngineScript.new_turn(5)
	ledger = TurnEngineScript.add_maintenance(ledger, "gu_007", 1)
	var result := TurnEngineScript.can_enact(ledger,
			{"kind": "activate_gu", "instance_id": "gu_007", "thought": 1})
	assert_false(bool(result["ok"]))
	assert_eq(str(result["reason"]), "maintenance_blocks_activation")


func test_basic_actions_each_usable_once_per_round() -> void:
	# §12.3: move / strike / dodge / grapple each at most once per round.
	var ledger := TurnEngineScript.new_turn(5)
	for action in ["move", "strike", "dodge", "grapple"]:
		var first := TurnEngineScript.enact(ledger,
				{"kind": "basic_action", "action": action, "thought": 1})
		assert_true(bool(first["ok"]), "%s must be usable once" % action)
		ledger = first["ledger"]
		var again := TurnEngineScript.can_enact(ledger,
				{"kind": "basic_action", "action": action, "thought": 1})
		assert_false(bool(again["ok"]), "%s must be single-use per round" % action)
		assert_eq(str(again["reason"]), "action_already_used_this_turn")


func test_parallel_groups_dedupe_actions_and_instances() -> void:
	# §12.3: a parallel group cannot repeat an action kind or an instance.
	var ok_group := [
		{"instance_id": "gu_001", "action": "move"},
		{"instance_id": "gu_002", "action": "strike"},
	]
	assert_true(bool(TurnEngineScript.parallel_group_valid(ok_group)["ok"]))
	var dup_action := [
		{"instance_id": "gu_001", "action": "move"},
		{"instance_id": "gu_002", "action": "move"},
	]
	var action_check := TurnEngineScript.parallel_group_valid(dup_action)
	assert_false(bool(action_check["ok"]))
	assert_eq(str(action_check["reason"]), "parallel_group_repeats_action")
	var dup_instance := [
		{"instance_id": "gu_001", "action": "move"},
		{"instance_id": "gu_001", "action": "strike"},
	]
	assert_false(bool(TurnEngineScript.parallel_group_valid(dup_instance)["ok"]))


func test_cross_round_actions_claim_next_round_usage() -> void:
	# §12.5/§12.3: ongoing actions keep occupying the matching usage slot and
	# must keep receiving their thought or they default to a stop.
	var ledger := TurnEngineScript.new_turn(5)
	ledger = TurnEngineScript.add_ongoing(ledger,
			{"kind": "grapple_hold", "action": "grapple", "instance_id": "gu_001",
			"thought": 1, "turns_left": 1})
	ledger = TurnEngineScript.start_turn(ledger, 5)
	assert_true(bool(TurnEngineScript.action_used(ledger, "grapple")),
			"ongoing grapple occupies the grapple usage slot next round")
	assert_eq(int(TurnEngineScript.thoughts_left(ledger)), 4,
			"continuing the hold pays its 1 thought next round")
	assert_eq(int((ledger["ongoing"] as Array).size()), 1,
			"the hold stays active while its turns remain")


func test_zero_randomness_audit() -> void:
	# Determinism red line (§17.3): the turn engine source must not call any
	# random source; battle settlement is deterministic by spec.
	var source: String = FileAccess.get_file_as_string("res://scripts/domain/battle2/turn_engine.gd")
	for token in ["SeededRoll", "roll(", "rand", "randomize", "Rng"]:
		assert_false(source.contains(token),
				"turn_engine.gd must not reference %s" % token)