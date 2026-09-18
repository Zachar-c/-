extends GutTest


# BUG-001 regression: the rest snapshot exposed by RunSnapshotBuilder.rest()
# must surface every choice the domain resolver can consume on a generic rest
# node (heal, upgrade_card, remove_card, remove_imprint, remove_curse) plus an
# explicit "skip" affordance. Players must never be in a state where every
# rest option is disabled yet leave_node is still gated by rest_choice_required.
#
# These tests fail on the pre-fix snapshot (only heal/remove/wash exposed)
# and pass once the snapshot exposes the full set with correct disabling.

const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _snapshot_for(node_id: String, state: RunState) -> Dictionary:
	var stub := _StubController.new()
	stub.state = state
	stub.current_node = {"id": node_id, "type": "rest"}
	stub.catalog = catalog
	return RunSnapshotBuilderScript.rest(stub)


func _choice(snapshot: Dictionary, choice_id: String) -> Dictionary:
	for choice in snapshot.get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			return choice
	return {}


func test_rest_snapshot_exposes_all_six_choice_ids() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	var snapshot := _snapshot_for("rest_shrine", state)
	var ids: Array[String] = []
	for choice in snapshot.get("choices", []):
		ids.append(str(choice.get("id", "")))
	for required_id in ["heal", "upgrade_card", "remove_card", "remove_imprint", "remove_curse", "skip"]:
		assert_true(ids.has(required_id),
				"rest snapshot must expose %s; got %s" % [required_id, str(ids)])


func test_rest_snapshot_skip_choice_is_disabled_only_when_visit_consumed() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	var snapshot := _snapshot_for("rest_shrine", state)
	var skip := _choice(snapshot, "skip")
	assert_false(bool(skip.get("disabled", true)),
			"skip must be enabled before the visit is consumed; got %s" % str(skip))
	assert_ne(str(skip.get("reason", "")), "",
			"skip must carry a confirmation prompt in reason")


func test_rest_snapshot_skip_choice_disabled_after_visit_consumed() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	state.node_flags["rest_shrine_used"] = "used"
	var snapshot := _snapshot_for("rest_shrine", state)
	var skip := _choice(snapshot, "skip")
	assert_true(bool(skip.get("disabled", false)),
			"skip must be disabled after the visit is consumed")


func test_rest_snapshot_disables_remove_curse_when_no_curse_present() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	state.refined_gu_ids = ["light_probe"]
	var snapshot := _snapshot_for("rest_shrine", state)
	var remove_curse := _choice(snapshot, "remove_curse")
	assert_true(bool(remove_curse.get("disabled", false)),
			"remove_curse must be disabled when no curse layers exist")
	assert_ne(str(remove_curse.get("reason", "")), "",
			"remove_curse disabled reason must explain why")


func test_rest_snapshot_disables_remove_imprint_when_no_relics() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	var snapshot := _snapshot_for("rest_shrine", state)
	var remove_imprint := _choice(snapshot, "remove_imprint")
	assert_true(bool(remove_imprint.get("disabled", false)),
			"remove_imprint must be disabled when no relics held")


func test_rest_snapshot_disables_upgrade_when_no_refined_gu() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	state.refined_gu_ids = []
	var snapshot := _snapshot_for("rest_shrine", state)
	var upgrade := _choice(snapshot, "upgrade_card")
	assert_true(bool(upgrade.get("disabled", false)),
			"upgrade_card must be disabled when refined_gu_ids is empty")
	assert_ne(str(upgrade.get("reason", "")), "",
			"upgrade_card disabled reason must explain why")


func test_rest_snapshot_targets_lists_reflect_state() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	state.refined_gu_ids = ["light_probe"]
	state.relic_ids = ["poison_fang"]
	# Attach a non-meta_rule grade so remove_imprint keeps it as a candidate.
	catalog["relic_by_id"] = catalog.get("relic_by_id", {})
	catalog["relic_by_id"]["poison_fang"] = {"grade": "tactical"}
	var snapshot := _snapshot_for("rest_shrine", state)
	assert_true(snapshot.has("upgrade_targets"), "snapshot must carry upgrade_targets")
	assert_true(snapshot.has("imprint_targets"), "snapshot must carry imprint_targets")
	assert_true(snapshot.has("curse_targets"), "snapshot must carry curse_targets")
	assert_true(snapshot.has("remove_card_targets"), "snapshot must carry remove_card_targets")
	assert_gt(snapshot["upgrade_targets"].size(), 0,
			"upgrade_targets must include refined_gu_ids when present")
	assert_gt(snapshot["imprint_targets"].size(), 0,
			"imprint_targets must include non-meta_rule relics when present")


