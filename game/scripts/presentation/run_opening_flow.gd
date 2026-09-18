extends RefCounted

## A7：开局结算（流派 starter / Buff / 契约）外提。controller 保持同名一行包装。


const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const RejectionTextScript = preload("res://scripts/presentation/rejection_text.gd")


# R-opening-fairness 2026-08-27: runs started without a school pick used to
# enter the guaranteed layer-one combat with a one-card deck (novice only),
# which was unwinnable against reaction-guarded enemies. The wanderer pack
# makes the opening fight winnable without visiting a shop first. Pools stay
# school-agnostic: state.school remains "".
# 802 catalog 重建后（2026-09-06）原包 thorn_whip/trail_eye/mist_step 已删，
# 依「机制角色映射」自拟新包（全部 rank1 且 combat 字段非空，V1 槽位可打）：
#   缚=blood_farewell_gu  守=stone_shell_gu  吸/blood_bat_gu  攻=force_gu  察=small_light_gu
const WANDERER_STARTER_GU_IDS := [
	"blood_farewell_gu",
	"stone_shell_gu",
	"blood_bat_gu",
	"force_gu",
	"small_light_gu",
]


# Stage 1 切片（specs/2026-09-16 §2）：开局另带两只未炼化小光蛊。
# 野生态自食元气、不进 refined_instances 喂养投影；炼化（attune_gu）后
# 才改由真元喂养。本数组只声明「额外野生持有」，不改流派 starter 包。
const WILD_STARTER_GU_IDS := [
	"small_light_gu",
	"small_light_gu",
]


static func apply_run_buffs(controller, buff_ids: Array) -> void:
	var state = controller.state
	var catalog: Dictionary = controller.catalog
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


static func inject_school_starters(controller, school: String) -> void:
	var state = controller.state
	var catalog: Dictionary = controller.catalog
	var schools: Dictionary = catalog.get("schools", {})
	var starters: Array = WANDERER_STARTER_GU_IDS if school.is_empty() \
		else (schools.get(school, {}).get("starter_gu_ids", []) as Array)
	var before := {"school": str(state.school)}
	if not school.is_empty():
		state.school = school
	var injected: Array[String] = []
	for starter_value in starters:
		var gu_id := str(starter_value)
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
	var next: RunState = state.append_event({
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
	controller.state = next
	_inject_wild_starters(controller)


# Stage 1：在流派 starter 之后再入账野生蛊（state=wild），供 attune 通道消费。
# 只改 gu_instances / 蛊仓持有列表；不进 refined_gu_ids、不进 equipped、不进喂养账。
static func _inject_wild_starters(controller) -> void:
	var state = controller.state
	var catalog: Dictionary = controller.catalog
	var injected: Array[String] = []
	var before_count: int = state.gu_instances.size()
	for wild_value in WILD_STARTER_GU_IDS:
		var gu_id := str(wild_value)
		if not catalog.get("gu_by_id", {}).has(gu_id):
			continue
		var instance_id := _next_gu_instance_id(state)
		state.gu_instances[instance_id] = GuInstanceScript.new_instance(
			gu_id, instance_id, catalog, {"state": "wild"})
		state.cave_aperture["stored_gu_instance_ids"].append(instance_id)
		injected.append(str(gu_id))
	if injected.is_empty():
		return
	state.sync_legacy_gu_projections()
	# after 必须放完整 gu_instances 字典（STATE_FIELDS 键名冲突：整数计数会冲掉实例表）。
	var next: RunState = state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "wild_starters_injected",
		"before": {"gu_instance_count": before_count},
		"after": {
			"gu_instances": state.gu_instances.duplicate(true),
			"cave_aperture": state.cave_aperture.duplicate(true),
		},
		"reason": "stage1_wild_opening",
		"source": "run_controller",
		"targets": injected,
	})
	next.sync_legacy_gu_projections()
	controller.state = next


static func swear_opening_contracts(controller, contract_ids: Array) -> void:
	if contract_ids.is_empty():
		return
	var state = controller.state
	var catalog: Dictionary = controller.catalog
	var allowed: Array = []
	if controller.meta != null and controller.meta.has_method("unlocked_contracts"):
		allowed = controller.meta.unlocked_contracts(catalog)
	var resolved := Resolver.apply(state, {
		"type": "swear_contracts",
		"ids": contract_ids,
		"allowed_ids": allowed,
	}, catalog)
	var succeeded := bool(resolved["result"].get("ok", false))
	state = resolved["state"]
	controller.state = state
	if not succeeded:
		controller.last_feedback = "契约被拒：%s。" % str(resolved["result"].get("reason", ""))
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
		controller.state = state
	controller.last_feedback = "已立誓契约。"


static func _next_gu_instance_id(state_ref) -> String:
	return RunState.next_gu_instance_id(state_ref.gu_instances)
