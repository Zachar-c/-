extends SceneTree

# 玩家视角游玩冒烟（playthrough smoke）：无头驱动一整局真实游玩回路——
# 大厅开局契约 → 地图逐节点推进（商队/黑市/险地/休整/炼蛊/遭遇）→
# 战斗（手牌卡/普攻）→ 飞升/死亡落账 → 汇总打印。全程只经
# RunController.submit_command 真实领域通道，无内联捷径。
# 用法：& .\tools\godot.ps1 --headless --path . -s res://scripts/playthrough_smoke.gd

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const BattleCommandFacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const V1BattleResolverScript = preload("res://scripts/domain/v1_battle_resolver.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")


## 修复 6：非蛊商品（魂丹/材料/配方/服务）不能按 gu_id 取名落成空串。
static func offer_label(offer: Dictionary) -> String:
	var gu_id := str(offer.get("gu_id", ""))
	if not gu_id.is_empty():
		return DisplayText.gu(gu_id)
	var output_gu_id := str(offer.get("output_gu_id", ""))
	if not output_gu_id.is_empty():
		return DisplayText.gu(output_gu_id)
	var material_id := str(offer.get("material_id", ""))
	if not material_id.is_empty():
		return DisplayText.material(material_id)
	var card_key := str(offer.get("card_key", ""))
	if not card_key.is_empty():
		return card_key
	return str(offer.get("id", "商品"))


## 修复 6：离场命令结果的 ok/reason 检查（会话路径 ok 在嵌套 result 里）。
static func leave_result_ok(result: Dictionary) -> bool:
	var payload: Dictionary = result.get("result", result) as Dictionary
	return bool(payload.get("ok", false))


## 修复 6：统一离场——失败即终止冒烟，绝不静默循环重试。
func _leave(controller, context: String) -> bool:
	var result: Dictionary = controller.submit_command({"type": "leave_node"})
	if leave_result_ok(result):
		_tell("%s：已离场" % context)
		return true
	var payload: Dictionary = result.get("result", result) as Dictionary
	_tell("%s：离场被拒（%s）——终止冒烟以防静默空转" % [context, str(payload.get("reason", "unknown"))])
	return false


var _log: Array[String] = []
var _last_view := ""
# 止损检测：同一战斗内敌血持续无变化则认定打不动，尝试撤离。
var _stuck_battle_id := ""
var _stuck_count := 0
var _stuck_enemy_hp := -1


func _initialize() -> void:
	var controller := RunControllerScript.new()
	controller.catalog = ContentCatalog.load_all()
	# 发散试玩参数：PLAYTHROUGH_SEED / PLAYTHROUGH_CONTRACTS（逗号分隔，空=无契约）。
	var seed_env := OS.get_environment("PLAYTHROUGH_SEED")
	var seed_value := int(seed_env) if not seed_env.is_empty() else 20260927
	var contract_env := OS.get_environment("PLAYTHROUGH_CONTRACTS")
	var contracts: Array[String] = []
	if not contract_env.is_empty():
		for piece in contract_env.split(",", false):
			contracts.append(piece.strip_edges())
	var school_env := OS.get_environment("PLAYTHROUGH_SCHOOL")
	var school := school_env if school_env in ["blood", "qi", "force", "soul", "refine"] else ""
	# 玩家真实开局路径：大厅选择流派与契约后开新局（controller 内部执行 swearing）。
	controller.start_new_run(seed_value, school, contracts)
	_tell("开局 seed=%d | 起点=%s | 元石=%d | 气血=%d/%d | 魂魄=%d | 契约=%s" % [
		seed_value, controller.state.current_node_id,
		int(controller.state.stone), int(controller.state.health),
		int(controller.state.max_health), int(controller.state.cultivator.get("soul", 0)),
		str(controller.state.contracts),
	])

	var steps := 0
	var outcome := "ongoing"
	# 拓扑 v2 一局 160–220 节点（含每层 Boss 台），400 步预算必然中途截断。
	while steps < 900 and outcome == "ongoing":
		steps += 1
		outcome = _step(controller)
		if controller.state != null and controller.state.is_terminal():
			outcome = "terminal"
	_tell("-- 游玩结束 --")
	_tell("总步数: %d | 结局: %s" % [steps, outcome])
	_tell("终局状态: 节点=%s | 元石=%d | 气血=%d/%d | 蛊=%d | 契约=%s | 图鉴=%d | 事件=%d" % [
		controller.state.current_node_id, int(controller.state.stone),
		int(controller.state.health), int(controller.state.max_health),
		(controller.state.gu_instances as Dictionary).size(),
		str(controller.state.contracts), (controller.state.global_codex_ids as Array).size(),
		(controller.state.event_log as Array).size(),
	])
	var dda_triggers := 0
	for event in controller.state.event_log:
		if str(event.get("action", "")) == "dda_marker":
			dda_triggers += 1
	_tell("DDA 标记触发: %d 次" % dda_triggers)
	_tell("中途进程: %s" % ["失败(无进展)" if steps >= 900 else "正常"])
	controller.free()
	quit(0)


