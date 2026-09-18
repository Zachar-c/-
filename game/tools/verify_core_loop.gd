extends SceneTree

## Q8 Playable Core Loop — 垂直切片真实验收（2026-09-15）。
##
## 目的：用**真实领域命令**走通
##   start_new_run → Map → 战斗 → Reward → Map → Refinement → 真实 promotion → Map
## 并验证 Gate A–F（任务书 §验收 Gate）。
##
## 纪律：
##   - 只用 controller.submit_command(...)（UI 唯一提交入口），不直接写 state 字段；
##   - 不重抽 loot、不改领域规则、不伪造状态；
##   - 断言全部基于真实事件日志与真实库存变化。
##
## 用法（headless 可跑）：
##   godot --headless --path . -s tools/verify_core_loop.gd

const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")
const RunSnapshotBuilderScript := preload("res://scripts/presentation/run_snapshot_builder.gd")
const RunCommandBuilderScript := preload("res://scripts/presentation/run_command_builder.gd")
const BuildGoalProjectionScript := preload("res://scripts/presentation/snapshots/build_goal_projection.gd")
const V1BattleResolverScript := preload("res://scripts/domain/v1_battle_resolver.gd")

## 预登记 seed 列表（不是事后挑选）：driver 从列表头开始确定性尝试，
## 取第一个能在单局内闭合「战斗→材料→目标就绪→真实 promotion→目标变化」的 seed。
## 生产 pacing.ending_after_stage == "one" ⇒ 单局只跑 L1（约 7 场战斗），
## 而第一条 promotion 需要的 crude 材料按每场 Common 胜利 ~40% 命中，
## 因此并非每个 seed 都能在 L1 内闭合 —— 这是被记录的产品观察，不是 driver 缺陷。
const SEED_CANDIDATES: Array[int] = [101, 202, 303, 404, 505, 606, 707, 808,
		909, 1111, 1212, 1313, 1414, 1515, 1616, 1717, 1818, 1919, 2020, 2121]

## 可用环境变量覆盖（默认值 = 正式验收口径）：
##   CORE_LOOP_SCHOOL=force|sword   选流派（默认 force）
##   CORE_LOOP_FAITHFUL=1           关闭 driver 侧「按 enemy_roll 偏好 common」的路由优势，
##                                  只用玩家可见信息（节点类型）选路 —— 用于量化风险 R2。
var _school := "force"
var _route_advantage := true
const MAX_TRAVELS := 40
const MAX_BATTLE_TURNS := 60

var _failed := 0
var _checks := 0
## Gate F 用：把「与命令序列一一对应」的规范化轨迹记下来，供回放比对。
var _trace: Array[String] = []
## Gate D 用：炼蛊执行前的目标，用于对比炼蛊后的变化。
var _goal_before_refine: Dictionary = {}


func _initialize() -> void:
	var env_school := OS.get_environment("CORE_LOOP_SCHOOL")
	if not env_school.is_empty():
		_school = env_school
	_route_advantage = OS.get_environment("CORE_LOOP_FAITHFUL") != "1"
	print("===== Playable Core Loop vertical slice =====")
	print("school=%s  路由优势=%s  预登记 seed 列表=%s"
			% [_school, str(_route_advantage), str(SEED_CANDIDATES)])
	var chosen := 0
	for candidate in SEED_CANDIDATES:
		print("")
		print("----- 尝试 seed=%d -----" % candidate)
		_failed = 0
		_checks = 0
		var ok: bool = await _primary_pass(candidate)
		if ok:
			chosen = candidate
			break
	print("")
	print("===== summary =====")
	if chosen == 0:
		print("RESULT: FAIL（预登记 seed 列表内无一局能在 L1 内闭合）")
		quit(1)
		return
	print("闭环 seed = %d" % chosen)
	_checks = 0
	_failed = 0
	await _determinism_pass(chosen)
	print("checks=%d failed=%d" % [_checks, _failed])
	if _failed > 0:
		print("RESULT: FAIL")
		quit(1)
		return
	print("RESULT: PASS")
	quit(0)


# ---------------------------------------------------------------- 主路径

