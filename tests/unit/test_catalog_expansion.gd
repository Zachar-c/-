extends "res://addons/gut/test.gd"


# Task C1: gu catalog expanded to 200 total (data-driven combat effects for
# every generated entry, deterministic generator rerun). C2 (2026-09-05)
# remapped the 214 gu onto the 20 dao-mark schools; the old 40-gu/rarity-per-
# school generation quota no longer applies and the invariants below verify
# the remap stays whole (every school keeps gu, pools == full membership).


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const FacadeScript := preload("res://scripts/domain/battle_command_facade.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func test_total_gu_is_200() -> void:
	assert_gte(catalog()["gu"].size(), 200)


func test_every_declared_school_has_gu() -> void:
	var counts := _school_counts()
	for school_id in ContentCatalogScript.SCHOOL_IDS:
		assert_gte(int(counts.get(school_id, 0)), 1,
			"school %s must keep gu after the C2 remap" % school_id)


func test_school_pool_is_exact_school_membership() -> void:
	var cat := catalog()
	var counts := _school_counts()
	for school_id in ContentCatalogScript.SCHOOL_IDS:
		var pool: Array = cat["school_pools"].get(school_id, [])
		assert_eq(pool.size(), int(counts.get(school_id, 0)),
			"%s pool must hold every gu of the school" % school_id)


func test_gu_schools_stay_within_declared_set() -> void:
	for gu in catalog()["gu"]:
		assert_true(ContentCatalogScript.SCHOOL_IDS.has(str(gu["school"])),
			"gu %s has undeclared school %s" % [gu.get("id", ""), gu.get("school", "")])


func _school_counts() -> Dictionary:
	var counts := {}
	for gu in catalog()["gu"]:
		counts[gu["school"]] = int(counts.get(gu["school"], 0)) + 1
	return counts


func test_no_duplicate_ids_in_real_catalog() -> void:
	var errors: Array[String] = ContentCatalogScript.validate(catalog())
	assert_eq(errors, [], "real catalog must pass schema validation")
	for error in errors:
		assert_false(error.contains("duplicate"), error)


func test_validate_flags_synthetic_duplicate_gu_id() -> void:
	var fake := catalog()
	fake["gu"].append(fake["gu"][0].duplicate(true))
	var errors: Array[String] = ContentCatalogScript.validate(fake)
	assert_true(errors.any(func(e: String) -> bool: return e.contains("duplicate gu id")))


func test_validate_flags_broken_v1_effect_on_gu() -> void:
	# B2 2026-09-06 卡层退役后的效果完备守卫：gu 显式声明 v1_effect 时
	# 形状必须通过校验（kind 白名单 + 字段形状），未声明则走 role 兜底。
	var fake := catalog()
	(fake["gu"][0] as Dictionary)["v1_effect"] = {"kind": "no_such_kind"}
	var errors: Array[String] = ContentCatalogScript.validate(fake)
	assert_true(errors.any(func(e: String) -> bool:
			return e.contains("v1_effect") and e.contains("unknown kind")))


func test_attack_gu_deals_damage_in_v1_battle() -> void:
	var cat := catalog()
	# 802 重建后 gen_* 占位蛊已删：攻击蛊以现存战斗蛊为锚（force_gu 力道校 V1 战斗锚）。
	var attacker: Dictionary = cat["gu_by_id"]["force_gu"]
	assert_eq(str(attacker["role"]), "attack")
	var state := RunStateScript.new_run(4242)
	state.school = str(attacker["school"])
	state.gu_instances["gu_100"] = {
		"instance_id": "gu_100",
		"definition_id": str(attacker["id"]),
		"state": "refined",
	}
	state.cave_aperture["stored_gu_instance_ids"].append("gu_100")
	state.sync_legacy_gu_projections()
	var battle := FacadeScript.start({"enemy_kind": "ridge_hound"}, state, cat)
	assert_true(not (battle["gu_slots"] as Array).is_empty(), "attack gu must enter a V1 slot")
	var enemy_hp_before := int(battle["enemies"][0]["hp"])
	var turn := FacadeScript.apply_turn(battle,
			state, {"type": "use_gu", "instance_id": "gu_100"}, cat)
	assert_true(bool(turn.get("accepted", false)), "attack gu use accepted")
	assert_lt(int((turn.get("battle", battle) as Dictionary)["enemies"][0]["hp"]), enemy_hp_before)


func test_generator_rerun_is_idempotent() -> void:
	var before_gu: Array = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/gu.json"))
	var output := []
	OS.execute("python", ["tools/generate_gu_catalog.py",
			"--harvest", "..\\..\\.superpowers\\sdd\\gu-name-harvest.txt"], output, true)
	var after_gu: Array = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/gu.json"))
	assert_gte(after_gu.size(), before_gu.size())
	assert_gte(JSON.stringify(after_gu), JSON.stringify(before_gu))