func _step(controller) -> String:
	var view: String = controller.current_view_name()
	if view == "Battle" and _last_view != "Battle":
		_tell("开战于 %s（%s）" % [
			controller.state.current_node_id,
			str(controller.current_node.get("enemy_kind", "")),
		])
	_last_view = view
	match view:
		"Map":
			return _step_map(controller)
		"Shop":
			return _step_shop(controller)
		"Encounter":
			return _step_encounter(controller)
		"Rest":
			return _step_via_cards(controller, "休整")
		"Refine":
			# 玩家策略：有元石就先做同名升阶（质量换预算的核心成长点）。
			for recipe_value in controller.catalog.get("refinement_recipes", []):
				var recipe: Dictionary = recipe_value
				if str(recipe.get("kind", "")) != "advance":
					continue
				var result: Dictionary = controller.submit_command({"type": "refine_gu", "recipe_id": str(recipe.get("id", ""))})
				if bool(result.get("ok", false)) or bool((result.get("result", {}) as Dictionary).get("ok", false)):
					_tell("炼蛊台：同名升阶 %s" % str(recipe.get("id", "")))
					return "ongoing"
			if not _leave(controller, "炼蛊台"):
				return "leave_blocked"
			return "ongoing"
		"Reward":
			if not _leave(controller, "战利品"):
				return "leave_blocked"
			return "ongoing"
		"Npc":
			if not _leave(controller, "NPC"):
				return "leave_blocked"
			return "ongoing"
		"Battle":
			return _step_battle(controller)
		"Ending", "Title", "Hall", "Settings", "Codex", "Journal":
			return str(view).to_lower()
		_:
			_tell("未知视口 %s：尝试离开" % view)
			if not _leave(controller, "未知视口"):
				return "leave_blocked"
			return "ongoing"


func _step_via_cards(controller, label: String) -> String:
	# 通用节点策略：按官方动作预览逐张消费可执行卡（含休整双选/地脉探查），
	# 全部处置完或只剩离场时离开。硬编码单一动作会撞 R8.1 rest_choice 门禁。
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(
		controller.state, controller.current_node, controller.catalog)
	var node_type := str(controller.current_node.get("type", ""))
	var acted := false
	for card in cards:
		var card_id := str(card.get("id", ""))
		if not bool(card.get("executable", false)):
			continue
		if str(card_id) == "node.leave":
			continue
		# 玩家理财：元石要留给战力构筑；商店之外不为情报/服务掏钱。
		var cost: Dictionary = card.get("cost", {})
		if int(cost.get("stone", 0)) > 0 and node_type != "shop":
			continue
		var command: Dictionary = card.get("command", {})
		if command.is_empty():
			continue
		command = command.duplicate(true)
		command["type"] = "action_card"
		command["action_id"] = card_id
		command["state_version"] = controller.state.event_log.size()
		var result: Dictionary = controller.submit_command(command)
		# 会话路径返回 {state, session, feed, result}：ok 在内层 result 里。
		var payload: Dictionary = result.get("result", result) as Dictionary
		var battle_started: bool = bool(payload.get("start_battle", false)) \
			or controller.current_view_name() == "Battle"
		if battle_started or bool(payload.get("ok", false)):
			_tell("%s：执行 %s" % [label, card_id])
			acted = true
		else:
			_tell("%s：%s 被拒（%s）" % [label, card_id, str(payload.get("reason", "unknown"))])
		break
	if not acted:
		if not _leave(controller, label):
			return "leave_blocked"
		_tell("%s：已无可用动作，离场" % label)
	return "ongoing"