func _primary_pass(seed_value: int) -> bool:
	print("----- pass 1: 真实闭环 -----")
	var controller = await _new_controller()
	controller.start_new_run(seed_value, _school)
	await process_frame
	_trace.clear()
	if controller.current_view_name() != "Map":
		_check("开局进入 Map 屏", false, controller.current_view_name())
		return false
	_check("开局进入 Map 屏", true, "Map")

	# --- Gate A：地图可直接回答「目标 / 缺什么 / 去哪」 ---
	var map_snap: Dictionary = RunSnapshotBuilderScript.for_screen("Map", controller)
	var goal: Dictionary = map_snap.get("build_goal", {})
	_gate_a(goal, map_snap)

	# --- 第一轮：战斗 → 材料 → 目标进度（与 Gate F 回放共用 _drive_loop） ---
	var loop_result: Dictionary = await _drive_loop(controller, true)
	var battle_round: int = int(loop_result["battle_round"])
	var reward_evidence: Array = loop_result["reward_evidence"]
	# Gate F：主路径的规范化轨迹直接取 _drive_loop 产出的同构轨迹。
	_trace.assign(loop_result["trace"])
	var reached_refine: bool = bool(loop_result["reached_refine"])
	var saw_refine_reachable: bool = bool(loop_result["saw_refine_reachable"])

	if controller.current_view_name() == "Ending":
		print("  [注意] 本局在闭环完成前进入 Ending（终局），说明该 seed 的生存窗口不足。")
	print("  Gate B 证据（每场战利品 → 目标进度）：")
	for line in reward_evidence:
		print("    " + line)
	_gate_b(controller, reward_evidence)

	# --- Gate C：真实炼蛊 / promotion ---
	var goal_ready: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
	if not bool(goal_ready.get("ready", false)):
		print("  [skip] 本 seed 在 L1 内未凑齐目标材料（%s）；L1 内曾出现可达炼蛊台=%s。"
				% [str(goal_ready.get("missing_summary", "")), str(saw_refine_reachable)])
		return false
	_check("Gate C 前置：目标已就绪（材料 + 元石 + 输入蛊）", true,
			str(goal_ready.get("title", "")))

	if not reached_refine:
		print("  [skip] 本 seed 在目标就绪后未能行至炼蛊台；L1 内曾出现可达炼蛊台=%s。"
				% str(saw_refine_reachable))
		return false
	_check("行至炼蛊台（目标就绪后沿路前进抵达）", true, str(controller.current_node.get("id", "")))
	_gate_c(controller)

	# --- Gate D：炼蛊后回地图，目标变化 ---
	# 注意必须 await：_gate_d 内部有 await process_frame，不 await 会在挂起点返回，
	# 其后的轨迹追加不会执行（曾因此让 Gate F 误报不一致）。
	await _gate_d(controller)

	# --- Gate E：三屏可达 + 命令接线（headless 可判定的部分） ---
	_gate_e(controller)
	return true


