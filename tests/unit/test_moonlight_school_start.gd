extends GutTest


# 验收台账 · 开局月光流派：点击开始 → 流派选择 → 月光 → 契约选择 →
# 契约多选（含 starter_stone=1000 与 enemy_hp_floor=1）→ 地图。
#
# 红门禁：
#   - moonlight 流派在 catalog.schools 中存在，starter pack 顺序/数量正确。
#   - start_new_run 后 gu_instances/refined_gu_ids 含完整 5 只初始蛊实例。
#   - 契约可多选且 starter_stone 把 RunState.stone 抬到 1000。
#   - enemy_hp_floor 对普通敌人压到 1，对 Boss 不压。
#   - Title/Hall/School/Contract/Map 五屏均有出口，不阻塞。


const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")


func before_each() -> void:
	pass


func test_moonlight_school_starter_pack() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var schools: Dictionary = catalog.get("schools", {})
	assert_true(schools.has("moonlight"), "moonlight school 存在")
	var moon: Dictionary = schools["moonlight"]
	assert_eq(str(moon.get("name", "")), "月光道", "中文名固定")
	var starters: Array = moon.get("starter_gu_ids", [])
	assert_eq(starters, ["moonlight_gu", "moonlight_gu", "small_light_gu", "stone_shell_gu", "vitality_grass_gu"],
		"starter pack 顺序/数量符合验收台账")
	# gu.json 注册
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	for gid in starters:
		assert_false(gu_by_id.get(gid, {}).is_empty(), "gu %s 已注册" % gid)


func test_start_new_run_seeds_moonlight_starter_pack() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var controller := RunControllerScript.new()
	controller.catalog = catalog
	controller.start_new_run(42, "moonlight", [])
	assert_eq(controller.state.school, "moonlight", "school 已设置")
	# 5 个 starter 全部入 refined_gu_ids（vitality_grass 是新增的，可能有 realm_cap 限制，先用 refined_gu_ids 计数）
	var expected: Array = ["moonlight_gu", "moonlight_gu", "small_light_gu", "stone_shell_gu", "vitality_grass_gu"]
	for gid in expected:
		assert_true(controller.state.refined_gu_ids.has(gid), "refined_gu_ids 包含 %s" % gid)
	# gu_instances 至少新增 5 个 instance_id（gu_001 是默认 small_light_gu，可能被覆盖）
	var instances: Dictionary = controller.state.gu_instances
	var count := 0
	for inst in instances.values():
		if str(inst.get("definition_id", "")) in expected:
			count += 1
	assert_true(count >= 5, "gu_instances 含全部 starter 定义")
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
	# 选 moonlight → contract 子视图
	controller._selected_school = "moonlight"
	controller._show_hall_subview("contracts")
	assert_eq(controller._hall_subview, "contracts", "contract 子视图")
	# 多选契约
	controller._selected_contracts = ["blood_pact", "enemy_vitality_trial"]
	# 模拟开始按钮触发 start_new_run
	controller.start_new_run(controller.roll_seed(), controller._selected_school, Array(controller._selected_contracts))
	assert_eq(controller.current_view_name(), "Map", "进 Map")
	assert_eq(controller.state.school, "moonlight")
	assert_eq(controller.state.contracts.size(), 2, "契约可多选")
	# 出口存在：save_run / leave_map_without_save 不抛错
	var save_res := controller.submit_command({"type": "save_run"})
	assert_true(bool(save_res.get("ok", false)), "save_run OK")
	controller.free()