func _step_map(controller) -> String:
	# 玩家生存本能：带伤先吃粮（材料「直接使用」通路），气血不满才优先休整。
	if int(controller.state.health) < int(controller.state.max_health):
		for mat_id in ["beast_blood", "beast_bone"]:
			if int(controller.state.materials.get(mat_id, 0)) > 0:
				var eaten: Dictionary = controller.submit_command({"type": "use_material", "material_id": mat_id})
				var eaten_result: Dictionary = eaten.get("result", eaten) as Dictionary
				if bool(eaten_result.get("ok", false)):
					_tell("服用 %s 调理气血（气血=%d）" % [mat_id, int(controller.state.health)])
					return "ongoing"

	var visible: Array = controller.visible_route_nodes(2)

	var visited: Dictionary = controller.state.node_flags
	# 候选顺序：默认玩家策略为「攒实力、Boss 放最后」——先清其余节点，
	# 气血不足六成或战力未成型也不碰任何关底 Boss（拓扑 v2 每大层都有
	# layer_boss_stand_N 关底台，旧逻辑只认 final_boss_stand 全局门）；
	# 仅当别无可走时才硬闯（或用 PLAYTHROUGH_BOSS_FIRST=1 还原旧的 Boss 优先）。
	# 可见 ≠ 可达，逐个尝试直到成功。
	var boss_first := OS.get_environment("PLAYTHROUGH_BOSS_FIRST") == "1"
	var hurt := int(controller.state.health) * 10 < int(controller.state.max_health) * 6
	var strong_enough := (controller.state.gu_instances as Dictionary).size() >= 2 \
		or int(controller.state.stone) >= 10
	var boss_ready := (not hurt) and strong_enough
	var candidates: Array[Dictionary] = []
	var reposition: Array[Dictionary] = []
	var boss_node := {}
	for node in visible:
		var node_id := str(node.get("id", ""))
		if _is_boss_stand(node):
			boss_node = node
			continue
		# 前瞻节点（reachable=false）会让 travel 必被拒，会浪费步数与刷
		# unreachable_route_node 噪声；先只收当前可达的候选。Boss/已访
		# 问节点保留特殊路径在下面单独处理。
		if not bool(node.get("reachable", false)):
			continue
		if visited.has(node_id):
			# 领域允许沿前向边重走已访问节点：困在无 Boss 边的行末时可
			# 绕行到有 Boss 边的节点——兜底重定位目标，优先级最低。
			reposition.append(node)
			continue
		candidates.append(node)
	# 冲仙五项收集优先（玩家策略：升仙前集齐条件节点）；气血不满就主动
	# 补休整（防带伤抵达 Boss 台后无路可退），其余节点随后。
	var sources := ["body_imprint_ritual", "earth_vein_contest", "sealed_earth_vein", "mist_shrine", "poison_fog_vein"]
	var prioritized: Array[Dictionary] = []
	var rest_first: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	var optional_combat: Array[Dictionary] = []
	for candidate in candidates:
		var node_id := str(candidate.get("id", ""))
		var candidate_type := str(candidate.get("type", ""))
		if _is_ascension_source(candidate, sources):
			prioritized.append(candidate)
		elif int(controller.state.health) < int(controller.state.max_health) and candidate_type == "rest":
			rest_first.append(candidate)
		elif candidate_type in ["combat", "pursuit"]:
			optional_combat.append(candidate)
		else:
			others.append(candidate)
	candidates = prioritized
	for rest_node in rest_first:
		candidates.append(rest_node)
	for other in others:
		candidates.append(other)
	for combat_node in optional_combat:
		candidates.append(combat_node)
	# 未访问节点全部走完后，允许沿前向边重走已访问节点（领域不拒 visited），
	# 绕到有 Boss 边的节点——单向链上不再困死。
	if candidates.is_empty():
		for rep in reposition:
			candidates.append(rep)
	if not boss_node.is_empty():
		if boss_first or boss_ready or candidates.is_empty():
			if boss_first:
				candidates.push_front(boss_node)
			else:
				candidates.append(boss_node)
	var traveled := false
	for target in candidates:
		var node_id := str(target.get("id", ""))
		var result: Dictionary = controller.submit_command({"type": "travel", "node_id": node_id})
		if bool(result.get("ok", false)):
			_tell("行至 %s (%s)：元石=%d 气血=%d" % [
				node_id, str(target.get("type", "")),
				int(controller.state.stone), int(controller.state.health),
			])
			traveled = true
			break
		_tell("行至被拒 %s：%s" % [node_id, str(result.get("reason", "unknown"))])
	# 兜底：候选里全是不可达的未访问节点（如下一大层被 Boss 门禁锁住）
	# 时，Boss 台仍在当前可达集内——硬着头皮也要试（困死比战败更糟）。
	if not traveled and not boss_node.is_empty():
		var boss_id := str(boss_node.get("id", ""))
		var boss_travel: Dictionary = controller.submit_command({"type": "travel", "node_id": boss_id})
		if bool(boss_travel.get("ok", false)):
			_tell("行至 %s (boss)：元石=%d 气血=%d" % [
				boss_id, int(controller.state.stone), int(controller.state.health),
			])
			return "ongoing"
		_tell("行至被拒 %s：%s" % [boss_id, str(boss_travel.get("reason", "unknown"))])
	if not traveled:
		_tell("地图无新节点可走（路线尽头）")
		return "no_route"
	return "ongoing"


