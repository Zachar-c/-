extends GutTest

## S2 开局 Buff 切片验收：表驱动校验、run 创建结算、战斗期「凡敌一滴血」。

const CONTENT = preload("res://scripts/domain/content_catalog.gd")
const FACADE = preload("res://scripts/domain/battle_command_facade.gd")
const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")


func test_buffs_table_validates_and_exposes() -> void:
	var loaded: Dictionary = CONTENT.load_and_validate_all()
	assert_eq((loaded.get("errors", []) as Array).size(), 0,
			"buffs.json must not introduce content errors")
	var catalog: Dictionary = loaded.get("catalog", {})
	for buff_id in ["lesser_one_hp", "slay_gu_ten", "opening_stones"]:
		assert_true(catalog.get("buffs", {}).has(buff_id),
				"buff %s must be declared" % buff_id)


func test_start_new_run_settles_buffs() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(20260906, "light", [],
			["lesser_one_hp", "opening_stones", "slay_gu_ten"])
	var state = controller.state
	assert_eq(int(state.stone), 2012, "2000 stones granted on top of base 12")
	assert_true(state.run_buff_ids.has("lesser_one_hp"),
			"battle-time buff must be recorded on state")
	var defs: Array = []
	for instance_value in state.gu_instances.values():
		defs.append(str(instance_value.definition_id))
	assert_true(defs.has("test_slay_gu"), "slay gu granted as a real instance")


func test_unknown_buff_ids_are_ignored() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(20260907, "light", [], ["no_such_buff"])
	assert_eq(controller.state.run_buff_ids.size(), 0,
			"unknown buff ids must not settle")


func test_lesser_one_hp_spares_bosses_only() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(20260908, "light", [], ["lesser_one_hp"])
	var common: Dictionary = FACADE.start(
			{"enemy_kind": "neutral_stone_wanderer"}, controller.state, controller.catalog)
	assert_gt((common.get("enemies", []) as Array).size(), 0, "battle must build enemies")
	for enemy_value in common.get("enemies", []):
		assert_eq(int(enemy_value.hp), 1, "common enemy reduced to 1 hp")
	var boss: Dictionary = FACADE.start(
			{"enemy_kind": "miasma_vein_lord"}, controller.state, controller.catalog)
	# Boss 血量以目录为准：数值随 enemies.json 调整，此处的契约是「不受减血 buff 影响」。
	var boss_hp := -1
	for enemy_value in (controller.catalog.get("enemies", []) as Array):
		if str(enemy_value.get("id", "")) == "miasma_vein_lord":
			boss_hp = int(enemy_value.get("hp", 0))
	assert_gt(boss_hp, 1, "boss baseline hp must come from the catalog")
	for enemy_value in boss.get("enemies", []):
		if str(enemy_value.get("id", "")) == "miasma_vein_lord":
			assert_eq(int(enemy_value.hp), boss_hp, "boss keeps its own hp")
