extends GutTest


# Stage 1 缺口 2：炼化（attune_gu）领域契约。
# 依据 docs/superpowers/reports/2026-09-17-lianhua-corpus-research.md：
#   - 代价只扣真元，按转数分档 cost = 4 + 2 × (rank - 1)
#   - 只接受 state=wild 的实例，成功后变为 refined 并纳入喂养投影
#   - 门禁先于扣费：真元不足不改状态、不扣真元
#   - 首只炼化事件 reason = first_gu_attuned（仅记录，不给槽位加成）


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const RefineSnapshotScript = preload("res://scripts/presentation/snapshots/refine_snapshot.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _wild_instance(state: RunState, instance_id: String, definition_id: String) -> void:
	state.gu_instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"state": "wild",
	}
	state.cave_aperture["stored_gu_instance_ids"].append(instance_id)


func _cost_for(definition_id: String) -> int:
	var rank := clampi(int((catalog["gu_by_id"] as Dictionary)[definition_id].get("rank", 1)), 1, 5)
	return 4 + 2 * (rank - 1)


func test_attune_requires_exactly_one_target() -> void:
	var run := RunState.new_run(101)
	_wild_instance(run, "gu_901", "moonlight_gu")
	var empty := ResolverScript.apply(run, {"type": "attune_gu", "input_instance_ids": []}, catalog)
	assert_false(bool(empty["result"].get("ok", false)))
	assert_eq(str(empty["result"].get("reason", "")), "attune_target_missing")


func test_attune_rejects_non_wild_target() -> void:
	var run := RunState.new_run(101)
	# starter gu_001 is refined by default
	var out := ResolverScript.apply(run, {"type": "attune_gu", "input_instance_ids": ["gu_001"]}, catalog)
	assert_false(bool(out["result"].get("ok", false)))
	assert_eq(str(out["result"].get("reason", "")), "attune_target_not_wild")


func test_attune_success_pays_essence_and_marks_refined() -> void:
	var run := RunState.new_run(101)
	_wild_instance(run, "gu_901", "moonlight_gu")
	var cost := _cost_for("moonlight_gu")
	var before_essence := run.essence
	var out := ResolverScript.apply(run, {"type": "attune_gu", "input_instance_ids": ["gu_901"]}, catalog)
	assert_true(bool(out["result"].get("ok", false)), "attune should succeed")
	var next: RunState = out["state"]
	assert_eq(str(next.gu_instances["gu_901"]["state"]), "refined")
	assert_eq(next.essence, before_essence - cost)
	assert_true(next.refined_instances().any(func(inst): return str(inst.get("instance_id", "")) == "gu_901"),
			"attuned gu must join refined_instances feeding projection")
	assert_eq(next.event_log.back()["action"], "attune_gu")
	assert_eq(next.event_log.back()["reason"], "first_gu_attuned")
	# source state must stay immutable
	assert_eq(str(run.gu_instances["gu_901"]["state"]), "wild")
	assert_eq(run.essence, before_essence)


func test_attune_cost_scales_with_rank() -> void:
	var run := RunState.new_run(101)
	_wild_instance(run, "gu_902", "moon_ray_gu")
	var cost := _cost_for("moon_ray_gu")
	assert_eq(cost, 6, "rank 2 cost formula 4+2*(2-1)")
	var before_essence := run.essence
	var out := ResolverScript.apply(run, {"type": "attune_gu", "input_instance_ids": ["gu_902"]}, catalog)
	assert_true(bool(out["result"].get("ok", false)))
	assert_eq(int(out["state"].essence), before_essence - cost)


func test_attune_insufficient_essence_blocks_without_side_effects() -> void:
	var run := RunState.new_run(101)
	_wild_instance(run, "gu_901", "moonlight_gu")
	run.essence = 1
	var out := ResolverScript.apply(run, {"type": "attune_gu", "input_instance_ids": ["gu_901"]}, catalog)
	assert_false(bool(out["result"].get("ok", false)))
	assert_eq(str(out["result"].get("reason", "")), "insufficient_essence")
	assert_eq(str(out["state"].gu_instances["gu_901"]["state"]), "wild")
	assert_eq(out["state"].essence, 1)


func test_second_attune_is_not_first_gu() -> void:
	var run := RunState.new_run(101)
	_wild_instance(run, "gu_901", "moonlight_gu")
	_wild_instance(run, "gu_902", "small_light_gu")
	var first := ResolverScript.apply(run, {"type": "attune_gu", "input_instance_ids": ["gu_901"]}, catalog)
	assert_eq(str(first["state"].event_log.back()["reason"]), "first_gu_attuned")
	var second := ResolverScript.apply(first["state"], {"type": "attune_gu", "input_instance_ids": ["gu_902"]}, catalog)
	assert_true(bool(second["result"].get("ok", false)))
	assert_eq(str(second["state"].event_log.back()["reason"]), "gu_attuned")
	assert_eq(str(second["state"].gu_instances["gu_902"]["state"]), "refined")


