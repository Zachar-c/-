class_name BattleSnapshot
extends RefCounted


# W12 split: the Battle and Kill screen snapshots, moved verbatim from
# run_snapshot_builder.gd. Read-only projection of the single V1 battle
# schema; multi-screen shared helpers stay on RunSnapshotBuilder and are
# called via the global class name.


const V1BattleResolverScript = preload("res://scripts/domain/v1_battle_resolver.gd")
const BattleCommandFacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const ActionPointsScript = preload("res://scripts/domain/action_points.gd")


## 战斗屏快照：唯一 V1 战斗 Schema 投影（BattleCommandFacade → V1BattleResolver）。
## 领域状态只有 "battle/player/gu_slots/enemies/kill_moves/flags(Dictionary)" 一套，
## 本函数只做字段搬运与文字拼装，绝不重算领域结果；旧卡牌字段
## （draw_pile/actions_max/visible_intent/Array flags）一律不再读取。
static func build_battle(controller) -> Dictionary:
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var battle_data: Dictionary = controller.current_battle
	var out := RunSnapshotBuilder._gui_state(controller)
	out["enemies"] = _v1_enemies(battle_data)
	out["player"] = _v1_player(battle_data)
	out["hand"] = _v1_hand(battle_data, catalog)
	out["piles"] = {}
	out["actions"] = _v1_actions(battle_data)
	out["default_target_id"] = _first_living_enemy_id(out["enemies"])
	out["kill_moves"] = _v1_kill_moves(battle_data, catalog)
	# R-boss-no-retreat：门禁以 V1 flags(Dictionary) 判定（facade 与 resolver 同源），
	# UI 只镜像展示结果，不自行判断敌人定义。
	out["flee_available"] = not BattleCommandFacadeScript.boss_blocks_retreat(battle_data)
	# S4 元素协同：本回合流派支援随快照透出（透明度红线）。
	out["turn_supports"] = battle_turn_supports(battle_data)
	out["synthesis"] = RunSnapshotBuilder._synthesis_options(state, catalog)
	out["can_ultimate"] = false
	out["dda_boss_hint"] = str(battle_data.get("dda_boss_hint", ""))
	out["first_battle"] = not state.event_log.any(func(event): return str(event.get("action", "")) == "battle_finished")
	# 手牌版本 = 领域 event_log 大小（与 use_gu 命令 state_version 同源），供 UI 判断
	# 快照是否推进：相同版本重挂载不清重复提交缓存，避免同命令被重放。
	out["hand_version"] = int(state.event_log.size())
	return out


static func battle_turn_supports(battle_data: Dictionary) -> Dictionary:
	## S4 元素协同：本回合流派支援（流派 id -> 加成值），供快照与小组件读取。
	return (battle_data.get("turn_supports", {}) as Dictionary).duplicate(true)