func _is_ascension_source(node: Dictionary, sources: Array) -> bool:
	var node_id := str(node.get("id", ""))
	var template_id := str(node.get("template_id", ""))
	return sources.has(node_id) or sources.has(template_id)


func _is_boss_stand(node: Dictionary) -> bool:
	# 关底 Boss 台：拓扑 v2 层 Boss（template_id=layer_boss_stand_N，实例 id
	# 是 L{层}R{行}N{序}）+ 五层终局 final_boss_stand。
	var node_id := str(node.get("id", ""))
	if node_id == "final_boss_stand":
		return true
	return str(node.get("template_id", "")).begins_with("layer_boss_stand")


const STONE_RESERVE := 1


func _owned_count(state, gid: String) -> int:
	var count := 0
	for inst in state.gu_instances.values():
		if str(inst.get("definition_id", "")) == gid:
			count += 1
	return count


func _step_shop(controller) -> String:
	# 玩家视角：把元石花成战力——优先未持有的战力蛊，已持有的同名卡再买
	# 也有价值（多一张手牌 + 同名升阶的原料）；灵魂丹在魂魄不满时补；
	# 货阶高于当前大层的不碰（shop_tier_locked 必拒）。留 2 元石应急。
	var node_type := str(controller.current_node.get("type", ""))
	var state = controller.state
	var max_tier: int = ResolverScript.shop_max_tier(state, controller.catalog)
	if node_type == "caravan":
		var caravan_offers: Array[Dictionary] = []
		for offer_value in controller.catalog.get("caravan_offer_by_id", {}).values():
			var offer: Dictionary = offer_value
			if str(offer.get("kind", "")) != "buy":
				continue
			caravan_offers.append(offer)
		caravan_offers.sort_custom(func(a, b): return int(a.get("stone_cost", 0)) < int(b.get("stone_cost", 0)))
		for offer in caravan_offers:
			var price := int(offer.get("stone_cost", 0))
			if int(state.stone) - price >= STONE_RESERVE:
				var bought: Dictionary = controller.submit_command({"type": "buy_gu", "offer_id": str(offer.get("id", ""))})
				var bought_payload: Dictionary = bought.get("result", bought) as Dictionary
				if bool(bought_payload.get("ok", false)):
					_tell("商队购入 %s（%d 元石）" % [offer_label(offer), price])
		if not _leave(controller, "商队"):
			return "leave_blocked"
		return "ongoing"
	var shop_offers: Array[Dictionary] = []
	for offer_value in controller.catalog.get("shop_offer_by_id", {}).values():
		var offer: Dictionary = offer_value
		var kind := str(offer.get("kind", ""))
		var tier := int(offer.get("tier", 1))
		if tier > max_tier:
			continue
		# 玩家优先级：战力蛊（purchase）> 魂丹（soul_boost，魂魄不满才买）。
		if kind == "purchase":
			shop_offers.append(offer)
		elif kind == "soul_boost" and int(state.cultivator.get("soul", 0)) < int(state.cultivator.get("soul_max", 0)):
			shop_offers.append(offer)
	shop_offers.sort_custom(func(a, b):
		var a_owned := _owned_count(state, str(a.get("gu_id", "")))
		var b_owned := _owned_count(state, str(b.get("gu_id", "")))
		if a_owned != b_owned:
			return a_owned < b_owned
		return int(a.get("stone_cost", 0)) < int(b.get("stone_cost", 0)))
	for offer in shop_offers:
		var price := int(offer.get("stone_cost", 0))
		if price <= 0 or int(state.stone) - price < STONE_RESERVE:
			continue
		var bought: Dictionary = controller.submit_command({"type": "shop_purchase", "offer_id": str(offer.get("id", ""))})
		var bought_payload: Dictionary = bought.get("result", bought) as Dictionary
		if bool(bought_payload.get("ok", false)):
			_tell("黑市购入 %s（%d 元石）" % [offer_label(offer), price])
		else:
			_tell("黑市购入被拒：%s（%s）" % [offer_label(offer), str(bought_payload.get("reason", "unknown"))])
	if not _leave(controller, "黑市"):
		return "leave_blocked"
	return "ongoing"


