extends GutTest


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")
const MasterScenes := [
	"res://scenes/ui_masters/wenzhen_hall_master.tscn",
	"res://scenes/ui_masters/wenzhen_map_master.tscn",
	"res://scenes/ui_masters/wenzhen_battle_master.tscn",
]

var _rui_roots: Array = []
var _rui_hosts: Array = []


func after_each() -> void:
	for root in _rui_roots:
		if root != null and root.has_method("unmount"):
			root.unmount()
	_rui_roots.clear()
	for host in _rui_hosts:
		if host != null and is_instance_valid(host):
			host.queue_free()
	_rui_hosts.clear()


func test_button_style_has_distinct_normal_hover_pressed_states() -> void:
	for role in ["primary", "action", "danger", "cancel", "archive", "target", "card", "node_reachable"]:
		var spec: Dictionary = MasterTheme.button_style(role)
		var normal: Dictionary = spec
		var hover: Dictionary = spec.get("hover", {})
		var pressed: Dictionary = spec.get("pressed", {})
		assert_ne(normal["bg_color"], hover["bg_color"], "%s must change background on hover" % role)
		assert_ne(hover.get("bg_color", hover.get("border_color")), pressed.get("bg_color", pressed.get("border_color")), "%s hover/pressed must differ visually" % role)
		assert_ne(normal["bg_color"], pressed["bg_color"], "%s must change background on press" % role)
		assert_ne(spec["colors"]["font_color"], spec["colors"]["font_pressed_color"], "%s must change text color on press" % role)
		var primary_btn := Button.new()
		add_child(primary_btn)
		MasterTheme.apply_button(primary_btn, role)
		_rui_hosts.append(primary_btn)
		assert_not_null(primary_btn.get_theme_stylebox("normal"), "%s missing normal stylebox" % role)
		assert_not_null(primary_btn.get_theme_stylebox("hover"), "%s missing hover stylebox" % role)
		assert_not_null(primary_btn.get_theme_stylebox("pressed"), "%s missing pressed stylebox" % role)
		assert_not_null(primary_btn.get_theme_stylebox("disabled"), "%s missing disabled stylebox" % role)
		assert_not_null(primary_btn.get_theme_stylebox("focus"), "%s missing focus stylebox" % role)
		assert_eq(primary_btn.get_theme_color("font_color"), spec["colors"]["font_color"], "%s font_color mismatch" % role)
		assert_eq(primary_btn.get_theme_color("font_hover_color"), spec["colors"]["font_hover_color"], "%s font_hover_color mismatch" % role)
		assert_eq(primary_btn.get_theme_color("font_pressed_color"), spec["colors"]["font_pressed_color"], "%s font_pressed_color mismatch" % role)


func test_master_scenes_instantiate_with_expected_root_anchors() -> void:
	for scene_path in MasterScenes:
		var packed: PackedScene = load(scene_path)
		assert_not_null(packed, "%s must load as PackedScene" % scene_path)
		if packed == null:
			continue
		var instance := packed.instantiate()
		assert_not_null(instance, "%s must instantiate" % scene_path)
		assert_eq(instance.get_child_count() >= 1, true, "%s must contain at least one Control child" % scene_path)
		instance.queue_free()


func test_wenzhen_master_mounts_rendertree() -> void:
	for scene_path in MasterScenes:
		var packed: PackedScene = load(scene_path)
		var instance := packed.instantiate() as Control
		add_child(instance)
		_rui_hosts.append(instance)
		for _i in 3:
			await get_tree().process_frame
		assert_true(instance.has_method("mount_snapshot"), "%s master script must expose mount_snapshot" % scene_path)
		instance.mount_snapshot({}, {})
		for _i in 2:
			await get_tree().process_frame
		var screen_host := instance.get_node_or_null("HallScreen")
		if screen_host == null:
			screen_host = instance.get_node_or_null("MapScreen")
		if screen_host == null:
			screen_host = instance.get_node_or_null("BattleScreen")
		assert_not_null(screen_host, "%s must mount a RUI screen host" % scene_path)


func test_master_scenarios_keep_static_button_stateboxes() -> void:
	var hall: Control = (load("res://scenes/ui_masters/wenzhen_hall_master.tscn") as PackedScene).instantiate()
	add_child(hall)
	_rui_hosts.append(hall)
	for _i in 2:
		await get_tree().process_frame
	var primary := hall.get_node_or_null("HallSheet/HallColumns/PrimaryRegion/HallPrimaryAction") as Button
	assert_not_null(primary, "hall master must keep HallPrimaryAction as static Button")
	if primary != null:
		assert_not_null(primary.get_theme_stylebox("normal"), "primary button missing normal stylebox")
		assert_not_null(primary.get_theme_stylebox("hover"), "primary button missing hover stylebox")
		assert_not_null(primary.get_theme_stylebox("pressed"), "primary button missing pressed stylebox")
	for link_name in ["JournalLink", "CodexLink", "SettingsLink"]:
		var link := hall.get_node_or_null("HallSheet/HallColumns/ArchiveRegion/" + link_name) as Button
		assert_not_null(link, "hall master must keep %s as static archive Button" % link_name)
		if link != null:
			assert_not_null(link.get_theme_stylebox("hover"), "%s must have hover stylebox" % link_name)


func test_master_battle_keeps_static_turn_action_stateboxes() -> void:
	var battle: Control = (load("res://scenes/ui_masters/wenzhen_battle_master.tscn") as PackedScene).instantiate()
	add_child(battle)
	_rui_hosts.append(battle)
	for _i in 2:
		await get_tree().process_frame
	for action_name in ["RefineButton", "FleeButton", "EndTurnButton"]:
		var node := battle.get_node_or_null("BattleHandZone/TurnActions/" + action_name) as Button
		assert_not_null(node, "battle master must keep static %s" % action_name)
		if node != null:
			assert_not_null(node.get_theme_stylebox("normal"), "%s missing normal stylebox" % action_name)
			assert_not_null(node.get_theme_stylebox("hover"), "%s missing hover stylebox" % action_name)
			assert_not_null(node.get_theme_stylebox("pressed"), "%s missing pressed stylebox" % action_name)


func test_master_map_keeps_static_inspector_buttons() -> void:
	var map_root: Control = (load("res://scenes/ui_masters/wenzhen_map_master.tscn") as PackedScene).instantiate()
	add_child(map_root)
	_rui_hosts.append(map_root)
	for _i in 2:
		await get_tree().process_frame
	for action_name in ["TravelButton", "SaveButton"]:
		var node := map_root.get_node_or_null("MapInspector/" + action_name) as Button
		assert_not_null(node, "map master must keep static %s" % action_name)
		if node != null:
			assert_not_null(node.get_theme_stylebox("normal"), "%s missing normal stylebox" % action_name)
			assert_not_null(node.get_theme_stylebox("hover"), "%s missing hover stylebox" % action_name)
			assert_not_null(node.get_theme_stylebox("pressed"), "%s missing pressed stylebox" % action_name)
