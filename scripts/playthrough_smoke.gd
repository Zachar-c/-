extends SceneTree

# 玩家视角游玩冒烟（playthrough smoke）：无头驱动一整局真实游玩回路——
# 大厅开局契约 → 地图逐节点推进（商队/黑市/险地/休整/炼蛊/遭遇）→
# 战斗（手牌卡/普攻）→ 飞升/死亡落账 → 汇总打印。全程只经
# RunController.submit_command 真实领域通道，无内联捷径。
# 用法：& .\tools\godot.ps1 --headless --path . -s res://scripts/playthrough_smoke.gd

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")


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
	# 玩家真实开局路径：大厅选中契约后开新局（controller 内部执行 swearing）。
	controller.start_new_run(seed_value, "", contracts)
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
			controller.submit_command({"type": "leave_node"})
			return "ongoing"
		"Reward":
			controller.submit_command({"type": "leave_node"})
			return "ongoing"
		"Npc":
			controller.submit_command({"type": "leave_node"})
			return "ongoing"
		"Battle":
			return _step_battle(controller)
		"Ending", "Title", "Hall", "Settings", "Codex", "Journal":
			return str(view).to_lower()
		_:
			_tell("未知视口 %s：尝试离开" % view)
			controller.submit_command({"type": "leave_node"})
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
		controller.submit_command({"type": "leave_node"})
		_tell("%s：已无可用动作，离场" % label)
	return "ongoing"


func _step_map(controller) -> String:
	# 玩家生存本能：带伤先吃粮（材料「直接使用」通路），气血不满才优先休整。
	if int(controller.state.health) < int(controller.state.max_health):
		for mat_id in ["beast_blood", "beast_bone"]:
			if int(controller.state.materials.get(mat_id, 0)) > 0:
				var eaten: Dictionary = controller.submit_command({"type": "use_material", "material_id": mat_id})
				if bool(eaten.get("ok", false)):
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
	for candidate in candidates:
		var node_id := str(candidate.get("id", ""))
		if sources.has(node_id):
			prioritized.append(candidate)
		elif int(controller.state.health) < int(controller.state.max_health) and str(candidate.get("type", "")) == "rest":
			rest_first.append(candidate)
		else:
			others.append(candidate)
	candidates = prioritized
	for rest_node in rest_first:
		candidates.append(rest_node)
	for other in others:
		candidates.append(other)
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
			if str(offer.get("kind", "")) != "purchase":
				continue
			caravan_offers.append(offer)
		caravan_offers.sort_custom(func(a, b): return int(a.get("stone_cost", 0)) < int(b.get("stone_cost", 0)))
		for offer in caravan_offers:
			var price := int(offer.get("stone_cost", 0))
			if int(state.stone) - price >= STONE_RESERVE:
				var bought: Dictionary = controller.submit_command({"type": "buy_gu", "offer_id": str(offer.get("id", ""))})
				var bought_payload: Dictionary = bought.get("result", bought) as Dictionary
				if bool(bought_payload.get("ok", false)):
					_tell("商队购入 %s（%d 元石）" % [str(offer.get("gu_id", "")), price])
		controller.submit_command({"type": "leave_node"})
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
			_tell("黑市购入 %s（%d 元石）" % [str(offer.get("gu_id", "")), price])
		else:
			_tell("黑市购入被拒：%s（%s）" % [str(offer.get("id", "")), str(bought_payload.get("reason", "unknown"))])
	controller.submit_command({"type": "leave_node"})
	return "ongoing"


func _step_encounter(controller) -> String:
	var node: Dictionary = controller.current_node
	var node_type := str(node.get("type", ""))
	# 战后阶段：胜利后结算再离场（玩家视角的战后处理）。
	if str(controller.current_session.get("phase", "")) == "post_battle":
		controller.submit_command({"type": "leave_node"})
		_tell("战后结算完成，离场")
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
			return "ending"
		_tell("飞升未成（%s），本次旅途结束" % outcome)
		return "retreat_end"
	# 总账：先结清养蛊开支（玩家必做项）。
	if node_type == "ledger":
		var settled: Dictionary = controller.submit_command({"type": "settle_feeding"})
		if not bool(settled.get("ok", false)):
			controller.submit_command({"type": "choose_action", "action_id": "accept_debt"})
		_tell("总账结清：元石=%d" % int(controller.state.stone))
		controller.submit_command({"type": "leave_node"})
		return "ongoing"
	if node_type == "event":
		var choices: Array = node.get("choices", [])
		if not choices.is_empty():
			var taken: Dictionary = controller.submit_command({"type": "choose_action", "action_id": str(choices[0])})
			_tell("事件选项 %s: %s" % [str(choices[0]), "接受" if bool(taken.get("ok", false)) else "被拒(%s)" % str(taken.get("reason", ""))])
		controller.submit_command({"type": "leave_node"})
		return "ongoing"
	# 其余节点（险地/传承/野蛊/地脉/闭关等）：按预览卡逐张处置后离场。
	return _step_via_cards(controller, "遭遇")


