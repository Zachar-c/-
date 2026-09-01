class_name RunController
extends Node


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")

const DeathReportBuilderScript = preload("res://scripts/domain/death_report_builder.gd")
const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const BattleCommandFacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const TemplateDialogueGatewayScript = preload("res://scripts/domain/template_dialogue_gateway.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const DeckCapacityScript = preload("res://scripts/domain/deck_capacity.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const RunCommandBuilderScript = preload("res://scripts/presentation/run_command_builder.gd")
const DebugActionsScript = preload("res://scripts/domain/debug_actions.gd")
const AppSettingsScript = preload("res://scripts/domain/app_settings.gd")
const ResourceVocabularyScript = preload("res://scripts/presentation/resource_vocabulary.gd")

const SCREEN_PATHS := {
	"Title": "res://ui/screens/hall_view.gd",
	"Map": "res://ui/screens/map_screen.gd",
	"Encounter": "res://ui/screens/encounter_screen.gd",
	"Battle": "res://ui/screens/battle_screen.gd",
	"Ending": "res://ui/screens/ending_screen.gd",
	"Shop": "res://ui/screens/shop_screen.gd",
	"Rest": "res://ui/screens/rest_screen.gd",
	"Refine": "res://ui/screens/refine_screen.gd",
	"Reward": "res://ui/screens/reward_screen.gd",
	"Npc": "res://ui/screens/npc_screen.gd",
	"ContentError": "res://ui/screens/content_error_screen.gd",
}
const MASTER_SCENE_PATHS := {
	"Title": "res://scenes/ui_masters/wenzhen_hall_master.tscn",
	"Map": "res://scenes/ui_masters/wenzhen_map_master.tscn",
	"Battle": "res://scenes/ui_masters/wenzhen_battle_master.tscn",
}


var catalog: Dictionary
var _content_errors: Array[String] = []
var state: RunState
var meta  # MetaProgress instance loaded from save, untyped for property access
## 客户端偏好（音量/显示，§16.22）：独立 ConfigFile，绝不进 RunData 或大厅档。
var app_settings  # AppSettings instance, untyped so tests can stub it with null
var route: Array[Dictionary] = []
var current_node: Dictionary = {}
var current_battle: Dictionary = {}
var current_session: Dictionary = {}
## D3 战利品弹窗数据源：最近一场胜利的 loot/elite cost（只读快照消费）。
var last_battle_loot: Dictionary = {}
var last_battle_cost: Dictionary = {}
var last_result: Dictionary = {}
var last_load_diagnosis: Dictionary = {}
var dialogue_replies: Array[Dictionary] = []
var last_feedback := ""
var _dialogue_gateway: DialogueGateway
var _view_name := "Map"
var _hall_subview := "main"
var _selected_school := "force"
## 大厅勾选的开局契约（§15/§16.13）；new_run 时经 swear 门禁正式立誓。
var _selected_contracts: Array[String] = []

var _rui_host: Control
var _rui_root
var _mounted_screen := ""
var _master_instance: Control
var _ending_state: Dictionary = {}

# T6-E 跨屏过渡（§3.4 动效预算）：一次性淡入时长；无常驻循环动画。
# 仅在 _view_name 变化（屏切换）时淡入，同屏命令重渲染不闪屏。
const SCREEN_FADE_SECONDS := 0.14
var _screen_tween: Tween
var _faded_view := ""

# ----------------------------------------------------------------------------
# §16.22 D5 开发者调试（仅开发构建）：整条链路以 is_debug_build 门控，Release 下
# 面板零节点存在、方法全部早退。调试写操作只落本局 RunData、绝不触碰大厅存档；
# 加蛊走与 Resolver 同源的 DeckCapacity 正式容量校验；资源钳制到合法区间；
# 全部操作 print 带 [debug] 前缀可追溯。按简报裁定：调试操作不写事件日志。
# ----------------------------------------------------------------------------
const DEBUG_PANEL_PATH := "res://ui/screens/debug_panel.gd"
## 元石调试硬上限（经济供给上限未在数据表落地前的展示层安全界）。
const DEBUG_STONE_CAP := 99999
var DEBUG_RESOURCE_LABELS := {
	"yuanstone": ResourceVocabularyScript.label("yuanstone"),
	"health": "生命",
	"lifespan": ResourceVocabularyScript.label("lifespan"),
	"soul": ResourceVocabularyScript.label("soul"),
	"essence": ResourceVocabularyScript.label("essence"),
}

## 测试注入开关：默认跟随构建类型（GUT/编辑器为 true，Release 导出为 false）。
var _debug_enabled_for_test: bool = OS.is_debug_build()
var _debug_panel_open := false
var _debug_rui_root: RuitkRoot = null
var _debug_host: Control = null
var _debug_gu_input := ""
var _debug_res_kind := "yuanstone"
var _debug_res_value := ""
var _debug_travel_node := ""
var _debug_feedback := ""
var _map_leave_confirm := false
var _feedback_timer: Timer = null
const FEEDBACK_TOAST_SECONDS := 2.5


func _ready() -> void:
	ensure_ui()


func ensure_ui() -> void:
	if _rui_root != null:
		return
	_initialize_view_flow()


func _initialize_view_flow() -> void:
	# 大厅子视图（流派/契约/图鉴）只读快照依赖 catalog；启动即加载内容表，
	# 否则选流派前列表恒为空（2026-08-27 实机走查断点）。
	catalog = ContentCatalog.load_all()
	_content_errors = ContentCatalog.validate(catalog)
	app_settings = AppSettingsScript.load_settings()
	# 仅在玩家显式保存过偏好时才施加引擎副作用，首跑保持项目默认窗口。
	if AppSettingsScript.has_saved_file():
		_apply_master_volume()
		_apply_window_mode()
	_rui_host = Control.new()
	_rui_host.name = "RUIHost"
	_rui_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rui_host)
	_feedback_timer = Timer.new()
	_feedback_timer.name = "FeedbackToastTimer"
	_feedback_timer.one_shot = true
	_feedback_timer.timeout.connect(_on_feedback_timer_timeout)
	add_child(_feedback_timer)
	if not _content_errors.is_empty():
		_show_content_error()
		return
	_show_title()
	if _debug_enabled():
		_mount_debug_panel()


