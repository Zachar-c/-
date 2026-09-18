extends RefCounted

## M0 三选一奖励：确定性、一次性、只服务独立 M0 路线。


const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")

const M0_GU_POOL: Array[String] = [
	"small_light_gu",
	"stone_shell_gu",
	"moonlight_gu",
	"jade_skin_gu",
	"white_boar_strength_gu",
	"blood_bat_gu",
]
const HEAL_AMOUNT := 12
const STONE_AMOUNT := 12


static func build_options(state: RunState, battle_index: int, catalog: Dictionary) -> Array[Dictionary]:
	var pool: Array[String] = []
	for gu_id in M0_GU_POOL:
		if catalog.get("gu_by_id", {}).has(gu_id):
			pool.append(gu_id)
	if pool.is_empty():
		return []
	var gu_index: int = (abs(int(state.seed)) + battle_index) % pool.size()
	# SeededRoll 让相同 seed+战斗序号重建同一组选择；seed 偏移保证不同局
	# 的奖励问题不会固定成同一张卡。
	gu_index = (gu_index + SeededRollScript.index(pool.size(), int(state.seed),
			"m0.reward.%d" % battle_index, 0)) % pool.size()
	var gu_id: String = pool[gu_index]
	var rotation: int = abs(int(state.seed) + battle_index) % 3
	var options: Array[Dictionary] = [
		{
			"id": "m0_gu_%s" % gu_id,
			"kind": "gu",
			"title": "获得%s" % gu_id,
			"description": "加入当前蛊囊，改变后续战斗可用组合。",
			"gu_id": gu_id,
		},
		{
			"id": "m0_heal_%d" % battle_index,
			"kind": "heal",
			"title": "疗伤回元",
			"description": "恢复 %d 点生命，不超过生命上限。" % HEAL_AMOUNT,
			"amount": HEAL_AMOUNT,
		},
		{
			"id": "m0_stone_%d" % battle_index,
			"kind": "stone",
			"title": "收取元石",
			"description": "获得 %d 枚元石，为后续取舍保留余地。" % STONE_AMOUNT,
			"amount": STONE_AMOUNT,
		},
	]
	var rotated: Array[Dictionary] = []
	for offset in range(options.size()):
		rotated.append(options[(offset + rotation) % options.size()])
	return rotated


static func apply_choice(state: RunState, option: Dictionary, catalog: Dictionary) -> Dictionary:
	var kind := str(option.get("kind", ""))
	var option_id := str(option.get("id", ""))
	if option_id.is_empty():
		return {"ok": false, "reason": "m0_reward_unknown"}
	match kind:
		"gu":
			return _apply_gu(state, option, catalog)
		"heal":
			return _apply_scalar(state, option_id, "health", HEAL_AMOUNT, true)
		"stone":
			return _apply_scalar(state, option_id, "stone", STONE_AMOUNT, false)
		_:
			return {"ok": false, "reason": "m0_reward_unknown"}


static func _apply_gu(state: RunState, option: Dictionary, catalog: Dictionary) -> Dictionary:
	var gu_id := str(option.get("gu_id", ""))
	if not catalog.get("gu_by_id", {}).has(gu_id):
		return {"ok": false, "reason": "m0_reward_unknown_gu"}
	var ledger := GuInstanceScript.transaction_ledger(
			state.gu_instances, state.cave_aperture, gu_id, catalog, [])
	if not str(ledger.get("error", "")).is_empty():
		return {"ok": false, "reason": str(ledger.get("error", ""))}
	var next := state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "m0_reward_chosen",
		"before": {"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		"after": {"gu_instances": ledger["instances"], "cave_aperture": ledger["aperture"]},
		"reason": "m0_reward_chosen",
		"source": "m0_reward_resolver",
		"targets": [str(option.get("id", "")), gu_id],
	})
	next.sync_legacy_gu_projections()
	return {"ok": true, "state": next, "reason": "m0_reward_chosen"}


static func _apply_scalar(state: RunState, option_id: String, field: String,
		amount: int, clamp_health: bool) -> Dictionary:
	var after_value := int(state.get(field)) + amount
	if clamp_health:
		after_value = mini(after_value, int(state.max_health))
	var after: Dictionary = {field: after_value}
	if field == "health":
		var cultivator := state.cultivator.duplicate(true)
		cultivator["health"] = after_value
		after["cultivator"] = cultivator
	var next := state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "m0_reward_chosen",
		"before": {field: int(state.get(field))},
		"after": after,
		"reason": "m0_reward_chosen",
		"source": "m0_reward_resolver",
		"targets": [option_id],
	})
	return {"ok": true, "state": next, "reason": "m0_reward_chosen"}
