class_name SwordMarkRules
extends RefCounted


# 剑道 T16 残锋降转（2026-09-12 规格 §2，2026-09-15 修正 D16-4）。
#
# 原文依据（重查报告 §2-M7）：
#   「剑痕索命……永久性地耗费剑道仙蛊中的道痕」；
#   「永久性的消耗仙蛊上的道痕……无法回复。这样一来，剑道仙蛊会越来越弱。
#     次数达到一定程度之后，就会引来质变，使得六转仙蛊跌落到五转凡级」；
#   市场评价「弊端相当严重，……价值不高，并不太受欢迎」。
#
# 术语：**逆炼** = 用一次带 `sword_mark_cost` 的杀招，其配方中每只该标记的剑蛊
# 各扣 1 点道痕余量；余量归零即**质变**：等效转数 -1（下限 1 转＝凡级）。
#
# 🔴 本模块为何存在（架构缺口）：残锋是**跨战斗的永久消耗**，必须写回
# `RunState.gu_instances`；而 `v1_battle_resolver` 只持有 battle 字典，
# 摸不到 RunState。故结算按 `loot_resolver` 同款范式独立成模块，由
# `battle_command_facade` 在杀招成功结算后调用——不引入新的回写通路。
#
# 不可逆：本模块是**唯一**允许写 `dao_marks` / `sword_downgrades` 的地方，
# 且只减不增（原文「无法回复」）。

const STATE_ACTION := "sword_erosion"


## 道痕余量初值（= 距首次质变的逆炼次数）。缺省 5。
static func dao_marks_init(catalog: Dictionary) -> int:
	return maxi(1, int(_config(catalog).get("sword_dao_marks_init", 5)))


## 每次质变后重新计入的逆炼次数。缺省与初值相同。两键分离以便单点调参。
static func downgrade_every(catalog: Dictionary) -> int:
	return maxi(1, int(_config(catalog).get("sword_downgrade_every", dao_marks_init(catalog))))


static func _config(catalog: Dictionary) -> Dictionary:
	var battle: Variant = catalog.get("v1_battle", {})
	return battle if battle is Dictionary else {}


## 实例已发生的质变次数。缺键 = 0（旧存档免迁移）。
static func downgrades_of(instance: Dictionary) -> int:
	return maxi(0, int((instance as Dictionary).get("sword_downgrades", 0)))


## 距下次质变还剩几次逆炼。缺键按配置初值读取（免 SAVE_VERSION 迁移）。
static func remaining_marks(instance: Dictionary, catalog: Dictionary) -> int:
	var every := downgrade_every(catalog)
	return clampi(int((instance as Dictionary).get("dao_marks", dao_marks_init(catalog))), 0, every)


## 等效转数：持有转数（含同名升阶）减去质变次数，下限 1 转。
static func effective_rank(held_rank: int, instance: Dictionary) -> int:
	return maxi(1, held_rank - downgrades_of(instance))


## 本次出招是否会把任一配方蛊推过质变阈值（出招前预检；红线要求执行前可见）。
## 只读 battle，不触碰 RunState。
static func pending_downgrade(battle: Dictionary, kill_move_id: String) -> bool:
	for instance_id_value in _mark_recipe(battle, kill_move_id):
		var slot := _find_slot(battle, str(instance_id_value))
		if slot.is_empty():
			continue
		if int(slot.get("dao_marks", 0)) <= 1:
			return true
	return false


## 配方中带残锋标记的实例 id（`_build_kill_moves` 组装时已按蛊定义预筛）。
static func _mark_recipe(battle: Dictionary, kill_move_id: String) -> Array:
	for km_value in (battle.get("kill_moves", []) as Array):
		var km: Dictionary = km_value
		if str(km.get("id", "")) == kill_move_id:
			return (km.get("sword_mark_recipe", []) as Array)
	return []


static func _find_slot(battle: Dictionary, instance_id: String) -> Dictionary:
	for slot_value in (battle.get("gu_slots", []) as Array):
		var slot: Dictionary = slot_value
		if str(slot.get("instance_id", "")) == instance_id:
			return slot
	return {}


## 逆炼结算：对配方中带残锋标记的剑蛊各扣 1 点余量，归零者质变（等效转数 -1）。
## 返回 {"state": RunState, "spent": Array[Dictionary], "downgraded": Array[String]}。
## 空配方或全部实例缺失时原样返回，不落事件（避免空转日志）。
static func apply_erosion(state, instance_ids: Array, catalog: Dictionary) -> Dictionary:
	if instance_ids.is_empty() or state == null:
		return {"state": state, "spent": [], "downgraded": []}
	var every := downgrade_every(catalog)
	var instances: Dictionary = (state.gu_instances as Dictionary).duplicate(true)
	var spent: Array = []
	var downgraded: Array = []
	var mutated := false
	for instance_id_value in instance_ids:
		var instance_id := str(instance_id_value)
		if not instances.has(instance_id):
			continue
		var instance: Dictionary = (instances[instance_id] as Dictionary).duplicate(true)
		var marks_after := int(instance.get("dao_marks", dao_marks_init(catalog))) - 1
		var downgrades := downgrades_of(instance)
		if marks_after <= 0:
			# 质变：六转仙蛊跌落到五转凡级——等效转数 -1，余量重新计满。
			downgrades += 1
			marks_after = every
			downgraded.append(str(instance.get("definition_id", "")))
		instance["dao_marks"] = marks_after
		instance["sword_downgrades"] = downgrades
		instances[instance_id] = instance
		spent.append({
			"instance_id": instance_id,
			"definition_id": str(instance.get("definition_id", "")),
			"dao_marks": marks_after,
			"sword_downgrades": downgrades,
		})
		mutated = true
	if not mutated:
		return {"state": state, "spent": [], "downgraded": []}
	# _apply_after 会把 after.gu_instances 落到新 RunState（STATE_FIELDS 白名单内）。
	var next: RunState = state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": STATE_ACTION,
		"before": {},
		"after": {"gu_instances": instances},
		"reason": "sword_mark_spent",
		"source": "sword_mark_rules",
		"targets": downgraded.duplicate(),
		"info": {"spent": spent.duplicate(true), "downgraded": downgraded.duplicate()},
	})
	next.gu_instances = instances
	next.sync_legacy_gu_projections()
	return {"state": next, "spent": spent, "downgraded": downgraded}