func start_new_run(seed_value: int, school: String = "", contract_ids: Array = []) -> void:
	var loaded := ContentCatalog.load_and_validate_all()
	catalog = loaded.get("catalog", {})
	_content_errors = loaded.get("errors", [])
	if not _content_errors.is_empty():
		_show_content_error()
		return
	meta = SaveRepository.load_meta_file()
	if meta == null:
		meta = load("res://scripts/domain/meta_progress.gd").new_empty()
	state = RunState.new_run(seed_value, meta)
	state.cave_aperture["essence_max"] = EssenceCapacityScript.essence_max(state, catalog)
	_inject_school_starters(school)
	_swear_opening_contracts(contract_ids)
	_selected_contracts.clear()
	route = MapGenerator.build(seed_value, seed_value == 101, catalog)
	current_node = {}
	current_battle = {}
	current_session = {}
	last_result = {}
	dialogue_replies = []
	_dialogue_gateway = TemplateDialogueGatewayScript.new()
	_show_map()


func submit_command(command: Dictionary) -> Dictionary:
	if not _content_errors.is_empty() and command.get("type", "") != "quit":
		_show_content_error()
		return {"ok": false, "reason": "content_invalid", "feedback": "内容配置无法加载。"}
	# D4 Toast：反馈只在产生它的那次命令后可见；下一条命令即清空（无计时器，确定性显隐）。
	last_feedback = ""
	if command.get("type", "") == "save_run":
		var save_error := save_current_run()
		last_feedback = "进度已保存 · 关闭游戏后可继续本次冒险" if save_error == OK else "存档失败（错误码 %d）。" % save_error
		_show_map()
		return {"ok": save_error == OK, "feedback": last_feedback}
	if command.get("type", "") == "load_run":
		var loaded := load_saved_run()
		last_feedback = "已返回上次保存的行程。" if loaded else _save_load_feedback(last_load_diagnosis)
		_show_map()
		return {"ok": loaded, "feedback": last_feedback}



	if command.get("type", "") == "travel":
		return _travel_to(str(command.get("node_id", "")))
	if command.get("type", "") == "leave_encounter":
		command = {"type": "leave_node"}
	if command.get("type", "") == "action_card" and not current_battle.is_empty():
		return _submit_battle_command(command)
	if command.get("type", "") in ["use_gu", "use_inheritance", "end_turn", "retreat", "basic_attack", "basic_dodge", "refine"] and not current_battle.is_empty():
		return _submit_battle_command(command)
	if not current_node.is_empty():
		var session_result := EncounterSessionResolverScript.apply(state, current_session, command, catalog, current_node)
		state = session_result["state"]
		current_session = session_result["session"]
		last_result = session_result["result"]
		_attach_social_dialogue(last_result)
		_record_dialogue_reply(last_result)
		_apply_command_feedback(last_result)
		if bool(last_result.get("start_battle", false)) or str(last_result.get("action_id", "")) == "fight":
			_start_battle()
			return last_result
		# 统一结算路由（§16.6/§16.10）：升仙窗口内的冲仙无论档位成败，
		# 都必须切入 Ending 结算页，而不是停留在遭遇会话里。
		if str(command.get("type", "")) == "attempt_ascension" and bool(last_result.get("ok", false)):
			_show_ending(last_result)
			return session_result
		if bool(current_session.get("completed", false)):
			_return_to_map()
		else:
			_re_show_current_screen()
		return session_result

	var resolved := Resolver.apply(state, command, catalog)
	state = resolved["state"]
	last_result = resolved["result"]
	_attach_social_dialogue(last_result)
	_record_dialogue_reply(last_result)
	_apply_command_feedback(resolved["result"])
	if bool(last_result.get("start_battle", false)):
		_start_battle()
		return last_result
	if command.get("type", "") == "choose_action" and command.get("action_id", "") == "fight":
		_start_battle()
		return {"ok": true}
	if command.get("type", "") == "attempt_ascension":
		_show_ending(resolved["result"])
	elif not current_node.is_empty():
		_show_encounter()
	return resolved


func _submit_battle_command(command: Dictionary) -> Dictionary:
	var turn: Dictionary = BattleCommandFacadeScript.apply_turn(current_battle, state, command, catalog)
	state = turn["state"]
	current_battle = turn["battle"]
	last_result = {"battle_result": turn.get("result", "ongoing"), "feeds": turn.get("feeds", [])}
	if bool(turn.get("finished", false)):
		if str(turn.get("result", "")) == "death":
			_show_death(DeathReportBuilderScript.build(current_battle, state))
		else:
			_finish_battle_in_session(str(turn.get("result", "")))
	else:
		_show_battle()
	return turn


## B 批反馈基建（§16.5 信息透明）：命令结果必须可见——被拒走 rejection_text 中文，
## 成功且无人为反馈时拼接 actual_changes 的结构化中文（"元石减少 6。"等）。
## 战斗回合分支（take_turn/apply_action_card 直返）不经此函数，反馈由战斗屏自身呈现。
func _apply_command_feedback(result: Dictionary) -> void:
	if not bool(result.get("ok", true)):
		if last_feedback.is_empty():
			last_feedback = rejection_text(str(result.get("reason", "unknown")))
	elif last_feedback.is_empty():
		last_feedback = _summarize_changes(result.get("actual_changes", []))


## 拓扑 v2：把当前实例的模板 id 与大层盖到 RunState，供领域侧
## （升仙授予查模板、掉落/黑市按层裁定）读取；存档随行。
func _stamp_current_node(run_state, node: Dictionary) -> void:
	run_state.current_node_template_id = str(node.get("template_id", node.get("id", "")))
	run_state.current_node_layer = int(node.get("layer", 0))


func current_view_name() -> String:
	return _view_name


func _show_content_error() -> void:
	_view_name = "ContentError"
	_ending_state = {}
	_render()


## 成功命令的反馈摘要：拼接 actual_changes 的 message（领域侧已中文化）。
## 空变化（如纯查询命令）返回空串，toast 不显示。
func _summarize_changes(changes) -> String:
	if changes == null or not (changes is Array):
		return ""
	var parts: Array[String] = []
	for c in changes:
		var msg := str(c.get("message", "")) if c is Dictionary else ""
		if not msg.is_empty():
			parts.append(msg)
	return "、".join(parts)


## B 批反馈基建：resolver 拒绝 reason → 玩家可见中文文案（§16.5 数值明确、不模糊）。
## 未收录的 reason 走通用兜底并保留原始键（可追溯，不静默）。
func rejection_text(reason: String) -> String:
	if reason.is_empty() or reason == "unknown":
		return "该操作暂时无法执行。"
	return _REJECTION_TEXT.get(reason, "无法执行：%s" % reason)


