extends GutTest


# 命令契约守卫（2026-08-28 全量验收 P0-2）：UI 命令 builder 里出现的每个
# "type" 字面量必须落在真实处理集合——resolver dispatch / 控制器战斗与流程
# 路由 / 会话层——否则就是幽灵命令：按钮可点但必被 unsupported_command 拒绝。
# 双通道拦截：源扫描抓 builder 全部字面量 + 行为探针验证领域侧真有 handler；
# 历史幽灵命令清单单独钉死，防止回归。


const CommandBuilderPath := "res://scripts/presentation/run_command_builder.gd"
const ResolverScript = preload("res://scripts/domain/resolver.gd")


# controller.submit_command / EncounterSessionResolver 自行处理的命令类型
# （不经 resolver dispatch，但都有真实行为）。
const NON_DISPATCH_TYPES := [
	"save_run", "load_run", "travel", "leave_encounter", "leave_node",
	"action_card", "choose_action", "attempt_ascension",
	"use_gu", "use_inheritance", "end_turn", "retreat", "basic_attack", "basic_dodge", "refine",
	"play_kill_move",
]


func _builder_types() -> Array[String]:
	var text := FileAccess.get_file_as_string(CommandBuilderPath)
	var types: Array[String] = []
	var regex := RegEx.new()
	regex.compile("\"type\": \"([a-z_]+)\"")
	for match_value in regex.search_all(text):
		var type_name := str((match_value as RegExMatch).get_string(1))
		if not types.has(type_name):
			types.append(type_name)
	return types


func test_builder_commands_all_have_real_handlers() -> void:
	var catalog := ContentCatalog.load_all()
	var ghosts: Array[String] = []
	for type_name in _builder_types():
		if type_name in NON_DISPATCH_TYPES:
			continue
		# 行为探针：最小载荷发进 resolver；未知类型必回 unsupported_command。
		# 其他拒绝原因（unknown_xxx 等）恰好证明 handler 存在且门禁生效。
		var state := RunState.new_run(101)
		var result: Dictionary = ResolverScript.apply(state, {"type": type_name}, catalog)
		var reason := str((result.get("result", {}) as Dictionary).get("reason", ""))
		if reason == "unsupported_command":
			ghosts.append(type_name)
	assert_eq(ghosts, [], "builder emits command types with no domain handler: %s" % [", ".join(ghosts)])


func test_builder_has_no_known_ghost_commands() -> void:
	var text := FileAccess.get_file_as_string(CommandBuilderPath)
	var known_ghosts := [
		"shop_block_pool", "shop_service",
		"reward_take", "reward_replace", "reward_skip",
		"refine_channel", "refine_toggle_input", "refine_confirm",
		"ultimate", "view_node",
	]
	for ghost in known_ghosts:
		# 匹配命令字面量（含引号/字段上下文），避免误伤同名前缀的合法 helper 名。
		assert_false(text.contains("\"%s\"" % ghost) or text.contains("{\"type\": \"%s\"" % ghost),
				"ghost command must not return to the builder: %s" % ghost)


func test_builder_covers_every_command_surface_key() -> void:
	# 反向守卫：builder 若声明了命令却拼错 type 字面量（如 "type": "shop_purchse"），
	# 行为探针同样能抓到——本用例确保源扫描本身没漏（至少抓到已知真实命令）。
	var types := _builder_types()
	for expected in ["shop_purchase", "npc_trade", "refine_gu", "destroy_gu", "remove_card"]:
		assert_true(types.has(expected), "source scan must see command type %s" % expected)


func test_player_view_playthrough_wraps_regular_battle_commands_with_freshness() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/acceptance_driver.gd")
	for command_type in ["retreat", "basic_dodge", "end_turn"]:
		assert_false(text.contains('{"type": "%s"}' % command_type), "playthrough must not emit bare battle command: %s" % command_type)
	assert_true(text.contains("_battle_turn_command"), "playthrough must use the shared battle freshness helper")


