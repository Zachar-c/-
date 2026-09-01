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