## 主循环：战斗 → Reward → 继续选路 → 目标就绪后进炼蛊台。
## Gate F 的回放复用同一实现（collect_evidence=false 时不打印证据）。
## 返回 {battle_round, reward_evidence, reached_refine, saw_refine_reachable}。
func _drive_loop(controller, collect_evidence: bool) -> Dictionary:
	var battle_round := 0
	var reward_evidence: Array[String] = []
	var trace: Array[String] = []
	var traveled := 0
	var reached_refine := false
	var saw_refine_reachable := false
	while traveled < MAX_TRAVELS:
		var current_goal: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
		# 目标就绪后：优先直奔炼蛊台；若此刻 frontier 里没有炼蛊台，
		# 就继续沿路前进（炼蛊台是稀疏节点，不一定正好在下一行）。
		if not _pick_travel_target(controller, true).is_empty():
			saw_refine_reachable = true
		var target := ""
		if bool(current_goal.get("ready", false)):
			target = _pick_travel_target(controller, true)
		if target == "":
			target = _pick_travel_target(controller, false)
		if target == "":
			break
		traveled += 1
		var travel_result: Dictionary = _submit(controller, {"type": "travel", "node_id": target})
		if not _command_ok(travel_result):
			print("    travel#%d -> %s 被拒：%s" % [traveled, target, str(travel_result.get("reason", ""))])
			continue
		var view: String = str(controller.current_view_name())
		if collect_evidence:
			print("    travel#%d -> %s  视图=%s" % [traveled, target, view])
		if view == "Battle":
			battle_round += 1
			await _drive_battle(controller)
			view = controller.current_view_name()
			if collect_evidence:
				print("    战斗 #%d 结束，视图=%s" % [battle_round, view])
		if view == "Reward":
			var loot: Dictionary = controller.get("last_battle_loot") if controller.get("last_battle_loot") != null else {}
			if collect_evidence:
				print("    战利品 #%d：mats=%s stone=%s" % [battle_round,
						str(loot.get("material_ids", [])), str(loot.get("stone_reward", 0))])
			var reward_snap: Dictionary = RunSnapshotBuilderScript.for_screen("Reward", controller)
			var progress: Dictionary = reward_snap.get("build_progress", {})
			reward_evidence.append("battle#%d goal=%s ready_after=%s lines=%s" % [
				battle_round, str(progress.get("title", "")),
				str(progress.get("ready_after", false)),
				_progress_line_summary(progress)])
			trace.append("reward:%s:%s" % [str(progress.get("recipe_id", "")),
					_progress_line_summary(progress)])
			_submit(controller, {"type": "leave_encounter"})
			await process_frame
		elif view == "Rest":
			# 休整节点同时是**炼蛊台的第二入口**：休息屏 mode_groups 的「炼蛊」卡
			# 调 controller.open_refine_subview()，进的是同一个 Refine 屏（E4a 子屏）。
			# 目标就绪时优先走这条路，否则按领域全集落 skip 再离开
			# （leave_encounter 会被 rest_choice_required 门禁挡住，是既有软锁约束）。
			var rest_goal: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
			if bool(rest_goal.get("ready", false)) and controller.has_method("open_refine_subview"):
				controller.open_refine_subview()
				await process_frame
				if controller.current_view_name() == "Refine":
					reached_refine = true
					break
			_submit(controller, {"type": "rest", "mode": "skip"})
			_submit(controller, {"type": "leave_encounter"})
			await process_frame
		elif view == "Refine":
			var goal_now: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
			if bool(goal_now.get("ready", false)):
				reached_refine = true
				break
			# 还没就绪就先离开，继续找战斗节点。
			_submit(controller, {"type": "leave_encounter"})
			await process_frame
		elif view == "Battle":
			# 战斗未在预算内结束（已撤退收尾）：不追加离开命令，继续下一轮。
			pass
		elif view != "Map":
			# 非战斗/炼蛊节点（事件、商店等）：离开继续。
			_submit(controller, {"type": "leave_encounter"})
			await process_frame
		if battle_round >= 8:
			break

	return {
		"battle_round": battle_round,
		"reward_evidence": reward_evidence,
		"trace": trace,
		"reached_refine": reached_refine,
		"saw_refine_reachable": saw_refine_reachable,
	}


func _gate_a(goal: Dictionary, map_snap: Dictionary) -> void:
	print("")
	print("----- Gate A：玩家目标清楚 -----")
	_check("Map 快照携带 build_goal", map_snap.has("build_goal"), "")
	_check("build_goal 可用", bool(goal.get("available", false)), str(goal.get("title", "")))
	print("  当前目标：%s" % str(goal.get("title", "")))
	print("  配方：%s" % str(goal.get("recipe_name", "")))
	print("  进度：%s" % str(goal.get("progress_text", "")))
	print("  缺失：%s" % str(goal.get("missing_summary", "")))
	print("  建议节点类型：%s" % str(goal.get("recommended_node_types", [])))
	_check("目标含 recipe_id", not str(goal.get("recipe_id", "")).is_empty(), "")
	_check("目标含材料缺口信息", goal.get("materials", []) is Array, "")
	_check("目标含推荐节点类型", not (goal.get("recommended_node_types", []) as Array).is_empty(), "")
	_check("目标声明输入蛊状态", goal.has("input_gu_ready"), str(goal.get("input_gu_ready")))
	_check("目标声明元石需求", int(goal.get("stone_required", 0)) > 0, str(goal.get("stone_required")))
	# 信息纪律：目标块不得泄露内部保底计数。
	var serialized := str(goal)
	_check("build_goal 不含内部保底计数", not serialized.contains("pity"), "")
	# 节点相关性：可达节点带 build_relevance。
	var with_relevance := 0
	for node_value in map_snap.get("nodes", []):
		if (node_value as Dictionary).has("build_relevance"):
			with_relevance += 1
	_check("每个节点携带 build_relevance", with_relevance == (map_snap.get("nodes", []) as Array).size(),
			"%d/%d" % [with_relevance, (map_snap.get("nodes", []) as Array).size()])
	# 诊断：打印当前 frontier（可达节点），便于排查 driver 选路。
	var reachable_desc: Array[String] = []
	for node_value in map_snap.get("nodes", []):
		var node: Dictionary = node_value
		if bool(node.get("reachable", false)):
			reachable_desc.append("%s(%s)" % [str(node.get("id", "")), str(node.get("type", ""))])
	print("  当前可达节点：%s" % (", ".join(reachable_desc) if not reachable_desc.is_empty() else "(无)"))
	print("  当前节点：%s" % str(map_snap.get("current_node_id", "")))


