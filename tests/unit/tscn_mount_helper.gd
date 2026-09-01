class_name TscnMountHelper
extends RefCounted

## 测试侧的 Godot 官方 .tscn 屏挂载辅助。
##
## 屏幕陆续从 RUITK 声明式（.guitkx）迁到官方节点树后，一批测试原本用
## `RuiRoot.create(VLib.fc(Script.render, props))` 挂载，现在要改成
## `instantiate() + mount_snapshot(snapshot, commands)`。各测试文件各自实现一遍
## 只会漂移，所以收敛到这里。
##
## 本文件不是测试（不含 test_ 前缀方法），GUT 不会把它当测试脚本执行。


## 实例化一个 .tscn 屏并喂快照。返回的节点**尚未入树**——调用方需要自己
## `add_child()`；`mount_snapshot` 会先记下数据，等 `_ready()` 时再渲染，
## 所以对调用时序免疫（生产环境 add_child 是同步触发 _ready 的）。
static func instantiate(path: String, snapshot: Dictionary, commands: Dictionary) -> Node:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	if inst.has_method("mount_snapshot"):
		inst.mount_snapshot(snapshot, commands)
	return inst


## 收集节点树里所有可见文本（Label / Button / RichTextLabel）。
## 对应旧测试里对 RUI host 做文本查找的断言方式。
## 返回 Array[String] 而非裸 Array：GUT 的断言辅助（如 _any_contains）常要求
## 具型数组，传裸 Array 会报 "does not have the same element type"。
static func texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	_collect(node, out)
	return out


## 节点树里是否含某段文本（子串匹配，对应旧的 _host_has_label_text 类断言）。
static func has_text(node: Node, needle: String) -> bool:
	for t in texts(node):
		if str(t).contains(needle):
			return true
	return false


static func _collect(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	elif node is RichTextLabel:
		out.append((node as RichTextLabel).text)
	elif node is LineEdit:
		out.append((node as LineEdit).text)
	for c in node.get_children():
		_collect(c, out)
