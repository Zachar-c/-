extends GutTest

## D1b 古方知识模型验收：配对稳定映射、零门槛试炼、首炼授予古方、
## 三层揭示、失败受伤、黑市古方直购。

const CONTENT = preload("res://scripts/domain/content_catalog.gd")
const SYNTHESIS = preload("res://scripts/domain/synthesis_rules.gd")
const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")


func _controller(seed_value: int) -> RunController:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(seed_value, "light", [])
	return controller


func _instance_id_by_definition(controller: RunController, definition_id: String) -> String:
	for instance_id in controller.state.gu_instances:
		if str(controller.state.gu_instances[instance_id].definition_id) == definition_id:
			return str(instance_id)
	return ""


func test_pair_mapping_is_stable_and_seed_independent() -> void:
	var catalog: Dictionary = CONTENT.load_and_validate_all().get("catalog", {})
	var first: String = SYNTHESIS.pair_output_id("moonlight_gu", "small_light_gu", catalog)
	var second: String = SYNTHESIS.pair_output_id("moonlight_gu", "small_light_gu", catalog)
	assert_eq(first, second, "same pair must always map to the same output")
	assert_false(first.is_empty(), "light rank-2 domain must have products")
	var outputs := {}
	for partner in ["small_light_gu", "vitality_grass_gu", "light_rec_1_10_gu", "light_def_1_15_gu", "light_mov_1_16_gu", "light_atk_1_01_gu"]:
		outputs[SYNTHESIS.pair_output_id("moonlight_gu", str(partner), catalog)] = true
	assert_gt(outputs.size(), 1, "different partners must open different outputs in the domain")


func test_mx_recipes_are_replaced_by_the_mapping() -> void:
	var catalog: Dictionary = CONTENT.load_and_validate_all().get("catalog", {})
	for recipe in catalog.get("refinement_recipes", []):
		assert_false(str(recipe.get("id", "")).begins_with("mx_"), "mx_ fixed recipes must be gone")
	var loaded: Dictionary = CONTENT.load_and_validate_all()
	assert_eq((loaded.get("errors", []) as Array).size(), 0, "no content errors after mx_ removal")


func test_free_pair_executes_without_any_recipe_and_grants_gu_fang() -> void:
	var controller := _controller(20260930)
	controller.state.stone = 500
	var main_id := _instance_id_by_definition(controller, "moonlight_gu")
	var partner_id := _instance_id_by_definition(controller, "small_light_gu")
	assert_false(main_id.is_empty() or partner_id.is_empty(), "light starters present")
	var saw_success := false
	var granted_fang := ""
	for attempt in range(12):
		var turned := controller.submit_command({"type": "refine_free_pair",
				"main_instance_id": main_id, "partner_instance_id": partner_id})
		var result: Dictionary = turned.get("result", {})
		if bool(result.get("ok", false)):
			saw_success = true
			granted_fang = str(result.get("output_id", ""))
			break
		else:
			assert_eq(str(result.get("reason", "")), "free_pair_failed",
					"failure must be the free-pair failure branch, not a gate")
			controller.state.stone = 500
	assert_true(saw_success, "zero-gate synthesis must succeed without any recipe (90% per attempt)")
	assert_true(controller.state.global_codex_ids.has(granted_fang),
			"first craft must auto-grant the gu fang")
	assert_eq(controller.state.gu_instances.size(), 3, "two starters consumed, one output granted")


