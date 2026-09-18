extends GutTest

## M2（纠偏计划 2026-09-12）：战斗命令路由单一事实来源。
## 1. is_battle_command 覆盖全部可路由战斗命令（含 V1 未实现的 3 个遗留
##    类型——它们仍路由到 facade 走统一拒绝，行为与硬编码表时代逐条相同）；
## 2. 源码卫生守卫：run_controller.gd 不得再出现战斗命令 ID 字面量表
##    （用户验收标准："Controller 不再需要维护任何具体战斗命令 ID / 类型列表"）。

const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")


func test_is_battle_command_covers_all_routable_types() -> void:
	for command_type in [
		"use_gu", "end_turn", "retreat", "basic_attack", "play_kill_move",
		"use_inheritance", "basic_dodge", "refine",
	]:
		assert_true(FacadeScript.is_battle_command(command_type),
				"must route to battle flow: %s" % command_type)


func test_is_battle_command_rejects_non_battle_types() -> void:
	for command_type in ["travel", "buy", "save_run", "load_run", "leave_node", "action_card", ""]:
		assert_false(FacadeScript.is_battle_command(str(command_type)),
				"must NOT route to battle flow: %s" % command_type)


func test_run_controller_holds_no_battle_command_id_list() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/presentation/run_controller.gd")
	for command_type in ["use_gu", "use_inheritance", "basic_dodge", "play_kill_move", "basic_attack"]:
		assert_false(source.contains("\"%s\"" % command_type),
				"run_controller must not carry battle command literal: %s" % command_type)