## 高频拒绝 reason 的玩家文案。新增拒绝理由时在此登记，漏网走兜底显示原始键。
const _REJECTION_TEXT := {
	"insufficient_stone": "元石不足。",
	"insufficient_lifespan": "寿元不足。",
	"insufficient_soul": "魂魄不足。",
	"insufficient_material": "材料不足。",
	"unknown_shop_offer": "该商品不在货架上。",
	"npc_stock_missing": "该货物已被买空。",
	"npc_not_present": "对方不在此地。",
	"unknown_npc": "这里没有可交易的人。",
	"npc_missing": "这里没有可交易的人。",
	"contract_locked": "该契约尚未解锁。",
	"contract_sworn": "该契约已立誓。",
	"contract_soft_cap": "契约数量已达上限。",
	"deck_capacity": "蛊囊已满，无法再装入。",
	"gu_slot_full": "蛊槽已满，请先取舍。",
	"refine_input_missing": "炼蛊材料不足：先投入至少两味材料。",
	"refine_slot_invalid": "炼蛊空位校验未通过。",
	"refine_recipe_locked": "该配方尚未解锁。",
	"retreat_forbidden": "此战不可撤退。",
	"invalid_action": "当前阶段不能执行该操作。",
	"invalid_action_card": "这张牌当前不能打出。",
	"stale_state_version": "局面已变化，操作已过期，请重试。",
	"not_enough_essence": "真元不足。",
	"no_actions_left": "行动值已用完，结束回合恢复。",
	"dodge_exhausted": "本回合已闪避过。",
	"not_enough_hp": "生命不足，不能支付该代价。",
	"lifespan_trade_warning": "这笔交易将耗尽寿元，被拒绝。",
	"already_completed": "该节点已完成。",
	"invalid_node_completion": "节点状态已变化。",
	"unknown_contact": "此人无可交涉的选项。",
	"invalid_contact_approach": "该交涉方式不可用。",
	"unknown_command": "未知指令。",
	"unknown_gu": "没有这只蛊。",
	"unknown_card": "没有这张卡。",
	"unknown_node": "无法前往该地点。",
	"node_not_reachable": "该地点与当前位置不连通。",
	"unknown_material": "没有这种材料。",
	"material_not_usable": "这种材料不能直接使用。",
	"no_material_to_use": "身上没有这种材料。",
	"material_use_lethal": "直接使用会耗尽气血，被拒绝。",
}


func force_complete_for_test() -> void:
	_show_ending({"outcome": "survived_failure", "conditions": {}})


func visible_route_nodes(forward_layers: int = 2) -> Array[Dictionary]:
	return MapGenerator.visible_nodes(route, state, forward_layers)


func force_death_for_test(final_blow_id: String) -> void:
	state = state.finalize_death()
	var report := DeathReportBuilderScript.build({}, state)
	report["final_blow"] = final_blow_id
	_show_death(report)


func request_map_leave() -> void:
	if _view_name == "Map" and state != null and not state.is_terminal():
		_map_leave_confirm = true
		_render()


func cancel_map_leave() -> void:
	_map_leave_confirm = false
	_render()


func save_and_leave_map() -> void:
	if _view_name != "Map" or state == null:
		return
	var save_error := save_current_run()
	if save_error == OK:
		last_feedback = "进度已保存 · 已返回大厅"
		_map_leave_confirm = false
		_show_title()
	else:
		last_feedback = "存档失败（错误码 %d），仍留在地图。" % save_error
		_render()


func leave_map_without_save() -> void:
	if _view_name != "Map":
		return
	_map_leave_confirm = false
	last_feedback = "未保存本次变化 · 返回大厅后仍可继续上次存档"
	_show_title()




func save_current_run() -> Error:
	return SaveRepository.save_run(state, route, dialogue_replies)


func load_saved_run() -> bool:
	last_load_diagnosis = SaveRepositoryScript.diagnose_run_file()
	if not bool(last_load_diagnosis.get("ok", false)):
		return false
	return _restore_game(SaveRepositoryScript.load_run())


func _save_load_feedback(diagnosis: Dictionary) -> String:
	match str(diagnosis.get("kind", "missing")):
		"unsupported_version":
			return "上次冒险存档版本不受支持（v%d）。" % int(diagnosis.get("version", -1))
		"checksum_missing", "checksum_mismatch":
			return "上次冒险存档校验失败，已拒绝载入。"
		"invalid_json":
			return "上次冒险存档格式损坏，已拒绝载入。"
		"invalid_state", "invalid_route", "invalid_event_log":
			return "上次冒险存档内容损坏，已拒绝载入。"
		_: return "暂无可继续的冒险：先在地图「存档」一次。"


func _restore_game(loaded: Dictionary) -> bool:
	if loaded.is_empty():
		return false
	state = loaded["state"]
	if loaded.has("route"):
		route = loaded["route"].duplicate(true)
	current_node = _node_by_id(state.current_node_id)
	if current_node.is_empty() and not route.is_empty():
		for node_value in route:
			var node_item: Dictionary = node_value
			if str(node_item.get("id", "")) == state.current_node_id:
				current_node = node_item
				break
	_stamp_current_node(state, current_node)
	current_battle = {}
	current_session = state.encounter_session.duplicate(true)
	dialogue_replies = loaded.get("replies", [])
	if meta == null and FileAccess.file_exists(SaveRepositoryScript.META_PATH):
		meta = SaveRepositoryScript.load_meta_file()
	_show_map()
	return true


func _travel_to(node_id: String) -> Dictionary:
	var node := _node_by_id(node_id)
	if node.is_empty():
		return {"ok": false, "reason": "unknown_route_node"}
	var reachable_ids: Array[String] = []
	for reachable in MapGenerator.reachable_nodes(route, state):
		reachable_ids.append(str(reachable["id"]))
	if not reachable_ids.has(node_id):
		return {"ok": false, "reason": "unreachable_route_node"}
	var resolved := Resolver.apply(state, {"type": "travel", "node_id": node_id}, catalog)
	state = resolved["state"]
	current_node = node
	_stamp_current_node(state, node)
	var session_started := EncounterSessionResolverScript.begin(state, node)
	state = session_started["state"]
	current_session = session_started["session"]
	last_result = resolved["result"]
	if node["type"] in ["combat", "pursuit"]:
		_start_battle()
	elif node["type"] in ["shop", "market", "caravan"]:
		_show_shop()
	elif node["type"] == "rest":
		_show_rest()
	elif node["type"] == "refinement":
		_show_refine()
	elif node["type"] == "contact":
		_show_npc()
	else:
		_show_encounter()
	return resolved["result"]


