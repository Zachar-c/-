class_name RunController
extends Node


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
const RejectionTextScript = preload("res://scripts/presentation/rejection_text.gd")
const RunOpeningFlowScript = preload("res://scripts/presentation/run_opening_flow.gd")
const RunSettingsFlowScript = preload("res://scripts/presentation/run_settings_flow.gd")
const RunBattleFlowScript = preload("res://scripts/presentation/run_battle_flow.gd")
const RunTravelFlowScript = preload("res://scripts/presentation/run_travel_flow.gd")
const RunDialogueFlowScript = preload("res://scripts/presentation/run_dialogue_flow.gd")
const RunEndingFlowScript = preload("res://scripts/presentation/run_ending_flow.gd")
const M0RunFlowScript = preload("res://scripts/presentation/m0_run_flow.gd")
# 公开常量转发：测试/外部仍可读 controller.WANDERER_STARTER_GU_IDS。
const WANDERER_STARTER_GU_IDS = RunOpeningFlowScript.WANDERER_STARTER_GU_IDS
const AppSettingsScript = preload("res://scripts/domain/app_settings.gd")
## Debug façade is optional at compile-time (Release prune): only this bridge is
## statically preloaded; the implementation script loads by path on debug builds.
const DebugBridge = preload("res://scripts/presentation/debug_bridge.gd")
# V1 battle lifecycle hook: battle2 ledger sits in the RunState for the
# duration of a single battle. Sized by CultivatorRules.thought_capacity and
# consumed by the battle facade on each accepted turn; finalised through
# the _battle2_ledger info key when the battle exits.
const Battle2TurnEngineScript = preload("res://scripts/domain/battle2/turn_engine.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")

## 全部屏使用 Godot 官方 .tscn 节点树（scenes/ui/screens/）。W12 split：
## 路由表与挂载机制迁至 run_screen_router.gd（RunScreenRouter.MASTER_SCENE_PATHS
## 即唯一路由表）；本文件只持有挂载节点状态。

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
# M3（2026-09-12 纠偏）：encounter 会话唯一真状态是 RunState.encounter_session；
# 本控制器不再持有镜像副本（原 current_session 字段已删）。
## D3 战利品弹窗数据源：最近一场胜利的 loot/elite cost（只读快照消费）。
var last_battle_loot: Dictionary = {}
var last_battle_cost: Dictionary = {}
## 独立 M0 垂直切片状态；完整运行流保持旧的自动战利品语义。
var m0_mode := false
var m0_reward_options: Array[Dictionary] = []
var m0_reward_selected := false
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


## W5 目录复用：初始化（_initialize_view_flow）已加载并校验过目录，开局直接复用，
## 避免每次开新局重复全量解析 data/*.json。未经初始化的 headless 测试/工具
## （catalog 仍为空）在此处补齐加载 + 校验；已有目录只重新校验内存数据，
## 不再重复解析文件；内容非法时的内容错误行为不变。
func _ensure_catalog_loaded() -> void:
	if catalog.is_empty():
		var loaded := ContentCatalog.load_and_validate_all()
		catalog = loaded.get("catalog", {})
		_content_errors = loaded.get("errors", [])
		return
	_content_errors = ContentCatalog.validate(catalog)


func start_new_run(seed_value: int, school: String = "", contract_ids: Array = [], buff_ids: Array = []) -> void:
	m0_mode = false
	m0_reward_options.clear()
	m0_reward_selected = false
	_ensure_catalog_loaded()
	if not _content_errors.is_empty():
		_show_content_error()
		return
	meta = SaveRepository.load_meta_file()
	if meta == null:
		meta = load("res://scripts/domain/meta_progress.gd").new_empty()
	state = RunState.new_run(seed_value, meta)
	state.cave_aperture["essence_max"] = EssenceCapacityScript.essence_max(state, catalog)
	# P2.1 (RUL-2026-09-19-009):开局气血从唯一真源写入(与 essence_max 接线同构).
	RunState.apply_start_hp(state, catalog)
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
	last_result = {}
	dialogue_replies = []
	_dialogue_gateway = DialogueManagerAdapterScript.new()
	_show_map()


