extends GutTest


const SchoolRulesScript = preload("res://scripts/domain/school_rules.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")
const HALL_SCREEN_TSCN := "res://scenes/ui/screens/hall_screen.tscn"
const RuiVLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_real_catalog_passes_school_validation() -> void:
	assert_eq(ContentCatalogScript.validate(catalog), [])


func test_validation_rejects_missing_and_unknown_school() -> void:
	var tuned := catalog.duplicate(true)
	var gu_list: Array = tuned["gu"]
	var first: Dictionary = gu_list[0].duplicate(true)
	first.erase("school")
	gu_list[0] = first
	tuned["gu"] = gu_list
	tuned["gu_by_id"] = {}
	for gu in gu_list:
		tuned["gu_by_id"][gu["id"]] = gu
	var errors: Array[String] = ContentCatalogScript.validate(tuned)
	assert_true(_has_hint(errors, "missing school"))

	var bad := catalog.duplicate(true)
	var bad_gu: Dictionary = bad["gu"][0].duplicate(true)
	bad_gu["school"] = "myth"
	bad["gu"][0] = bad_gu
	bad["gu_by_id"] = {}
	for gu in bad["gu"]:
		bad["gu_by_id"][gu["id"]] = gu
	assert_true(_has_hint(ContentCatalogScript.validate(bad), "invalid school"))


func test_school_starter_injection_on_new_run() -> void:
	var run := _start_with_school("blood")
	assert_eq(run.school, "blood")
	assert_true(run.refined_gu_ids.has("blood_moss_gu"))
	assert_true(run.refined_gu_ids.has("small_light_gu"))

	var force_run := _start_with_school("force")
	assert_true(force_run.refined_gu_ids.has("force_gu"))


func test_school_survives_save_data_and_copy() -> void:
	var run := _start_with_school("qi")
	var data: Dictionary = run.to_save_data()
	assert_eq(str(data["school"]), "qi")
	var copied := run.append_event({"action": "probe", "after": {}, "reason": "probe", "targets": []})
	assert_eq(copied.school, "qi")


func test_force_power_grants_once_and_boosts_punch() -> void:
	var run := _start_with_school("force")
	var first := ResolverScript.apply(run, {"type": "gain_force_power", "source_id": "bloodline_core", "amount": 1}, catalog)
	assert_true(first["result"]["ok"])
	assert_eq(int(first["state"].cultivator["force_power"]), 1)
	assert_eq(first["state"].event_log.back()["reason"], "force_power_gained")

	var repeat := ResolverScript.apply(first["state"], {"type": "gain_force_power", "source_id": "bloodline_core", "amount": 1}, catalog)
	assert_false(repeat["result"]["ok"])
	assert_eq(repeat["result"]["reason"], "force_imprint_repeated")

	var battle := BattleResolver.start({"enemy_kind": "wild_boar"}, first["state"], catalog)
	var punch := BattleResolver.take_turn(battle, {"type": "basic_attack"}, first["state"], catalog)
	assert_eq(int(punch["battle"]["enemy_hp"]), int(battle["enemy_hp"]) - 2)


func test_blood_stack_and_material_helpers() -> void:
	var battle := BattleResolver.start({"enemy_kind": "wild_boar"}, RunState.new_run(101), catalog)
	assert_eq(int(battle.get("blood_stacks", -1)), 0)
	assert_eq(SchoolRulesScript.add_blood_stacks(battle, 3), 3)
	assert_eq(SchoolRulesScript.blood_stacks(battle), 3)
	assert_eq(SchoolRulesScript.add_blood_stacks(battle, 2), 5)

	var run := RunState.new_run(101)
	run.materials["feed_points"] = 3
	assert_eq(SchoolRulesScript.material_fuel(run, catalog), 3)


func test_hall_exposes_school_choices_in_rui_screen() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	var snapshot: Dictionary = controller._snapshot_for("Title")
	snapshot["hall_subview"] = "schools"
	var host := Control.new()
	add_child_autofree(host)
	host.add_child(TscnMountHelper.instantiate(HALL_SCREEN_TSCN, snapshot, {}))
	await get_tree().process_frame
	for school in ["血道", "气道", "力道"]:
		assert_true(_has_text(host, school), "RUI hall must expose %s" % school)


func _start_with_school(school: String) -> RunState:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller.start_new_run(101, school)
	return controller.state


func _has_text(root: Node, text: String) -> bool:
	if root is Label and str(root.text).contains(text):
		return true
	if root is Button and str((root as Button).text).contains(text):
		return true
	for child in root.get_children():
		if _has_text(child, text):
			return true
	return false


func _has_hint(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false