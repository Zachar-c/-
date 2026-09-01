extends GutTest


## 蛊方图鉴门禁（2026-08-30 用户裁定）：
## - fixed/combine 配方必须持有蛊方（跨局图鉴）才可炼制，advance/free_mix 不设门禁；
## - default_unlocked 配方初始持有（moon_ray_forged 一转月光+一转小光→二转月芒）；
## - 第一次获得（Boss 搜刮 / 调试授方）后随 MetaProgress 永久保留；
## - 配方按 recipe id 粒度持有：同名异转、同转多方互不串权。


const MetaProgressScript = preload("res://scripts/domain/meta_progress.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const DebugActionsScript = preload("res://scripts/domain/debug_actions.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")

const BLOOD_QI_GU_ID := "gen_blood_attack_009_gu"
const BLOOD_MOON_GU_ID := "gen_blood_attack_002_gu"
const MOON_RAY_GU_ID := "moon_ray_gu"


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_and_validate_all()["catalog"]


func test_default_recipe_moon_ray_forged_needs_no_codex() -> void:
	var run := _run_with_instances([
		{"definition_id": "moonlight_gu", "rank": 1},
		{"definition_id": "small_light_gu", "rank": 1},
	])

	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "moon_ray_forged"}, catalog)

	assert_true(result["result"]["ok"])
	assert_true(result["state"].global_codex_ids.is_empty())


func test_blood_moon_forged_rejected_without_recipe_ownership() -> void:
	var run := _run_with_instances([
		{"definition_id": MOON_RAY_GU_ID, "rank": 2},
		{"definition_id": BLOOD_QI_GU_ID, "rank": 2},
	])

	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "blood_moon_forged"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "refinement_recipe_locked")
	# 门禁拒绝不得消耗输入与材料。
	var live_ids: Array = result["state"].cave_aperture["stored_gu_instance_ids"]
	assert_eq(live_ids.size(), 2)


func test_granted_recipe_enables_synthesis_with_per_recipe_granularity() -> void:
	var run := _run_with_instances([
		{"definition_id": MOON_RAY_GU_ID, "rank": 2},
		{"definition_id": BLOOD_QI_GU_ID, "rank": 2},
		{"definition_id": "moon_glow_gu", "rank": 2},
		{"definition_id": "shadow_veil_gu", "rank": 2},
	])

	var granted := DebugActionsScript.apply(run, catalog, {"op": "grant_recipe", "recipe_id": "blood_moon_forged"}, true)
	assert_true(granted["ok"])
	assert_true(granted["state"].global_codex_ids.has("blood_moon_forged"))

	var refined: RunState = granted["state"]
	var result := ResolverScript.apply(refined, {"type": "refine_gu", "recipe_id": "blood_moon_forged"}, catalog)
	assert_true(result["result"]["ok"])

	# 同族锁定配方不因持有别的蛊方而串权：幻月配方仍需其自身的蛊方。
	var legacy := ResolverScript.apply(result["state"], {"type": "refine_gu", "recipe_id": "phantom_moon_locked"}, catalog)
	assert_false(legacy["result"]["ok"])
	assert_eq(legacy["result"]["reason"], "refinement_recipe_locked")


func test_scavenge_grants_all_boss_recipes_once() -> void:
	var run := _run_with_instances([])
	run.node_flags["boss_defeated"] = "true"

	var result := ResolverScript.apply(run, {"type": "scavenge"}, catalog)
	var scavenged: RunState = result["state"]

	assert_true(result["result"]["ok"])
	assert_true(scavenged.global_codex_ids.has("phantom_moon_locked"))
	assert_true(scavenged.global_codex_ids.has("blood_moon_forged"))
	assert_eq(scavenged.event_log.back()["reason"], "scavenge_recipe_unlocked")

	var repeat := ResolverScript.apply(scavenged, {"type": "scavenge"}, catalog)
	assert_false(repeat["result"]["ok"])
	assert_eq(repeat["result"]["reason"], "scavenge_already_done")


