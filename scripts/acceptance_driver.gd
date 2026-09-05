extends SceneTree
## Unified acceptance entry point.
##
## This is intentionally a thin dispatcher while the legacy drivers are migrated.
## It keeps one stable command surface without duplicating their domain-specific
## assertions, screenshot matrices, or crash-recovery orchestration.

const MODES := ["smoke", "capture", "play", "render", "crash"]
const LEGACY := {
	"smoke": "res://scripts/smoke_render.gd",
	"capture": "res://scripts/ui_capture.gd",
	"play": "res://scripts/playthrough_smoke.gd",
	"crash": "res://scripts/crash_recovery_driver.gd",
}
const DEFAULT_SCENE := "res://scenes/main.tscn"


func _initialize() -> void:
	var mode := _arg("mode", "")
	if mode == "smoke":
		await _delegate("smoke", str(LEGACY["smoke"]))
		return
	if mode == "capture":
		await _delegate("capture", str(LEGACY["capture"]))
		return
	if mode == "play":
		await _delegate("play", str(LEGACY["play"]))
		return
	if mode == "crash":
		await _delegate("crash", str(LEGACY["crash"]))
		return
	if mode == "render":
		await _run_render(_arg("scene", DEFAULT_SCENE))
		return
	if not LEGACY.has(mode):
		printerr("ACCEPTANCE usage: -- --mode=%s" % ",".join(MODES))
		quit(2)
		return
	await _delegate(mode, str(LEGACY[mode]))


func _delegate(mode: String, script_path: String) -> void:
	var args: PackedStringArray = ["--path", ProjectSettings.globalize_path("res://"), "-s", script_path]
	for arg in OS.get_cmdline_user_args():
		if arg != "--mode=%s" % mode and not arg.begins_with("mode="):
			args.append(arg)
	var executable := OS.get_executable_path()
	var exit_code := OS.execute(executable, args, [], true)
	print("ACCEPTANCE mode=%s delegated=%s exit=%d" % [mode, script_path, exit_code])
	quit(exit_code)


func _run_render(path: String) -> void:
	var scene: PackedScene = load(path)
	if scene == null:
		printerr("RENDER_PROBE_FAIL cannot load ", path)
		quit(1)
		return
	var inst: Node = scene.instantiate()
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	vp.add_child(inst)
	for _i in 10:
		await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var counts := {}
	var total := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var key := image.get_pixel(x, y).to_html(false).substr(0, 6)
			counts[key] = int(counts.get(key, 0)) + 1
			total += 1
	var rows: Array = []
	for key in counts:
		rows.append([key, int(counts[key])])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	print("SCENE=", path)
	print("UNIQUE=", rows.size(), " SAMPLED=", total)
	for i in mini(3, rows.size()):
		print("TOP ", rows[i][0], " ", rows[i][1],
				" ", "%.1f%%" % (100.0 * float(rows[i][1]) / float(total)))
	var exit_code := 0 if rows.size() > 1 else 1
	print("VERDICT=", "BLANK" if exit_code != 0 else "OK")
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.free()
	await process_frame
	await process_frame
	quit(exit_code)


func _arg(key: String, fallback: String) -> String:
	var args: Array[String] = []
	for value in OS.get_cmdline_user_args():
		args.append(str(value))
	for value in OS.get_cmdline_args():
		args.append(str(value))
	for arg in args:
		if arg.begins_with(key + "="):
			return arg.substr(key.length() + 1)
		if arg.begins_with("--" + key + "="):
			return arg.substr(key.length() + 3)
	return fallback