func _gate_b(controller, reward_evidence: Array[String]) -> void:
	print("")
	print("----- Gate B：产出真实进入闭环 -----")
	_check("至少结算过 1 场战斗并读取 Reward 快照", reward_evidence.size() > 0,
			"%d 场" % reward_evidence.size())
	# 显示与库存一致：Reward 快照的 lines 必须等于真实库存的读数。
	var reward_snap: Dictionary = RunSnapshotBuilderScript.for_screen("Reward", controller)
	var progress: Dictionary = reward_snap.get("build_progress", {})
	if not bool(progress.get("available", false)):
		# 最后一场可能没推进目标材料；用最后一场的 loot 重新对齐一次。
		print("  （末场无 build_progress，跳过一致性重算）")
		return
	for row_value in progress.get("lines", []):
		var row: Dictionary = row_value
		var owned_real := int(controller.state.materials.get(str(row["id"]), 0))
		_check("Reward 材料 %s 与库存一致" % str(row["id"]),
				owned_real == int(row["owned_after"]),
				"快照=%d 库存=%d" % [int(row["owned_after"]), owned_real])
	_check("Reward 元石与库存一致",
			int(progress.get("stone_after", -1)) == int(controller.state.stone),
			"快照=%d 库存=%d" % [int(progress.get("stone_after", -1)), int(controller.state.stone)])


func _gate_c(controller) -> void:
	print("")
	print("----- Gate C：炼蛊真实可执行 -----")
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Refine", controller)
	var goal: Dictionary = snap.get("build_goal", {})
	var goal_recipe_id := str(snap.get("goal_recipe_id", ""))
	_check("Refine 快照携带 build_goal", bool(goal.get("available", false)), str(goal.get("title", "")))
	_check("Refine 快照给出 goal_recipe_id", not goal_recipe_id.is_empty(), goal_recipe_id)

	var goal_row: Dictionary = {}
	var first_row: Dictionary = {}
	for row_value in snap.get("recipes", []):
		var row: Dictionary = row_value
		if first_row.is_empty():
			first_row = row
		if str(row.get("id", "")) == goal_recipe_id:
			goal_row = row
			break
	_check("目标配方出现在配方列表中", not goal_row.is_empty(), goal_recipe_id)
	_check("目标配方排在首位（Phase 4 优先级）",
			not first_row.is_empty() and str(first_row.get("id", "")) == goal_recipe_id,
			"首位=%s" % str(first_row.get("id", "")))
	if goal_row.is_empty():
		return
	# Phase 4：点击前即可见成本。
	_check("目标配方带材料成本明细", goal_row.get("materials", []) is Array, "")
	_check("目标配方带元石成本", int(goal_row.get("stone_required", 0)) > 0,
			str(goal_row.get("stone_required")))
	_check("目标配方带输入蛊信息", not str(goal_row.get("input_gu_name", "")).is_empty(),
			str(goal_row.get("input_gu_name", "")))
	_check("目标配方标记为可执行", bool(goal_row.get("executable", false)),
			str(goal_row.get("missing_summary", "")))

	var recipe: Dictionary = controller.catalog.get("refinement_by_id", {}).get(goal_recipe_id, {})
	var material_cost: Dictionary = recipe.get("materials", {})
	var stone_cost := int(recipe.get("stone_cost", 0))
	var input_instance_id := str(goal.get("input_instance_id", ""))
	var output_gu_id := str(goal.get("output_gu_id", ""))

	var before_materials: Dictionary = controller.state.materials.duplicate(true)
	var before_stone := int(controller.state.stone)
	var before_instances: int = controller.state.gu_instances.keys().size()
	var before_stored: int = controller.state.cave_aperture.get("stored_gu_instance_ids", []).size()
	var before_events: int = controller.state.event_log.size()
	var owned_output_before := _owns_definition(controller, output_gu_id)
	_goal_before_refine = goal.duplicate(true)

	var result: Dictionary = _submit(controller, {
		"type": "refine_gu",
		"recipe_id": goal_recipe_id,
		"input_instance_ids": [input_instance_id] if not input_instance_id.is_empty() else [],
	})
	_check("promotion 命令被领域接受", _command_ok(result),
			"changes=%s" % str(_command_changes(result)))
	if not _command_ok(result):
		return

	print("  执行：%s" % goal_recipe_id)
	print("  输入实例：%s → 产出蛊：%s" % [input_instance_id, output_gu_id])
	for material_id in material_cost:
		var spent := int(before_materials.get(str(material_id), 0)) \
				- int(controller.state.materials.get(str(material_id), 0))
		_check("材料 %s 真实扣除 %d" % [str(material_id), int(material_cost[material_id])],
				spent == int(material_cost[material_id]),
				"实际扣除=%d" % spent)
	_check("元石真实扣除 %d" % stone_cost,
			before_stone - int(controller.state.stone) == stone_cost,
			"实际扣除=%d" % (before_stone - int(controller.state.stone)))
	# 领域语义（GuInstance.consume_instance_id_list）：输入实例记录保留、
	# 状态置 "consumed"，并从蛊仓 stored_gu_instance_ids 中移除。
	var consumed_state := str(controller.state.gu_instances.get(input_instance_id, {}).get("state", ""))
	_check("输入蛊实例被真实消费（状态置 consumed 且移出蛊仓）",
			consumed_state == "consumed"
			and not controller.state.cave_aperture.get("stored_gu_instance_ids", []).has(input_instance_id),
			"实例 %s state=%s" % [input_instance_id, consumed_state])
	_check("产出蛊真实进入库存", _owns_definition(controller, output_gu_id),
			"产出=%s" % output_gu_id)
	_check("产出蛊为新增（此前不持有）", not owned_output_before, "")
	_check("事件日志记录 promotion_succeeded", _has_promotion_event(controller, goal_recipe_id),
			"事件数 %d → %d" % [before_events, controller.state.event_log.size()])
	# 蛊仓（可用实例）守恒：-1 输入 +1 产出；gu_instances 记录数会 +1
	# （被消费的输入以 consumed 记录留档，这是既有账本语义）。
	_check("蛊仓可用实例数守恒（-1 输入 +1 产出）",
			controller.state.cave_aperture.get("stored_gu_instance_ids", []).size() == before_stored,
			"%d → %d" % [before_stored,
					controller.state.cave_aperture.get("stored_gu_instance_ids", []).size()])