## M0 独立入口：只启用四场最小路线与三选一奖励，不改变完整运行流。
func start_m0_run(seed_value: int) -> void:
	_ensure_catalog_loaded()
	if not _content_errors.is_empty():
		_show_content_error()
		return
	meta = SaveRepositoryScript.load_meta_file()
	if meta == null:
		meta = load("res://scripts/domain/meta_progress.gd").new_empty()
	state = RunState.new_run(seed_value, meta)
	state.cave_aperture["essence_max"] = EssenceCapacityScript.essence_max(state, catalog)
	# P2.1 (RUL-2026-09-19-009):开局气血从唯一真源写入(与 essence_max 接线同构).
	RunState.apply_start_hp(state, catalog)
	# M0 content cap: one player, three starting Gu, six possible reward Gu.
	state.gu_instances = {}
	state.cave_aperture["stored_gu_instance_ids"] = []
	state.gu_ids = []
	state.refined_gu_ids = []
	state.equipped_gu_ids = []
	for gu_id in ["small_light_gu", "stone_shell_gu", "moonlight_gu"]:
		if not catalog.get("gu_by_id", {}).has(gu_id):
			continue
		var instance_id := RunState.next_gu_instance_id(state.gu_instances)
		state.gu_instances[instance_id] = GuInstanceScript.new_instance(gu_id, instance_id, catalog)
		(state.cave_aperture["stored_gu_instance_ids"] as Array).append(instance_id)
	state.sync_legacy_gu_projections()
	state.equipped_gu_ids = state.refined_gu_ids.duplicate()
	state.node_flags["m0_mode"] = true
	m0_mode = true
	m0_reward_options.clear()
	m0_reward_selected = false
	route = M0RunFlowScript.build_route()
	current_node = {}
	current_battle = {}
	last_result = {}
	last_battle_loot = {}
	last_battle_cost = {}
	dialogue_replies = []
	_dialogue_gateway = DialogueManagerAdapterScript.new()
	_show_map()


func submit_command(command: Dictionary) -> Dictionary:
	if not _content_errors.is_empty() and command.get("type", "") != "quit":
		_show_content_error()
		return {"ok": false, "reason": "content_invalid", "feedback": "内容配置无法加载。"}
	# D4 Toast：反馈只在产生它的那次命令后可见；下一条命令即清空（无计时器，确定性显隐）。
	last_feedback = ""
	if m0_mode and str(command.get("type", "")) == "m0_reward_take":
		return _submit_m0_reward(command)
	if m0_mode and _view_name == "Reward" and not m0_reward_selected \
			and str(command.get("type", "")) in ["leave_encounter", "leave_node"]:
		return {"ok": false, "reason": "m0_reward_choice_required", "feedback": "请先选择一项战后奖励。"}
	if command.get("type", "") == "save_run":
		var save_error := save_current_run()
		last_feedback = "进度已保存 · 关闭游戏后可继续本次冒险" if save_error == OK else "存档失败（错误码 %d）。" % save_error
		_show_map()
		return {"ok": save_error == OK, "feedback": last_feedback}
	if command.get("type", "") == "load_run":
		var loaded := load_saved_run()
		last_feedback = "已返回上次保存的行程。" if loaded else _save_load_feedback(last_load_diagnosis)
		# W10 方案甲：读档失败（校验不符/版本拒绝）留在原屏显拒绝文案，
		# 不切到 Map——null state 渲染地图快照必错，且玩家需要看到失败原因。
		if loaded:
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
	# M2（2026-09-12 纠偏）：战斗命令类型表的唯一事实来源在
	# BattleCommandFacade.BATTLE_COMMAND_TYPES；本文件不得自持命令 ID 列表
	# （tests/unit/test_battle_command_routing.gd 有源码卫生守卫）。
	if BattleCommandFacadeScript.is_battle_command(str(command.get("type", ""))) and not current_battle.is_empty():
		return _submit_battle_command(command)
	# 收官抉择（2026-09-15）：收官是 **Run 级**命令，不属于任何节点或遭遇会话，
	# 必须在遭遇会话路由之前短路——否则会被 session resolver 当作未知会话命令
	# 拒掉（战斗刚结束时 currentNode 仍非空，正是最需要它的时刻）。
	if str(command.get("type", "")) == "close_run":
		return _submit_close_run(command)
	if not current_node.is_empty():
		var session_result := EncounterSessionResolverScript.apply(state, state.encounter_session, command, catalog, current_node)
		state = session_result["state"]
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
		if bool(session_result["session"].get("completed", false)):
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