func test_recipe_codex_persists_across_runs() -> void:
	var first := _run_with_instances([
		{"definition_id": MOON_RAY_GU_ID, "rank": 2},
		{"definition_id": BLOOD_QI_GU_ID, "rank": 2},
	])
	first.node_flags["boss_defeated"] = "true"
	first = ResolverScript.apply(first, {"type": "scavenge"}, catalog)["state"]
	first = ResolverScript.apply(first, {"type": "refine_gu", "recipe_id": "blood_moon_forged"}, catalog)["state"]

	var meta = MetaProgressScript.new_empty()
	meta = meta.record_run_end(first, "death", catalog)
	assert_true(meta.recipe_codex_ids.has("blood_moon_forged"))

	var second := _run_with_instances([
		{"definition_id": MOON_RAY_GU_ID, "rank": 2},
		{"definition_id": BLOOD_QI_GU_ID, "rank": 2},
	])
	var reseeded := RunState.new_run(202, meta)
	reseeded.gu_instances = second.gu_instances
	reseeded.cave_aperture = second.cave_aperture
	reseeded.refined_gu_ids = second.refined_gu_ids
	reseeded.gu_ids = second.gu_ids
	reseeded.equipped_gu_ids = second.equipped_gu_ids

	var result := ResolverScript.apply(reseeded, {"type": "refine_gu", "recipe_id": "blood_moon_forged"}, catalog)
	assert_true(result["result"]["ok"])


func test_preview_blocks_recipes_without_codex_and_marks_default_ready() -> void:
	var run := _run_with_instances([
		{"definition_id": MOON_RAY_GU_ID, "rank": 2},
		{"definition_id": BLOOD_QI_GU_ID, "rank": 2},
		{"definition_id": "moonlight_gu", "rank": 1},
		{"definition_id": "small_light_gu", "rank": 1},
	])
	var node := {"id": "refinement_den", "type": "refinement", "choices": []}

	var cards := ActionPreviewServiceScript.preview_actions(run, node, catalog)
	var gated := _card(cards, "refine.blood_moon_forged")
	assert_false(bool(gated["executable"]))
	assert_string_contains(str(gated["block_reason"]), "蛊方")
	assert_true(bool(_card(cards, "refine.moon_ray_forged")["executable"]))


func test_refine_snapshot_unlock_flags_follow_codex() -> void:
	var run := _run_with_instances([
		{"definition_id": MOON_RAY_GU_ID, "rank": 2},
		{"definition_id": BLOOD_QI_GU_ID, "rank": 2},
	])
	var stub := {
		"state": run,
		"catalog": catalog,
		"current_node": {"id": "refinement_den", "type": "refinement", "choices": []},
		"meta": null,
	}

	var rows: Array = RunSnapshotBuilderScript.refine(stub)["recipes"]
	assert_false(bool(_row(rows, "blood_moon_forged")["unlocked"]))
	assert_true(bool(_row(rows, "moon_ray_forged")["unlocked"]))
	var gated_row: Dictionary = _row(rows, "blood_moon_forged")
	assert_string_contains(str(gated_row["rank_note"]), "三转")

	var granted := DebugActionsScript.apply(run, catalog, {"op": "grant_recipe", "recipe_id": "blood_moon_forged"}, true)
	var stub2 := {
		"state": granted["state"],
		"catalog": catalog,
		"current_node": {"id": "refinement_den", "type": "refinement", "choices": []},
		"meta": null,
	}
	assert_true(bool(_row(RunSnapshotBuilderScript.refine(stub2)["recipes"], "blood_moon_forged")["unlocked"]))


func test_hall_codex_lists_default_recipe_as_owned() -> void:
	var meta = MetaProgressScript.new_empty()
	var codex: Dictionary = RunSnapshotBuilderScript._codex(catalog, meta)
	var recipes: Array = codex["recipes"]
	assert_true(bool(_row(recipes, "moon_ray_forged")["unlocked"]))
	assert_false(bool(_row(recipes, "blood_moon_forged")["unlocked"]))


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


func _card(cards: Array[Dictionary], id: String) -> Dictionary:
	for card in cards:
		if str(card.get("id", "")) == id:
			return card
	push_error("Missing action card: %s" % id)
	return {}


func _row(rows: Array, id: String) -> Dictionary:
	for row in rows:
		if str(row.get("id", "")) == id:
			return row
	push_error("Missing row: %s" % id)
	return {}