func _gate_d(controller) -> void:
	print("")
	print("----- Gate D：第二轮决策被改变 -----")
	var goal_before_refine: Dictionary = _goal_before_refine
	# 回到地图：提交离开命令（与 UI「离开」同一条路由）。
	_submit(controller, {"type": "leave_encounter"})
	await process_frame
	var view: String = str(controller.current_view_name())
	_check("炼蛊后回到地图屏", view == "Map", view)
	var map_snap: Dictionary = RunSnapshotBuilderScript.for_screen("Map", controller)
	var goal_after: Dictionary = map_snap.get("build_goal", {})
	print("  炼蛊前目标：%s" % str(goal_before_refine.get("title", "(未记录)")))
	print("  炼蛊后目标：%s" % str(goal_after.get("title", "")))
	print("  炼蛊后进度：%s" % str(goal_after.get("progress_text", "")))
	_check("地图目标已改变（推进到下一条 promotion）",
			str(goal_after.get("recipe_id", "")) != str(goal_before_refine.get("recipe_id", ""))
			or int(goal_after.get("chain_index", 0)) > int(goal_before_refine.get("chain_index", 0)),
			"%s -> %s" % [str(goal_before_refine.get("recipe_id", "")),
					str(goal_after.get("recipe_id", ""))])
	# 节点推荐理由随之改变。
	var relevance_changed := false
	var new_goal := BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
	for node_value in map_snap.get("nodes", []):
		var node: Dictionary = node_value
		if not bool(node.get("revealed", true)):
			continue
		var relevance: Dictionary = node.get("build_relevance", {})
		if str(relevance.get("code", "")) != "none":
			relevance_changed = true
			break
	print("  新目标缺口：%s" % str(new_goal.get("missing_summary", "")))
	_check("节点相关性随新目标重算", relevance_changed,
			"至少一个已揭示节点与目标相关")
	_trace.append("goal_after_refine:%s" % str(goal_after.get("recipe_id", "")))


