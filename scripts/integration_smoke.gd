extends SceneTree

# 集成冒烟：编译 .guitkx -> 加载 main.tscn -> 实例化 RunController ->
# start_new_run 后断言 RUI 宿主已挂载渲染；再经 submit_command 推进一屏，断言无报错。

const Guitkx = preload("res://addons/reactive_ui_toolkit/guitkx/guitkx.gd")
const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const ROOT := "res://"

const WIDGET_DIR := "res://ui/widgets"
const SCREEN_DIR := "res://ui/screens"


func _compile_file(rel_path: String) -> bool:
	var src := FileAccess.get_file_as_string(rel_path)
	if src.is_empty():
		push_error("读不到 %s" % rel_path)
		return false
	var res := Guitkx.compile(src, rel_path.get_file().get_basename(), [], {}, rel_path, ROOT)
	if res.get("env_error", false):
		push_error("RUI 环境未就绪: %s" % rel_path)
		return false
	if not res.get("ok", false):
		push_error("编译失败 %s: %s" % [rel_path, str(res.get("diagnostics", []))])
		return false
	var gd_path := rel_path.get_basename() + ".gd"
	var f := FileAccess.open(gd_path, FileAccess.WRITE)
	if f == null:
		push_error("写不出 %s" % gd_path)
		return false
	f.store_string(res["gd"])
	f.close()
	return true


func _compile_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("打不开 %s" % dir_path)
		quit(1)
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.get_extension() == "guitkx":
			if not _compile_file(dir_path.path_join(fname)):
				quit(1)
		fname = dir.get_next()
	dir.list_dir_end()


func _initialize() -> void:
	# 1) 先编译 widgets 与 screens，确保 .gd 产物存在（VLib.comp 运行时加载需要）。
	_compile_dir(WIDGET_DIR)
	_compile_dir(SCREEN_DIR)

	# 2) 加载场景并实例化（RunController._ready 会创建 RUI 宿主并渲染大厅）。
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var rc: RunController = main.get_node("RunController")
	if rc == null:
		push_error("找不到 RunController")
		quit(1)
	rc.ensure_ui()

	# 3) 开新局，断言 RUI 宿主已挂载并渲染了地图屏。
	rc.start_new_run(12345, "force")
	var host = rc.get_node("RUIHost")
	if host == null or host.get_child_count() <= 0:
		push_error("RUI 宿主未挂载任何控件")
		quit(1)
	if rc.current_view_name() != "Map":
		push_error("开新局后未进入地图屏: %s" % rc.current_view_name())
		quit(1)
	print("INTEGRATION step1: host children=%d view=%s" % [host.get_child_count(), rc.current_view_name()])

	# 4) 经 submit_command 推进到可达节点（遭遇或战斗），断言屏切换且宿主仍渲染无报错。
	var reach := MapGenerator.reachable_nodes(rc.route, rc.state)
	if reach.is_empty():
		push_error("没有任何可达节点，无法推进")
		quit(1)
	var target_id := str(reach[0]["id"])
	rc.submit_command({"type": "travel", "node_id": target_id})
	var view := rc.current_view_name()
	if view != "Encounter" and view != "Battle":
		push_error("推进后未进入遭遇/战斗屏: %s" % view)
		quit(1)
	if host.get_child_count() <= 0:
		push_error("推进后宿主无控件")
		quit(1)
	print("INTEGRATION step2: after travel view=%s host children=%d" % [view, host.get_child_count()])

	print("INTEGRATION OK")
	quit()
