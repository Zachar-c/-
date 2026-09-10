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
const DialogueManagerAdapterScript = preload("res://scripts/domain/dialogue_manager_adapter.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const RunCommandBuilderScript = preload("res://scripts/presentation/run_command_builder.gd")
const AppSettingsScript = preload("res://scripts/domain/app_settings.gd")
# V1 battle lifecycle hook: battle2 ledger sits in the RunState for the
# duration of a single battle. Sized by CultivatorRules.thought_capacity and
# consumed by the battle facade on each accepted turn; finalised through
# the _battle2_ledger info key when the battle exits.
const Battle2TurnEngineScript = preload("res://scripts/domain/battle2/turn_engine.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")

## 全部屏已迁到 Godot 官方 .tscn 节点树（scenes/ui/screens/），RUITK 路由表
## 清空：_mount_screen() 只剩 .tscn 一条路径。表留在原位是「RUITK 屏必须为零」
## 的锚点——非空即代表有屏回退到 .guitkx。
const SCREEN_PATHS := {}
const MASTER_SCENE_PATHS := {
	"Title": "res://scenes/ui/screens/hall_screen.tscn",
	"Map": "res://scenes/ui/screens/map_screen.tscn",
	"Battle": "res://scenes/ui/screens/battle_screen.tscn",
	# 所有屏走同一套 instantiate + mount_snapshot 协议，本表即唯一路由表。
	"Shop": "res://scenes/ui/screens/shop_screen.tscn",
	"Rest": "res://scenes/ui/screens/rest_screen.tscn",
	"Reward": "res://scenes/ui/screens/reward_screen.tscn",
	"Npc": "res://scenes/ui/screens/npc_screen.tscn",
	"Encounter": "res://scenes/ui/screens/encounter_screen.tscn",
	"Refine": "res://scenes/ui/screens/refine_screen.tscn",
	"Ending": "res://scenes/ui/screens/ending_screen.tscn",
	"ContentError": "res://scenes/ui/screens/content_error_screen.tscn",
	"Kill": "res://scenes/ui/screens/kill_screen.tscn",
	"Settings": "res://scenes/ui/screens/settings_screen.tscn",
}

## 视图 → BGM 曲目映射（key 见 AudioDirector.BGM_PATHS，曲目由
## tools/generate_music.py 确定性合成）。探索/商店/休整/炼蛊/事件等屏共用 map。
const BGM_BY_VIEW := {
	"Title": "hall",
	"Map": "map",
	"Battle": "battle",
	"Ending": "ending",
}
const BGM_DEFAULT := "map"


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
## 覆盖屏（杀招/设置）的返回源视图。
var _overlay_return_view := "Title"
var _selected_school := "force"
# S2 开局 Buff：大厅多选暂存，run 创建时一次性结算。
var _selected_buffs: Array = []
# D1b 自由配对：炼蛊洞的主/辅蛊实例选择（屏内决策，经快照回显）。
var _selected_pair_main := ""
var _selected_pair_partner := ""
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
# V-F-05 batch19: full-screen transition for major scene changes (TransitionLayer/TransitionVeil).
var _veil: ScreenTransition
var _prev_major_scene := false

# ----------------------------------------------------------------------------
# §16.22 D5 开发者调试（仅开发构建）：整条链路以 is_debug_build 门控，Release 下
# 面板零节点存在、方法全部早退。调试写操作只落本局 RunData、绝不触碰大厅存档；
# 加蛊走与 Resolver 同源的 DeckCapacity 正式容量校验；资源钳制到合法区间；
# 全部操作 print 带 [debug] 前缀可追溯。按简报裁定：调试操作不写事件日志。
# W12 split: 常量与方法体迁至 run_debug_facade.gd，此处只留门控开关与面板节点状态。
# ----------------------------------------------------------------------------

## 测试注入开关：默认跟随构建类型（GUT/编辑器为 true，Release 导出为 false）。
var _debug_enabled_for_test: bool = OS.is_debug_build()
var _debug_panel_open := false
var _debug_panel: Control = null
var _debug_host: Control = null
var _debug_gu_school := "blood"
var _debug_gu_selected := ""
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
	if _rui_host != null and is_instance_valid(_rui_host):
		return
	_initialize_view_flow()


func _initialize_view_flow() -> void:
	# 大厅子视图（流派/契约/图鉴）只读快照依赖 catalog；启动即加载内容表，
	# 否则选流派前列表恒为空（2026-08-27 实机走查断点）。
	catalog = ContentCatalog.load_all()
	_content_errors = ContentCatalog.validate(catalog)
	# 渲染文案表预热：此后 DisplayText 运行时不再直读 data/*.json（2026-09-09 W6）。
	DisplayText.prime_from_catalog(catalog)
	app_settings = AppSettingsScript.load_settings()
	# 仅在玩家显式保存过偏好时才施加引擎副作用，首跑保持项目默认窗口。
	if AppSettingsScript.has_saved_file():
		_apply_master_volume()
		_apply_window_mode()
	_rui_host = Control.new()
	_rui_host.name = "RUIHost"
	_veil = get_node_or_null("../TransitionLayer/TransitionVeil")
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


func start_new_run(seed_value: int, school: String = "", contract_ids: Array = [], buff_ids: Array = []) -> void:
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
	_apply_run_buffs(buff_ids)
	_selected_contracts.clear()
	_selected_buffs.clear()
	# R-seed 2026-09-03（垂直切片裁定）：玩家局不设教学种子/固定种子——
	# 种子 101 不再映射手写 first_run 路线，任何一世都按传入种子生成地图；
	# first_run 手写图仅保留给 MapGenerator.build(..., true) 的测试夹具。
	route = MapGenerator.build(seed_value, false, catalog)
	current_node = {}
	current_battle = {}
	current_session = {}
	last_result = {}
	dialogue_replies = []
	_dialogue_gateway = DialogueManagerAdapterScript.new()
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
	if command.get("type", "") == "dialogue_branch":
		return _submit_dialogue_branch(command)
	# Event action cards are authored by ActionPreviewService for compatibility;
	# route their branch IDs through DialogueManagerAdapter before the generic
	# encounter-card path so narrative choices cannot silently leave the node.
	if command.get("type", "") == "action_card" and str(current_node.get("type", "")) == "event":
		return _submit_dialogue_branch({
			"type": "dialogue_branch",
			"branch_id": str(command.get("action_id", "")),
			"context": command.duplicate(true),
		})
	if command.get("type", "") == "leave_encounter":
		command = {"type": "leave_node"}
	if command.get("type", "") == "action_card" and not current_battle.is_empty():
		return _submit_battle_command(command)
	if command.get("type", "") in ["use_gu", "use_inheritance", "end_turn", "retreat", "basic_attack", "basic_dodge", "refine", "play_kill_move"] and not current_battle.is_empty():
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
	_sync_battle_hp_to_state()
	last_result = {"battle_result": turn.get("result", "ongoing"), "feeds": turn.get("feeds", [])}
	if bool(turn.get("finished", false)):
		if str(turn.get("result", "")) == "death":
			_show_death(DeathReportBuilderScript.build(current_battle, state))
		else:
			_finish_battle_in_session(str(turn.get("result", "")))
	else:
		_show_battle()
	return turn


## Dialogue Manager balloon 选择桥接入口（P1-1）：插件/UI 在标题变化
## （非入口 title，如 "echo_cave.accept"）时调用本方法，把选择标题转成
## dialogue_branch 领域命令提交，走与 submit_command 完全相同的结算路径。
func submit_dialogue_selection(selection_title: String) -> Dictionary:
	if str(selection_title).is_empty():
		return {"ok": false, "reason": "empty_dialogue_selection", "state": state}
	return _submit_dialogue_branch({
		"type": "dialogue_branch",
		"branch_id": str(selection_title),
		"state_version": state.event_log.size(),
	})


func _submit_dialogue_branch(command: Dictionary) -> Dictionary:
	if _dialogue_gateway == null:
		_dialogue_gateway = DialogueManagerAdapterScript.new()
	var branch_id := str(command.get("branch_id", ""))
	var branch_result: Dictionary = {}
	var branch_context: Dictionary = command.get("context", {}) if command.get("context", {}) is Dictionary else {}
	if command.has("state_version"):
		branch_context["state_version"] = command.get("state_version")
	if _dialogue_gateway.has_method("apply_branch"):
		branch_result = _dialogue_gateway.apply_branch(
			state,
			current_session,
			branch_id,
			catalog,
			current_node,
			branch_context
		)
	else:
		branch_result = {
			"ok": false,
			"reason": "dialogue_adapter_unavailable",
			"feedback": "对话暂时无法回应，局面没有改变。",
			"state": state,
			"session": current_session.duplicate(true),
			"result": {"ok": false, "reason": "dialogue_adapter_unavailable"},
		}
	state = branch_result.get("state", state)
	current_session = branch_result.get("session", current_session)
	last_result = branch_result.get("result", {})
	last_feedback = str(branch_result.get("feedback", ""))
	if last_feedback.is_empty() and not bool(branch_result.get("ok", false)):
		last_feedback = rejection_text(str(branch_result.get("reason", "unknown_dialogue_branch")))
	if bool(current_session.get("completed", false)):
		_return_to_map()
	else:
		_re_show_current_screen()
	return branch_result


## 战斗内 hp 写回 RunState：RunState.health 是本局气血唯一真值（resolver/shop/
## rest 全部写它），V1 战斗 hp 只活在 current_battle.player 里——每回合结算后
## 同步回写（含 cultivator 镜像），避免战后休整/服务读到陈旧 hp。
func _sync_battle_hp_to_state() -> void:
	if current_battle.is_empty():
		return
	var player: Dictionary = current_battle.get("player", {})
	if player.is_empty():
		return
	var hp := maxi(0, int(player.get("hp", state.health)))
	var max_hp := maxi(1, int(player.get("max_hp", state.max_health)))
	state.health = hp
	state.max_health = max_hp
	var cultivator: Dictionary = state.cultivator.duplicate(true)
	cultivator["health"] = hp
	cultivator["max_health"] = max_hp
	state.cultivator = cultivator


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
	"unknown_dialogue_branch": "无法理解这段对话的选择，局面没有改变。",
	"dialogue_branch_used": "这项对话选择已经处理过了。",
	"dialogue_adapter_unavailable": "对话暂时无法回应，局面没有改变。",
	"unknown_gu": "没有这只蛊。",
	"unknown_card": "没有这张卡。",
	"unknown_node": "无法前往该地点。",
	"node_not_reachable": "该地点与当前位置不连通。",
	"unknown_material": "没有这种材料。",
	"material_not_usable": "这种材料不能直接使用。",
	"no_material_to_use": "身上没有这种材料。",
	"material_use_lethal": "直接使用会耗尽气血，被拒绝。",
	# T9.2 v2 command rejection texts.
	"too_early_first_layer": "尚在第一大层前段，稍后才能确认核心。",
	"core_already_confirmed": "本局已有一只核心蛊。",
	"instance_missing": "没有这只蛊实例。",
	"replace_limit_reached": "本局核心更换次数已达上限。",
	"guarantee_replaced_with_peer_reward": "已更换过核心，此处改发同级收益。",
	"no_token_on_node": "此处没有核心更换凭证。",
	"buyer_already_paid": "这位买家已为这条消息付过费。",
	"insufficient_thought": "念头不足。",
	"gu_already_used_this_turn": "这只蛊本回合已催动过。",
	"maintenance_blocks_activation": "维持中的蛊本回合不可再催动。",
	"action_already_used_this_turn": "这个基础动作本回合已用过。",
	"unknown_action": "未知的基础动作。",
	"unknown_proposal_kind": "未知的编排提案。",
	"parallel_group_repeats_action": "并行组重复了动作种类。",
	"parallel_group_repeats_instance": "并行组重复了蛊实例。",
	"no_thought": "没有可用的念头。",
	"window_closed": "反应窗口已关闭。",
	"dodge_not_allowed": "这次攻击不容许闪避。",
	"grappled_blocks_dodge": "被擒抱时无法闪避。",
	"bound_blocks_dodge": "被束缚时无法闪避。",
	"terrain_restricted": "地形限制无法闪避。",
	"not_at_contact": "不在接触距离，无法发起擒抱。",
	"not_stronger": "力量不足，擒抱未能成立。",
	"no_reserved_thought": "没有预留念头发起反应。",
	"not_a_legal_reaction": "这不是合法的脱离反应。",
	"insufficient_health": "气血不足，不能支付该代价。",
	"bleed_rank_exceeds_cultivator": "不能凝炼高于自身转数的血气。",
	"soulless_target": "这个目标没有魂魄。",
	"no_means_declared": "没有声明收魂手段。",
	"means_capacity_full": "收魂手段容量已满。",
	"soul_yield_zero": "此次收魂没有收益。",
	# D1b 古方知识模型：自由配对合炼拒绝/失败文案。
	"free_pair_failed": "合炼失败：主蛊受伤（休整可愈），元石已耗。",
	"pair_invalid": "这对蛊虫无法入炉（预检未通过）。",
	"gu_fang_already_unlocked": "你已持有该古方。",
	"gu_fang_unknown": "没有这张古方对应的蛊。",
	"refinement_capacity_exceeded": "炼蛊需要至少保留两处空位，当前不足。",
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


## W12 split: save/load lifecycle moved to run_save_flow.gd. Same-name
## one-line wrappers keep the public API and internal call sites unchanged.
func save_and_leave_map() -> void:
	RunSaveFlow.save_and_leave_map(self)


func leave_map_without_save() -> void:
	RunSaveFlow.leave_map_without_save(self)


func save_current_run() -> Error:
	return RunSaveFlow.save_current_run(self)


func load_saved_run() -> bool:
	return RunSaveFlow.load_saved_run(self)


func _save_load_feedback(diagnosis: Dictionary) -> String:
	return RunSaveFlow._save_load_feedback(diagnosis)


func _restore_game(loaded: Dictionary) -> bool:
	return RunSaveFlow._restore_game(self, loaded)


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
	# E4a：新探访开始，炼蛊子屏状态复位（上一个休息探访的子屏语境不残留）。
	_refine_from_rest = false
	_refine_initial_channel = ""
	if node["type"] in ["combat", "pursuit"]:
		_start_battle()
	elif node["type"] in ["shop", "market", "caravan"]:
		_show_shop()
	elif node["type"] in ["rest", "refinement", "cultivation"]:
		# E4a 三选一（规格 §4）：三个休息类模板统一 _show_rest()；refinement
		# 不再单独走 Refine 屏——炼蛊经休息屏「炼蛊」卡以子屏方式进入。
		_show_rest()
	elif node["type"] == "contact":
		_show_npc()
	else:
		if node["type"] == "event" and _dialogue_gateway != null and _dialogue_gateway.has_method("begin"):
			# P1-2 路由：事件入口 Dialogue title 由节点声明（dialogue_title），默认 "start"；
			# gu_rot_pact 等事件使用专属 title，不再全部从 echo_cave 的 start 打开。
			_dialogue_gateway.begin(
				str(node.get("event_id", node.get("id", ""))),
				str(node.get("dialogue_title", "start"))
			)
			# P1-B 接线：Dialogue Manager 的 passed_title（玩家点选项跳转 title）
			# 转发到 submit_dialogue_selection，走统一命令结算路径。绑定 Callable
			# 使 controller 释放后回调自动失效，避免跨测试的信号串扰。
			if _dialogue_gateway.has_method("set_branch_selection_callback"):
				_dialogue_gateway.set_branch_selection_callback(
					Callable(self, "submit_dialogue_selection"))
		_show_encounter()
	return resolved["result"]


# ----------------------------------------------------------------------------
# §16.22 D5 调试方法族（全部 is_debug_build 门控早退；只写本局 RunData；
# 不写事件日志、不碰大厅存档；print 带 [debug] 前缀可追溯）。
# W12 split: implementation moved to run_debug_facade.gd; the is_debug_build
# gate stays here (`_debug_enabled_for_test`, initialized from
# OS.is_debug_build) and the facade reads it through _debug_enabled(self).
# Same-name one-line wrappers keep the public API and test call sites.
# ----------------------------------------------------------------------------

func _debug_enabled() -> bool:
	return RunDebugFacade._debug_enabled(self)


func debug_panel_mounted() -> bool:
	return RunDebugFacade.debug_panel_mounted(self)


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
	return RunDebugFacade.debug_add_gu(self, gu_id)


func debug_set_resource(kind: String, value) -> Dictionary:
	return RunDebugFacade.debug_set_resource(self, kind, value)


func debug_travel(node_id: String) -> Dictionary:
	return RunDebugFacade.debug_travel(self, node_id)


func debug_snapshot_dump() -> Dictionary:
	return RunDebugFacade.debug_snapshot_dump(self)


## 调试面板跳层下拉选项：仅当前可见节点（防越层破坏地图不变量）。
func _debug_travel_options() -> Array[Dictionary]:
	return RunDebugFacade._debug_travel_options(self)


func _debug_props() -> Dictionary:
	return RunDebugFacade._debug_props(self)


## 加蛊下拉 · 流派列表：目录 schools 顺序即展示顺序，label 用流派中文名。
func _debug_gu_schools() -> Array[Dictionary]:
	return RunDebugFacade._debug_gu_schools(self)


## 加蛊下拉 · 蛊虫选项：按所选流派过滤目录，label 用蛊虫中文名（DisplayText 同源）。
func _debug_gu_options(school_id: String) -> Array[Dictionary]:
	return RunDebugFacade._debug_gu_options(self, school_id)


func _set_debug_gu_school(value: String) -> void:
	RunDebugFacade._set_debug_gu_school(self, value)


func _set_debug_gu_option(value: String) -> void:
	RunDebugFacade._set_debug_gu_option(self, value)


func _set_debug_res_kind(value: String) -> void:
	RunDebugFacade._set_debug_res_kind(self, value)


func _set_debug_res_value(value: String) -> void:
	RunDebugFacade._set_debug_res_value(self, value)


func _set_debug_travel_node(value: String) -> void:
	RunDebugFacade._set_debug_travel_node(self, value)


func _toggle_debug_panel() -> void:
	RunDebugFacade._toggle_debug_panel(self)


func _mount_debug_panel() -> void:
	RunDebugFacade._mount_debug_panel(self)


func _debug_host_size() -> Vector2:
	return RunDebugFacade._debug_host_size(self)


func _render_debug_panel() -> void:
	RunDebugFacade._render_debug_panel(self)


func _debug_ok(feedback: String) -> Dictionary:
	return RunDebugFacade._debug_ok(self, feedback)


func _debug_fail(reason: String) -> Dictionary:
	return RunDebugFacade._debug_fail(self, reason)


func _debug_fail_with(reason: String, feedback: String) -> Dictionary:
	return RunDebugFacade._debug_fail_with(self, reason, feedback)


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
		# Boss 身份透传：关底台（layer_boss_stand_N / final_boss_stand）必须让
		# facade 知道这是 Boss 战（flags.boss_battle），否则退避门禁与 UI 全失效。
		"layer_boss": int(current_node.get("layer_boss", 0)),
		"terrain": _battle_terrain(),
		"first_mover": first_mover,
		"kill_source": kill_source,
	}
	if current_node.has("enemy_kinds"):
		encounter["enemy_kinds"] = (current_node.get("enemy_kinds", []) as Array).duplicate()
	else:
		encounter["enemy_kind"] = enemy_kind
	# V1 battle2 ledger hook: seed a fresh per-battle ledger sized by the
	# current cultivator's thought capacity. The battle facade advances it on
	# each accepted turn and finalises it on the exit info key.
	state.current_battle2_ledger = Battle2TurnEngineScript.new_turn(
		CultivatorRulesScript.thought_capacity(state.cultivator, catalog)
	)
	current_battle = BattleCommandFacadeScript.start(encounter, state, catalog)
	# N6: weaknesses procured through probe carry into the battle as bonus damage.
	if state.known_facts.has("procured_weakness"):
		current_battle["intel_bonus"] = 1
	if first_mover == "enemy":
		# 敌方本回合全部存活意图的伤害总和（围攻节点多名敌人叠伤，单看
		# 单个 intent 会漏判致死）。V1 契约：意图在 enemies[].intent。
		var opening_damage := 0
		for enemy_value in current_battle.get("enemies", []):
			opening_damage += maxi(0, int(((enemy_value as Dictionary).get("intent", {}) as Dictionary).get("damage", 0)))
		# 2 低血进敌方先手战（死亡可预见红线）：先手意图本会在本帧无条件结算，
		# 低血玩家入屏即死、无从反应。致死开场不自动结算——先亮意图 + 致命
		# 警告（快照 lethal_warning + 战斗日志），把敌方先手延后到玩家首个回合
		# 结束；意图与后续掷骰序列不变，全确定性。玩家可守护/闪避/治疗自救；
		# 未自救仍由常规结算致死并走统一 DeathReport（击杀意图由战斗日志归因）。
		var lethal_opening := opening_damage > 0 and state.health <= opening_damage
		if lethal_opening:
			# V1 flags 是 Dictionary（禁止 Array 型 flags）。
			(current_battle["flags"] as Dictionary)["opening_lethal"] = true
			current_battle["log"].append({"id": "opening_lethal_warning", "damage": opening_damage})
			_show_battle()
			return
		var pre := BattleCommandFacadeScript.apply_enemy_pre_turn(current_battle, state, catalog)
		state = pre["state"]
		current_battle = pre["battle"]
		_sync_battle_hp_to_state()
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
# makes the opening fight winnable without visiting a shop first. Pools stay
# school-agnostic: state.school remains "".
# 802 catalog 重建后（2026-09-06）原包 thorn_whip/trail_eye/mist_step 已删，
# 依「机制角色映射」自拟新包（全部 rank1 且 combat 字段非空，V1 槽位可打）：
#   缚=blood_farewell_gu  守=stone_shell_gu  吸/blood_bat_gu  攻=force_gu  察=small_light_gu
# legacy deck 契约仍含 stone_guard（stone_shell_gu blueprint）。
const WANDERER_STARTER_GU_IDS := [
	"blood_farewell_gu",
	"stone_shell_gu",
	"blood_bat_gu",
	"force_gu",
	"small_light_gu",
]