func _step_encounter(controller) -> String:
	var node: Dictionary = controller.current_node
	var node_type := str(node.get("type", ""))
	# 战后阶段：胜利后结算再离场（玩家视角的战后处理）。
	if str(controller.current_session.get("phase", "")) == "post_battle":
		if not _leave(controller, "战后结算"):
			return "leave_blocked"
		return "ongoing"
	# 升仙窗：玩家终局抉择（需先击败 Boss，choice=now 是真实命令契约）。
	if node_type == "ascension":
		# 玩家策略（规格：可补足一个短板后冲仙）：先在窗口内筹备护道，
		# 再冲仙；结果从嵌套 result 里读取（attempt_ascension 的 ok/outcome）。
		var prepared: Dictionary = controller.submit_command({"type": "choose_action", "action_id": "prepare"})
		if bool(prepared.get("ok", false)):
			_tell("升仙窗口：护道筹备完成")
		var attempted: Dictionary = controller.submit_command({"type": "attempt_ascension", "choice": "now"})
		var nested: Dictionary = attempted.get("result", attempted) as Dictionary
		var outcome := str(nested.get("outcome", ""))
		if outcome.is_empty():
			outcome = str(nested.get("reason", "unknown"))
		_tell("尝试飞升：%s（条件 %s）" % [outcome, str(nested.get("conditions", {}))])
		if controller.current_view_name() == "Ending":
			_tell("已进入统一结算页 Ending")
			return "ending"
		_tell("飞升未成（%s），本次旅途结束" % outcome)
		return "retreat_end"
	# 总账：先结清养蛊开支（玩家必做项）。
	if node_type == "ledger":
		var settled: Dictionary = controller.submit_command({"type": "settle_feeding"})
		if not bool(settled.get("ok", false)):
			controller.submit_command({"type": "choose_action", "action_id": "accept_debt"})
		_tell("总账结清：元石=%d" % int(controller.state.stone))
		if not _leave(controller, "总账"):
			return "leave_blocked"
		return "ongoing"
	if node_type == "event":
		var choices: Array = node.get("choices", [])
		if not choices.is_empty():
			var taken: Dictionary = controller.submit_command({"type": "choose_action", "action_id": str(choices[0])})
			_tell("事件选项 %s: %s" % [str(choices[0]), "接受" if bool(taken.get("ok", false)) else "被拒(%s)" % str(taken.get("reason", ""))])
		if not _leave(controller, "事件"):
			return "leave_blocked"
		return "ongoing"
	# 其余节点（险地/传承/野蛊/地脉/闭关等）：按预览卡逐张处置后离场。
	return _step_via_cards(controller, "遭遇")


