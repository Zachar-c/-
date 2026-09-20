class_name RunScreenRouter
extends RefCounted


# W12 split: the view mount table and mounting machinery moved out of
# run_controller.gd. Static functions take the controller reference (mounted
# nodes stay on the controller); the controller keeps same-name one-line
# wrappers so call sites and tests are unchanged.


## 唯一视图路由表（.tscn）。所有屏走同一套 instantiate + mount_snapshot 协议。
const MASTER_SCENE_PATHS := {
	"Title": "res://scenes/ui/screens/hall_screen.tscn",
	"Map": "res://scenes/ui/screens/map_screen.tscn",
	"Battle": "res://scenes/ui/screens/battle_screen.tscn",
	# 所有屏走同一套 instantiate + mount_snapshot 协议，本表即唯一路由表。
	"Shop": "res://scenes/ui/screens/shop_screen.tscn",
	"Rest": "res://scenes/ui/screens/rest_screen.tscn",
	"Reward": "res://scenes/ui/screens/reward_screen.tscn",
	"Npc": "res://scenes/ui/screens/npc_screen.tscn",
	"Encounter": "res://scenes/ui/screens/encounter_screen.tscn",
	"Refine": "res://scenes/ui/screens/refine_screen.tscn",
	"Ending": "res://scenes/ui/screens/ending_screen.tscn",
	"ContentError": "res://scenes/ui/screens/content_error_screen.tscn",
	"Kill": "res://scenes/ui/screens/kill_screen.tscn",
	"Settings": "res://scenes/ui/screens/settings_screen.tscn",
}


static func is_registered_screen(screen: String) -> bool:
	return MASTER_SCENE_PATHS.has(screen)


static func mount_screen(controller, screen: String, snapshot: Dictionary, commands: Dictionary) -> void:
	var master_path := str(MASTER_SCENE_PATHS.get(screen, ""))
	if master_path != "":
		if controller._master_instance == null or not is_instance_valid(controller._master_instance) or controller._mounted_screen != screen:
			if controller._master_instance != null and is_instance_valid(controller._master_instance):
				controller._master_instance.queue_free()
			controller._master_instance = (load(master_path) as PackedScene).instantiate()
			controller._master_instance.name = "Wenzhen%sMaster" % screen
			controller._rui_host.add_child(controller._master_instance)
			controller._mounted_screen = screen
		if controller._master_instance.has_method("mount_snapshot"):
			controller._master_instance.mount_snapshot(snapshot, commands)
		return
	# 路由表漏登记时直接报错，不静默白屏。
	unmount_master_instance(controller)
	push_error(".tscn 路由表缺少视图 %s" % screen)


static func unmount_master_instance(controller) -> void:
	if controller._master_instance != null and is_instance_valid(controller._master_instance):
		controller._master_instance.queue_free()
	controller._master_instance = null
	if controller._mounted_screen in MASTER_SCENE_PATHS:
		controller._mounted_screen = ""