func _step_battle(controller) -> String:
	var battle: Dictionary = controller.current_battle
	if bool(battle.get("finished", false)):
		_tell("战斗结束：%s（我方气血 %d/%d）" % [
			str(battle.get("result", "unknown")),
			int(controller.state.health), int(controller.state.max_health),
		])
		return "ongoing"
	var battle_id := str(battle.get("battle_id", ""))
	var living_enemies := _living_enemies(battle)
	var enemy_hp := _total_enemy_hp(living_enemies)
	if battle_id != _stuck_battle_id:
		_stuck_battle_id = battle_id
		_stuck_count = 0
		_stuck_enemy_hp = enemy_hp
	elif enemy_hp == _stuck_enemy_hp:
		_stuck_count += 1
	else:
		_stuck_count = 0
		_stuck_enemy_hp = enemy_hp
	var intent_damage := _incoming_damage(living_enemies)
	var hand: Array = battle.get("hand", [])
	var command: Dictionary
	var guarded: bool = (battle.get("flags", []) as Array).has("guarded")
	var can_flee: bool = not BattleResolverScript.boss_blocks_retreat(battle)
	var hp := int(controller.state.health)
	var max_hp := int(controller.state.max_health)
	# 按卡蓝谱 effects 选牌（真值来源）：输出/守护/祛伤各取一张可执行手牌。
	# 旧 slot_role 反查会把侦察/增益蛊当成攻击（trail_eye 当攻击牌打了整局）。
	var attack_id := _pick_card_by_effect(battle, controller, ["strike_enemy", "deal_damage"])
	var heal_id := _pick_card_by_effect(battle, controller, ["relief_injury"])
	var guard_id := _pick_card_by_effect(battle, controller, ["gain_guard", "guard_self"])
	var lethal := intent_damage > 0 and hp <= intent_damage
	var dodging: bool = (battle.get("flags", []) as Array).has("dodging")
	if can_flee and (hp <= 1 or intent_damage >= hp or _stuck_count >= 6):
		# 玩家止损：下一口齐射能咬死（围攻节点 4 伤/回合）或打不动敌血时
		# 抽身——早期小怪可打赢换战利品，但双敌围攻对开局套路是死局，撤为上策。
		command = {"type": "retreat"}
	elif lethal and not dodging and guard_id.is_empty() \
			and (attack_id.is_empty() or _total_enemy_hp(living_enemies) > 4):
		# 敌方下一口能咬死人且手里没有守护牌：闪避保命——除非敌方血量已薄
		#（≤4）且手里有攻击牌，那是搏命收头的窗口，闪避死守只会无限拖延。
		command = {"type": "basic_dodge"}
	elif not can_flee:
		# Boss 死战节奏：守护旗标只挡一口，攻击与垫挡必须交替。血量进入
		# 危险线（两口内死）才垫挡（守护优先、闪避兜底）；敌方血量 ≤4 是
		# 收头窗口——先手结算意味着搏命连砍也能在反打前终结战斗；僵局 4 步
		# 强制恢复进攻（死也要打死，绝不无限闪避拖延）。
		var attack_usable := not attack_id.is_empty() and not attack_id.contains("bind")
		var heal_usable := not heal_id.is_empty() and hp < max_hp and int(controller.state.injury) > 0
		var kill_window := _total_enemy_hp(living_enemies) <= 4
		var danger := hp <= intent_damage * 2
		var must_attack := attack_usable and (not danger or kill_window or _stuck_count >= 4)
		if must_attack:
			command = _play_card_command(battle, attack_id, living_enemies)
		elif danger and not guarded:
			if not guard_id.is_empty():
				command = _play_card_command(battle, guard_id, living_enemies)
			else:
				command = {"type": "basic_dodge"}
		elif heal_usable:
			command = _play_card_command(battle, heal_id, living_enemies)
		elif not guard_id.is_empty():
			command = _play_card_command(battle, guard_id, living_enemies)
		else:
			var punch_result: Dictionary = controller.submit_command(_punch_command(battle, living_enemies))
			if not bool(punch_result.get("finished", false)):
				# 拳脚门（basic_attack_used）只在收势时清除——被拒就收势换牌，
				# 收势同时回气 3/回合并补手牌，绝不能无限闪避空转。
				controller.submit_command({"type": "end_turn"})
			return "ongoing"
	else:
		# 常规战：大口守护 → 攻击 → 带伤祛伤 → 僵局收势换牌。
		if intent_damage >= 2 and not guarded and not guard_id.is_empty():
			command = _play_card_command(battle, guard_id, living_enemies)
		elif not attack_id.is_empty():
			command = _play_card_command(battle, attack_id, living_enemies)
		elif not heal_id.is_empty() and hp < max_hp and int(controller.state.injury) > 0:
			command = _play_card_command(battle, heal_id, living_enemies)
		elif _stuck_count >= 2:
			command = {"type": "end_turn"}
		elif hand.is_empty():
			command = {"type": "end_turn"}
		else:
			command = {"type": "end_turn"}
	var pre_hp := int(controller.state.health)
	var result: Dictionary = controller.submit_command(command)
	if bool(result.get("finished", false)):
		_tell("战斗结束：%s（我方气血 %d/%d）" % [
			str(result.get("result", "unknown")),
			int(controller.state.health), int(controller.state.max_health),
		])
		if str(result.get("result", "")) == "retreat":
			controller.submit_command({"type": "leave_node"})
			_tell("止损撤离，离开该节点")
		return "ongoing"
	# 拒绝回退（旧实现放在 return 之后永远不可达）：命令被拒不推进时依次
	# 回退 普攻 → 收势，避免原地空转耗尽步数。
	if int(controller.state.health) == pre_hp and _stuck_count >= 1:
		var punch: Dictionary = controller.submit_command(_punch_command(battle, living_enemies))
		if not bool(punch.get("finished", false)) and int(controller.state.health) == pre_hp:
			controller.submit_command({"type": "end_turn"})
	return "ongoing"