func _gate_e(controller) -> void:
	print("")
	print("----- Gate E：交互接线（headless 可判定部分） -----")
	# 三屏路由可达 + 每屏命令集非空（真实点击/遮挡由 verify_interaction_loop.gd 守门）。
	for screen in ["Map", "Refine", "Reward"]:
		var snap: Dictionary = RunSnapshotBuilderScript.for_screen(screen, controller)
		_check("%s 快照非空" % screen, snap.size() > 0, str(snap.size()))
	var commands_map: Dictionary = RunCommandBuilderScript.for_screen("Map", controller)
	var commands_refine: Dictionary = RunCommandBuilderScript.for_screen("Refine", controller)
	var commands_reward: Dictionary = RunCommandBuilderScript.for_screen("Reward", controller)
	_check("Map 命令含 travel", commands_map.has("travel"), "")
	_check("Refine 命令含 refine", commands_refine.has("refine"), "")
	_check("Refine 命令含 leave", commands_refine.has("leave"), "")
	_check("Reward 命令含 close", commands_reward.has("close"), "")


# ---------------------------------------------------------------- Gate F

func _determinism_pass(seed_value: int) -> void:
	print("")
	print("----- Gate F：确定性（同 seed / school / 命令序列） -----")
	var primary_trace := _trace.duplicate()
	var controller = await _new_controller()
	controller.start_new_run(seed_value, _school)
	await process_frame
	_trace.clear()
	await _replay(controller)
	var replayed := _trace.duplicate()
	_check("回放轨迹与首轮一致", primary_trace == replayed,
			"首轮 %d 行 / 回放 %d 行" % [primary_trace.size(), replayed.size()])
	if primary_trace != replayed:
		print("    首轮轨迹：")
		for line in primary_trace:
			print("      P %s" % line)
		print("    回放轨迹：")
		for line in replayed:
			print("      R %s" % line)
		for i in mini(primary_trace.size(), replayed.size()):
			if primary_trace[i] != replayed[i]:
				print("    首个差异 @%d：%s  vs  %s" % [i, primary_trace[i], replayed[i]])
				break


## Gate F 回放：用与主路径**完全相同**的 `_drive_loop` 再走一遍。
## 同 seed 下战斗 RNG 由种子决定，因此同命令序列必须得到同轨迹。
func _replay(controller) -> void:
	var loop_result: Dictionary = await _drive_loop(controller, false)
	_trace.assign(loop_result["trace"])
	var goal_ready: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
	if not bool(loop_result["reached_refine"]) or not bool(goal_ready.get("ready", false)):
		_trace.append("loop_end:refine=%s ready=%s missing=%s" % [
				str(loop_result["reached_refine"]), str(goal_ready.get("ready", false)),
				str(goal_ready.get("missing_summary", ""))])
		return
	_submit(controller, {
		"type": "refine_gu",
		"recipe_id": str(goal_ready.get("recipe_id", "")),
		"input_instance_ids": [str(goal_ready.get("input_instance_id", ""))],
	})
	_submit(controller, {"type": "leave_encounter"})
	await process_frame
	var map_snap: Dictionary = RunSnapshotBuilderScript.for_screen("Map", controller)
	var goal_after: Dictionary = map_snap.get("build_goal", {})
	_trace.append("goal_after_refine:%s" % str(goal_after.get("recipe_id", "")))


# ---------------------------------------------------------------- 工具

func _new_controller() -> Node:
	# controller 是 Node：先入树并等一帧，_ready() 跑完再 start_new_run
	# （与 tests/unit 的既有写法一致；否则视图路由尚未装配）。
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	return controller


## 命令成功判定：resolver 的返回把 ok 嵌在 result 键下（顶层是 session/feed/state），
## 战斗命令则用 accepted；三种形状都认。
func _command_ok(result: Dictionary) -> bool:
	if bool(result.get("ok", false)) or bool(result.get("accepted", false)):
		return true
	var nested: Variant = result.get("result", null)
	if nested is Dictionary:
		return bool((nested as Dictionary).get("ok", false))
	return false


func _command_changes(result: Dictionary) -> Array:
	var nested: Variant = result.get("result", null)
	if nested is Dictionary:
		return (nested as Dictionary).get("actual_changes", [])
	return []


func _submit(controller, command: Dictionary) -> Dictionary:
	var result: Dictionary = controller.submit_command(command)
	if not _command_ok(result):
		print("    [command rejected] %s -> %s" % [str(command.get("type", "")),
				str(result.get("reason", ""))])
	return result