# ---- domain resolver side: rest mode=skip must consume the visit and emit
# rest_skipped so the leave gate stays aligned. ----

func test_rest_skip_consumes_visit_and_emits_rest_skipped_event() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "rest_shrine"
	var base_size := run.event_log.size()

	var result := ResolverScript.apply(run, {"type": "rest", "mode": "skip"}, catalog)
	assert_true(bool(result["result"]["ok"]), str(result["result"]))
	assert_eq(str(result["state"].node_flags.get("rest_shrine_used", "")), "used",
			"skip must mark the scoped visit flag")
	# Bare-id marker contract: consumed visit also refreshes the visited flag.
	assert_eq(str(result["state"].node_flags.get("rest_shrine", "")), "used")

	var saw_skipped := false
	for entry in result["state"].event_log.slice(base_size):
		if str(entry.get("reason", "")) == "rest_skipped":
			saw_skipped = true
			break
	assert_true(saw_skipped,
			"skip must append a rest_skipped event for audit/ending attribution")


func test_rest_skip_unlocks_travel_after_consumption() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "rest_shrine"

	var gated := ResolverScript.apply(run, {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	assert_eq(str(gated["result"]["reason"]), "rest_choice_required")

	var skipped := ResolverScript.apply(run, {"type": "rest", "mode": "skip"}, catalog)
	assert_true(bool(skipped["result"]["ok"]))

	var travel := ResolverScript.apply(skipped["state"], {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	assert_true(bool(travel["result"]["ok"]),
			"travel must unlock after skip consumed the visit")


func test_rest_skip_after_consumed_visit_is_rejected() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "rest_shrine"
	run.node_flags["rest_shrine_used"] = "used"
	var result := ResolverScript.apply(run, {"type": "rest", "mode": "skip"}, catalog)
	assert_false(bool(result["result"]["ok"]))
	assert_eq(str(result["result"]["reason"]), "rest_already_used")


func test_rest_skip_outside_rest_node_is_rejected() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "ridge_caravan"
	var result := ResolverScript.apply(run, {"type": "rest", "mode": "skip"}, catalog)
	assert_false(bool(result["result"]["ok"]))
	assert_eq(str(result["result"]["reason"]), "not_rest_node")


# ---- encounter session mirror ----

func test_session_leave_after_rest_skip_unlocks() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "rest_shrine"
	var skipped := ResolverScript.apply(run, {"type": "rest", "mode": "skip"}, catalog)
	var session := {"node_id": "rest_shrine", "completed": false}
	var left := preload("res://scripts/domain/encounter_session_resolver.gd").apply(
		skipped["state"], session, {"type": "leave_node"}, catalog,
		{"id": "rest_shrine", "template_id": "rest_shrine", "type": "rest"})
	assert_true(bool(left["result"].get("ok", false)),
			"leave must succeed after skip; got %s" % str(left["result"]))


# ---- regression seeds from the playtest report ----

func test_regression_seed_list_no_leave_softlock() -> void:
	# BUG-001 reproducible seeds per the playtest report. Each seed drives a
	# drive_to_ending-style flow; once the player reaches a rest node with no
	# rest_choice_available, snapshot must still expose skip so the page is
	# navigable instead of leaving the player stuck.
	#
	# The integration harness lives in tests/integration/test_drive_to_ending.gd;
	# here we pin the contract: every seed's rest snapshot must expose skip.
	var regression_seeds := [2, 6, 8, 10, 13, 15, 16, 18, 33, 34, 41, 49]
	for seed_value in regression_seeds:
		var state := RunState.new_run(seed_value)
		state.current_node_id = "rest_shrine"
		state.refined_gu_ids = []
		state.relic_ids = []
		var snapshot := _snapshot_for("rest_shrine", state)
		var skip := _choice(snapshot, "skip")
		assert_false(bool(skip.get("disabled", true)),
				"seed %d: skip must remain enabled when every other rest option is disabled" % seed_value)
		assert_ne(str(skip.get("reason", "")), "",
				"seed %d: skip must carry confirmation text" % seed_value)


class _StubController:
	extends RefCounted
	var state: RunState
	var current_node: Dictionary
	var catalog: Dictionary
	var current_session: Dictionary = {}
	var current_battle: Dictionary = {}