extends "res://addons/gut/test.gd"


# School starter data batch: every dao-mark school declares a starter pack
# (1..4 rank-one gu, from the C2 2026-09-05 214-gu remap) plus their effects.
# (The in-battle effect legs of the starters once ran through the legacy
# engine and died with the V1 convergence, B1 bucket C.)


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")


# C2: the full declared dao-mark set (was the five legacy novelschools).
const SCHOOLS: Array = ContentCatalogScript.SCHOOL_IDS
const ROLES := ["attack", "defense", "movement", "healing", "logistics", "recon"]


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func make_state(run_seed: int = 2026) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func test_each_declared_school_has_starters() -> void:
	var cat: Dictionary = catalog()
	for school_id in SCHOOLS:
		var starters: Array = cat["schools"][school_id].get("starter_gu_ids", [])
		assert_false(starters.is_empty(), "%s must declare a non-empty starter pack" % school_id)
		var seen := {}
		for starter in starters:
			var gu_id := str(starter)
			assert_true(cat["gu_by_id"].has(gu_id), "%s starter missing gu %s" % [school_id, gu_id])
			assert_false(seen.has(gu_id), "%s starter list has duplicates" % school_id)
			seen[gu_id] = true


func test_every_school_has_display_name_and_summary() -> void:
	var cat: Dictionary = catalog()
	assert_eq((cat["schools"] as Dictionary).size(), SCHOOLS.size(), "all declared schools must exist")
	for school_id in SCHOOLS:
		var entry: Dictionary = cat["schools"].get(school_id, {})
		assert_false(entry.is_empty(), "school %s must be declared" % school_id)
		assert_false(str(entry.get("name", "")).is_empty(), "school %s needs a display name" % school_id)
		assert_false(str(entry.get("summary", "")).is_empty(), "school %s needs a summary" % school_id)


## 用户裁定 2026-09-05：光道初始四只 = 月光蛊/小光蛊/石皮蛊/生机草蛊。
## 石皮蛊 (stone_shell_gu) 道痕归属 earth，不改其流派（D1b 合炼矩阵以
## school 字段为锚），仅作为光道初始包的跨道携带蛊出现在此豁免清单。
const CROSS_SCHOOL_STARTERS := {
	"light:stone_shell_gu": true,
}


func test_starters_belong_to_their_school() -> void:
	var cat: Dictionary = catalog()
	for school_id in SCHOOLS:
		for starter in cat["schools"][school_id].get("starter_gu_ids", []):
			var starter_school := str(cat["gu_by_id"][str(starter)]["school"])
			if starter_school == school_id:
				continue
			assert_true(
				CROSS_SCHOOL_STARTERS.has("%s:%s" % [school_id, starter]),
				"%s starter %s (%s) must match its school or be an exempted cross-school starter" % [
					school_id, starter, starter_school,
				]
			)


func test_starter_roles_are_valid() -> void:
	var cat: Dictionary = catalog()
	for school_id in SCHOOLS:
		for starter in cat["schools"][school_id].get("starter_gu_ids", []):
			var role := str(cat["gu_by_id"][str(starter)]["role"])
			assert_true(ROLES.has(role), "%s starter %s has invalid role %s" % [school_id, starter, role])


func test_starter_gu_can_enter_v1_battle() -> void:
	# B2 卡层退役：starter 战斗表达不再依赖卡蓝谱；每个 starter 必须
	# 是战斗蛊（combat 字段非空且非 none，V1 槽位装载的同一判据）。
	var cat: Dictionary = catalog()
	for school_id in SCHOOLS:
		for starter in cat["schools"][school_id].get("starter_gu_ids", []):
			var gu: Dictionary = cat["gu_by_id"][str(starter)]
			var combat := str(gu.get("combat", ""))
			assert_false(combat.is_empty() or combat == "none",
					"%s starter %s must be a V1 combat gu" % [school_id, starter])


func test_school_starter_injection_grants_novice_plus_pack() -> void:
	var cat: Dictionary = catalog()
	var controller = preload("res://scripts/presentation/run_controller.gd").new()
	add_child_autofree(controller)
	controller.start_new_run(2026, "blood")
	# Default run carries the novice small_light_gu plus the blood starter pack.
	var pack: Array = cat["schools"]["blood"].get("starter_gu_ids", [])
	assert_eq(controller.state.refined_gu_ids.size(), pack.size() + 1)
	for starter in pack:
		assert_true(controller.state.refined_gu_ids.has(str(starter)), "blood run must start with %s" % str(starter))


func test_refine_starter_injection_grants_novice_plus_pack() -> void:
	var controller = preload("res://scripts/presentation/run_controller.gd").new()
	add_child_autofree(controller)
	controller.start_new_run(2026, "refine")
	# Default run carries the novice small_light_gu plus the refine starter pack.
	var pack: Array = catalog()["schools"]["refine"]["starter_gu_ids"]
	assert_eq(controller.state.refined_gu_ids.size(), pack.size() + 1)
	for starter in pack:
		assert_true(controller.state.refined_gu_ids.has(str(starter)), "refine run must start with %s" % str(starter))


func test_school_pools_are_isolated_and_school_matched() -> void:
	var cat: Dictionary = catalog()
	var pools: Dictionary = cat.get("school_pools", {})
	var seen_globally := {}
	for school_id in SCHOOLS:
		var pool: Array = pools.get(school_id, [])
		assert_false(pool.is_empty(), "%s must declare a non-empty exclusive pool" % school_id)
		for gu_id_value in pool:
			var gu_id := str(gu_id_value)
			assert_true(cat["gu_by_id"].has(gu_id), "%s pool references missing gu %s" % [school_id, gu_id])
			assert_eq(str(cat["gu_by_id"][gu_id]["school"]), school_id, "%s pool must not contain other-school gu %s" % [school_id, gu_id])
			assert_false(seen_globally.has(gu_id), "gu %s appears in more than one school pool" % gu_id)
			seen_globally[gu_id] = true


func test_school_pool_entries_have_display_names() -> void:
	var cat: Dictionary = catalog()
	var pools: Dictionary = cat.get("school_pools", {})
	var gu_names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gu_names.json"))
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/names.json"))
	var legacy_gu: Dictionary = legacy.get("gu", {})
	for school_id in pools:
		for gu_id_value in pools[school_id]:
			var gu_id := str(gu_id_value)
			var named := gu_names.has(gu_id) or legacy_gu.has(gu_id)
			assert_true(named, "pool gu %s needs a Chinese display name" % gu_id)


func test_wanderer_starter_pack_gu_all_exist_and_inject_on_empty_school() -> void:
	## 散修(空 school)走 run_controller.WANDERER_STARTER_GU_IDS 开局包；
	## 该常量引用的蛊必须在目录（域债回归钉：曾疑为已删蛊死分支，
	## 802 重建后核实全部存活——此处锁定，防未来蛊删再回归）。
	var controller = preload("res://scripts/presentation/run_controller.gd").new()
	add_child_autofree(controller)
	var wanderer: Array = controller.WANDERER_STARTER_GU_IDS
	assert_false(wanderer.is_empty(), "wanderer pack must not be empty")
	var cat: Dictionary = catalog()
	for starter in wanderer:
		assert_true(cat["gu_by_id"].has(str(starter)),
				"wanderer starter gu %s must exist in the catalog" % str(starter))
	# 空 school 开局 = 无流派散修：注入 wanderer 包。
	controller.catalog = cat
	controller.state = make_state(2026)
	controller._inject_school_starters("")
	for starter in wanderer:
		assert_true(controller.state.refined_gu_ids.has(str(starter)),
				"wanderer run must start with %s" % str(starter))
