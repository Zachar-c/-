extends SceneTree

# 无头冒烟：编译 .guitkx -> 加载 .gd -> 挂载组件 -> 统计可交互控件数。
# 验证 RUI 工具链可在无编辑器 GUI 下编译并渲染（满足「导出前先编译」与 CI 验证）。

const Guitkx = preload("res://addons/reactive_ui_toolkit/guitkx/guitkx.gd")
const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const ROOT := "res://"

func _compile_file(rel_path: String) -> bool:
	var src := FileAccess.get_file_as_string(rel_path)
	if src.is_empty():
		push_error("读不到 %s" % rel_path)
		return false
	var res := Guitkx.compile(src, rel_path.get_file().get_basename(), [], {}, rel_path, ROOT)
	if res.get("env_error", false):
		push_error("RUI 环境未就绪（词汇表未加载）: %s" % rel_path)
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

func _mount(rel_gd: String, component: String, props: Dictionary) -> int:
	var fn = VLib.comp(rel_gd, component)
	if not (fn is Callable):
		push_error("%s 无组件 %s" % [rel_gd, component])
		quit(1)
	var container := Control.new()
	root.add_child(container)
	RuiRoot.create(container, VLib.fc(fn, props))
	return _count_buttons(container)

func _count_buttons(node: Node) -> int:
	var n := 0
	if node is Button:
		n += 1
	for c in node.get_children():
		n += _count_buttons(c)
	return n

func _initialize() -> void:
	var sample := "res://ui/_sample.guitkx"
	if not _compile_file(sample):
		quit(1)
	var count := _mount("res://ui/_sample.gd", "render", {})
	print("OK SampleApp buttons=%d" % count)
	quit()