## 收官抉择（2026-09-15）：主动收官与冲仙同走 Ending 结算路由；被领域判据拒绝时
## 留在原屏（`last_result` 已带闭包原因），不切屏、不落事件。
func _submit_close_run(command: Dictionary) -> Dictionary:
	var resolved := Resolver.apply(state, command, catalog)
	state = resolved["state"]
	last_result = resolved["result"]
	_apply_command_feedback(last_result)
	if bool(last_result.get("ok", false)):
		_show_ending(last_result)
	else:
		_re_show_current_screen()
	return resolved


func _submit_battle_command(command: Dictionary) -> Dictionary:
	return RunBattleFlowScript.submit_battle_command(self, command)


func _submit_m0_reward(command: Dictionary) -> Dictionary:
	if not m0_mode or _view_name != "Reward":
		return {"ok": false, "reason": "m0_reward_not_available"}
	if m0_reward_selected:
		return {"ok": false, "reason": "m0_reward_already_chosen"}
	var reward_id := str(command.get("reward_id", ""))
	var option: Dictionary = {}
	for option_value in m0_reward_options:
		var candidate: Dictionary = option_value
		if str(candidate.get("id", "")) == reward_id:
			option = candidate
			break
	if option.is_empty():
		return {"ok": false, "reason": "m0_reward_unknown"}
	var reward_command := command.duplicate(true)
	reward_command["option"] = option
	var applied: Dictionary = Resolver.apply(state, reward_command, catalog)
	var result: Dictionary = applied.get("result", {})
	if not bool(result.get("ok", false)):
		return {"ok": false, "reason": str(result.get("reason", "m0_reward_rejected"))}
	state = applied["state"]
	m0_reward_selected = true
	last_result = {"ok": true, "action_id": "m0_reward_take", "reward_id": reward_id}
	_apply_command_feedback(last_result)
	_re_show_current_screen()
	return {"ok": true, "result": last_result}


## 兼容入口：把 authored branch title（如 "echo_cave.accept"）转成
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
	return RunDialogueFlowScript.submit_branch(self, command)


## A7：战斗 hp 同步 / 开局 / 设置 / 拒绝文案已外提；见 run_*_flow 与 rejection_text。
func _sync_battle_hp_to_state() -> void:
	RunBattleFlowScript.sync_battle_hp_to_state(self)


## B 批反馈基建（§16.5 信息透明）：命令结果必须可见——被拒走 rejection_text 中文，
## 成功且无人为反馈时拼接 actual_changes 的结构化中文（"元石减少 6。"等）。
## 战斗回合分支（take_turn/apply_action_card 直返）不经此函数，反馈由战斗屏自身呈现。
func _apply_command_feedback(result: Dictionary) -> void:
	if not bool(result.get("ok", true)):
		if last_feedback.is_empty():
			last_feedback = rejection_text(str(result.get("reason", "unknown")))
	elif last_feedback.is_empty():
		var refinement_note := _last_refinement_note()
		if not refinement_note.is_empty():
			last_feedback = refinement_note
		else:
			last_feedback = _summarize_changes(result.get("actual_changes", []))


