extends GutTest
## E3a：rest 快照 mode_groups 三族（休整/修炼/炼蛊）+ 修炼/炼蛊并入 rest 会话。
## 规格：docs/superpowers/specs/2026-09-09-event-classification-design.md §4。
## - 快照契约：mode_groups 三键齐全，未开放动作族 disabled + 原因直白。
## - 领域契约：修炼（meditate/cultivate_rank_two）与炼蛊（refine_gu）在休息类
##   节点成功执行即消费本次探访（rest_choice_required 门禁放行支点）。

const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _snapshot_for(node_id: String, node_type: String, state: RunState) -> Dictionary:
	var stub := _StubController.new()
	stub.state = state
	stub.current_node = {"id": node_id, "type": node_type}
	stub.catalog = catalog
	return RunSnapshotBuilderScript.rest(stub)


func _group(snapshot: Dictionary, key: String) -> Array:
	return snapshot.get("mode_groups", {}).get(key, [])


func _card(cards: Array, card_id: String) -> Dictionary:
	for c in cards:
		if c is Dictionary and str(c.get("id", "")) == card_id:
			return c
	return {}


# ---- 快照侧：三族齐全 + 执行性镜像领域状态 ----

func test_mode_groups_expose_three_families() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	var snapshot := _snapshot_for("rest_shrine", "rest", state)
	var groups: Dictionary = snapshot.get("mode_groups", {})
	for key in ["休整", "修炼", "炼蛊"]:
		assert_true(groups.has(key), "mode_groups must expose %s; got %s" % [key, str(groups.keys())])
		assert_gt((groups.get(key, []) as Array).size(), 0, "%s group must not be empty" % key)
	var rest_ids: Array[String] = []
	for c in _group(snapshot, "休整"):
		rest_ids.append(str(c.get("id", "")))
	for required in ["heal", "upgrade_card", "remove_card", "remove_imprint", "remove_curse", "skip"]:
		assert_true(rest_ids.has(required), "休整 group must expose %s" % required)
	assert_false(_card(_group(snapshot, "修炼"), "meditate").is_empty(), "修炼 group must expose meditate")
	assert_false(_card(_group(snapshot, "修炼"), "cultivate").is_empty(), "修炼 group must expose cultivate")
	assert_false(_card(_group(snapshot, "炼蛊"), "refine").is_empty(), "炼蛊 group must expose refine")
	assert_false(_card(_group(snapshot, "炼蛊"), "free_pair").is_empty(), "炼蛊 group must expose free_pair")


func test_meditate_card_mirrors_essence_cap() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	state.essence = 10
	var meditate := _card(_group(_snapshot_for("rest_shrine", "rest", state), "修炼"), "meditate")
	assert_false(bool(meditate.get("disabled", true)),
			"meditate must be enabled below the essence cap")
	state.essence = int(state.cave_aperture.get("essence_max", 4))
	meditate = _card(_group(_snapshot_for("rest_shrine", "rest", state), "修炼"), "meditate")
	assert_true(bool(meditate.get("disabled", false)),
			"meditate must be disabled at the essence cap")
	assert_ne(str(meditate.get("reason", "")), "", "disabled meditate must explain why")


func test_cultivate_card_mirrors_rank_and_stone() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	state.cultivation = 1
	state.stone = 12
	var cultivate := _card(_group(_snapshot_for("rest_shrine", "rest", state), "修炼"), "cultivate")
	assert_false(bool(cultivate.get("disabled", true)),
			"cultivate must be enabled at rank 1 with enough stone")
	state.stone = 1
	cultivate = _card(_group(_snapshot_for("rest_shrine", "rest", state), "修炼"), "cultivate")
	assert_true(bool(cultivate.get("disabled", false)), "cultivate must be disabled without stone")
	assert_ne(str(cultivate.get("reason", "")), "", "disabled cultivate must explain why")
	state.stone = 12
	state.cultivation = 2
	cultivate = _card(_group(_snapshot_for("rest_shrine", "rest", state), "修炼"), "cultivate")
	# 一转一突破（2026-09-15）：二转不再是终点——有余量就继续冲三转。
	assert_false(bool(cultivate.get("disabled", true)), "二转后仍可继续突破三转")
	assert_eq(str(cultivate.get("label", "")), "冲击三转", "档位随当前转数自增")
	state.stone = 11
	cultivate = _card(_group(_snapshot_for("rest_shrine", "rest", state), "修炼"), "cultivate")
	assert_true(bool(cultivate.get("disabled", false)), "三转成本 12，11 枚不足")
	assert_ne(str(cultivate.get("reason", "")), "", "元石不足必须说明原因")
	state.stone = 999
	state.cultivation = 5
	cultivate = _card(_group(_snapshot_for("rest_shrine", "rest", state), "修炼"), "cultivate")
	assert_true(bool(cultivate.get("disabled", false)), "五转为境内上限，无更高境界")


