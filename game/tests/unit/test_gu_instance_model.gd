extends GutTest


# Spec-v4 phase-2 (T3.1): GuInstance model.
# RunState.gu_instances keeps plain dictionaries; GuInstance standardizes the
# §2.1 field list, defaults, validation and serialization. Instances stay
# plain value dictionaries inside event snapshots - never engine objects.


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_two_instances_of_same_definition_have_distinct_ids() -> void:
	# §2.1: same-name gu are different entities; ids come from the
	# deterministic RunState.next_gu_instance_id allocation, never an RNG.
	var first_id := RunStateScript.next_gu_instance_id({})
	var second_id := RunStateScript.next_gu_instance_id({first_id: {}})
	var first := GuInstanceScript.new_instance("small_light_gu", first_id, catalog)
	var second := GuInstanceScript.new_instance("small_light_gu", second_id, catalog)
	assert_eq(str(first["definition_id"]), str(second["definition_id"]))
	assert_ne(first_id, second_id)
	assert_ne(str(first["instance_id"]), str(second["instance_id"]))


func test_section_2_1_fields_all_present_with_defaults() -> void:
	var instance := GuInstanceScript.new_instance("small_light_gu", "gu_900", catalog)
	# Definition id / instance id / rank / refine state (legacy "state" kept).
	assert_eq(str(instance["instance_id"]), "gu_900")
	assert_eq(str(instance["definition_id"]), "small_light_gu")
	assert_eq(int(instance["rank"]),
			int((catalog["gu_by_id"]["small_light_gu"] as Dictionary)["rank"]))
	assert_eq(GuInstanceScript.refine_state(instance), "refined")
	assert_eq(str(instance["state"]), "refined")
	# Core state (T7.1 extends), hunger / feeding need, lifecycle.
	assert_true(instance["core_state"] is Dictionary)
	assert_eq(int(instance["hunger_phase"]), 0)
	assert_true(instance["next_feed_need"] is Dictionary)
	assert_eq(str(instance["lifecycle"]), "long")
	# Instance statuses (§2.1: loyal / ferocity / parasitic / flee / sealed).
	for key in ["loyal", "parasitic", "flee", "sealed"]:
		assert_eq(instance[key], false)
	assert_eq(int(instance["ferocity"]), 0)
	assert_true(instance["modifications"] is Array)
	assert_true((instance["modifications"] as Array).is_empty())


func test_serialize_round_trip_keeps_only_plain_values() -> void:
	# v4 save contract: instances persist as ids / scalars / plain arrays and
	# dicts; never engine objects.
	var instance := GuInstanceScript.new_instance("moonlight_gu", "gu_901", catalog)
	instance["modifications"] = [{"kind": "imprint", "source": "test"}]
	var saved := GuInstanceScript.to_save_data(instance)
	for key in saved:
		var value: Variant = saved[key]
		assert_true(value is String or value is bool or value is int or value is float \
				or value is Array or value is Dictionary,
				"save field %s must be a plain value" % key)
	var restored := GuInstanceScript.from_save_data(saved)
	assert_eq(restored, GuInstanceScript.normalize(instance))


func test_factory_tolerates_missing_definition_and_legacy_instances() -> void:
	# Unknown definition in (or without) catalog: sane defaults, no crash.
	var sparse := GuInstanceScript.new_instance("not_in_catalog", "gu_902", {})
	assert_eq(int(sparse["rank"]), 1)
	assert_eq(str(sparse["state"]), "refined")
	# Legacy 3-field instances gain §2.1 defaults without touching existing
	# values; readers keep working on the old keys unchanged.
	var legacy := {"instance_id": "gu_903", "definition_id": "ridge_hound", "state": "weakened"}
	var normalized := GuInstanceScript.normalize(legacy)
	assert_eq(str(normalized["state"]), "weakened")
	assert_true(normalized.has("core_state"))
	assert_true(normalized.has("modifications"))
	assert_eq(int(normalized["rank"]), 1)


func test_validate_instance_flags_bad_shapes() -> void:
	var good := GuInstanceScript.new_instance("small_light_gu", "gu_904", catalog)
	assert_eq(GuInstanceScript.validate_instance(good), [])
	var bad := good.duplicate(true)
	bad["state"] = "sparkled"
	assert_true(GuInstanceScript.validate_instance(bad).size() > 0)
	bad = good.duplicate(true)
	bad.erase("definition_id")
	assert_true(GuInstanceScript.validate_instance(bad).size() > 0)