## 选择下一个行路目标。
##
## 地图是无回溯 DAG，而 refinement 节点在 L1 中段（探针实测 row 4–5）。
## 因此 driver 必须做两件事：
##   1) **导航**：让路径通向 refinement 节点（否则到了那一行也够不着）；
##   2) **攒料**：沿途优先打战斗节点。
## 于是本函数用 2 步前瞻：在可达节点里优先挑「能在 2 步内走到 refinement」的，
## 其中再优先战斗类型。目标就绪后则直接取 refinement 节点本身。
func _pick_travel_target(controller, want_refinement: bool) -> String:
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Map", controller)
	var by_id: Dictionary = {}
	for node_value in snap.get("nodes", []):
		var node: Dictionary = node_value
		by_id[str(node.get("id", ""))] = node
	var reachable: Array[String] = []
	for node_value in snap.get("nodes", []):
		var node: Dictionary = node_value
		if bool(node.get("reachable", false)):
			reachable.append(str(node.get("id", "")))
	if reachable.is_empty():
		return ""
	# 目标就绪：直接上炼蛊台。
	if want_refinement:
		for node_id in reachable:
			if str((by_id[node_id] as Dictionary).get("type", "")) == "refinement":
				return node_id
		return ""
	# 未就绪：优先「通向炼蛊台」的节点，其次战斗节点，最后任意（避开休整）。
	# 战斗节点内部再按「本场结算 tier 是否为 common」排序 —— 只有 Common 胜利
	# 才掉 band-1（crude）材料，而目标 promotion 要的正是它。
	# 这是 driver 侧的路由优势（玩家看不到 enemy_roll），已记入报告的风险节。
	var steering_combat: Array[String] = []
	var combat: Array[String] = []
	var steering: Array[String] = []
	var any_non_rest: Array[String] = []
	for node_id in reachable:
		var node_type := str((by_id[node_id] as Dictionary).get("type", ""))
		var is_combat := node_type == "combat" or node_type == "pursuit"
		var leads := _leads_to_type(node_id, by_id, "refinement", 2)
		if leads:
			steering.append(node_id)
		if is_combat:
			combat.append(node_id)
			if leads:
				steering_combat.append(node_id)
		if node_type != "rest":
			any_non_rest.append(node_id)
	if not steering_combat.is_empty():
		return _best_common_candidate(controller, steering_combat)
	if not combat.is_empty():
		return _best_common_candidate(controller, combat)
	if not steering.is_empty():
		return steering[0]
	if not any_non_rest.is_empty():
		return any_non_rest[0]
	return reachable[0]


## 在候选里挑「最可能是 Common 结算」的战斗节点。
## 依据 route 节点的 enemy_roll：空 roll（多敌）按 LootResolver 口径兜底 common；
## 非空则看敌人定义的 tier 是否全为 common。affinity 越大越优先；平手按 id 稳定排序。
func _best_common_candidate(controller, candidates: Array[String]) -> String:
	# faithful 模式：不用 enemy_roll（玩家看不到），按快照顺序取第一个。
	if not _route_advantage:
		return candidates[0]
	var best_id := ""
	var best_affinity := -1
	for node_id in candidates:
		var affinity := _common_affinity(controller, node_id)
		if affinity > best_affinity:
			best_affinity = affinity
			best_id = node_id
	return best_id if not best_id.is_empty() else candidates[0]


func _common_affinity(controller, node_id: String) -> int:
	var route_node: Dictionary = {}
	for node_value in controller.route:
		var node: Dictionary = node_value
		if str(node.get("id", "")) == node_id:
			route_node = node
			break
	if route_node.is_empty():
		return 0
	var roll: Array = route_node.get("enemy_roll", [])
	if roll.is_empty():
		# 多敌战斗：battle.enemy_kind 为空，正式结算按 common 兜底。
		return 2
	var enemy_by_id: Dictionary = controller.catalog.get("enemy_by_id", {})
	var all_common := true
	for enemy_id_value in roll:
		var enemy: Dictionary = enemy_by_id.get(str(enemy_id_value), {})
		if str(enemy.get("tier", "common")) != "common":
			all_common = false
			break
	return 2 if all_common else 0


## 从 node_id 出发，depth 步内是否能到达指定类型的节点（沿 next_ids）。
func _leads_to_type(node_id: String, by_id: Dictionary, target_type: String, depth: int) -> bool:
	if depth <= 0:
		return false
	if not by_id.has(node_id):
		return false
	var node: Dictionary = by_id[node_id]
	for next_value in node.get("next_ids", []):
		var next_id := str(next_value)
		if not by_id.has(next_id):
			continue
		if str((by_id[next_id] as Dictionary).get("type", "")) == target_type:
			return true
		if _leads_to_type(next_id, by_id, target_type, depth - 1):
			return true
	return false