func test_refine_cards_mirror_aperture_state() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "rest_shrine"
	state.cave_aperture["stored_gu_instance_ids"] = []
	state.gu_instances = {}
	state.refined_gu_ids = []
	state.materials = {}
	var group := _group(_snapshot_for("rest_shrine", "rest", state), "炼蛊")
	var refine := _card(group, "refine")
	assert_true(bool(refine.get("disabled", false)), "refine must be disabled with no gu/materials")
	assert_ne(str(refine.get("reason", "")), "", "disabled refine must explain 无蛊可炼")
	var free_pair := _card(group, "free_pair")
	assert_true(bool(free_pair.get("disabled", false)),
			"free_pair must be disabled with fewer than two live gu")
	assert_ne(str(free_pair.get("reason", "")), "", "disabled free_pair must explain why")
	# 两只活蛊：炼蛊与自由配对均开放。
	state.gu_instances = {
		"gu_001": {"definition_id": "small_light_gu", "state": "refined"},
		"gu_002": {"definition_id": "light_probe", "state": "refined"},
	}
	state.cave_aperture["stored_gu_instance_ids"] = ["gu_001", "gu_002"]
	group = _group(_snapshot_for("rest_shrine", "rest", state), "炼蛊")
	refine = _card(group, "refine")
	free_pair = _card(group, "free_pair")
	assert_false(bool(refine.get("disabled", true)), "refine must be enabled with live gu")
	assert_false(bool(free_pair.get("disabled", true)), "free_pair must be enabled with two live gu")


# ---- 领域侧：修炼/炼蛊族在休息类节点成功执行即消费探访 ----

func test_meditate_at_rest_node_consumes_visit_and_unlocks_leave() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "rest_shrine"
	run.essence = 10
	var result := ResolverScript.apply(run, {"type": "choose_action", "action_id": "meditate"}, catalog)
	assert_true(bool(result["result"]["ok"]), str(result["result"]))
	assert_eq(str(result["state"].node_flags.get("rest_shrine_used", "")), "used",
			"meditate at a rest node must consume the visit")
	var travel := ResolverScript.apply(result["state"], {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	assert_true(bool(travel["result"]["ok"]), "leave must unlock after meditate consumed the visit")


func test_meditate_outside_rest_class_writes_no_rest_flags() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "ridge_caravan"
	run.essence = 10
	var result := ResolverScript.apply(run, {"type": "choose_action", "action_id": "meditate"}, catalog)
	assert_true(bool(result["result"]["ok"]), str(result["result"]))
	assert_false(result["state"].node_flags.has("ridge_caravan_used"),
			"meditate outside the rest class must not consume any visit")


func test_cultivate_now_allowed_at_rest_nodes_and_consumes_visit() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "rest_shrine"
	run.cultivation = 1
	run.stone = 12
	var result := ResolverScript.apply(run, {"type": "cultivate_rank_two"}, catalog)
	assert_true(bool(result["result"]["ok"]), str(result["result"]))
	assert_eq(int(result["state"].cultivation), 2)
	assert_eq(str(result["state"].node_flags.get("rest_shrine_used", "")), "used",
			"cultivate at a rest node must consume the visit")


func test_cultivate_outside_rest_class_still_rejected() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "ridge_caravan"
	var result := ResolverScript.apply(run, {"type": "cultivate_rank_two"}, catalog)
	assert_false(bool(result["result"]["ok"]))
	assert_eq(str(result["result"]["reason"]), "not_cultivation_window")


func test_free_mix_at_rest_node_consumes_visit() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "rest_shrine"
	run.cave_aperture["stored_gu_instance_ids"] = ["gu_001", "gu_002"]
	run.gu_instances["gu_002"] = {"definition_id": "light_probe", "state": "refined", "rank": 1}
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "free_mix"}, catalog)
	assert_true(bool(result["result"]["ok"]), str(result["result"]))
	assert_eq(str(result["state"].node_flags.get("rest_shrine_used", "")), "used",
			"refine at a rest node must consume the visit")


class _StubController:
	extends RefCounted
	var state: RunState
	var current_node: Dictionary
	var catalog: Dictionary
	var current_session: Dictionary = {}
	var current_battle: Dictionary = {}