static func _v1_enemies(battle_data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enemy_value in battle_data.get("enemies", []):
		var enemy: Dictionary = enemy_value
		var raw_label := str(enemy.get("label", ""))
		var enemy_id := str(enemy.get("id", ""))
		# label 为原始 kind/缺省时用 DisplayText 翻译；自定义 label 直通。
		var name := raw_label
		if raw_label.is_empty() or raw_label == enemy_id:
			name = DisplayText.enemy(enemy_id)
		out.append({
			"id": enemy_id,
			"name": name,
			"hp": int(enemy.get("hp", 0)),
			"max_hp": maxi(1, int(enemy.get("max_hp", 1))),
			"shield": int(enemy.get("shield", 0)),
			"statuses": RunSnapshotBuilder._statuses_to_list(enemy.get("statuses", {})),
			"intent": _v1_intent_to_screen(enemy.get("intent", {})),
			"alive": bool(enemy.get("alive", true)),
			"counter_revealed": (enemy.get("counter_revealed", []) as Array).duplicate(),
		})
	return out


## V1 敌人意图（kind 直映，不套旧引擎的 damage/defense 推断）。
static func _v1_intent_to_screen(i: Dictionary) -> Dictionary:
	var kind := str(i.get("kind", "attack"))
	var base := {
		"type": kind,
		"value": 0,
		"detail": str(i.get("label", "蓄力")),
		"speed": int(i.get("speed", 0)),
	}
	match kind:
		"attack":
			base["value"] = int(i.get("damage", 0))
		"seal":
			base["value"] = int(i.get("seal_turns", 0))
		"soul_drain":
			base["value"] = int(i.get("soul_drain", 0))
		"life_cost":
			base["value"] = int(i.get("life_cost", 0))
		"counter":
			base["value"] = 0
			base["tag"] = str(i.get("counter_tag", ""))
	return base


static func _v1_player(battle_data: Dictionary) -> Dictionary:
	var p: Dictionary = battle_data.get("player", {})
	return {
		"hp": int(p.get("hp", 0)),
		"max_hp": maxi(1, int(p.get("max_hp", 1))),
		"shield": int(p.get("shield", 0)),
		"primordial": int(p.get("true_qi", 0)),
		"primordial_max": maxi(1, int(p.get("true_qi_max", 1))),
		"soul": int(p.get("soul", 0)),
		"life_time": int(p.get("life_time", 0)),
		"thoughts": int(p.get("thoughts", 0)),
		"used_this_turn": int(p.get("used_this_turn", 0)),
		"statuses": _v1_buffs_to_statuses(p.get("buffs", {})),
		"buffs": (p.get("buffs", {}) as Dictionary).duplicate(true),
	}


## 行动点（V1 念头预算）投影：max=魂魄底蕴分档，left=预算-已用。
static func _v1_actions(battle_data: Dictionary) -> Dictionary:
	var p: Dictionary = battle_data.get("player", {})
	var budget := ActionPointsScript.per_turn(int(p.get("soul", 1)))
	var used := clampi(int(p.get("used_this_turn", 0)), 0, budget)
	return {"max": budget, "left": budget - used, "used": used}


static func _v1_buffs_to_statuses(buffs: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in buffs:
		var stacks := int(buffs[key])
		if stacks > 0:
			out.append({"name": SnapshotTextUtil._buff_label(str(key)), "stacks": stacks})
	return out


## V1 手牌：每个蛊槽一张卡（id "gu.<instance_id>"）+ 拳脚（肉体搏斗）。
## 可执行性直接复用 V1 领域门禁 can_play_gu/basic_attack_reason，禁止 UI 自算。
static func _v1_hand(battle_data: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	for i in (battle_data.get("gu_slots", []) as Array).size():
		var slot: Dictionary = battle_data["gu_slots"][i]
		var def_id := str(slot.get("definition_id", ""))
		var definition: Dictionary = gu_by_id.get(def_id, {})
		var reason := V1BattleResolverScript.can_play_gu(battle_data, i)
		var note := _v1_slot_note(slot)
		var effect := SnapshotTextUtil._v1_effect_text(slot)
		var slot_effect: Dictionary = slot.get("effect", {})
		var support_school := str(slot_effect.get("support_school", ""))
		var support_bonus := int(slot_effect.get("support_bonus", 0))
		if not support_school.is_empty() and support_bonus > 0:
			# S4 元素协同：支援类效果随卡面声明（静态语义）。
			effect = "%s；本回合内后续%s蛊伤害 +%d" % [effect, SnapshotTextUtil._school_display_name(catalog, support_school), support_bonus]
		# 2026-09-04：手牌摘要携带转数前缀，升阶蛊与定义转数一眼可分。
		var summary := "%d转·%s" % [maxi(1, int(slot.get("rank", 1))), effect]
		summary = summary if note == "" else "%s（%s）" % [summary, note]
		if bool(slot.get("is_permanent", false)):
			summary = "%s · 常驻 %s" % [summary, str(slot.get("durability_mode", ""))]
		var risks := _v1_life_cost_risk(slot)
		var live_support := int((battle_data.get("turn_supports", {}) as Dictionary).get(str(slot.get("school", "")), 0))
		if live_support > 0:
			# S4 元素协同：当前回合已生效的流派支援随卡面透出（透明度红线）。
			risks.append("当前受%s支援：本回合该流派蛊伤害 +%d。" % [SnapshotTextUtil._school_display_name(catalog, str(slot.get("school", ""))), live_support])
		var card := {
			"id": "gu.%s" % str(slot.get("instance_id", "")),
			"name": DisplayText.gu(def_id),
			"summary": summary,
			"effect": summary,
			"quality": _gu_quality(definition),
			"cost": _v1_cost_text(slot, "thought_cost", "true_qi_cost", "life_cost"),
			"cost_ex": "",
			"school_label": SnapshotTextUtil._school_display_name(catalog, str(definition.get("school", ""))),
			"school_id": str(definition.get("school", "")),
			"executable": reason.is_empty(),
			"block_reason": _v1_reject_text(reason),
			"known_risk": risks,
			"target_type": "single_enemy" if str(slot.get("effect", {}).get("kind", "")) == "strike" else "none",
			"valid_target_ids": _living_enemy_ids_v1(battle_data),
			"curse_warning": false,
			"state_version": int(battle_data.get("turn", 1)),
			"expected_phase": str(battle_data.get("phase", "player_action")),
		}
		out.append(card)
	var punch_reason := V1BattleResolverScript.basic_attack_reason(battle_data)
	var fight_damage := int(battle_data.get("cfg", {}).get("fight_damage_base", 1))
	out.append({
		"id": "basic_attack",
		"name": "拳脚",
		"summary": "肉体搏斗：基础 %d 伤 + 力道 + 仪仗，耗 1 念头。" % fight_damage,
		"effect": "基础 %d 伤 + 力道 + 仪仗" % fight_damage,
		"quality": "普通",
		"cost": "念头 1",
		"cost_ex": "",
		"school_label": "",
		"executable": punch_reason.is_empty(),
		"block_reason": _v1_reject_text(punch_reason),
		"known_risk": [],
		"target_type": "single_enemy",
		"valid_target_ids": _living_enemy_ids_v1(battle_data),
		"curse_warning": false,
		"state_version": int(battle_data.get("turn", 1)),
		"expected_phase": str(battle_data.get("phase", "player_action")),
	})
	return out


static func _v1_slot_note(slot: Dictionary) -> String:
	if bool(slot.get("is_sealed", false)):
		return "封印 %d 回合" % int(slot.get("seal_turns", 0))
	if bool(slot.get("consumed", false)):
		return "已消耗"
	if bool(slot.get("used_this_turn", false)):
		return "本回合已用"
	return ""


static func _v1_cost_text(slot: Dictionary, thought_key: String, qi_key: String, life_key: String) -> String:
	var parts: Array[String] = []
	if int(slot.get(qi_key, 0)) > 0:
		parts.append("真元 %d" % int(slot.get(qi_key, 0)))
	parts.append("念头 %d" % int(slot.get(thought_key, 1)))
	if int(slot.get(life_key, 0)) > 0:
		parts.append("寿元 %d" % int(slot.get(life_key, 0)))
	return " · ".join(parts)


static func _v1_life_cost_risk(slot: Dictionary) -> Array[String]:
	if int(slot.get("life_cost", 0)) <= 0:
		return []
	return ["释放此蛊消耗寿元 %d，寿元归零将当场陨落。" % int(slot.get("life_cost", 0))]


static func _gu_quality(definition: Dictionary) -> String:
	match str(definition.get("rarity", "")):
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary", "legacy": return "传说"
	return ""


static func _v1_reject_text(reason: String) -> String:
	match reason:
		"unknown_gu": return "未知蛊虫"
		"gu_consumed": return "此蛊已在战斗中被消耗"
		"gu_sealed": return "此蛊正被封印"
		"gu_used_this_turn": return "此蛊本回合已释放"
		"action_limit_reached": return "本回合行动次数已用完"
		"insufficient_thought": return "念头不足（每次行动耗 1 念头）"
		"insufficient_true_qi": return "真元不足"
		"insufficient_qi_quality": return "真元质量不足，无法催动此转数的蛊虫"
		"kill_move_recipe_sealed": return "配方蛊被封印，杀招不可用"
		"unknown_kill_move": return "未知杀招"
	return reason


## V1 杀招：配方实例 → 蛊名（只读拼装），可释放性复用 kill_move_reason 门禁。
## 杀招屏快照：研习录（已研习）+ 战斗栏位（装配槽）。
## 数据源与战斗屏同一套 battle.kill_moves；无战斗数据时给空态。
static func build_kill(controller) -> Dictionary:
	var base := RunSnapshotBuilder._gui_state(controller)
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var battle: Dictionary = controller.current_battle if controller.current_battle != null else {}
	base["title"] = "杀招"
	base["subtitle"] = "研习于战 · 一场一用"
	base["study_slots"] = 3
	base["kill_moves"] = _v1_kill_moves(battle, catalog)
	var slots: Array[Dictionary] = []
	var moves: Array = battle.get("kill_moves", [])
	for i in mini(3, moves.size()):
		var mv: Dictionary = moves[i] if moves[i] is Dictionary else {}
		slots.append({
			"name": str(mv.get("name", "")),
			"sequence_display": str(mv.get("sequence_display", "")),
			"cost": str(mv.get("cost", "")),
		})
	base["slots"] = slots
	return base


static func _v1_kill_moves(battle_data: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for km_value in battle_data.get("kill_moves", []):
		var km: Dictionary = km_value
		var recipe_names: Array[String] = []
		for instance_id_value in km.get("recipe", []):
			var slot := _find_v1_slot(battle_data, str(instance_id_value))
			if not slot.is_empty():
				recipe_names.append(DisplayText.gu(str(slot.get("definition_id", ""))))
			else:
				recipe_names.append(str(instance_id_value))
		var reason := V1BattleResolverScript.kill_move_reason(battle_data, str(km.get("id", "")))
		var costs: Array[String] = []
		if int(km.get("true_qi_cost", 0)) > 0:
			costs.append("真元 %d" % int(km.get("true_qi_cost", 0)))
		costs.append("念头 %d" % int(km.get("thought_cost", 1)))
		if int(km.get("life_cost", 0)) > 0:
			costs.append("寿元 %d" % int(km.get("life_cost", 0)))
		out.append({
			"id": str(km.get("id", "")),
			"name": str(km.get("label", str(km.get("id", "")))),
			"sequence_display": " · ".join(recipe_names) if not recipe_names.is_empty() else "配方缺失",
			"progress": 0,
			"next_name": "",
			"total": 0,
			"cost": " · ".join(costs),
			"effect": SnapshotTextUtil._v1_effect_text(km),
			"executable": reason.is_empty(),
			"block_reason": _v1_reject_text(reason),
		})
	return out


static func _find_v1_slot(battle_data: Dictionary, instance_id: String) -> Dictionary:
	for slot in battle_data.get("gu_slots", []):
		if str(slot.get("instance_id", "")) == instance_id:
			return slot
	return {}


static func _living_enemy_ids_v1(battle_data: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for enemy_value in battle_data.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", true)) and int(enemy.get("hp", 0)) > 0:
			ids.append(str(enemy.get("id", "")))
	return ids


static func _first_living_enemy_id(enemies: Array[Dictionary]) -> String:
	for enemy in enemies:
		if bool(enemy.get("alive", false)):
			return str(enemy.get("id", ""))
	return ""