func _pick_card_by_effect(battle: Dictionary, controller, wanted: Array) -> String:
	# 按卡蓝谱 effects 挑可执行手牌——slot_role 反查会把侦察/增益蛊当成攻击，
	# effects 是唯一真值（strike_enemy/deal_damage=输出，gain_guard=守护）。
	var prefix := "battle.%s." % str(battle.get("battle_id", ""))
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_battle_actions(
		battle, controller.state, controller.catalog)
	var executable := {}
	for card_value in cards:
		var card: Dictionary = card_value
		var card_id := str(card.get("id", ""))
		if card_id.begins_with(prefix) and bool(card.get("executable", false)):
			executable[card_id.trim_prefix(prefix)] = true
	for hand_value in battle.get("hand", []):
		var hand_card: Dictionary = hand_value
		var instance_id := str(hand_card.get("instance_id", ""))
		if not executable.has(instance_id):
			continue
		var definition: Dictionary = controller.catalog.get("card_by_id", {}).get(
			str(hand_card.get("definition_id", "")), {})
		for effect_value in definition.get("effects", []):
			if str(effect_value) in wanted:
				return instance_id
	return ""


func _play_card_command(battle: Dictionary, action_id: String, living_enemies: Array[Dictionary]) -> Dictionary:
	var target_id := str(living_enemies[0].get("enemy_id", "")) if not living_enemies.is_empty() else ""
	return {
		"type": "action_card",
		"action_id": "battle.%s.%s" % [str(battle.get("battle_id", "")), action_id],
		"card_id": action_id,
		"target_id": target_id,
		"state_version": int(battle.get("hand_version", 0)),
	}


func _punch_command(battle: Dictionary, living_enemies: Array[Dictionary]) -> Dictionary:
	var target_id := str(living_enemies[0].get("enemy_id", "")) if not living_enemies.is_empty() else ""
	return {
		"type": "action_card",
		"action_id": "battle.%s.basic.punch" % str(battle.get("battle_id", "")),
		"card_id": "basic.punch",
		"target_id": target_id,
		"state_version": int(battle.get("hand_version", 0)),
	}


func _pick_hand_card(battle: Dictionary, controller, wanted_defs: Array) -> String:
	# 依预览挑一张可执行手牌；wanted_defs 非空时只挑指定蛊（守护类优先策略），
	# 否则挑第一张可执行的单体/自体动作卡（攻击、束缚均可），手牌顺序即平局裁决。
	var hand: Array = battle.get("hand", [])
	if hand.is_empty():
		return ""
	var wanted := {}
	for def_id in wanted_defs:
		wanted[str(def_id)] = true
	var prefix := "battle.%s." % str(battle.get("battle_id", ""))
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_battle_actions(
		battle, controller.state, controller.catalog)
	var fallback := ""
	for card_value in cards:
		var card: Dictionary = card_value
		var card_id := str(card.get("id", ""))
		if not card_id.begins_with(prefix):
			continue
		var instance_id := card_id.trim_prefix(prefix)
		if not bool(card.get("executable", false)):
			continue
		if instance_id in ["basic.punch", "basic.dodge", "retreat", "end_turn"]:
			continue
		var definition_id := _definition_of_instance(hand, instance_id)
		if wanted.has(definition_id):
			return instance_id
		if fallback.is_empty() and str(card.get("target_type", "")) in ["single_enemy", "none", "self"]:
			fallback = instance_id
	return fallback


func _definition_of_instance(hand: Array, instance_id: String) -> String:
	for card_value in hand:
		var card: Dictionary = card_value
		if str(card.get("instance_id", "")) == instance_id:
			return str(card.get("definition_id", ""))
	return ""


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
		total += maxi(0, int((enemy.get("visible_intent", {}) as Dictionary).get("damage", 0)))
	return total


func _tell(text: String) -> void:
	_log.append(text)
	print("[play] %s" % text)
