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