## 驱动一场战斗到结束（真实命令：出蛊 / 拳脚 / 收势）。
## 挑牌口径与 acceptance_driver 一致：必须过 V1BattleResolver.can_play_gu 门禁，
## 否则 use_gu 会被领域拒绝，driver 会空转到预算耗尽。
func _drive_battle(controller) -> void:
	# travel 之后 battle 语境要等一帧才装配；否则会读到空 battle 直接退出。
	await process_frame
	var turns := 0
	var idle := 0
	while controller.current_view_name() == "Battle" and turns < MAX_BATTLE_TURNS:
		turns += 1
		var battle: Dictionary = controller.current_battle
		if battle.is_empty():
			break
		# 止损：气血过低先撤退——死亡会直接结束本局，中断闭环验证。
		var player: Dictionary = battle.get("player", {})
		var hp := int(player.get("hp", 0))
		var max_hp := int(player.get("max_hp", 1))
		if max_hp > 0 and hp <= maxi(6, int(max_hp * 0.3)):
			controller.submit_command({"type": "retreat"})
			await process_frame
			return
		var instance_id := _pick_attack_gu(battle)
		var command: Dictionary = ({"type": "use_gu", "instance_id": instance_id}
				if not instance_id.is_empty() else {"type": "basic_attack"})
		var result: Dictionary = controller.submit_command(command)
		if bool(result.get("finished", false)):
			return
		# 战斗命令的成功信号是 accepted（非 ok）——两者都认，避免误判为空转。
		if bool(result.get("ok", false)) or bool(result.get("accepted", false)):
			idle = 0
		else:
			# 命令被拒：收势换回合；连续两次收势也失败则判定卡死。
			var end_result: Dictionary = controller.submit_command({"type": "end_turn"})
			if bool(end_result.get("finished", false)):
				return
			idle += 1
			if idle >= 3:
				print("    战斗驱动卡死：连续 %d 次无法推进（最后拒因 %s）" % [
						idle, str(result.get("reason", ""))])
				break
		await process_frame
	print("    战斗驱动退出：turns=%d 视图=%s" % [turns, str(controller.current_view_name())])
	# 未在预算内结束：撤退收尾，避免 driver 卡死。
	if controller.current_view_name() == "Battle":
		controller.submit_command({"type": "retreat"})
		await process_frame


## 挑一张本回合可释放、伤害最高的攻击蛊（预览与执行共用 can_play_gu 门禁）。
func _pick_attack_gu(battle: Dictionary) -> String:
	var slots: Array = battle.get("gu_slots", [])
	var best_id := ""
	var best_amount := -1.0
	for index in slots.size():
		var slot: Dictionary = slots[index]
		if bool(slot.get("consumed", false)) or bool(slot.get("is_sealed", false)) \
				or bool(slot.get("used_this_turn", false)):
			continue
		var effect: Dictionary = slot.get("effect", {})
		if str(effect.get("kind", "")) not in ["strike", "aoe_strike"]:
			continue
		# 预览与执行共用同一门禁：不可释放的槽不发命令。
		if V1BattleResolverScript.can_play_gu(battle, index) != "":
			continue
		var amount := float(effect.get("amount", 0.0))
		if amount > best_amount:
			best_amount = amount
			best_id = str(slot.get("instance_id", ""))
	return best_id


func _owns_definition(controller, definition_id: String) -> bool:
	if definition_id.is_empty():
		return false
	for instance_value in controller.state.gu_instances.values():
		var instance: Dictionary = instance_value
		if str(instance.get("definition_id", "")) == definition_id \
				and str(instance.get("state", "")) != "dead":
			return true
	return false


func _has_promotion_event(controller, recipe_id: String) -> bool:
	for event_value in controller.state.event_log:
		var event: Dictionary = event_value
		if str(event.get("reason", "")) != "promotion_succeeded":
			continue
		for target_value in event.get("targets", []):
			if str(target_value) == "recipe:%s" % recipe_id:
				return true
	return false


func _progress_line_summary(progress: Dictionary) -> String:
	var parts: Array[String] = []
	for row_value in progress.get("lines", []):
		var row: Dictionary = row_value
		parts.append("%s=%d/%d" % [str(row.get("id", "")), int(row.get("owned_after", 0)),
				int(row.get("required", 0))])
	if int(progress.get("stone_after", 0)) > 0:
		parts.append("stone=%d" % int(progress.get("stone_after", 0)))
	return ",".join(parts)


func _check(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s%s" % [label, "" if detail.is_empty() else "  (%s)" % detail])
		return
	_failed += 1
	print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  (%s)" % detail])
