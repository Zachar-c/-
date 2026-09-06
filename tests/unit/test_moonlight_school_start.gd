extends GutTest


# 验收台账 · 开局光道流派（moonlight 于 C2 2026-09-05 并入 light）：
# 点击开始 → 流派选择 → 光道 → 契约选择 →
# 契约多选（含 starter_stone=1000 与 enemy_hp_floor=1）→ 地图。
#
# 红门禁：
#   - light 流派在 catalog.schools 中存在（月光系蛊并入光道），starter pack
#     顺序/数量正确且全属 light。
#   - start_new_run 后 gu_instances/refined_gu_ids 含完整 starter 蛊实例。
#   - 契约可多选且 starter_stone 把 RunState.stone 抬到 1000。
#   - enemy_hp_floor 对普通敌人压到 1，对 Boss 不压。
#   - Title/Hall/School/Contract/Map 五屏均有出口，不阻塞。


const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")


func before_each() -> void:
	pass


func test_light_school_starter_pack() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var schools: Dictionary = catalog.get("schools", {})
	assert_false(schools.has("moonlight"), "moonlight 已并入 light，不再单列")
	assert_true(schools.has("light"), "light school 存在")
	var light: Dictionary = schools["light"]
	assert_eq(str(light.get("name", "")), "光道", "中文名固定")
	var starters: Array = light.get("starter_gu_ids", [])
	assert_eq(starters, ["small_light_gu", "light_def_1_15_gu", "light_mov_1_16_gu", "light_rec_1_10_gu"],
		"starter pack 顺序/数量符合 802 重建后的 light 校 starter（school v2 派生）")
	# gu.json 注册且全属 light
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	for gid in starters:
		assert_false(gu_by_id.get(gid, {}).is_empty(), "gu %s 已注册" % gid)
		assert_eq(str(gu_by_id[gid].get("school", "")), "light", "gu %s 属 light" % gid)


func test_start_new_run_seeds_light_starter_pack() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var controller := RunControllerScript.new()
	controller.catalog = catalog
	controller.start_new_run(42, "light", [])
	assert_eq(controller.state.school, "light", "school 已设置")
	var expected: Array = ["small_light_gu", "light_def_1_15_gu", "light_mov_1_16_gu", "light_rec_1_10_gu"]
	for gid in expected:
		assert_true(controller.state.refined_gu_ids.has(gid), "refined_gu_ids 包含 %s" % gid)
	# gu_instances 覆盖全部 starter 定义（gu_001 是默认 small_light_gu，可能被覆盖）
	var instances: Dictionary = controller.state.gu_instances
	var count := 0
	for inst in instances.values():
		if str(inst.get("definition_id", "")) in expected:
			count += 1
	assert_true(count >= expected.size(), "gu_instances 含全部 starter 定义")
	controller.free()


func test_enemy_vitality_trial_has_starter_stone_and_hp_floor() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var entry: Dictionary = catalog.get("contract_entry_by_id", {}).get("enemy_vitality_trial", {})
	var rules: Array = entry.get("rules", [])
	var keys: Array = []
	for r in rules:
		keys.append(str((r as Dictionary).get("key", "")))
	assert_true("starter_stone" in keys, "starter_stone 规则存在")
	assert_true("enemy_hp_floor" in keys, "enemy_hp_floor 规则存在")


func test_starter_stone_lifts_run_state_stone_to_1000() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var controller := RunControllerScript.new()
	controller.catalog = catalog
	# 默认元石 12；签 starter_stone=1000 契约后应为 1000
	controller.start_new_run(101, "force", ["enemy_vitality_trial"])
	assert_true(int(controller.state.stone) >= 1000,
		"开局元石受 starter_stone 影响，实际=%d" % int(controller.state.stone))
	assert_true("enemy_vitality_trial" in controller.state.contracts)
	controller.free()


func test_enemy_hp_floor_clamps_non_boss_to_one_and_skips_boss() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var sworn := RunState.new_run(7)
	sworn.contracts = ["enemy_vitality_trial"]
	var common := ContractRulesScript.enemy_hp(8, sworn, catalog, "common")
	assert_eq(int(common), 1, "普通敌人 HP 被压到 1")
	var boss := ContractRulesScript.enemy_hp(10, sworn, catalog, "boss")
	assert_eq(int(boss), 10, "Boss 不被压，HP 保持 10")


func test_opening_school_contract_map_chain_view_flow() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var controller := RunControllerScript.new()
	controller.catalog = catalog
	controller._show_title()
	assert_eq(controller.current_view_name(), "Title", "起点 Title")
	# 进入 school 子视图
	controller._show_hall_subview("schools")
	assert_eq(controller._hall_subview, "schools", "school 子视图")
	# 选 light → contract 子视图
	controller._selected_school = "light"
	controller._show_hall_subview("contracts")
	assert_eq(controller._hall_subview, "contracts", "contract 子视图")
	# 多选契约
	controller._selected_contracts = ["blood_pact", "enemy_vitality_trial"]
	# 模拟开始按钮触发 start_new_run
	controller.start_new_run(controller.roll_seed(), controller._selected_school, Array(controller._selected_contracts))
	assert_eq(controller.current_view_name(), "Map", "进 Map")
	assert_eq(controller.state.school, "light")
	assert_eq(controller.state.contracts.size(), 2, "契约可多选")
	# 出口存在：save_run / leave_map_without_save 不抛错
	var save_res := controller.submit_command({"type": "save_run"})
	assert_true(bool(save_res.get("ok", false)), "save_run OK")
	controller.free()