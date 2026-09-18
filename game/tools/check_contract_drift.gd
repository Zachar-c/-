extends SceneTree

# 契约漂移守门（W8, 2026-09-09，GDScript 版——check.ps1 只依赖 godot + git，
# 不可依赖 python：Windows App Execution Alias 下 PS 找不到 python）。
# 提取 domain-ui-contract 反引号 snake_case 标识符，在 scripts/ + tests/ + data/
# 全库检索（含文件名——契约有时引用测试文件名）；缺失即漂移，exit 1。
# 用法: godot --headless --path . -s tools/check_contract_drift.gd

const CONTRACT_PATH := "res://docs/contracts/2026-09-02-domain-ui-contract.md"
const SCAN_DIRS := ["res://scripts", "res://tests", "res://data"]
const TEXT_EXT := [".gd", ".json", ".dialogue"]

# 豁免白名单：逐项写理由。
const WHITELIST := {}


func _initialize() -> void:
	var contract_text := FileAccess.get_file_as_string(CONTRACT_PATH)
	var re := RegEx.new()
	var compiled := re.compile("`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)`")
	if compiled != OK:
		push_error("contract drift gate: regex compile failed")
		quit(1)
		return
	var ids := {}
	for m in re.search_all(contract_text):
		var token := m.get_string(1)
		if not token.ends_with(".gd") and not token.ends_with(".json") \
				and not token.ends_with(".dialogue"):
			ids[token] = true

	var haystack: Array[String] = []
	for dir_path in SCAN_DIRS:
		_collect_dir(dir_path, haystack)

	var missing: Array[String] = []
	for id_value in ids:
		var id_str := str(id_value)
		var found := false
		for chunk in haystack:
			if chunk.contains(id_str):
				found = true
				break
		if not found and not WHITELIST.has(id_str):
			missing.append(id_str)

	if not missing.is_empty():
		print("CONTRACT DRIFT: %d identifier(s) declared in the contract are missing "
				% missing.size())
		for id_missing in missing:
			print("  - %s" % id_missing)
		quit(1)
		return
	print("contract drift: ok (%d identifiers resolved)" % ids.size())
	quit(0)


func _collect_dir(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != ".." and not entry.begins_with("."):
				_collect_dir(path.path_join(entry), out)
		elif _is_text_file(entry):
			out.append(entry)
			var file := FileAccess.open(path.path_join(entry), FileAccess.READ)
			if file != null:
				out.append(file.get_as_text())
		entry = dir.get_next()
	dir.list_dir_end()


func _is_text_file(name: String) -> bool:
	for ext in TEXT_EXT:
		if name.ends_with(ext):
			return true
	return false