## S2 开局 Buff：选中的 Buff 在 run 创建时一次性结算（多选、本切片无限量）。
## grant_stones 直接加元石；grant_gu 按实例注入洞天；enemy_hp_one 由
## BattleCommandFacade.start 在战斗构建时消费（非 Boss 敌 hp=1）。
func _apply_run_buffs(buff_ids: Array) -> void:
	var buffs: Dictionary = catalog.get("buffs", {})
	var applied: Array[String] = []
	var before := {"stone": int(state.stone), "gu_instances": state.gu_instances.size()}
	for raw_id in buff_ids:
		var buff_id := str(raw_id)
		var bdata: Dictionary = buffs.get(buff_id, {})
		if bdata.is_empty():
			continue
		applied.append(buff_id)
		state.run_buff_ids.append(buff_id)
		match str(bdata.get("effect", "")):
			"grant_stones":
				state.stone = int(state.stone) + int(bdata.get("amount", 0))
			"grant_gu":
				var gu_id := str(bdata.get("gu_id", ""))
				if not gu_id.is_empty() and catalog.get("gu_by_id", {}).has(gu_id):
					var instance_id := _next_gu_instance_id(state)
					state.gu_instances[instance_id] = GuInstanceScript.new_instance(gu_id, instance_id, catalog)
					state.cave_aperture["stored_gu_instance_ids"].append(instance_id)
				state.sync_legacy_gu_projections()
	if applied.is_empty():
		return
	state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "run_buffs_applied",
		"before": before,
		"after": {
			"stone": int(state.stone),
			"gu_instances": state.gu_instances.size(),
			"run_buff_ids": state.run_buff_ids.duplicate(),
		},
		"reason": "opening_buffs_settled",
		"source": "run_controller",
	})


