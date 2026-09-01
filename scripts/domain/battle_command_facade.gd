class_name BattleCommandFacade
extends RefCounted


# V1 战斗门面（2026-08-30 全量替换卡牌战斗）：路由到 V1BattleResolver
# （蛊行动制）。API 形状保持 start/apply_turn/apply_enemy_pre_turn，
# run_controller 与命令通路零改动进入。


const V1Script = preload("res://scripts/domain/v1_battle_resolver.gd")
const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
const CommandSpecRegistryScript = preload("res://scripts/domain/command_spec_registry.gd")
const LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")


const BATTLE_COMMAND_TYPES := [
	"use_gu",
	"end_turn",
	"retreat",
	"basic_attack",
	"play_kill_move",
]


static func start(encounter: Dictionary, state: RunState, catalog: Dictionary = {}) -> Dictionary:
	var enemies := _v1_enemies(encounter, catalog)
	var battle := V1Script.start(state, catalog, enemies)
	# 战斗元信息透传：结算/死亡报告/撤退判定依赖这些顶层键。
	battle["enemy_kind"] = str(encounter.get("enemy_kind", ""))
	battle["kill_source"] = str(encounter.get("kill_source", ""))
	battle["terrain"] = str(encounter.get("terrain", ""))
	battle["layer"] = int(encounter.get("layer", 1))
	battle["first_mover"] = str(encounter.get("first_mover", "player"))
	if encounter.has("enemy_kinds"):
		battle["enemy_kinds"] = (encounter.get("enemy_kinds", []) as Array).duplicate()
	# Boss 身份（V1 契约 flags 为 Dictionary）：关底台 layer_boss > 0 或任一敌方
	# 定义为 tier=="boss" 即禁止撤退。_start_battle 已透传 layer_boss，
	# 这里再按敌方定义兜底，保证 boss_blocks_retreat() 全链可判定。
	var boss_layer := int(encounter.get("layer_boss", 0))
	var boss_tier := false
	var enemy_by_id: Dictionary = catalog.get("enemy_by_id", {})
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if str((enemy_by_id.get(str(enemy.get("id", "")), {}) as Dictionary).get("tier", "")) == "boss":
			boss_tier = true
			break
	if boss_layer > 0 or boss_tier:
		if not (battle["flags"] is Dictionary):
			battle["flags"] = {}
		battle["flags"]["boss_battle"] = true
	return battle


## 敌人定义 → V1 敌人条目：意图缺省按 attack 映射，V1 新增意图字段
## （kind/seal_turns/soul_drain/life_cost/counter_tag）随数据透传。
static func _v1_enemies(encounter: Dictionary, catalog: Dictionary) -> Array:
	var enemy_by_id: Dictionary = catalog.get("enemy_by_id", {})
	var result: Array = []
	var kinds: Array = []
	if encounter.has("enemy_kinds"):
		kinds = (encounter.get("enemy_kinds", []) as Array).duplicate()
	elif encounter.has("enemy_kind"):
		kinds.append(str(encounter.get("enemy_kind", "")))
	for kind_value in kinds:
		var kind := str(kind_value)
		var definition: Dictionary = enemy_by_id.get(kind, {})
		var intent: Dictionary = definition.get("intent", {})
		result.append({
			"id": kind,
			# V1 契约：label 是敌方名称（定义自带 label/name，缺省回退 kind），
			# 意图文案单独在 intent.label；呈现层对已知 kind 做中文翻译。
			"label": str(definition.get("label", definition.get("name", kind))),
			"hp": int(definition.get("hp", 1)),
			"intent": {
				"kind": str(intent.get("kind", "attack")),
				"damage": int(intent.get("damage", 0)),
				"label": str(intent.get("label", "蓄力")),
				"speed": int(intent.get("speed", 0)),
				"seal_turns": int(intent.get("seal_turns", 0)),
				"soul_drain": int(intent.get("soul_drain", 0)),
				"life_cost": int(intent.get("life_cost", 0)),
				"counter_tag": str(intent.get("counter_tag", "")),
			},
		})
	return result