# ----------------------------------------------------------------------------
# §16.22 D5 调试方法族（全部 is_debug_build 门控早退；只写本局 RunData；
# 不写事件日志、不碰大厅存档；print 带 [debug] 前缀可追溯）。
# ----------------------------------------------------------------------------

func _debug_enabled() -> bool:
	return _debug_enabled_for_test


func debug_panel_mounted() -> bool:
	return _debug_rui_root != null


func _unhandled_key_input(event: InputEvent) -> void:
	if not _debug_enabled():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != KEY_F12:
		return
	_toggle_debug_panel()


func debug_add_gu(gu_id: String) -> Dictionary:
	if not _debug_enabled():
		return {"ok": false, "reason": "debug_disabled"}
	if state == null or catalog == null or catalog.is_empty():
		return _debug_fail("no_active_run")
	var target := str(gu_id).strip_edges()
	var result := DebugActionsScript.apply(state, catalog,
			{"op": "add_gu", "definition_id": target}, _debug_enabled())
	state = result["state"]
	if not bool(result.get("ok", false)):
		var reason := str(result.get("result", {}).get("reason", ""))
		return _debug_fail_with(reason, "调试失败：%s" % reason)
	var instance_id := str(result.get("result", {}).get("instance_id", ""))
	_debug_feedback = "调试：已加入 %s（实例 %s）" % [DisplayText.gu(target), instance_id]
	print("[debug] add_gu %s as %s" % [target, instance_id])
	_render()
	return {"ok": true, "instance_id": instance_id}


func debug_set_resource(kind: String, value) -> Dictionary:
	if not _debug_enabled():
		return {"ok": false, "reason": "debug_disabled"}
	if state == null:
		return _debug_fail("no_active_run")
	var amount := 0
	if value is int or value is float:
		amount = int(value)
	elif value is String:
		var text_value := str(value).strip_edges()
		if not text_value.is_valid_int():
			return _debug_fail_with("invalid_number", "调试失败：数值必须是整数（收到 %s）" % text_value)
		amount = int(text_value)
	else:
		return _debug_fail_with("invalid_number", "调试失败：数值类型不支持")
	# UI-layer clamp: stones uncapped in domain but panel shows 99999 cap.
	var api_kind := str(kind)
	if api_kind == "yuanstone" or api_kind == "stones":
		amount = clampi(amount, 0, DEBUG_STONE_CAP)
		api_kind = "stones"
	elif api_kind == "lifespan":
		return _debug_fail_with("unknown_kind", "调试失败：未知资源类别（%s）" % str(kind))
	elif api_kind not in ["stones", "health", "soul", "essence"]:
		return _debug_fail_with("unknown_kind", "调试失败：未知资源类别（%s）" % str(kind))
	var action := {"op": "set_resources"}
	action[api_kind] = amount
	var result := DebugActionsScript.apply(state, catalog, action, _debug_enabled())
	state = result["state"]
	
	if not bool(result.get("ok", false)):
		var reason := str(result.get("result", {}).get("reason", ""))
		return _debug_fail_with(reason, "调试失败：%s" % reason)
	var applied := amount
	if api_kind == "essence":
		applied = int(result.get("result", {}).get("essence", amount))
	elif api_kind == "stones":
		applied = int(result.get("result", {}).get("stones", amount))
	elif api_kind == "health":
		applied = int(result.get("result", {}).get("health", amount))
	elif api_kind == "soul":
		applied = int(result.get("result", {}).get("soul", amount))
	print("[debug] set_resource %s -> %d" % [str(kind), applied])
	_debug_feedback = "调试：%s 已设为 %d" % [str(DEBUG_RESOURCE_LABELS.get(str(kind), str(kind))), applied]
	_render()
	return {"ok": true, "applied": applied}


func debug_travel(node_id: String) -> Dictionary:
	if not _debug_enabled():
		return {"ok": false, "reason": "debug_disabled"}
	if state == null or route.is_empty():
		return _debug_fail("no_active_run")
	if not current_battle.is_empty():
		return _debug_fail_with("battle_in_progress", "调试失败：战斗进行中，禁止跳层")
	var target := str(node_id).strip_edges()
	var visible_ids: Array[String] = []
	for visible_node in visible_route_nodes():
		visible_ids.append(str(visible_node.get("id", "")))
	if not visible_ids.has(target):
		return _debug_fail_with("invisible_node", "调试失败：目标节点不在当前可见范围（%s）" % target)
	var result := DebugActionsScript.apply(state, catalog,
			{"op": "jump_to_node", "node_id": target}, _debug_enabled(), route)
	state = result["state"]
	
	if not bool(result.get("ok", false)):
		var reason := str(result.get("result", {}).get("reason", ""))
		return _debug_fail_with(reason, "调试失败：跳层被拒（%s）" % reason)
	_debug_travel_node = target
	_view_name = "Map"
	_show_map()
	print("[debug] travel -> %s" % target)
	_debug_feedback = "调试：已跳至 %s" % target
	_render()
	return {"ok": true}


func debug_snapshot_dump() -> Dictionary:
	if not _debug_enabled():
		return {}
	if state == null:
		return {}
	var result := DebugActionsScript.apply(state, catalog,
			{"op": "dump_snapshot"}, _debug_enabled())
	state = result["state"]
	
	var snapshot: Dictionary = result.get("result", {}).get("snapshot", {})
	print("[debug] snapshot ", JSON.stringify(snapshot))
	_debug_feedback = "调试：RunData 快照已打印到 stdout"
	_render_debug_panel()
	return snapshot


## 调试面板跳层下拉选项：仅当前可见节点（防越层破坏地图不变量）。
func _debug_travel_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if state == null or route.is_empty():
		return options
	for node in visible_route_nodes():
		var nid := str(node.get("id", ""))
		options.append({
			"id": nid,
			"label": "[%s] %s" % [nid, str(node.get("label", DisplayText.node(nid)))],
		})
	return options