func _toggle_buff(buff_id: String) -> void:
	var bid := str(buff_id)
	if not catalog.get("buffs", {}).has(bid):
		return
	if _selected_buffs.has(bid):
		_selected_buffs.erase(bid)
	else:
		_selected_buffs.append(bid)


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
		state.gu_instances[instance_id] = GuInstanceScript.new_instance(gu_id, instance_id, catalog)
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
	# 自由配对的选择自净：被消耗/已死的实例选择直接作废。
	var alive := {}
	for keep_id in state.cave_aperture.get("stored_gu_instance_ids", []):
		alive[str(keep_id)] = true
	if not alive.has(_selected_pair_main):
		_selected_pair_main = ""
	if not alive.has(_selected_pair_partner):
		_selected_pair_partner = ""
	_view_name = "Refine"
	_render()


# E4a 炼蛊子屏（规格 §4）：休息探访内经「炼蛊」卡打开 Refine 视图；
# 子屏的「离开」不提交 leave_encounter，而是退回休息屏继续三选一。
var _refine_from_rest := false
var _refine_initial_channel := ""


## 从休息屏打开炼蛊子屏；channel 非空时预选通道（如 free_pair 自由配对）。
func open_refine_subview(channel := "") -> void:
	_refine_from_rest = true
	_refine_initial_channel = str(channel)
	_show_refine()