## Stage 1（2026-09-16）：盲炼/合炼失败必须给出世界内原因（设计 §5「火候/相性/心神」），
## 不能只让玩家看到蛊仓空了。只认最后一条 refine_gu 事件；成功（refinement_succeeded
## 等未收录 reason）返回空串，交回结构化变更摘要，不抢镜。
func _last_refinement_note() -> String:
	if state == null or state.event_log.is_empty():
		return ""
	var last_event: Dictionary = state.event_log[-1]
	if str(last_event.get("action", "")) != "refine_gu":
		return ""
	return DisplayText.refine_failure_text(str(last_event.get("reason", "")))


## 拓扑 v2：把当前实例的模板 id 与大层盖到 RunState，供领域侧
## （升仙授予查模板、掉落/黑市按层裁定）读取；存档随行。
func _stamp_current_node(run_state, node: Dictionary) -> void:
	run_state.current_node_template_id = str(node.get("template_id", node.get("id", "")))
	run_state.current_node_layer = int(node.get("layer", 0))


func current_view_name() -> String:
	return _view_name


func _show_content_error() -> void:
	_ending_state = {}
	_set_view("ContentError")


func _summarize_changes(changes) -> String:
	return RejectionTextScript.summarize_changes(changes)


func rejection_text(reason: String) -> String:
	return RejectionTextScript.text(reason)


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
	return RunTravelFlowScript.travel_to(self, node_id)


# ----------------------------------------------------------------------------
# §16.22 D5 调试方法族（全部 is_debug_build 门控早退；只写本局 RunData；
# 不写事件日志、不碰大厅存档；print 带 [debug] 前缀可追溯）。
# W12 split: implementation lives in run_debug_facade.gd, reached only through
# DebugBridge (lazy load on debug builds). Release packs must not contain a
# compile-time edge from this controller to the façade.
# ----------------------------------------------------------------------------

func _debug_enabled() -> bool:
	return DebugBridge.enabled(self)


func debug_panel_mounted() -> bool:
	return DebugBridge.panel_mounted(self)


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
	return DebugBridge.debug_add_gu(self, gu_id)


func debug_set_resource(kind: String, value) -> Dictionary:
	return DebugBridge.debug_set_resource(self, kind, value)


func debug_travel(node_id: String) -> Dictionary:
	return DebugBridge.debug_travel(self, node_id)


func debug_snapshot_dump() -> Dictionary:
	return DebugBridge.debug_snapshot_dump(self)


## 调试面板跳层下拉选项：仅当前可见节点（防越层破坏地图不变量）。
func _debug_travel_options() -> Array[Dictionary]:
	return DebugBridge.travel_options(self)


func _debug_props() -> Dictionary:
	return DebugBridge.props(self)


## 加蛊下拉 · 流派列表：目录 schools 顺序即展示顺序，label 用流派中文名。
func _debug_gu_schools() -> Array[Dictionary]:
	return DebugBridge.gu_schools(self)


## 加蛊下拉 · 蛊虫选项：按所选流派过滤目录，label 用蛊虫中文名（DisplayText 同源）。
func _debug_gu_options(school_id: String) -> Array[Dictionary]:
	return DebugBridge.gu_options(self, school_id)


func _set_debug_gu_school(value: String) -> void:
	DebugBridge.set_gu_school(self, value)


func _set_debug_gu_option(value: String) -> void:
	DebugBridge.set_gu_option(self, value)


func _set_debug_res_kind(value: String) -> void:
	DebugBridge.set_res_kind(self, value)


func _set_debug_res_value(value: String) -> void:
	DebugBridge.set_res_value(self, value)


func _set_debug_travel_node(value: String) -> void:
	DebugBridge.set_travel_node(self, value)


func _toggle_debug_panel() -> void:
	DebugBridge.toggle_panel(self)


func _mount_debug_panel() -> void:
	DebugBridge.mount_panel(self)


func _debug_host_size() -> Vector2:
	return DebugBridge.host_size(self)


func _render_debug_panel() -> void:
	DebugBridge.render_panel(self)


func _debug_ok(feedback: String) -> Dictionary:
	return DebugBridge.debug_ok(self, feedback)


func _debug_fail(reason: String) -> Dictionary:
	return DebugBridge.debug_fail(self, reason)


