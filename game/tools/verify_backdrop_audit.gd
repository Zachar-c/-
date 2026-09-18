extends SceneTree

## 审计补齐验收：encounter / npc / ending 三屏纸点背景渲染（1280×720）。
## 喂最小快照渲染骨架（背景/顶栏/标题/面板），验证补丁生效。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_backdrop_audit.gd

const SCENES := {
	"encounter": "res://scenes/ui/screens/encounter_screen.tscn",
	"npc": "res://scenes/ui/screens/npc_screen.tscn",
	"ending": "res://scenes/ui/screens/ending_screen.tscn",
}
const SNAPSHOTS := {
	"encounter": {
		"resources": {"shouyuan": 94, "hunpo": 7, "yuanstone": 12},
		"title": "遭遇", "subtitle": "前路未卜", "choices": [],
	},
	"npc": {
		"resources": {"shouyuan": 94, "hunpo": 7, "yuanstone": 12},
		"title": "NPC", "trade": [], "barter": [], "talk": [],
	},
	"ending": {
		"resources": {"shouyuan": 94, "hunpo": 7, "yuanstone": 12},
		"ending_type": "安稳", "title": "终局", "rewards": [],
	},
}


func _initialize() -> void:
	for key in SCENES:
		var snapshot: Dictionary = SNAPSHOTS[key]
		var screen: Control = (load(SCENES[key]) as PackedScene).instantiate()
		root.add_child(screen)
		screen.mount_snapshot(snapshot, {"close": Callable(self, "_noop")})
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var img := (root as Window).get_texture().get_image()
		var dir := "res://.preview"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var out := ProjectSettings.globalize_path(dir) + "/%s_backdrop_render.png" % key
		img.save_png(out)
		print("SAVED=" + out)
		root.remove_child(screen)
		screen.free()
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