## 关闭炼蛊子屏并回到休息屏（同一探访会话，不发领域命令）。
func close_refine_subview() -> void:
	_refine_from_rest = false
	_refine_initial_channel = ""
	_show_rest()


## D1b 自由配对：炼蛊洞屏内选择，只改展示状态，经快照回显。
func select_pair_main(instance_id: String) -> void:
	if state != null and state.gu_instances.has(instance_id):
		_selected_pair_main = instance_id


func select_pair_partner(instance_id: String) -> void:
	if state != null and state.gu_instances.has(instance_id):
		_selected_pair_partner = instance_id


func _show_reward() -> void:
	_view_name = "Reward"
	_render()


func _show_npc() -> void:
	_view_name = "Npc"
	_render()


## 覆盖屏统一切换：记录返回源，再挂载目标屏。
func _show_kill() -> void:
	_overlay_return_view = _view_name
	_view_name = "Kill"
	_render()


func _show_settings() -> void:
	_overlay_return_view = _view_name
	_view_name = "Settings"
	_render()


func back_from_overlay() -> void:
	match _overlay_return_view:
		"Map": _show_map()
		"Battle": _show_battle()
		_:
			_hall_subview = "main"
			_show_title()


## 设置屏 → 分辨率：直接设为指定档（区别于大厅的 cycle_resolution 循环）。
func set_resolution_index(index: int) -> void:
	if app_settings == null:
		return
	if int(index) < 0 or int(index) >= AppSettingsScript.RESOLUTIONS.size():
		return
	app_settings.resolution_index = int(index)
	AppSettingsScript.save_settings(app_settings)
	_apply_window_mode()
	_render()