func test_rejection_copy_is_available_in_presentation() -> void:
	var rejection_text_text := FileAccess.get_file_as_string("res://scripts/presentation/rejection_text.gd")
	for key in ["insufficient_essence", "attune_target_missing", "attune_target_not_wild"]:
		assert_true(rejection_text_text.contains("\"%s\"" % key), "rejection_text must cover %s" % key)


func test_refine_snapshot_exposes_attune_channel_and_candidates() -> void:
	# Command builder must emit attune_gu (contract ghost-guard is separate).
	var builder_text := FileAccess.get_file_as_string("res://scripts/presentation/run_command_builder.gd")
	assert_true(builder_text.contains("\"type\": \"attune_gu\""), "command builder must emit attune_gu")
	# Snapshot channel tab exists; candidates list is present even when empty.
	var controller := RunController.new()
	controller.state = RunState.new_run(101)
	controller.catalog = catalog
	var snap: Dictionary = RefineSnapshotScript.build(controller)
	var channels: Array = snap.get("channels", [])
	var has_attune := false
	for channel_value in channels:
		if str((channel_value as Dictionary).get("id", "")) == "attune":
			has_attune = true
			break
	assert_true(has_attune, "Refine channels must include attune")
	assert_true(snap.has("attune_candidates"), "Refine snapshot must always carry attune_candidates")
	var candidates: Array = snap.get("attune_candidates", [])
	assert_true(candidates.is_empty() or candidates[0] is Dictionary)


func test_refine_snapshot_lists_wild_candidates_with_visible_cost() -> void:
	var controller := RunController.new()
	controller.state = RunState.new_run(101)
	controller.catalog = catalog
	_wild_instance(controller.state, "gu_901", "moonlight_gu")
	var snap: Dictionary = RefineSnapshotScript.build(controller)
	var candidates: Array = snap.get("attune_candidates", [])
	assert_eq(candidates.size(), 1)
	var row: Dictionary = candidates[0]
	assert_eq(str(row.get("id", "")), "gu_901")
	assert_eq(int(row.get("essence_cost", 0)), _cost_for("moonlight_gu"))
	assert_true(bool(row.get("executable", false)), "default run has enough essence for rank-1 attune")
	assert_eq(int(row.get("essence_owned", 0)), controller.state.essence)


func test_start_new_run_injects_two_wild_small_light() -> void:
	# Stage 1 §2 开局：流派 starter 之外另带 2 只未炼化小光蛊，attune 通道一开局就有货。
	var controller := RunController.new()
	add_child_autofree(controller)
	controller.catalog = catalog
	controller.start_new_run(101, "light")
	var wild_ids: Array[String] = []
	for key_value in controller.state.gu_instances:
		var inst: Dictionary = controller.state.gu_instances[key_value]
		if str(inst.get("state", "")) == "wild" and str(inst.get("definition_id", "")) == "small_light_gu":
			wild_ids.append(str(key_value))
	assert_eq(wild_ids.size(), 2, "opening must carry two wild small_light_gu")
	# 野生不进已炼化投影 / 装备栏，也不进喂养账。
	var refined_instance_ids: Array[String] = []
	for inst in controller.state.refined_instances():
		refined_instance_ids.append(str(inst.get("instance_id", "")))
	for wild_id in wild_ids:
		assert_false(refined_instance_ids.has(wild_id), "wild %s must not enter refined_instances" % wild_id)
		# 野生不进喂养投影；equipped_gu_ids 按 definition_id 记，与流派 starter 重名不在此断言。
	var snap: Dictionary = RefineSnapshotScript.build(controller)
	var candidates: Array = snap.get("attune_candidates", [])
	assert_eq(candidates.size(), 2, "attune panel must list the two opening wild gu")


func test_opening_wild_gu_can_be_attuned_through_resolver() -> void:
	var controller := RunController.new()
	add_child_autofree(controller)
	controller.catalog = catalog
	controller.start_new_run(101, "")
	var wild_id := ""
	for key_value in controller.state.gu_instances:
		if str((controller.state.gu_instances[key_value] as Dictionary).get("state", "")) == "wild":
			wild_id = str(key_value)
			break
	assert_false(wild_id.is_empty(), "wanderer start must also carry wild gu")
	var out := ResolverScript.apply(controller.state, {
		"type": "attune_gu", "input_instance_ids": [wild_id],
	}, catalog)
	assert_true(bool(out["result"].get("ok", false)), "opening wild gu must be attunable")
	assert_eq(str(out["state"].gu_instances[wild_id]["state"]), "refined")