func _debug_props() -> Dictionary:
	var info: Dictionary = {}
	if state != null:
		info = RunSnapshotBuilderScript.debug(self)
	return {
		"open": _debug_panel_open,
		"feedback": _debug_feedback,
		"info": info,
		"gu_input": _debug_gu_input,
		"res_kind": _debug_res_kind,
		"res_value": _debug_res_value,
		"travel_options": _debug_travel_options(),
		"travel_selected": _debug_travel_node,
		"commands": {
			"toggle_open": func(): _toggle_debug_panel(),
			"set_gu_input": func(text_value: String): _set_debug_gu_input(text_value),
			"add_gu": func(): debug_add_gu(_debug_gu_input),
			"set_res_kind": func(kind_value: String): _set_debug_res_kind(kind_value),
			"set_res_value": func(num_text: String): _set_debug_res_value(num_text),
			"apply_resource": func(): debug_set_resource(_debug_res_kind, _debug_res_value),
			"set_travel_node": func(node_value: String): _set_debug_travel_node(node_value),
			"travel": func(): debug_travel(_debug_travel_node),
			"snapshot_dump": func(): debug_snapshot_dump(),
		},
	}


func _set_debug_gu_input(value: String) -> void:
	_debug_gu_input = value


func _set_debug_res_kind(value: String) -> void:
	_debug_res_kind = value


func _set_debug_res_value(value: String) -> void:
	_debug_res_value = value


func _set_debug_travel_node(value: String) -> void:
	_debug_travel_node = value


func _toggle_debug_panel() -> void:
	_debug_panel_open = not _debug_panel_open
	_render_debug_panel()


func _mount_debug_panel() -> void:
	if _debug_rui_root != null:
		return
	var comp = VLib.comp(DEBUG_PANEL_PATH, "render")
	if not (comp is Callable):
		print("[debug] debug_panel 组件缺失（未编译？），面板未挂载")
		return
	_debug_host = Control.new()
	_debug_host.name = "DebugPanelHost"
	_debug_host.position = Vector2(20, 80)
	_debug_host.custom_minimum_size = Vector2(260, 44)
	_debug_host.size = _debug_host_size()
	_debug_host.mouse_filter = Control.MOUSE_FILTER_PASS
	_debug_host.set_script(preload("res://scripts/presentation/debug_panel_drag.gd"))
	add_child(_debug_host)
	_debug_rui_root = RuiRoot.create(_debug_host, VLib.fc(comp, _debug_props()))


func _debug_host_size() -> Vector2:
	return Vector2(260, 360) if _debug_panel_open else Vector2(260, 44)


func _render_debug_panel() -> void:
	if _debug_rui_root == null:
		return
	if _debug_host != null:
		_debug_host.size = _debug_host_size()
	var comp = VLib.comp(DEBUG_PANEL_PATH, "render")
	if not (comp is Callable):
		return
	_debug_rui_root.set_root(VLib.fc(comp, _debug_props()))


func _debug_ok(feedback: String) -> Dictionary:
	_debug_feedback = feedback
	# 主屏重渲染末尾已联动刷新调试面板（_render -> _render_debug_panel）。
	_render()
	return {"ok": true}


func _debug_fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _debug_fail_with(reason: String, feedback: String) -> Dictionary:
	_debug_feedback = feedback
	_render_debug_panel()
	return {"ok": false, "reason": reason}


func _start_battle() -> void:
	var enemy_kind := str(current_node.get("enemy_kind", "beast_swarm"))
	var first_mover := "player"
	var notorious := Resolver.notoriety(state)
	var stance := str(current_session.get("stance", "neutral"))
	var hostile_flag := stance in ["hostile", "extreme_hostile"] or bool(current_session.get("flags", {}).get("reputation_hostile", false))
	if notorious > 0 or hostile_flag:
		if hostile_flag:
			first_mover = "enemy"
		else:
			var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
			var pct := notorious * int(effects.get("first_move_chance_pct_per_point", 10))
			if Resolver.roll_chance(state, pct, "reputation_first_move"):
				first_mover = "enemy"
	var kill_source := ""
	if str(current_session.get("kind", "")) in ["contact", "caravan", "market", "shop", "wild_gu"]:
		kill_source = "neutral_npc"
	var encounter := {
		"turn": int(current_node.get("layer", MapGenerator.layer_index(str(current_node.get("stage", ""))))),
		"layer": int(current_node.get("layer", 1)),
		"terrain": _battle_terrain(),
		"first_mover": first_mover,
		"kill_source": kill_source,
	}
	if current_node.has("enemy_kinds"):
		encounter["enemy_kinds"] = (current_node.get("enemy_kinds", []) as Array).duplicate()
	else:
		encounter["enemy_kind"] = enemy_kind
	current_battle = BattleCommandFacadeScript.start(encounter, state, catalog)
	# N6: weaknesses procured through probe carry into the battle as bonus damage.
	if state.known_facts.has("procured_weakness"):
		current_battle["intel_bonus"] = 1
	if first_mover == "enemy":
		# 敌方本回合全部存活意图的伤害总和（围攻节点多名敌人叠伤，单看
		# visible_intent 会漏判致死）。
		var opening_damage := 0
		for enemy_value in current_battle.get("enemies", []):
			opening_damage += maxi(0, int((enemy_value as Dictionary).get("visible_intent", {}).get("damage", 0)))
		# 2 低血进敌方先手战（死亡可预见红线）：先手意图本会在本帧无条件结算，
		# 低血玩家入屏即死、无从反应。致死开场不自动结算——先亮意图 + 致命
		# 警告（快照 lethal_warning + 战斗日志），把敌方先手延后到玩家首个回合
		# 结束；意图与后续掷骰序列不变，全确定性。玩家可守护/闪避/治疗自救；
		# 未自救仍由常规结算致死并走 final_blow + 统一 DeathReport。
		var lethal_opening := opening_damage > 0 and state.health <= opening_damage
		if lethal_opening:
			(current_battle["flags"] as Array).append("opening_lethal")
			current_battle["log"].append({"id": "opening_lethal_warning", "damage": opening_damage})
			_show_battle()
			return
		var pre := BattleCommandFacadeScript.apply_enemy_pre_turn(current_battle, state, catalog)
		state = pre["state"]
		current_battle = pre["battle"]
		if bool(pre["finished"]):
			if str(pre["result"]) == "death":
				_show_death(DeathReportBuilderScript.build(current_battle, state))
			else:
				_finish_battle_in_session(str(pre["result"]))
			return
	_show_battle()


