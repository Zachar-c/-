extends GutTest


## 月芒蛊合成链（2026-08-30 用户裁定）：
## 一转月光蛊 + 一转小光蛊 -> 二转月芒蛊；
## 二转月芒蛊 + 二转血气蛊 -> 三转血月蛊。
## 血气蛊二转走同名 advance 配方。

const BLOOD_QI_GU_ID := "gen_blood_attack_009_gu"
const BLOOD_MOON_GU_ID := "gen_blood_attack_002_gu"
const MOON_RAY_GU_ID := "moon_ray_gu"


var catalog: Dictionary


func before_each() -> void:
	var validated := ContentCatalog.load_and_validate_all()
	assert_eq(validated["errors"], [], "catalog data must validate")
	catalog = validated["catalog"]


func test_moonlight_plus_small_light_forges_rank_two_moon_ray() -> void:
	var run := _run_with_instances([
		{"definition_id": "moonlight_gu", "rank": 1},
		{"definition_id": "small_light_gu", "rank": 1},
	])

	var result := Resolver.apply(run, {"type": "refine_gu", "recipe_id": "moon_ray_forged"}, catalog)
	var refined: RunState = result["state"]

	assert_true(result["result"]["ok"])
	var live_ids: Array = refined.cave_aperture["stored_gu_instance_ids"]
	assert_eq(live_ids.size(), 1)
	var output: Dictionary = refined.gu_instances[str(live_ids[0])]
	assert_eq(str(output["definition_id"]), MOON_RAY_GU_ID)
	assert_eq(int(output["rank"]), 2)
	assert_eq(refined.event_log.back()["reason"], "refinement_succeeded")


func test_moon_ray_forged_rejects_wrong_input_set() -> void:
	var run := _run_with_instances([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "small_light_gu", "rank": 1},
	])

	var result := Resolver.apply(run, {"type": "refine_gu", "recipe_id": "moon_ray_forged"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "missing_refinement_input")


func test_blood_moon_forged_rejects_rank_one_inputs() -> void:
	var run := _run_with_instances([
		{"definition_id": MOON_RAY_GU_ID, "rank": 1},
		{"definition_id": BLOOD_QI_GU_ID, "rank": 1},
	])
	# 蛊方图鉴门禁（2026-08-30）：先授血月蛊方，再验证转数门禁本身。
	run.global_codex_ids = ["blood_moon_forged"]

	var result := Resolver.apply(run, {"type": "refine_gu", "recipe_id": "blood_moon_forged"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "refinement_input_rank_insufficient")


func test_blood_qi_gu_advances_to_rank_two() -> void:
	var run := _run_with_instances([
		{"definition_id": BLOOD_QI_GU_ID, "rank": 1},
	])
	run.materials["beast_bone"] = 1

	var result := Resolver.apply(run, {
		"type": "refine_gu",
		"recipe_id": "advance_gen_blood_attack_009_gu",
	}, catalog)
	var refined: RunState = result["state"]

	assert_true(result["result"]["ok"])
	var live_ids: Array = refined.cave_aperture["stored_gu_instance_ids"]
	assert_eq(live_ids.size(), 1)
	var output: Dictionary = refined.gu_instances[str(live_ids[0])]
	assert_eq(str(output["definition_id"]), BLOOD_QI_GU_ID)
	assert_eq(int(output["rank"]), 2)


func test_blood_moon_forged_combines_rank_two_inputs_into_rank_three_blood_moon() -> void:
	var run := _run_with_instances([
		{"definition_id": MOON_RAY_GU_ID, "rank": 2},
		{"definition_id": BLOOD_QI_GU_ID, "rank": 2},
	])
	run.global_codex_ids = ["blood_moon_forged"]

	var result := Resolver.apply(run, {"type": "refine_gu", "recipe_id": "blood_moon_forged"}, catalog)
	var refined: RunState = result["state"]

	assert_true(result["result"]["ok"])
	var live_ids: Array = refined.cave_aperture["stored_gu_instance_ids"]
	assert_eq(live_ids.size(), 1)
	var output: Dictionary = refined.gu_instances[str(live_ids[0])]
	assert_eq(str(output["definition_id"]), BLOOD_MOON_GU_ID)
	assert_eq(int(output["rank"]), 3)
	assert_eq(refined.event_log.back()["reason"], "refinement_succeeded")


func _run_with_instances(entries: Array) -> RunState:
	var run := RunState.new_run(101)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var instance_id := "gu_%03d" % (index + 1)
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": str(entry["definition_id"]),
			"state": "refined",
			"rank": int(entry.get("rank", 1)),
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()
	return run
