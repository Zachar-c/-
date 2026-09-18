extends GutTest


# 炼蛊节点事件最小实现（2026-08-31）：
# moonlight 派限定蛊方 moonlight_glow = moonlight_gu + small_light_gu → moon_glow_gu。
# moonlight 派 starter pack 自带 2 moonlight + 1 small_light，开局即可炼制一次。


const ResolverScript = preload("res://scripts/domain/resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _moonlight_starter_state() -> RunState:
	# 模拟 RunController.start_new_run("moonlight", ...) 之后的实例化状态。
	var state := RunState.new_run(101)
	state.school = "moonlight"
	state.refined_gu_ids = ["small_light_gu", "moonlight_gu", "moonlight_gu", "stone_shell_gu", "vitality_grass_gu"]
	state.gu_ids = state.refined_gu_ids.duplicate()
	# 装入 gu_instances 以满足 _selected_input_instance_ids。
	state.gu_instances = {
		"gu_001": {"instance_id": "gu_001", "definition_id": "small_light_gu", "state": "refined"},
		"gu_002": {"instance_id": "gu_002", "definition_id": "moonlight_gu", "state": "refined"},
		"gu_003": {"instance_id": "gu_003", "definition_id": "moonlight_gu", "state": "refined"},
	}
	state.cave_aperture["stored_gu_instance_ids"] = ["gu_001", "gu_002", "gu_003"]
	state.essence = 4
	state.essence_capacity = 4
	return state


func test_recipe_declared_with_expected_shape() -> void:
	var recipe: Dictionary = catalog.get("refinement_by_id", {}).get("moonlight_glow", {})
	assert_false(recipe.is_empty(), "moonlight_glow 配方存在")
	assert_eq(str(recipe.get("kind", "")), "fixed")
	assert_eq(recipe.get("input_gu_ids", []), ["moonlight_gu", "small_light_gu"])
	assert_eq(str(recipe.get("output_gu_id", "")), "moon_glow_gu")


func test_refine_consumes_inputs_and_produces_moon_glow_gu() -> void:
	var state := _moonlight_starter_state()
	var cmd := {"type": "refine_gu", "recipe_id": "moonlight_glow",
		"input_instance_ids": ["gu_002", "gu_001"]}
	var out := ResolverScript.apply(state, cmd, catalog)
	assert_true(bool(out["result"].get("ok", false)), "炼蛊 OK: %s" % str(out["result"].get("reason", "")))
	assert_true(out["state"].refined_gu_ids.has("moon_glow_gu"), "moon_glow_gu 入 refined_gu_ids")
	assert_eq(out["state"].refined_gu_ids.count("moonlight_gu"), 1, "moonlight_gu 消耗 1 剩 1")
	assert_eq(out["state"].refined_gu_ids.count("small_light_gu"), 0, "small_light_gu 消耗 1 剩 0")
	# 实例被标记 consumed
	var moon_inst: Dictionary = (out["state"] as RunState).gu_instances.get("gu_002", {})
	assert_eq(str(moon_inst.get("state", "")), "consumed", "moonlight_gu 实例被消耗")
	var small_inst: Dictionary = (out["state"] as RunState).gu_instances.get("gu_001", {})
	assert_eq(str(small_inst.get("state", "")), "consumed", "small_light_gu 实例被消耗")
	# 产出蛊实例被新增
	var found := false
	for inst in (out["state"] as RunState).gu_instances.values():
		if str(inst.get("definition_id", "")) == "moon_glow_gu":
			found = true
			break
	assert_true(found, "产出 moon_glow_gu 实例")


func test_refine_rejects_when_small_light_missing() -> void:
	var state := _moonlight_starter_state()
	state.refined_gu_ids = ["moonlight_gu", "moonlight_gu"]  # 没有 small_light_gu
	state.gu_ids = state.refined_gu_ids.duplicate()
	var cmd := {"type": "refine_gu", "recipe_id": "moonlight_glow",
		"input_instance_ids": ["gu_002", "gu_002"]}
	var out := ResolverScript.apply(state, cmd, catalog)
	assert_false(bool(out["result"].get("ok", false)), "缺料应被拒")
	assert_eq(str(out["result"].get("reason", "")), "missing_refinement_input")
	assert_false(out["state"].refined_gu_ids.has("moon_glow_gu"), "未产出")
	assert_eq(out["state"].refined_gu_ids.count("moonlight_gu"), 2, "未消耗 moonlight")