func _battle_terrain() -> String:
	if current_node.get("id", "") == "greedy_wanderer":
		return "ridge"
	return "path"


func _show_title() -> void:
	_view_name = "Title"
	_hall_subview = "main"
	_render()


# 退出流程（A6 设置 → 退出游戏）：request_quit 只置标志（可测），
# quit_game 在真实运行树下追加 SceneTree.quit；headless/GUT 下树为空或
# 为编辑器提示时安全跳过，避免测试进程被终止。
var quit_requested := false


func request_quit() -> void:
	quit_requested = true


func quit_game() -> void:
	request_quit()
	if is_inside_tree() and not Engine.is_editor_hint():
		get_tree().quit()


## A6 设置 → 状态自适应难度开关（R14.6⑧）：翻转大厅档布尔值并即时存档。
func toggle_dda() -> void:
	if meta == null:
		return
	meta.dda_state_adaptive_enabled = not meta.dda_state_adaptive_enabled
	SaveRepository.save_meta_file(meta)
	_render()


## A6 设置 → 主音量步进（±delta，钳制 0–100），立即作用于 Master 总线并持久化。
func step_master_volume(delta: int) -> void:
	if app_settings == null:
		return
	app_settings.master_volume = AppSettingsScript.clamp_volume(int(app_settings.master_volume) + delta)
	AppSettingsScript.save_settings(app_settings)
	_apply_master_volume()
	_render()


## A6 设置 → 分辨率循环切换（全屏 ↔ 各窗口档），立即作用于窗口并持久化。
func cycle_resolution() -> void:
	if app_settings == null:
		return
	app_settings.resolution_index = AppSettingsScript.next_resolution_index(int(app_settings.resolution_index))
	AppSettingsScript.save_settings(app_settings)
	_apply_window_mode()
	_render()


func _apply_master_volume() -> void:
	var percent := AppSettingsScript.clamp_volume(int(app_settings.master_volume)) if app_settings != null else 100
	if AudioServer.get_bus_count() < 1:
		return
	var bus := 0
	AudioServer.set_bus_mute(bus, percent <= 0)
	if percent > 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(float(percent) / 100.0))


func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var option: Dictionary = AppSettingsScript.resolution_at(int(app_settings.resolution_index)) if app_settings != null else {}
	if option.is_empty():
		return
	if bool(option.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size: Vector2i = option.get("size", Vector2i(1920, 1080))
		call_deferred("_deferred_set_window_size", size)


func _deferred_set_window_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)


## 大厅内部子视图切换（A3 流派 / A4 契约 / A5 图鉴 / A6 设置 / A7 手记）。
## 仅改展示层 `_hall_subview`，不触碰领域状态；A2 主界面为默认根。
func _show_hall_subview(subview: String) -> void:
	if _view_name != "Title":
		return
	_hall_subview = subview
	_render()


# R-opening-fairness 2026-08-27: runs started without a school pick used to
# enter the guaranteed layer-one combat with a one-card deck (novice only),
# which was unwinnable against reaction-guarded enemies. The wanderer pack
# (bind/guard/heal/scout/mobility) makes the opening fight winnable without
# visiting a shop first. Pools stay school-agnostic: state.school remains "".
const WANDERER_STARTER_GU_IDS := [
	"thorn_whip_gu",
	"stone_shell_gu",
	"bear_strength_gu",
	"trail_eye_gu",
	"mist_step_gu",
]


func _inject_school_starters(school: String) -> void:
	var schools: Dictionary = catalog.get("schools", {})
	var starters: Array = WANDERER_STARTER_GU_IDS if school.is_empty() \
		else (schools.get(school, {}).get("starter_gu_ids", []) as Array)
	var before := {"school": str(state.school)}
	if not school.is_empty():
		state.school = school
	var injected: Array[String] = []
	for starter_value in starters:
		var gu_id := str(starter_value)
		# Starter packs may intentionally contain duplicates (e.g. two moonlight gu).
		# Only skip when the existing instance count already satisfies this pack's
		# requested multiplicity.
		var existing_count := 0
		for instance_value in state.gu_instances.values():
			if str((instance_value as Dictionary).get("definition_id", "")) == gu_id:
				existing_count += 1
		var requested_count := 0
		for prior_value in starters:
			if str(prior_value) == gu_id:
				requested_count += 1
		if existing_count >= requested_count:
			continue
		var instance_id := _next_gu_instance_id(state)
		state.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": gu_id,
			"state": "refined",
		}
		state.cave_aperture["stored_gu_instance_ids"].append(instance_id)
		injected.append(str(gu_id))
		state.sync_legacy_gu_projections()
	var after := {
		"school": str(state.school),
		"gu_instances": state.gu_instances.duplicate(true),
		"cave_aperture": state.cave_aperture.duplicate(true),
	}
	var next := state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "school_selected",
		"before": before,
		"after": after,
		"reason": "school_starters_injected",
		"source": "run_controller",
		"targets": injected,
	})
	next.sync_legacy_gu_projections()
	state = next


func _next_gu_instance_id(state_ref: RunState) -> String:
	return RunState.next_gu_instance_id(state_ref.gu_instances)


# C1-min §16.13: opening swears ride the same Resolver.apply path as every
# other command; the allowed whitelist comes from the hall save so locked
# contracts are refused with an explicit reason feed. After a successful
# swear the aggregate may include a starter_stone contract; we lift the
# opening meta stone above that floor and emit one opening_contract_effects
# event so journal and replay see the same source.
func _swear_opening_contracts(contract_ids: Array) -> void:
	if contract_ids.is_empty():
		return
	var allowed: Array = []
	if meta != null and meta.has_method("unlocked_contracts"):
		allowed = meta.unlocked_contracts(catalog)
	var resolved := Resolver.apply(state, {
		"type": "swear_contracts",
		"ids": contract_ids,
		"allowed_ids": allowed,
	}, catalog)
	var succeeded := bool(resolved["result"].get("ok", false))
	state = resolved["state"]
	if not succeeded:
		last_feedback = "契约被拒：%s。" % str(resolved["result"].get("reason", ""))
		return
	var totals := ContractRulesScript.aggregate(state, catalog)
	var starter_floor := int(totals.get("starter_stone", 0))
	if starter_floor > state.stone:
		var before := int(state.stone)
		state = state.append_event({
			"stage": state.stage,
			"time": state.event_log.size(),
			"node_id": state.current_node_id,
			"action": "opening_contract_effects",
			"before": {"stone": before},
			"after": {"stone": starter_floor},
			"reason": "starter_stone_applied",
			"source": "run_controller",
			"targets": contract_ids,
		})
		state.stone = starter_floor
	last_feedback = "已立誓契约。"


