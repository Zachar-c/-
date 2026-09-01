extends GutTest

## UI 规则守卫 —— docs/ui/UI_RULES.md 的可执行部分。
##
## 规则写进文档只靠自觉，几轮改动就会腐化。这里把能静态判定的部分钉成断言：
## 新增代码一旦绕过 token / 超圆角 / 屏根不是 MarginContainer / 图标不走 GuIcon，
## 测试立刻变红，不给「先这样吧」留余地。
##
## 扫描范围刻意分两级：
##   - **新体系**（scripts/presentation/ + scenes/ui/）：违规即阻断，这里是未来。
##   - **旧体系**（ui/ 下的 .guitkx / 编译产物 .gd）：只统计不阻断，
##     那是迁移队列，每转一屏清零一批；一旦全转完，本文件把旧体系也纳入阻断即可。
##
## 若你新增了一条规则，请同时改本文件与 UI_RULES.md——两边是一套。

const NEW_STACK_DIRS := ["res://scripts/presentation/", "res://scenes/ui/"]
const ICON_DIR_MARK := "wenzhen/icons/"

# 整数写法的 Color(0, 0, 0, 0) / Color(1, 1, 1, 1) 是「透明 / 纯白」的惯用写法，
# 不算绕过 token；只有小数写法（Color(0.55, ...)）才是硬编码色。
const HARDCODED_COLOR := "Color\\(\\s*[01]\\.\\d+"

var _rgx_color: RegEx
var _rgx_radius: RegEx
var _rgx_font_preload: RegEx
var _rgx_icon_load: RegEx


func before_all() -> void:
	_rgx_color = RegEx.create_from_string(HARDCODED_COLOR)
	# corner_radius_all = 15 / "corner_radius_all": 15 / set_corner_radius_all(15)
	_rgx_radius = RegEx.create_from_string("(?:corner_radius_all\"?:?\\s*=?\\s*|set_corner_radius_all\\()\\s*(\\d+)")
	_rgx_font_preload = RegEx.create_from_string("preload\\(\\s*\"[^\"]*\\.(?:ttf|otf)\"")
	_rgx_icon_load = RegEx.create_from_string("(?:pre)?load\\(\\s*\"[^\"]*" + ICON_DIR_MARK)


func _walk(path: String, exts: Array) -> Array:
	var out: Array = []
	var da := DirAccess.open(path)
	if da == null:
		return out
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = da.get_next()
			continue
		var full := path.path_join(entry)
		if da.current_is_dir():
			out.append_array(_walk(full, exts))
		else:
			for e in exts:
				if entry.ends_with(e):
					out.append(full)
					break
		entry = da.get_next()
	da.list_dir_end()
	return out


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


## 规则 1：新体系的 .gd 里不许出现小数写法的 Color(...)——一律走 GuStyle token。
func test_no_hardcoded_colors_in_new_stack() -> void:
	var offenders: Array = []
	for d in NEW_STACK_DIRS:
		for path in _walk(d, [".gd"]):
			# GuStyle 本身就是 token 的定义处，自然允许出现字面量。
			if path.ends_with("gu_style.gd"):
				continue
			var text := _read(path)
			for m in _rgx_color.search_all(text):
				var line := text.substr(0, m.get_start()).count("\n") + 1
				offenders.append("%s:%d -> %s" % [path.get_file(), line,
						text.split("\n")[line - 1].strip_edges()])
	assert_eq(offenders.size(), 0,
			"新体系不得硬编码色值，必须走 GuStyle token（详见 docs/ui/UI_RULES.md §2）: " + str(offenders))


## 规则 2：圆角上限 8px。超过即视为「浮动卡片」，违反极简原则。
func test_corner_radius_within_cap_in_new_stack() -> void:
	var offenders: Array = []
	for d in NEW_STACK_DIRS:
		for path in _walk(d, [".gd", ".tscn"]):
			var text := _read(path)
			for m in _rgx_radius.search_all(text):
				var v := int(m.get_string(1))
				if v > 8:
					var line := text.substr(0, m.get_start()).count("\n") + 1
					offenders.append("%s:%d -> %d" % [path.get_file(), line, v])
	assert_eq(offenders.size(), 0,
			"圆角不得超过 8px（UI_RULES §3）: " + str(offenders))