func _step_battle(controller) -> String:
	var battle: Dictionary = controller.current_battle
	var living_enemies := _living_enemies(battle)
	var enemy_hp := _total_enemy_hp(living_enemies)
	var node_id := str(controller.current_node.get("id", "battle"))
	if node_id != _stuck_battle_id:
		_stuck_battle_id = node_id
		_stuck_count = 0
		_stuck_enemy_hp = enemy_hp
	elif enemy_hp == _stuck_enemy_hp:
		_stuck_count += 1
	else:
		_stuck_count = 0
		_stuck_enemy_hp = enemy_hp
	var intent_damage := _incoming_damage(living_enemies)
	var player: Dictionary = battle.get("player", {})
	var hp := int(player.get("hp", 0))
	var max_hp := maxi(1, int(player.get("max_hp", 1)))
	var can_flee: bool = not BattleCommandFacadeScript.boss_blocks_retreat(battle)
	# V1 蛊行动制选牌：按 v1_effect 种类挑攻击/守护蛊（瞬发或常驻皆可）。
	var attack_gu := _pick_effect_gu(battle, ["strike"])
	var guard_gu := _pick_effect_gu(battle, ["shield", "buff"])
	var finish_now := enemy_hp <= 1
	var immediate_kill := finish_now and not attack_gu.is_empty()
	var guarded: bool = int(player.get("shield", 0)) > 0
	var command: Dictionary
	if immediate_kill:
		command = _play_gu_command(battle, attack_gu)
	elif can_flee and finish_now and attack_gu.is_empty():
		command = _battle_turn_command(controller, "retreat")
	elif can_flee and (hp <= 1 or intent_damage >= hp or _stuck_count >= 6):
		command = _battle_turn_command(controller, "retreat")
	elif not can_flee:
		# Boss 死战节奏：攻击与守护交替，危险线守护优先，收头窗口搏命，
		# 僵局 4 步强制恢复进攻。
		var kill_window := enemy_hp <= 4
		var danger := hp <= intent_damage * 2
		var must_attack := (not attack_gu.is_empty()) and (not danger or kill_window or guarded or _stuck_count >= 4)
		if must_attack:
			command = _play_gu_command(battle, attack_gu)
		elif danger and not guarded and not guard_gu.is_empty():
			command = _play_gu_command(battle, guard_gu)
		elif not guard_gu.is_empty() and guard_gu != attack_gu:
			command = _play_gu_command(battle, guard_gu)
		else:
			command = _battle_turn_command(controller, "basic_attack")
	else:
		# 常规战：敌方大伤害先守护，否则攻击，无牌收势换回合。
		if intent_damage >= 2 and not guarded and not guard_gu.is_empty():
			command = _play_gu_command(battle, guard_gu)
		elif not attack_gu.is_empty():
			command = _play_gu_command(battle, attack_gu)
		else:
			command = _battle_turn_command(controller, "end_turn")
	var pre_hp := hp
	var result: Dictionary = controller.submit_command(command)
	if bool(result.get("finished", false)):
		_tell("战斗结束：%s（我方气血 %d/%d）" % [
			str(result.get("result", "unknown")),
			int(player.get("hp", 0)), max_hp,
		])
		if str(result.get("result", "")) == "retreat":
			if not _leave(controller, "止损撤离"):
				return "leave_blocked"
			_tell("止损撤离，离开该节点")
		return "ongoing"
	# 拒绝回退：命令被拒不推进时依次回退 肉体搏斗 → 收势，避免原地空转。
	var live_battle: Dictionary = controller.current_battle
	var live_player: Dictionary = live_battle.get("player", {})
	if int(live_player.get("hp", 0)) == pre_hp and _stuck_count >= 1:
		var punch: Dictionary = controller.submit_command(_battle_turn_command(controller, "basic_attack"))
		if not bool(punch.get("finished", false)) and int(live_battle["player"].get("hp", 0)) == pre_hp:
			controller.submit_command(_battle_turn_command(controller, "end_turn"))
	return "ongoing"


func _pick_effect_gu(battle: Dictionary, kinds: Array) -> String:
	# V1：按 v1_effect 种类挑一张本回合可释放的战斗蛊（瞬发/常驻皆可）。
	var slots: Array = battle.get("gu_slots", [])
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if bool(slot.get("consumed", false)) or bool(slot.get("is_sealed", false)) or bool(slot.get("used_this_turn", false)):
			continue
		if str(slot.get("effect", {}).get("kind", "")) not in kinds:
			continue
		if V1BattleResolverScript.can_play_gu(battle, i) != "":
			continue
		return str(slot.get("instance_id", ""))
	return ""


func _play_gu_command(battle: Dictionary, instance_id: String) -> Dictionary:
	return {"type": "use_gu", "instance_id": instance_id}


func _battle_turn_command(controller, command_type: String) -> Dictionary:
	return {"type": command_type}


func _living_enemies(battle: Dictionary) -> Array[Dictionary]:
	var living: Array[Dictionary] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", int(enemy.get("hp", 0)) > 0)):
			living.append(enemy)
	return living


func _total_enemy_hp(enemies: Array[Dictionary]) -> int:
	var total := 0
	for enemy in enemies:
		total += maxi(0, int(enemy.get("hp", 0)))
	return total


func _incoming_damage(enemies: Array[Dictionary]) -> int:
	var total := 0
	for enemy in enemies:
		total += maxi(0, int((enemy.get("intent", {}) as Dictionary).get("damage", 0)))
	return total


func _tell(text: String) -> void:
	_log.append(text)
	print("[play] %s" % text)