func _start_run_from_title() -> void:
	if _view_name == "Title":
		start_new_run(roll_seed(), _selected_school)


static func roll_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 2147483647)


static func _run_end_outcome(outcome: String) -> String:
	match outcome:
		"success", "ascension_special", "ascension_high", "ascension_medium", "ascension_low":
			return "won"
		"risky_success": return "risky"
		"surrendered": return "abandoned"
	return "dead"


func _show_map() -> void:
	_view_name = "Map"
	_render()


func _show_encounter() -> void:
	_view_name = "Encounter"
	_render()


func _show_shop() -> void:
	_view_name = "Shop"
	_render()


func _show_rest() -> void:
	_view_name = "Rest"
	_render()


func _show_refine() -> void:
	_view_name = "Refine"
	_render()


func _show_reward() -> void:
	_view_name = "Reward"
	_render()


func _show_npc() -> void:
	_view_name = "Npc"
	_render()


## 会话未完成时按当前屏留在原地（T4 节点屏替代 Encounter 通用展示）。
func _re_show_current_screen() -> void:
	match _view_name:
		"Shop": _show_shop()
		"Rest": _show_rest()
		"Refine": _show_refine()
		"Npc": _show_npc()
		_: _show_encounter()


func _show_battle() -> void:
	_view_name = "Battle"
	_render()


func _continue_saved_run() -> void:
	if not FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH):
		return
	if not _restore_game(SaveRepositoryScript.load_run()):
		_show_title()


## 批 E：主动投降（流程图 Z3 三类出口之一）。二次确认由地图屏确认框承担；
## 走统一结算模块（ending_type: abandoned），Run 存档随结算删除。
func surrender_run() -> void:
	if state == null or state.is_terminal():
		return
	current_battle = {}
	current_session = {}
	last_battle_loot = {}
	last_battle_cost = {}
	_record_run_end("surrendered", "abandoned")
	_show_ending({
		"outcome": "surrendered",
		"conditions": {},
	})


func _show_ending(outcome: Dictionary) -> void:
	var otype := str(outcome.get("outcome", ""))
	_record_run_end(_run_end_outcome(otype), RunSnapshotBuilderScript.ending_type_for(otype))
	_ending_state = RunSnapshotBuilderScript.ending(self, outcome, JournalBuilder.build(state, outcome), state.to_save_data())
	_view_name = "Ending"
	_render()


func _show_death(report: Dictionary) -> void:
	_record_run_end("dead", "death")
	# T5-B 结算联动：战斗死亡与 builder 路径共用精准死因三字段（只读扫描终局字段）。
	var cause: Dictionary = RunSnapshotBuilderScript.death_cause_fields(state)
	# T5-C 结算复盘：战斗死亡内联结算与 builder ending() 同形（路线/记录/最高转数/达成链）。
	var death_state := {
		"title": "身死道消",
		"ending_type": "death",
		"death_cause_id": str(cause["id"]),
		"death_cause": str(cause["text"]),
		"death_cause_short": str(cause["short"]),
		"key_decisions": ["最后一击：%s" % RunSnapshotBuilderScript.blow_text(str(report.get("final_blow", "")))],
		"gains_losses": "最后一击：%s（%d 点伤害）" % [RunSnapshotBuilderScript.blow_text(str(report.get("final_blow", ""))), int(report.get("damage", 0))],
		"resource_balance": {"yuanstone": int(state.stone), "shouyuan": int(state.cultivator.get("lifespan", 0))},
		"unlocks": [],
		"aftermath": "残魂归于大地，修行札记已留存。",
	}
	death_state.merge(RunSnapshotBuilderScript.settlement_extras(self))
	death_state["achievement"] = DisplayText.ending_achievement("death")
	_ending_state = death_state
	_view_name = "Ending"
	_render()


func _record_run_end(outcome: String, ending_type := "") -> void:
	if meta == null:
		return
	meta = meta.record_run_end(state, outcome, catalog if catalog != null else {}, ending_type)
	SaveRepository.save_meta_file(meta)


func _node_by_id(node_id: String) -> Dictionary:
	for node in route:
		if node["id"] == node_id:
			return node.duplicate(true)
	return {}


func _complete_current_node(outcome: String) -> void:
	if current_node.is_empty():
		return
	var completed := Resolver.apply(state, {
		"type": "complete_node",
		"node_id": current_node["id"],
		"outcome": outcome,
	}, catalog)
	state = completed["state"]


func _return_to_map() -> void:
	current_battle = {}
	current_node = {}
	current_session = {}
	_show_map()