func _debug_fail_with(reason: String, feedback: String) -> Dictionary:
	return DebugBridge.debug_fail_with(self, reason, feedback)


func _start_battle() -> void:
	RunBattleFlowScript.start_battle(self)


func _battle_terrain() -> String:
	return RunBattleFlowScript.battle_terrain(self)


func _show_title() -> void:
	_hall_subview = "main"
	_set_view("Title")


# 退出流程（A6 设置 → 退出游戏）：request_quit 只置标志（可测），
# quit_game 在真实运行树下追加 SceneTree.quit；headless/GUT 下树为空或
# 为编辑器提示时安全跳过，避免测试进程被终止。
var quit_requested := false


func request_quit() -> void:
	RunSettingsFlowScript.request_quit(self)


func quit_game() -> void:
	RunSettingsFlowScript.quit_game(self)


func toggle_dda() -> void:
	RunSettingsFlowScript.toggle_dda(self)


func step_master_volume(delta: int) -> void:
	RunSettingsFlowScript.step_master_volume(self, delta)


func cycle_resolution() -> void:
	RunSettingsFlowScript.cycle_resolution(self)


func _apply_master_volume() -> void:
	RunSettingsFlowScript.apply_master_volume(self)


func _apply_window_mode() -> void:
	RunSettingsFlowScript.apply_window_mode(self)


func _deferred_set_window_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)


## 大厅内部子视图切换（A3 流派 / A4 契约 / A5 图鉴 / A6 设置 / A7 手记）。
## 仅改展示层 `_hall_subview`，不触碰领域状态；A2 主界面为默认根。
func _show_hall_subview(subview: String) -> void:
	if _view_name != "Title":
		return
	_hall_subview = subview
	_render()


func _apply_run_buffs(buff_ids: Array) -> void:
	RunOpeningFlowScript.apply_run_buffs(self, buff_ids)


## 流派选择（大厅「择道」子视图）：校验 → 写入开局流派 → **重绘**。
## 旧实现只在命令回调里赋值 `_selected_school`、不重绘；流派卡片是自建 Panel
## （选中态与「已选」印章都由快照重建，没有自绘状态），所以点其它流派看不到
## 任何变化，表现为「只有默认力道能用」。重绘同时刷新确认按钮文案（以X入世）。
func select_school(school_id: String) -> void:
	var sid := str(school_id)
	if not catalog.get("schools", {}).has(sid):
		return
	_selected_school = sid
	_show_hall_subview("schools")


func _toggle_buff(buff_id: String) -> void:
	var bid := str(buff_id)
	if not catalog.get("buffs", {}).has(bid):
		return
	if _selected_buffs.has(bid):
		_selected_buffs.erase(bid)
	else:
		_selected_buffs.append(bid)
	# 勾选同样要重绘：加成行是目录投影，重建时按快照 selected_buffs 恢复；
	# 否则随后因选流派触发的重绘会把刚勾的加成视觉冲掉。
	_show_hall_subview("schools")


func _inject_school_starters(school: String) -> void:
	RunOpeningFlowScript.inject_school_starters(self, school)


func _next_gu_instance_id(state_ref: RunState) -> String:
	return RunState.next_gu_instance_id(state_ref.gu_instances)


func _swear_opening_contracts(contract_ids: Array) -> void:
	RunOpeningFlowScript.swear_opening_contracts(self, contract_ids)


func _start_run_from_title() -> void:
	if _view_name == "Title":
		start_new_run(roll_seed(), _selected_school)


static func roll_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 2147483647)


static func _run_end_outcome(outcome: String) -> String:
	return RunEndingFlowScript.run_end_outcome(outcome)


func _set_view(view_name: String) -> void:
	_view_name = view_name
	_render()


func _show_map() -> void:
	_set_view("Map")


func _show_encounter() -> void:
	_set_view("Encounter")


func _show_shop() -> void:
	_set_view("Shop")


func _show_rest() -> void:
	_set_view("Rest")


