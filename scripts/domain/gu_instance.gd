class_name GuInstance
extends RefCounted


# Spec-v4 phase-2 (T3.1): gu instance entity model (spec §2.1).
# RunState.gu_instances keeps instances as plain dictionaries (event snapshots
# carry them by value); this module is the single place that defines their
# shape: creation from a gu.json definition, §2.1 default filling for legacy
# instances, validation and the v4 save whitelist. No engine objects ever ride
# inside an instance - ids, scalars, plain arrays and dicts only.


const REFINE_STATES := ["refined", "contracted", "weakened"]
const REFINE_STATE_KEY := "state"

# v4 save whitelist: ids, scalars, plain arrays/dicts only. "state" is kept as
# the legacy refine-state key (8+ readers use it); GuInstance.refine_state()
# is the named accessor. core_state stays a stub dictionary until T7.1.
const SAVE_KEYS := [
	"instance_id", "definition_id", "rank", "state",
	"core_state", "hunger_phase", "next_feed_need",
	"lifecycle", "uses_left",
	"loyal", "ferocity", "parasitic", "flee", "sealed",
	"modifications",
]


# §2.1 factory: build a full instance from a gu.json definition. rank defaults
# to 1 when the definition is absent (legacy instances read as rank 1 too).
static func new_instance(definition_id: String, instance_id: String, catalog: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var definition: Dictionary = catalog.get("gu_by_id", {}).get(definition_id, {})
	var instance := {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"state": "refined",
		"rank": int(definition.get("rank", 1)),
		"core_state": {},
		"hunger_phase": 0,
		"next_feed_need": {},
		"lifecycle": "long",
		"loyal": false,
		"ferocity": 0,
		"parasitic": false,
		"flee": false,
		"sealed": false,
		"modifications": [],
	}
	for key in extra:
		instance[key] = extra[key]
	return instance


# §2.1 default filling for legacy instances (pre-T3.1 three-field dicts):
# adds every missing field, never overwrites existing values.
static func normalize(instance: Dictionary) -> Dictionary:
	var out := instance.duplicate(true)
	if not out.has("rank"):
		out["rank"] = 1
	if not out.has("core_state"):
		out["core_state"] = {}
	if not out.has("hunger_phase"):
		out["hunger_phase"] = 0
	if not out.has("next_feed_need"):
		out["next_feed_need"] = {}
	if not out.has("lifecycle"):
		out["lifecycle"] = "long"
	if not out.has("loyal"):
		out["loyal"] = false
	if not out.has("ferocity"):
		out["ferocity"] = 0
	if not out.has("parasitic"):
		out["parasitic"] = false
	if not out.has("flee"):
		out["flee"] = false
	if not out.has("sealed"):
		out["sealed"] = false
	if not out.has("modifications"):
		out["modifications"] = []
	return out


# Named accessor over the legacy refine-state key ("state").
static func refine_state(instance: Dictionary) -> String:
	return str((instance as Dictionary).get(REFINE_STATE_KEY, "refined"))


# 2026-09-04 中央计价辅助：同名蛊全部 refined 实例的最高转数（无实例回退
# 定义默认 1）。卖出计价用——升阶实例按实例转数取 gu_value_by_rank。
static func max_refined_rank(instances: Dictionary, gu_id: String) -> int:
	var rank := 0
	for instance_value in instances.values():
		var instance: Dictionary = instance_value
		if refine_state(instance) == "refined" and str(instance.get("definition_id", "")) == gu_id:
			rank = maxi(rank, int(instance.get("rank", 1)))
	return rank


# 2026-09-03 修复：炼蛊失败 / 卖出 / 商队兑换的实例销毁记账。实例与洞天
# stored 列表必须同步变更，否则下次 sync_legacy_gu_projections() 会把
# 只从 legacy 数组移除的蛊"复活"。多集语义与 resolver._has_all_gu 一致：
# 每个 definition_id 只消耗洞天中首个 refined 实例。
static func consume_definition_instances(instances: Dictionary, stored: Array, inputs: Array) -> void:
	for gu_id_value in inputs:
		var gu_id := str(gu_id_value)
		for instance_id_value in stored.duplicate():
			var instance_id := str(instance_id_value)
			var instance: Dictionary = instances.get(instance_id, {})
			if refine_state(instance) != "refined" or str(instance.get("definition_id", "")) != gu_id:
				continue
			var consumed: Dictionary = instance.duplicate(true)
			consumed[REFINE_STATE_KEY] = "consumed"
			instances[instance_id] = consumed
			stored.erase(instance_id)
			break


# 2026-09-12（Q8-G Batch 1-A）：按**显式实例 id** 消耗（promotion 用）。
# 与 consume_definition_instances 的区别只在选谁：这里认 id 不认 definition，
# 因为 promotion 的转数门禁是按选中实例算的，若退回"首个同名实例"会出现
# "校验 A、消耗 B"。"state" 沿用 refine 状态键（"consumed"），与 fixed 一致。
static func consume_instance_id_list(instances: Dictionary, stored: Array, instance_ids: Array) -> void:
	for instance_id_value in instance_ids:
		var instance_id := str(instance_id_value)
		if not instances.has(instance_id):
			continue
		if not stored.has(instance_id):
			continue
		var consumed: Dictionary = instances[instance_id].duplicate(true)
		consumed[REFINE_STATE_KEY] = "consumed"
		instances[instance_id] = consumed
		stored.erase(instance_id)


# 2026-09-03 修复：gu_transaction 的实例侧记账（combine 炼蛊 / 商队购买 /
# 商队兑换共用）。产出蛊必须落到 gu_instances + 洞天，否则 V1 战斗
# refined_instances() 看不见它，且下次 sync_legacy_gu_projections() 会把
# 只写 legacy 数组的产出抹掉；输入蛊同步销毁实例。返回新的
# {instances, aperture}，输入字典不被修改。
#
# consume_instance_ids（2026-09-12，Q8-G Batch 1-A）：调用方已按实例 id 选定
# 输入时（promotion 单输入带转数门禁），必须按**该实例**消耗，不能退回
# "首个同名 refined 实例"。为空时保持原语义（按 definition 逐个消耗）。
static func transaction_ledger(instances: Dictionary, aperture: Dictionary, output_gu_id: String, catalog: Dictionary, inputs: Array, output_rank: int = 0, consume_instance_ids: Array = []) -> Dictionary:
	var output_error := output_definition_error(output_gu_id, catalog)
	if not output_error.is_empty():
		return {"instances": instances, "aperture": aperture, "error": output_error}
	var next_instances := instances.duplicate(true)
	var next_aperture := aperture.duplicate(true)
	var stored: Array = next_aperture.get("stored_gu_instance_ids", []).duplicate()
	if consume_instance_ids.is_empty():
		consume_definition_instances(next_instances, stored, inputs)
	else:
		consume_instance_id_list(next_instances, stored, consume_instance_ids)
	var output_instance_id := RunState.next_gu_instance_id(next_instances)
	var extra := {"rank": clampi(output_rank, 1, 5)} if output_rank > 0 else {}
	next_instances[output_instance_id] = new_instance(output_gu_id, output_instance_id, catalog, extra)
	stored.append(output_instance_id)
	next_aperture["stored_gu_instance_ids"] = stored
	return {"instances": next_instances, "aperture": next_aperture, "error": ""}


# 2026-09-05 切片护栏：unknown_gu_definition 在原料/原石扣除前抛出，避免下游
# legacy 投影复活一个根本没定义的产出。返回空字符串表示合法输出。
static func output_definition_error(output_gu_id: String, catalog: Dictionary) -> String:
	var trimmed := str(output_gu_id).strip_edges()
	if trimmed.is_empty():
		return "unknown_gu_definition"
	var gu_by_id: Variant = catalog.get("gu_by_id", {})
	if not (gu_by_id is Dictionary) or not (gu_by_id as Dictionary).has(trimmed):
		return "unknown_gu_definition"
	return ""


static func validate_instance(instance: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(instance.get("instance_id", "")).is_empty():
		errors.append("gu instance missing instance_id")
	if str(instance.get("definition_id", "")).is_empty():
		errors.append("gu instance %s missing definition_id" % instance.get("instance_id", ""))
	if not REFINE_STATES.has(str(instance.get("state", ""))):
		errors.append("gu instance %s has invalid refine state %s" % [instance.get("instance_id", ""), instance.get("state", "")])
	var rank_value: Variant = instance.get("rank", null)
	if not (rank_value is int or (rank_value is float and is_equal_approx(rank_value, floor(rank_value)))) or int(rank_value) < 1:
		errors.append("gu instance %s rank must be a positive integer" % instance.get("instance_id", ""))
	return errors


static func to_save_data(instance: Dictionary) -> Dictionary:
	var normalized := normalize(instance)
	var out := {}
	for key in SAVE_KEYS:
		if not normalized.has(key):
			continue
		var value: Variant = normalized[key]
		if value is Dictionary or value is Array:
			out[key] = value.duplicate(true)
		else:
			out[key] = value
	return out


static func from_save_data(data: Dictionary) -> Dictionary:
	return normalize(data)
