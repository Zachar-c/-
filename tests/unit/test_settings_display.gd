extends GutTest


# A6 settings display wiring (volume + resolution): the hall settings subview
# must expose real, persisted client preferences instead of the 待接入
# placeholders. Domain data lives in AppSettings (ConfigFile-backed, testable);
# engine effects (AudioServer bus, window mode) stay in RunController.

const RunCommandBuilderScript := preload("res://scripts/presentation/run_command_builder.gd")
const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")
const RunSnapshotBuilderScript := preload("res://scripts/presentation/run_snapshot_builder.gd")
const AppSettingsScript := preload("res://scripts/domain/app_settings.gd")
const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")

const SETTINGS_PATH := "user://nanjiang_smoke_settings.cfg"

var _rui_roots: Array = []


func before_each() -> void:
	_remove_settings_file()


func after_each() -> void:
	_remove_settings_file()
	for r in _rui_roots:
		if r != null and r.has_method("unmount"):
			r.unmount()
	_rui_roots.clear()


func _remove_settings_file() -> void:
	var abs := ProjectSettings.globalize_path(SETTINGS_PATH)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(abs)


func _collect_texts(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Label or child is Button:
			out.append(str(child.text))
		_collect_texts(child, out)


func test_title_command_surface_exposes_volume_and_resolution_commands() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	var commands := RunCommandBuilderScript.for_screen("Title", controller)
	assert_true(commands.has("step_volume"), "Title must expose a step_volume command")
	assert_true(commands.has("cycle_resolution"), "Title must expose a cycle_resolution command")


func test_step_volume_clamps_between_0_and_100() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.app_settings = AppSettingsScript.new()
	controller.step_master_volume(10)
	assert_eq(int(controller.app_settings.master_volume), 100, "volume must clamp at 100")
	controller.step_master_volume(-30)
	assert_eq(int(controller.app_settings.master_volume), 70, "volume steps down by 10")
	controller.step_master_volume(-200)
	assert_eq(int(controller.app_settings.master_volume), 0, "volume must clamp at 0")


func test_volume_and_resolution_persist_through_config_round_trip() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.app_settings = AppSettingsScript.new()
	controller.step_master_volume(-30)
	controller.cycle_resolution()
	assert_true(AppSettingsScript.has_saved_file(), "explicit changes must write the settings file")
	var reloaded = AppSettingsScript.load_settings()
	assert_eq(int(reloaded.master_volume), 70, "volume must survive the config round trip")
	assert_eq(int(reloaded.resolution_index), 1, "resolution index must survive the config round trip")


func test_cycle_resolution_wraps_around_option_list() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.app_settings = AppSettingsScript.new()
	controller.app_settings.resolution_index = AppSettingsScript.resolution_labels().size() - 1
	controller.cycle_resolution()
	assert_eq(int(controller.app_settings.resolution_index), 0, "resolution cycling must wrap to the first option")


func test_settings_noop_when_app_settings_is_null() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.app_settings = null
	controller.step_master_volume(10)  # should not crash
	controller.cycle_resolution()  # should not crash
	assert_false(AppSettingsScript.has_saved_file(), "null settings must not write a config file")


func test_hall_snapshot_surfaces_settings_values() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.app_settings = AppSettingsScript.new()
	controller.app_settings.master_volume = 70
	controller.app_settings.resolution_index = 2
	var snapshot := RunSnapshotBuilderScript.hall(controller)
	assert_eq(int(snapshot.get("master_volume", -1)), 70, "hall snapshot must surface master_volume")
	assert_eq(int(snapshot.get("resolution_index", -1)), 2, "hall snapshot must surface resolution_index")
	assert_gt(snapshot.get("resolution_options", []).size(), 1, "hall snapshot must carry resolution option labels")


func test_hall_snapshot_defaults_when_app_settings_is_null() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.app_settings = null
	var snapshot := RunSnapshotBuilderScript.hall(controller)
	assert_eq(int(snapshot.get("master_volume", -1)), 100, "snapshot must fall back to default volume")
	assert_eq(int(snapshot.get("resolution_index", -1)), 0, "snapshot must fall back to default resolution")


func test_settings_screen_renders_real_values_without_placeholders() -> void:
	var state := {
		"hall_subview": "settings",
		"master_volume": 70,
		"resolution_index": 1,
		"resolution_options": AppSettingsScript.resolution_labels(),
	}
	var host := Control.new()
	add_child_autofree(host)
	var root := RuiRoot.create(host, VLib.fc(VLib.comp("res://ui/screens/hall_view.gd", "render"),
		{"state": state, "commands": {}}))
	_rui_roots.append(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var texts: Array = []
	_collect_texts(host, texts)
	var joined := "\n".join(texts)
	assert_false(joined.contains("待接入"), "settings screen must not keep the 待接入 placeholders")
	assert_true(joined.contains("音量 70%"), "volume label must show the live value")
	var res_label: String = AppSettingsScript.resolution_labels()[1]
	assert_true(joined.contains(res_label), "resolution button must show the current option label")