## 规则 3：屏幕场景根节点必须是带 SCREEN_MARGIN 的 MarginContainer，
## 否则内容会贴窗口边缘（这是早期一批屏的通病）。
func test_screen_roots_are_margin_containers() -> void:
	var offenders: Array = []
	var screens := _walk("res://scenes/ui/screens/", [".tscn"])
	assert_gt(screens.size(), 0, "应当能扫到已迁移的屏幕场景")
	for path in screens:
		var text := _read(path)
		# 第一个 [node ...] 段就是根节点。
		var first := RegEx.create_from_string("\\[node name=\"[^\"]+\" type=\"(\\w+)\"\\]")
		var m := first.search(text)
		if m == null:
			offenders.append("%s: 找不到根节点" % path.get_file())
			continue
		if m.get_string(1) != "MarginContainer":
			offenders.append("%s: 根节点是 %s，应为 MarginContainer"
					% [path.get_file(), m.get_string(1)])
			continue
		if not text.contains("margin_left = 32"):
			offenders.append("%s: 根节点缺少 SCREEN_MARGIN(32)" % path.get_file())
	assert_eq(offenders.size(), 0, "屏幕根节点约定（UI_RULES §5）: " + str(offenders))


## 规则 4：字体只能在 GuStyle 里 preload，其他文件一律引用 GuStyle.*_FONT。
func test_fonts_only_preloaded_in_gu_style() -> void:
	var offenders: Array = []
	for d in NEW_STACK_DIRS:
		for path in _walk(d, [".gd"]):
			if path.ends_with("gu_style.gd"):
				continue
			var text := _read(path)
			for m in _rgx_font_preload.search_all(text):
				var line := text.substr(0, m.get_start()).count("\n") + 1
				offenders.append("%s:%d -> %s" % [path.get_file(), line, m.get_string(0)])
	assert_eq(offenders.size(), 0,
			"字体只能在 GuStyle 里 preload，其余走 GuStyle.BODY_FONT / TITLE_FONT（UI_RULES §4）: " + str(offenders))


## 规则 5：图标必须经 GuIconView 注册，不许在别处直接 load 图标文件。
func test_icons_go_through_gu_icon_registry() -> void:
	var offenders: Array = []
	for d in NEW_STACK_DIRS:
		for path in _walk(d, [".gd"]):
			if path.ends_with("gu_icon_view.gd"):
				continue
			var text := _read(path)
			for m in _rgx_icon_load.search_all(text):
				var line := text.substr(0, m.get_start()).count("\n") + 1
				offenders.append("%s:%d -> %s" % [path.get_file(), line, m.get_string(0)])
	assert_eq(offenders.size(), 0,
			"图标必须走 GuIconView 注册表，不要直接 load（UI_RULES §6）: " + str(offenders))


## 规则 6：GuIconView 注册表里声明的图标，文件必须真实存在（防手写错名）。
func test_icon_registry_files_exist() -> void:
	var missing: Array = []
	for name in GuIconView.names():
		var file: String = GuIconView.ICON_PATHS[name]
		var p := "res://assets/" + ICON_DIR_MARK + file + ".svg"
		if not FileAccess.file_exists(p):
			missing.append("%s -> %s" % [name, p])
	assert_eq(missing.size(), 0, "图标注册表引用了不存在的 SVG: " + str(missing))


## 旧体系迁移进度（只报告，不阻断）——每转一屏这里就少一批。
func test_legacy_stack_violation_report() -> void:
	var counts := {"hardcoded_color": 0, "radius_over_cap": 0}
	for path in _walk("res://ui/", [".guitkx"]):
		var text := _read(path)
		counts["hardcoded_color"] += _rgx_color.search_all(text).size()
		for m in _rgx_radius.search_all(text):
			if int(m.get_string(1)) > 8:
				counts["radius_over_cap"] += 1
	gut.p("旧 .guitkx 体系残留违规: %s（迁移队列，暂不阻断）" % counts)
	pass_test("旧体系统计完成")