static func apply_turn(battle: Dictionary, state: RunState, command: Dictionary, catalog: Dictionary = {}) -> Dictionary:
	if battle.is_empty():
		return _rejected({}, state, "battle_missing")
	if state.is_terminal():
		return _rejected(battle, state, "terminal_run")
	var command_type := str(command.get("type", ""))
	# R3.6 兼容：action_card 信封只透传基础行动（V1 无手牌卡）。
	if command_type == "action_card":
		var passthrough := _action_card_passthrough(battle, command)
		if passthrough.is_empty():
			return _rejected(battle, state, "unsupported_battle_action")
		var forward := command.duplicate(true)
		forward["type"] = passthrough
		forward["state_version"] = state.event_log.size()
		return apply_turn(battle, state, forward, catalog)
	var action: Dictionary = {}
	match command_type:
		"use_gu":
			var instance_id := str(command.get("instance_id", command.get("gu_id", "")))
			var slot_index := _slot_index(battle, instance_id)
			if slot_index < 0:
				return _rejected(battle, state, "unknown_gu")
			action = {"type": "play_gu", "slot_index": slot_index}
		"basic_attack":
			action = {"type": "basic_attack"}
		"end_turn":
			action = {"type": "end_turn"}
		"play_kill_move":
			action = {"type": "play_kill_move", "kill_move_id": str(command.get("kill_move_id", ""))}
		"retreat":
			# V1 撤退：Boss 战禁止（flags.boss_battle 由 start() 落账）；其余直接
			# 结算为 retreat（战斗结束路由到结算屏）。
			if boss_blocks_retreat(battle):
				return _rejected(battle, state, "retreat_forbidden")
			return {"battle": battle, "state": state, "result": "retreat", "feeds": [], "finished": true, "accepted": true}
		_:
			return _rejected(battle, state, "unsupported_battle_action")
	var out: Dictionary = V1Script.player_action(battle, action)
	var next: Dictionary = out["battle"]
	if not bool(out["result"]["ok"]):
		return _rejected(next, state, str(out["result"]["reason"]))
	match str(next.get("phase", "")):
		"victory":
			# V1 胜利掉落：复用 LootResolver（材料/蛊/精英绑定代价），
			# 与旧卡牌战斗同一结算口径，保证战利品闭环。
			var settled := LootResolverScript.settle_victory(next, state, catalog)
			next["loot"] = settled.get("loot", {})
			if not (settled.get("cost", {}) as Dictionary).is_empty():
				next["cost"] = settled["cost"]
			return {"battle": next, "state": settled.get("state", state), "result": "victory", "feeds": [], "finished": true, "accepted": true}
		"defeat":
			return {"battle": next, "state": state, "result": "death", "feeds": [], "finished": true, "accepted": true}
		_:
			# V1 战斗动作推进事件日志：供确定性/存档校验/反馈锚点。
			var event_state := state.append_event({
				"stage": state.stage,
				"time": state.event_log.size(),
				"node_id": state.current_node_id,
				"action": "battle_v1",
				"before": {},
				"after": {"battle_turn": int(next.get("turn", 1))},
				"reason": "battle_v1_%s" % command_type,
				"source": "battle_facade",
				"targets": [],
			})
			return {"battle": next, "state": event_state, "result": "ongoing", "feeds": [], "accepted": true}


static func _action_card_passthrough(battle: Dictionary, command: Dictionary) -> String:
	var action_id := str(command.get("action_id", ""))
	var battle_id := str(battle.get("battle_id", ""))
	if battle_id != "" and action_id == "battle.%s.basic.punch" % battle_id:
		return "basic_attack"
	if battle_id != "" and action_id == "battle.%s.end_turn" % battle_id:
		return "end_turn"
	if battle_id != "" and action_id == "battle.%s.retreat" % battle_id:
		return "retreat"
	return ""


static func _slot_index(battle: Dictionary, instance_id: String) -> int:
	for i in (battle.get("gu_slots", []) as Array).size():
		if str(battle["gu_slots"][i].get("instance_id", "")) == instance_id:
			return i
	return -1


static func apply_enemy_pre_turn(battle: Dictionary, state: RunState, catalog: Dictionary = {}) -> Dictionary:
	if battle.is_empty():
		return _rejected({}, state, "battle_missing")
	if state.is_terminal():
		return _rejected(battle, state, "terminal_run")
	# V1：敌人先手 = 立即执行一次敌人回合（意图结算 + 玩家回合开始）。
	var out: Dictionary = V1Script.player_action(battle, {"type": "end_turn"})
	var next: Dictionary = out["battle"]
	var phase := str(next.get("phase", ""))
	var finished := phase == "victory" or phase == "defeat"
	var result := "ongoing"
	if phase == "defeat":
		result = "death"
	elif phase == "victory":
		result = "victory"
	return {"battle": next, "state": state, "finished": finished, "result": result}


## Boss 战禁止撤退（V1 兼容旧锚点：真 Boss 节点不可逃，普通战斗可逃）。
static func boss_blocks_retreat(battle: Dictionary) -> bool:
	return bool(battle.get("flags", {}).get("boss_battle", false))


static func _rejected(battle: Dictionary, state: RunState, reason: String, details: Dictionary = {}) -> Dictionary:
	var result := {
		"battle": battle.duplicate(true),
		"state": state,
		"feeds": [reason],
		"result": "rejected",
		"accepted": false,
	}
	if not details.is_empty():
		result["details"] = details
	return result