func test_preview_reveal_tiers_follow_gu_fang_ownership() -> void:
	var catalog: Dictionary = CONTENT.load_and_validate_all().get("catalog", {})
	var controller := _controller(20260931)
	var unknown: Dictionary = SYNTHESIS.pair_preview(controller.state, catalog,
			_instance_id_by_definition(controller, "moonlight_gu"),
			_instance_id_by_definition(controller, "small_light_gu"))
	assert_true(bool(unknown.get("ok", false)), "preview ok without any recipe")
	assert_false(bool(unknown.get("output_known", false)), "unknown before owning the gu fang")
	var output_id := str(unknown.get("output_id", ""))
	assert_false(output_id.is_empty(), "mapping still resolves the output id internally")
	controller.state.global_codex_ids.append(output_id)
	var known: Dictionary = SYNTHESIS.pair_preview(controller.state, catalog,
			_instance_id_by_definition(controller, "moonlight_gu"),
			_instance_id_by_definition(controller, "small_light_gu"))
	assert_true(bool(known.get("output_known", false)), "owning the gu fang reveals the product")


func test_failure_injures_the_main_gu() -> void:
	var controller := _controller(20260932)
	controller.state.stone = 5000
	# 确定性触发失败分支：成功率置 0（roll_chance(0) 恒 false），专测受伤语义。
	controller.catalog["balance"]["free_pair"]["success_pct"]["2"] = 0
	var main_id := _instance_id_by_definition(controller, "moonlight_gu")
	var partner_id := _instance_id_by_definition(controller, "small_light_gu")
	var stones_before := int(controller.state.stone)
	var turned := controller.submit_command({"type": "refine_free_pair",
			"main_instance_id": main_id, "partner_instance_id": partner_id})
	var result: Dictionary = turned.get("result", {})
	assert_eq(str(result.get("reason", "")), "free_pair_failed", "zero success rate must fail")
	var inst: Dictionary = controller.state.gu_instances.get(main_id, {})
	assert_eq(str(inst.get("state", "")), "weakened", "failed main gu must be injured")
	assert_true(controller.state.gu_instances.has(partner_id), "partner survives a failure")
	assert_eq(int(controller.state.stone), stones_before - int(result.get("stone_cost", 0)),
			"stones are consumed even on failure")


func test_dead_gu_cannot_enter_the_furnace() -> void:
	var catalog: Dictionary = CONTENT.load_and_validate_all().get("catalog", {})
	var controller := _controller(20260934)
	controller.state.stone = 500
	var main_id := _instance_id_by_definition(controller, "moonlight_gu")
	var partner_id := _instance_id_by_definition(controller, "small_light_gu")
	assert_false(main_id.is_empty() or partner_id.is_empty(), "light starters present")
	controller.state.gu_instances[main_id]["state"] = "dead"
	var dead: Dictionary = SYNTHESIS.pair_preview(controller.state, catalog, main_id, partner_id)
	assert_false(bool(dead.get("ok", false)), "dead main gu must be refused")
	assert_string_contains(str(dead.get("reason", "")), "已死")
	var turned := controller.submit_command({"type": "refine_free_pair",
			"main_instance_id": main_id, "partner_instance_id": partner_id})
	assert_eq(str(turned.get("result", {}).get("reason", "")), "pair_invalid",
			"dead pair must not execute")


func test_shop_gu_fang_unlock_grants_knowledge() -> void:
	var controller := _controller(20260933)
	controller.state.stone = 1000
	var offer_id := ""
	var catalog: Dictionary = controller.catalog
	for offer_id_value in catalog.get("shop_offer_by_id", {}):
		if str(catalog["shop_offer_by_id"][offer_id_value].get("kind", "")) == "gu_fang_unlock":
			offer_id = str(offer_id_value)
			break
	assert_false(offer_id.is_empty(), "at least one gu fang offer must be stocked")
	var gu_id := str(catalog["shop_offer_by_id"][offer_id].get("gu_id", ""))
	var bought := controller.submit_command({"type": "shop_purchase", "offer_id": offer_id})
	assert_true(bool(bought.get("result", {}).get("ok", false)), "gu fang purchase must succeed")
	assert_true(controller.state.global_codex_ids.has(gu_id), "purchased gu fang enters the codex")
	var again := controller.submit_command({"type": "shop_purchase", "offer_id": offer_id})
	assert_eq(str(again.get("result", {}).get("reason", "")), "gu_fang_already_unlocked",
			"second purchase must be refused")
