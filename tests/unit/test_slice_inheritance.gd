extends GutTest

## S3 遗葬门控传承切片验收：站点校验、三选项门槛、品质随机产出、防重复继承。

const CONTENT = preload("res://scripts/domain/content_catalog.gd")
const GU_INSTANCE = preload("res://scripts/domain/gu_instance.gd")
const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")


func _controller(seed_value: int) -> RunController:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(seed_value, "light", [])
	controller.state.current_node_id = "yizang_ridge"
	controller.state.current_node_template_id = "yizang_ridge"
	return controller


func test_inheritance_site_validates_and_exposes() -> void:
	var loaded: Dictionary = CONTENT.load_and_validate_all()
	assert_eq((loaded.get("errors", []) as Array).size(), 0,
			"inheritance_sites.json must not introduce content errors")
	var catalog: Dictionary = loaded.get("catalog", {})
	var site: Dictionary = catalog.get("inheritance_site_by_id", {}).get("yizang_ridge", {})
	assert_eq(int(site.get("level", 0)), 1, "slice site is a rank-1 burial")
	assert_false(site.is_empty(), "yizang_ridge site declared")


func test_both_claims_gated_without_prerequisites() -> void:
	var controller := _controller(20260911)
	# 清空携带蛊（光道开局的小光蛊 slot_role=scout 本身就满足侦察门槛），
	# 使「无侦察蛊」前提成立；断言两个门槛各自拒斥。
	controller.state.gu_instances = {}
	controller.state.cave_aperture["stored_gu_instance_ids"] = []
	var recon := controller.submit_command({"type": "choose_action", "action_id": "claim_recon"})
	assert_false(bool(recon.get("result", {}).get("ok", false)), "recon claim gated without scout gu")
	assert_eq(str(recon.get("result", {}).get("reason", "")), "inheritance_scout_required")
	var token := controller.submit_command({"type": "choose_action", "action_id": "claim_token"})
	assert_false(bool(token.get("result", {}).get("ok", false)), "token claim gated without token")
	assert_eq(str(token.get("result", {}).get("reason", "")), "inheritance_token_required")


func test_token_claim_grants_quality_loot_and_flags() -> void:
	var controller := _controller(20260912)
	controller.state.materials["inheritance_token"] = 1
	var claimed := controller.submit_command({"type": "choose_action", "action_id": "claim_token"})
	var result: Dictionary = claimed.get("result", {})
	assert_true(bool(result.get("ok", false)), "token claim must succeed with token held")
	var quality := str(result.get("quality", ""))
	assert_true(quality in ["broken", "common", "rare"], "quality must be one of the three tiers")
	var bounds := {"broken": [1, 2], "common": [3, 4], "rare": [5, 8]}
	var granted: Array = result.get("granted_gu", [])
	assert_true(granted.size() >= int(bounds[quality][0]) and granted.size() <= int(bounds[quality][1]),
			"granted gu count %d must match %s bounds" % [granted.size(), quality])
	var recipe_bounds := {"broken": [0, 0], "common": [1, 2], "rare": [3, 4]}
	var recipes: Array = result.get("granted_recipes", [])
	assert_true(recipes.size() >= int(recipe_bounds[quality][0]) and recipes.size() <= int(recipe_bounds[quality][1]),
			"granted recipe count must match %s bounds" % quality)
	for recipe_id in recipes:
		assert_true(controller.state.global_codex_ids.has(str(recipe_id)),
				"granted recipe %s must be unlocked in-run" % str(recipe_id))
	var blocked := controller.submit_command({"type": "choose_action", "action_id": "claim_token"})
	assert_eq(str(blocked.get("result", {}).get("reason", "")), "site_already_claimed",
			"second claim on the same site must be refused")


func test_scout_claim_path_and_seed_determinism() -> void:
	var scout_controller := _controller(20260913)
	var inst_id := "gu_9001"
	scout_controller.state.gu_instances[inst_id] = GU_INSTANCE.new_instance(
			"light_rec_1_10_gu", inst_id, scout_controller.catalog)
	scout_controller.state.cave_aperture["stored_gu_instance_ids"].append(inst_id)
	var recon := scout_controller.submit_command({"type": "choose_action", "action_id": "claim_recon"})
	assert_true(bool(recon.get("result", {}).get("ok", false)), "rank-1 scout gu opens the recon claim")
	var first_quality := str(recon.get("result", {}).get("quality", ""))
	var first_gu: Array = recon.get("result", {}).get("granted_gu", [])
	var replay := _controller(20260913)
	replay.state.materials["inheritance_token"] = 1
	var replayed := replay.submit_command({"type": "choose_action", "action_id": "claim_token"})
	assert_eq(str(replayed.get("result", {}).get("quality", "")), first_quality,
			"same seed must roll the same quality")
	assert_eq(replayed.get("result", {}).get("granted_gu", []).size(), first_gu.size(),
			"same seed must grant the same gu count")