func _finish_battle_in_session(outcome: String) -> void:
	var kill_source := str(current_battle.get("kill_source", ""))
	var enemy_kind := str(current_battle.get("enemy_kind", ""))
	var battle_loot: Dictionary = current_battle.get("loot", {})
	var battle_cost: Dictionary = current_battle.get("cost", {})
	current_battle = {}
	current_session = current_session.duplicate(true)
	current_session["phase"] = "post_battle"
	var feed := ResultFeedScript.entry("battle", "battle_%s" % outcome, {}, [])
	var results := state.encounter_results.duplicate(true)
	if outcome == "victory" and not battle_loot.is_empty():
		var loot_labels: Array[String] = []
		for material_value in battle_loot.get("material_ids", []):
			loot_labels.append(DisplayText.material(str(material_value)))
		var loot_gu := str(battle_loot.get("gu_id", ""))
		if not loot_gu.is_empty():
			loot_labels.append(DisplayText.gu(loot_gu))
		if not loot_labels.is_empty():
			results.append(ResultFeedScript.entry("battle", "battle_loot", {"loot_display": "、".join(loot_labels)}, []))
	# R5.2 elite cost transparency: the bound cost is shown with exact numbers.
	if outcome == "victory" and not battle_cost.is_empty():
		results.append(ResultFeedScript.entry(
			"battle",
			"elite_cost_applied",
			{"cost_display": DisplayText.elite_cost(battle_cost), "cost_kind": str(battle_cost.get("kind", ""))},
			[]
		))
	if outcome == "victory" and enemy_kind == "miasma_vein_lord":
		results.append(ResultFeedScript.entry("battle", "lifespan_milestone_gained", {}, []))
	results.append(feed)
	state = state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "battle_finished",
		"before": {},
		"after": {"encounter_session": current_session, "encounter_results": results},
		"reason": "battle_%s" % outcome,
		"source": "run_controller",
		"targets": [],
	})
	if outcome == "victory" and kill_source == "neutral_npc":
		state = Resolver.apply(state, {"type": "record_neutral_npc_kill"}, catalog)["state"]
	# 拓扑 v2：关底 Boss 按层落旗标（boss_defeated_L{n} 是下一大层的行进门禁）；
	# 大层五的瘴脉之主同时保留全局 boss_defeated（升仙窗门禁，语义不变）。
	if outcome == "victory":
		var layer_boss := int(current_node.get("layer_boss", 0))
		if layer_boss > 0:
			state = Resolver.apply(state, {"type": "record_layer_boss_defeated", "layer": layer_boss}, catalog)["state"]
		if enemy_kind == "miasma_vein_lord":
			state = Resolver.apply(state, {"type": "record_boss_defeated"}, catalog)["state"]
	# D3 战利品弹窗（流程图 G3）：有真实战利品或精英绑定时走 Reward 屏确认，
	# 纯文本 feed 仍保留在遭遇结果流（两处同源，不双份入账）。
	last_battle_loot = battle_loot
	last_battle_cost = battle_cost if outcome == "victory" else {}
	if outcome == "victory" and (not battle_loot.is_empty() or not last_battle_cost.is_empty()):
		_show_reward()
		return
	_show_encounter()


func _record_dialogue_reply(result: Dictionary) -> void:
	var reply: Variant = result.get("dialogue", {})
	if not reply is Dictionary or reply.is_empty():
		return
	var payload: Dictionary = reply.duplicate(true)
	payload.erase("source")
	if DialogueGateway.is_valid_response(payload):
		dialogue_replies.append(payload)


func _attach_social_dialogue(result: Dictionary) -> void:
	var action_id := str(result.get("action_id", ""))
	if action_id not in ["probe", "trade"] or _dialogue_gateway == null:
		return
	var social: Dictionary = state.relations.get("caravan_steward", {})
	result["dialogue"] = _dialogue_gateway.respond({
		"intent": action_id,
		"disposition": str(social.get("npc_disposition", "neutral")),
	})


# ----------------------------------------------------------------------------
# RUI 渲染层：单根挂载，按 _view_name 渲染对应屏；仅经 commands 提交领域命令。
# ----------------------------------------------------------------------------

func _on_feedback_timer_timeout() -> void:
	last_feedback = ""
	_render_debug_panel()
	if _view_name in ["Map", "Title"]:
		_render()


func _restart_feedback_timer() -> void:
	if _feedback_timer == null:
		return
	_feedback_timer.stop()
	if last_feedback != "":
		_feedback_timer.start(FEEDBACK_TOAST_SECONDS)


func _render() -> void:
	if _rui_host == null:
		return
	_restart_feedback_timer()
	if not SCREEN_PATHS.has(_view_name):
		push_error("未知视图名: %s" % _view_name)
		_view_name = "ContentError"
	var snapshot: Dictionary = _ending_state if _view_name == "Ending" else _snapshot_for(_view_name)
	_mount_screen(_view_name, snapshot, _build_commands(_view_name))
	if _view_name != _faded_view:
		_faded_view = _view_name
		_play_screen_fade()
	_render_debug_panel()


func _mount_screen(screen: String, snapshot: Dictionary, commands: Dictionary) -> void:
	var master_path := str(MASTER_SCENE_PATHS.get(screen, ""))
	if master_path != "":
		if _master_instance == null or not is_instance_valid(_master_instance) or _mounted_screen != screen:
			_unmount_rui_root()
			if _master_instance != null and is_instance_valid(_master_instance):
				_master_instance.queue_free()
			_master_instance = (load(master_path) as PackedScene).instantiate()
			_master_instance.name = "Wenzhen%sMaster" % screen
			_rui_host.add_child(_master_instance)
			_mounted_screen = screen
		if _master_instance.has_method("mount_snapshot"):
			_master_instance.mount_snapshot(snapshot, commands)
		return
	_unmount_master_instance()
	var comp := VLib.comp(SCREEN_PATHS[screen], "render")
	if not (comp is Callable):
		push_error("RUI 组件缺失: %s" % screen)
		return
	if _rui_root == null:
		_rui_root = RuiRoot.create(_rui_host, VLib.fc(comp, {"state": snapshot, "commands": commands}))
	else:
		_rui_root.set_root(VLib.fc(comp, {"state": snapshot, "commands": commands}))
	_mounted_screen = screen


func _unmount_rui_root() -> void:
	if _rui_root != null and _rui_root.has_method("unmount"):
		_rui_root.unmount()
	_rui_root = null


func _unmount_master_instance() -> void:
	if _master_instance != null and is_instance_valid(_master_instance):
		_master_instance.queue_free()
	_master_instance = null
	if _mounted_screen in MASTER_SCENE_PATHS:
		_mounted_screen = ""


func _exit_tree() -> void:
	_unmount_rui_root()
	_unmount_master_instance()


## T6-E 跨屏过渡：屏切换（含死亡返大厅）时对新挂载根做 140ms 一次性淡入
## （modulate 0→1）；同屏重渲染不触发，战斗/商店等连续操作零闪烁。
## 快速连切先杀上一条 Tween 防叠加；有限 Tween 播完即失效，无循环残留。
## RuitkRoot 无内置过渡 API，按简报裁定落在表现层控制器。
func _play_screen_fade() -> void:
	if _rui_host == null:
		return
	if _screen_tween != null and _screen_tween.is_valid():
		_screen_tween.kill()
	_rui_host.modulate.a = 0.0
	_screen_tween = create_tween()
	_screen_tween.tween_property(_rui_host, "modulate:a", 1.0, SCREEN_FADE_SECONDS)


func _snapshot_for(screen: String) -> Dictionary:
	return RunSnapshotBuilderScript.for_screen(screen, self)


func _build_commands(screen: String) -> Dictionary:
	return RunCommandBuilderScript.for_screen(screen, self)