func test_player_view_prioritizes_instanced_ascension_sources_by_template_id() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/acceptance_driver.gd")
	assert_true(text.contains("template_id"), "playthrough must match generated node templates")
	assert_true(text.contains("_is_ascension_source"), "playthrough must use a template-aware source helper")


func test_player_view_playthrough_accepts_the_same_school_choice_as_hall() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/acceptance_driver.gd")
	assert_true(text.contains("PLAYTHROUGH_SCHOOL"), "playthrough must exercise the hall school choice")
	assert_true(text.contains("start_new_run(seed_value, school"), "school choice must enter the real start_new_run path")


func test_player_view_boss_fight_uses_v1_gu_and_attack_fallback() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/acceptance_driver.gd")
	# V1 蛊行动制：Boss 战禁撤退由 facade 门禁判定，收头窗口搏命，攻击/守护交替。
	assert_true(text.contains("BattleCommandFacadeScript.boss_blocks_retreat(battle)"), "boss retreat gate must come from the V1 facade")
	assert_true(text.contains("finish_now") and text.contains("immediate_kill"), "one-health enemies must enter the immediate-kill branch")
	assert_true(text.contains("can_flee and finish_now and attack_gu.is_empty()"), "retreatable one-health fights without a safe attack must retreat")
	assert_true(text.contains('_pick_effect_gu(battle, ["strike"])'), "boss fight must pick strike gu by V1 effect kind")
	assert_true(text.contains('_play_gu_command(controller, battle, attack_gu)'),
			"boss fight must cast the picked gu through use_gu (with freshness context)")
	assert_true(text.contains('_battle_turn_command(controller, "basic_attack")'), "boss fight must fall back to the V1 basic attack")


func test_player_view_hard_fights_alternate_guard_and_attack_without_dodge() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/acceptance_driver.gd")
	# V1 无闪避/无 dodge_used 旗标；硬仗节奏 = 守护与攻击交替 + 僵局回退拳脚/收势。
	assert_false(text.contains("basic_dodge"), "playthrough must not emit the removed dodge command")
	assert_true(text.contains("kill_window") and text.contains("danger"), "boss fight must weigh kill windows against danger")
	assert_true(text.contains("must_attack"), "boss fight must close guarded turns by attacking")
	assert_true(text.contains("_stuck_count"), "stubborn battles must track no-progress rounds")
	assert_true(text.contains('"use_gu"'), "V1 gu casts must ride the use_gu command")


func test_player_view_map_strategy_uses_reachable_nodes_before_travel() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/acceptance_driver.gd")
	assert_true(text.contains("node.get(\"reachable\", false)"), "playthrough map strategy must skip lookahead nodes")
	assert_true(text.contains("optional_combat"), "optional combat nodes must be lower priority than safe progress")


func test_run_controller_does_not_bypass_battle_command_facade() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/presentation/run_controller.gd")
	for direct_call in [
		"BattleResolver.start",
		"BattleResolver.take_turn",
		"BattleResolver.apply_action_card",
		"BattleResolver.apply_enemy_pre_turn",
	]:
		assert_false(text.contains(direct_call), "RunController must delegate battle calls through BattleCommandFacade: %s" % direct_call)


func test_v2_command_family_registers_real_handlers() -> void:
	# T9.2: every v2 command type must have a real handler in the resolver
	# dispatch (ghost-free) - the probe asserts the reason is never
	# unsupported_command.
	var v2_types := [
		"confirm_core", "replace_core", "feed_instance", "settle_layer",
		"collect_surviving", "release_gu", "sell_info", "fulfill_demand", "enact", "dodge",
		"grapple", "respond", "refine_up_material", "bloodlet", "absorb_soul",
	]
	var catalog := ContentCatalog.load_all()
	var unsupported: Array[String] = []
	for type_name in v2_types:
		var state := RunState.new_run(101)
		var result: Dictionary = ResolverScript.apply(state, {"type": type_name}, catalog)
		var reason := str((result.get("result", {}) as Dictionary).get("reason", ""))
		if reason == "unsupported_command":
			unsupported.append(type_name)
	assert_eq(unsupported, [], "v2 commands without a dispatch handler: %s" % [", ".join(unsupported)])
