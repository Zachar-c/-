class_name WenzhenBattleMaster
extends Control


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const SCREEN = "res://ui/screens/battle_screen.gd"
const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")

var _rui_root: RuitkRoot
var _host: Control


func _ready() -> void:
	_apply_static_theme()
	_host = Control.new()
	_host.name = "BattleScreen"
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	_rui_root = RuiRoot.create(_host, VLib.fc(VLib.comp(SCREEN, "render"), {"state": {}, "commands": {}}))


func _apply_static_theme() -> void:
	for node_name in ["RefineButton", "FleeButton", "EndTurnButton"]:
		var node := get_node_or_null("BattleHandZone/TurnActions/" + node_name)
		if node is Button:
			var role := "action"
			if node_name == "FleeButton":
				role = "cancel"
			elif node_name == "EndTurnButton":
				role = "danger"
			MasterTheme.apply_button(node, role)


func mount_snapshot(snapshot: Dictionary, commands: Dictionary) -> void:
	if _rui_root == null:
		return
	_rui_root.set_root(VLib.fc(VLib.comp(SCREEN, "render"), {"state": snapshot, "commands": commands}))