## 设置屏 → 静音切换：0 ↔ 原音量（0 记入 app_settings 原值旁置 100）。
func toggle_mute() -> void:
	if app_settings == null:
		return
	var current := AppSettingsScript.clamp_volume(int(app_settings.master_volume))
	if current > 0:
		app_settings.pre_mute_volume = current
		app_settings.master_volume = 0
	else:
		app_settings.master_volume = AppSettingsScript.clamp_volume(int(app_settings.pre_mute_volume))
	AppSettingsScript.save_settings(app_settings)
	_apply_master_volume()
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
	# 结局即此世终点（AGENTS）：结算时删除进行中 Run 存档，使大厅
	# 「续入此世」不再回到已结束的旧档；下一世从大厅进入时以全新
	# 随机种子开局。删除放在 meta 判空前，确保任何结局路径都清理。
	SaveRepositoryScript.delete_run_save()
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
	# 胜负已分、对峙结束：战后立场归位。否则 extreme_hostile 遭遇在战斗胜利后
	# 仍被 _leave 的 feud_no_escape 锁死（打赢 Boss 却永远离不了场 = 软锁）。
	# feud 门禁只应在战斗前阻止「不战而逃」，不适用于已结算的战斗。
	current_session["stance"] = "neutral"
	if current_session.has("flags") and current_session["flags"] is Dictionary:
		current_session["flags"].erase("reputation_hostile")
		current_session["flags"].erase("reputation_extreme")
	var feed := ResultFeedScript.entry("battle", "battle_%s" % outcome, {}, [])
	var results := state.encounter_results.duplicate(true)
	# V1 battle2 ledger hook: capture the consumed ledger snapshot now and
	# ride it on the final battle_finished event's info key below (V1
	# retreat / death / victory bypass the engine's _battle_over funnel,
	# so the controller writes the info key itself; the old per-turn
	# _battle2_ledger info events are now redundant but kept for parity).
	var ledger_snapshot: Dictionary = {}
	if not state.current_battle2_ledger.is_empty():
		ledger_snapshot = state.current_battle2_ledger.duplicate(true)
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
	# V1 battle2 ledger hook: attach the captured ledger snapshot onto the
	# final battle_finished event's info key (the V1 engine funnel is
	# bypassed for the controller-driven retreat / death / victory exits,
	# so the controller writes the info key itself).
	var finished_event: Dictionary = {
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "battle_finished",
		"before": {},
		"after": {"encounter_session": current_session, "encounter_results": results},
		"reason": "battle_%s" % outcome,
		"source": "run_controller",
		"targets": [],
	}
	if not ledger_snapshot.is_empty():
		finished_event["info"] = {"_battle2_ledger": ledger_snapshot.duplicate(true)}
	state = state.append_event(finished_event)
	# V1 battle2 ledger hook: clear the per-battle handle on the surviving
	# state immediately after the snapshot rides the event. Future calls
	# into _start_battle reseed.
	state.current_battle2_ledger = {}
	if outcome == "victory" and kill_source == "neutral_npc":
		state = Resolver.apply(state, {"type": "record_neutral_npc_kill"}, catalog)["state"]
	# 拓扑 v2：关底 Boss 按层落旗标（boss_defeated_L{n} 是下一大层的行进门禁）；
	# 大层五的瘴脉之主同时保留全局 boss_defeated（升仙窗门禁，语义不变）。
	if outcome == "victory":
		var layer_boss := int(current_node.get("layer_boss", 0))
		if layer_boss > 0:
			state = Resolver.apply(state, {"type": "record_layer_boss_defeated", "layer": layer_boss}, catalog)["state"]
			# S6 切片收官：pacing.ending_after_stage 指定的最终层 Boss 落败即
			# 全局收官（本切片 = 第一层），走统一结算（outcome=success → won），
			# Run 存档随结算删除；战利品已入账，结算复盘给出整局摘要。
			var end_stage := str(catalog.get("pacing", {}).get("ending_after_stage", ""))
			var order: Array = MapGenerator.LAYER_ORDER
			var boss_stage := str(order[layer_boss - 1]) if layer_boss >= 1 and layer_boss <= order.size() else ""
			if not end_stage.is_empty() and boss_stage == end_stage:
				state.terminal_state = "success"
				_show_ending({"outcome": "success", "conditions": {"layer": layer_boss, "route": "slice_closure"}})
				return
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
	# 两张路由表都要认：_mount_screen() 是 MASTER_SCENE_PATHS 优先、SCREEN_PATHS 兜底，
	# 只查 SCREEN_PATHS 会把已迁到 .tscn 的屏全误判成未知视图名并跳 ContentError
	# （这个 bug 曾让已迁移的 Shop / Rest / Reward / Npc / Encounter / Refine / Ending
	# 在真实流程里全部降级，而 smoke_render / playthrough / GUT 都没抓到）。
	if not (SCREEN_PATHS.has(_view_name) or MASTER_SCENE_PATHS.has(_view_name)):
		push_error("未知视图名: %s" % _view_name)
		_view_name = "ContentError"
	var snapshot: Dictionary = _ending_state if _view_name == "Ending" else _snapshot_for(_view_name)
	_mount_screen(_view_name, snapshot, _build_commands(_view_name))
	_sync_bgm()
	if _view_name != _faded_view:
		_faded_view = _view_name
		# V-F-05 batch19: full-screen blink for Battle/Ending/Title in/out;
		# same-screen re-render and ordinary screen switches keep the RUIHost fade only.
		var major := _view_name in ["Battle", "Ending", "Title"]
		if (major or _prev_major_scene) and _veil != null:
			_veil.blink()
		_prev_major_scene = major
		_play_screen_fade()
	_render_debug_panel()


## 视图切换时同步 BGM：AudioDirector 缺失（单测直调树）或资源未落地时
## 静默跳过；同屏命令重渲染时 play_bgm 幂等，不打断正在播放的曲目。
func _sync_bgm() -> void:
	var director := get_node_or_null("../AudioDirector")
	if director == null or not director.has_method("play_bgm"):
		return
	director.play_bgm(str(BGM_BY_VIEW.get(_view_name, BGM_DEFAULT)))


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
	# RUITK 屏已全部迁离：走到这里说明路由表漏登记，直接报错而不是静默白屏。
	_unmount_rui_root()
	_unmount_master_instance()
	push_error(".tscn 路由表缺少视图 %s（RUITK 兜底已移除）" % screen)


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
	if _screen_tween != null and _screen_tween.is_valid():
		_screen_tween.kill()
	_screen_tween = null
	_unmount_rui_root()
	_master_instance = null
	_mounted_screen = ""


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