func _show_refine() -> void:
	# 自由配对的选择自净：被消耗/已死的实例选择直接作废。
	var alive := {}
	for keep_id in state.cave_aperture.get("stored_gu_instance_ids", []):
		alive[str(keep_id)] = true
	if not alive.has(_selected_pair_main):
		_selected_pair_main = ""
	if not alive.has(_selected_pair_partner):
		_selected_pair_partner = ""
	_set_view("Refine")


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
	_set_view("Reward")


func _show_npc() -> void:
	_set_view("Npc")


## 覆盖屏统一切换：记录返回源，再挂载目标屏。
func _show_kill() -> void:
	_overlay_return_view = _view_name
	_set_view("Kill")


func _show_settings() -> void:
	_overlay_return_view = _view_name
	_set_view("Settings")


func back_from_overlay() -> void:
	match _overlay_return_view:
		"Map": _show_map()
		"Battle": _show_battle()
		_:
			_hall_subview = "main"
			_show_title()


## 设置屏 → 分辨率：直接设为指定档（区别于大厅的 cycle_resolution 循环）。
func set_resolution_index(index: int) -> void:
	RunSettingsFlowScript.set_resolution_index(self, index)


## 设置屏 → 静音切换：0 ↔ 原音量（0 记入 app_settings 原值旁置 100）。
func toggle_mute() -> void:
	RunSettingsFlowScript.toggle_mute(self)


## 会话未完成时按当前屏留在原地（T4 节点屏替代 Encounter 通用展示）。
func _re_show_current_screen() -> void:
	match _view_name:
		"Shop": _show_shop()
		"Rest": _show_rest()
		"Refine": _show_refine()
		"Npc": _show_npc()
		_: _show_encounter()


func _show_battle() -> void:
	_set_view("Battle")


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
	last_battle_loot = {}
	last_battle_cost = {}
	_record_run_end("surrendered", "abandoned")
	_show_ending({
		"outcome": "surrendered",
		"conditions": {},
	})


func _show_ending(outcome: Dictionary) -> void:
	RunEndingFlowScript.show_ending(self, outcome)


func _show_death(report: Dictionary) -> void:
	RunEndingFlowScript.show_death(self, report)


func _record_run_end(outcome: String, ending_type := "") -> void:
	RunEndingFlowScript.record_run_end(self, outcome, ending_type)


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
	if m0_mode:
		m0_reward_options.clear()
		m0_reward_selected = false
	# M3：不再清空会话镜像——state.encounter_session 保留 completed 会话，
	# 下一次 travel 经 EncounterSessionResolver.begin 原子替换。
	_show_map()


func _finish_battle_in_session(outcome: String) -> void:
	RunBattleFlowScript.finish_battle_in_session(self, outcome)


func _record_dialogue_reply(result: Dictionary) -> void:
	RunDialogueFlowScript.record_dialogue_reply(self, result)


func _attach_social_dialogue(result: Dictionary) -> void:
	RunDialogueFlowScript.attach_social_dialogue(self, result)


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
	if not RunScreenRouter.is_registered_screen(_view_name):
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


## W12 split: mounting machinery moved to run_screen_router.gd. Same-name
## one-line wrappers keep call sites and tests unchanged.
func _mount_screen(screen: String, snapshot: Dictionary, commands: Dictionary) -> void:
	RunScreenRouter.mount_screen(self, screen, snapshot, commands)


func _unmount_master_instance() -> void:
	RunScreenRouter.unmount_master_instance(self)


func _exit_tree() -> void:
	if _screen_tween != null and _screen_tween.is_valid():
		_screen_tween.kill()
	_screen_tween = null
	_master_instance = null
	_mounted_screen = ""


## T6-E 跨屏过渡：屏切换（含死亡返大厅）时对新挂载根做 140ms 一次性淡入
## （modulate 0→1）；同屏重渲染不触发，战斗/商店等连续操作零闪烁。
## 快速连切先杀上一条 Tween 防叠加；有限 Tween 播完即失效，无循环残留。
## 过渡挂在统一屏宿主上，切屏时一次性淡入。
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
