extends SceneTree

# GUI 实跑截图：真实渲染器（非 headless）下逐屏挂载 RUI 屏组件，等布局帧后保存 PNG。
# 分辨率：1920x1080、1366x768、1280x720。用独立 SubViewport 精确控制输出尺寸。
# 用法：& <godot_gui.exe> --path . -s res://scripts/ui_capture.gd
# 输出：.superpowers/ui_captures/wenzhen/*.png（不污染仓库，.superpowers 已忽略）

const Guitkx = preload("res://addons/reactive_ui_toolkit/guitkx/guitkx.gd")
const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const ROOT := "res://"
const OUT_DIR := "res://.superpowers/ui_captures/wenzhen"
const BATTLE_SCREEN_TSCN := "res://scenes/ui/screens/battle_screen.tscn"
const HALL_SCREEN_TSCN := "res://scenes/ui/screens/hall_screen.tscn"
const MAP_SCREEN_TSCN := "res://scenes/ui/screens/map_screen.tscn"

const VIEWPORTS := [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1280, 720)]
const CAPTURE_MATRIX := {
	"hall": ["running", "no_save", "long_summary", "keyboard_focus"],
	"map": ["current", "candidate_a_focus", "candidate_b_focus", "future_camera", "collapsed_history", "long_label"],
	"battle": ["1_enemy_5_hand", "2_enemies", "3_enemies", "4_enemies_7_hand"],
	"encounter": ["default", "danger_confirmation"],
	"npc": ["default", "empty_stock"],
	"shop": ["default", "max_shelf", "danger_payment"],
	"rest": ["default", "required_choice"],
	"refine": ["default", "curse_inheritance", "danger_confirmation"],
	"reward": ["default", "full_satchel", "empty_pool"],
	"school": ["default", "locked"],
	"contract": ["default", "mutually_exclusive"],
	"codex": ["list", "detail"],
	"journal": ["list", "detail"],
	"settings": ["default", "extreme"],
	"ending": ["default", "long_route"],
}

const WIDGET_DIR := "res://ui/widgets"
const SCREEN_DIR := "res://ui/screens"

var _cur := 0


static func capture_ids() -> Array:
	return CAPTURE_MATRIX.keys()


static func viewport_sizes() -> Array:
	return VIEWPORTS.duplicate()


static func batch_from_args(user_args: Array, command_line_args: Array) -> String:
	var args: Array = user_args if user_args.has("--batch") else command_line_args
	var batch_index := args.find("--batch")
	if batch_index >= 0 and batch_index + 1 < args.size():
		return str(args[batch_index + 1])
	return ""


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


func _compile_dir(dir_path: String) -> bool:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("打不开 %s" % dir_path)
		return false
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.get_extension() == "guitkx":
			if not _compile_file(dir_path.path_join(fname)):
				return false
		fname = dir.get_next()
	dir.list_dir_end()
	return true


func _snap(component: String, props: Dictionary, slug: String = "", presses: Array[String] = [], focus_text: String = "") -> void:
	for viewport_size in VIEWPORTS:
		await _snap_at_size(component, props, slug, presses, focus_text, viewport_size)


func _snap_at_size(component: String, props: Dictionary, slug: String, presses: Array[String], focus_text: String, viewport_size: Vector2i, tscn_path: String = "") -> void:
	# tscn_path 非空时走 Godot 官方 .tscn 节点树（黑市已迁离 RUITK），否则走 .guitkx。
	var fn = null
	if tscn_path.is_empty():
		fn = VLib.comp("res://ui/screens/%s.gd" % component, "render")
		if not (fn is Callable):
			push_error("无组件 %s" % component)
			return
	if tscn_path.is_empty() and component == "map_screen" and viewport_size == VIEWPORTS[0]:
		_print_map_capture_identity(fn)
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	# Paper background remains visible wherever a screen intentionally leaves breathing room.
	var bg := ColorRect.new()
	bg.color = Color("eee9df")
	bg.size = Vector2(viewport_size)
	viewport.add_child(bg)
	# PanelContainer 强制唯一子（RUI 根）填满画幅，避免内容按最小尺寸收缩在左上角
	var inner := PanelContainer.new()
	inner.size = Vector2(viewport_size)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(inner)
	var rui_root = null
	if tscn_path.is_empty():
		rui_root = RuiRoot.create(inner, VLib.fc(fn, props))
	else:
		var tscn_inst := (load(tscn_path) as PackedScene).instantiate()
		inner.add_child(tscn_inst)
		if tscn_inst.has_method("mount_snapshot"):
			tscn_inst.mount_snapshot(props.get("state", {}), props.get("commands", {}))
	# 等逻辑帧确保 RUI 完成挂载与布局，再强制同步渲染一帧（不依赖窗口可见性，不会挂死）
	for i in range(6):
		await process_frame
	if tscn_path == MAP_SCREEN_TSCN and viewport_size == VIEWPORTS[0] and slug == "core_map_current":
		_print_map_render_state(inner)
	for button_text in presses:
		if not _press_button(inner, button_text):
			push_error("找不到交互按钮 %s (%s)" % [button_text, component])
		for i in range(4):
			await process_frame
	if not focus_text.is_empty():
		var focus_button := _find_button(inner, focus_text)
		if focus_button == null:
			push_error("找不到焦点按钮 %s (%s)" % [focus_text, component])
		else:
			focus_button.grab_focus()
			await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	_cur += 1
	var shot_name := slug if not slug.is_empty() else component
	var p := ProjectSettings.globalize_path(OUT_DIR).path_join("%02d_%s_%dx%d.png" % [_cur, shot_name, viewport_size.x, viewport_size.y])
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(p) != OK:
		push_error("窗口捕获失败: %s" % p)
	print("SNAP %s -> %s" % [component, p])
	if rui_root != null:
		rui_root.unmount()
		rui_root = null
	viewport.free()
	await process_frame


## 截图 Godot 官方 .tscn 节点树屏。presses 用于截"点了某按钮之后"的状态，
## focus_text 用于键盘焦点高亮（与 RUITK 版 _snap 的第 5 参同义）。
func _snap_tscn(tscn_path: String, props: Dictionary, slug: String,
		presses: Array[String] = [], focus_text: String = "") -> void:
	for viewport_size in VIEWPORTS:
		await _snap_at_size(slug, props, slug, presses, focus_text, viewport_size, tscn_path)


func _print_map_capture_identity(fn: Callable) -> void:
	var script_resource: Variant = fn.get_object()
	var source_path: String = "<not a script>"
	var source_code: String = ""
	if script_resource is Script:
		source_path = script_resource.resource_path
	if script_resource is GDScript:
		source_code = script_resource.source_code
	print("MAP CAPTURE IDENTITY path=%s has_paper=%s has_legacy_trip=%s" % [
		source_path,
		source_code.contains("map_paper"),
		source_code.contains("南疆行程") or source_code.contains("蛊囊") or source_code.contains("图例"),
	])


func _print_map_render_state(root_node: Node) -> void:
	for node_name in ["map_camera", "map_camera_backdrop", "map_world", "map_routes", "map_paths", "map_node_current", "map_node_elite"]:
		var node := root_node.find_child(node_name, true, false) as CanvasItem
		if node == null:
			print("MAP RENDER STATE name=%s missing=true" % node_name)
			continue
		var rect := node.get_global_transform_with_canvas().get_origin()
		var control := node as Control
		var size := control.size if control != null else Vector2.ZERO
		print("MAP RENDER STATE name=%s visible=%s modulate=%s z=%s pos=%s size=%s" % [
			node_name, node.is_visible_in_tree(), node.modulate, node.z_index, rect, size,
		])

func _button_matches(button: Button, button_text: String) -> bool:
	return button.text == button_text or button.tooltip_text == button_text


func _press_button(node: Node, button_text: String) -> bool:
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and _button_matches(button, button_text) and not button.disabled:
			button.pressed.emit()
			return true
	return false


func _find_button(node: Node, button_text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and _button_matches(button, button_text):
			return button
	return null


func _capture_hall_batch() -> void:
	var hall_cmds := {
		"continue_run": func(): pass, "new_run": func(): pass,
		"open_schools": func(): pass, "open_contracts": func(): pass,
		"open_codex": func(): pass, "open_settings": func(): pass,
		"open_journal": func(): pass, "back_to_hall": func(): pass,
	}
	var hall_state := {
		"hall_subview": "main",
		"has_save": true,
		"brand_title": "問眞",
		"primary_action": "continue_run",
		"run_summary": {"route": "黑市交易后的山道", "rank": 4, "hp": 27},
		"contracts": ["孤注"],
		"anomalies": ["衰运"],
		"meta_stats": {"runs": 3, "endings": 1},
	}
	await _snap_tscn(HALL_SCREEN_TSCN, {"state": hall_state, "commands": hall_cmds}, "core_hall_running")
	var new_hall_state := hall_state.duplicate(true)
	new_hall_state["has_save"] = false
	new_hall_state["primary_action"] = "open_schools"
	new_hall_state["run_summary"] = {"route": "", "rank": 0, "hp": 0}
	new_hall_state["contracts"] = []
	new_hall_state["anomalies"] = []
	await _snap_tscn(HALL_SCREEN_TSCN, {"state": new_hall_state, "commands": hall_cmds}, "core_hall_no_save")
	var long_summary_state := hall_state.duplicate(true)
	long_summary_state["run_summary"] = {"route": "南疆青茅山黑市交易后，经由旧寨石阶折返的第六十三处节点", "rank": 5, "hp": 1}
	long_summary_state["contracts"] = ["孤注 · 元石供给受限"]
	long_summary_state["anomalies"] = ["衰运 · 敌方危险意图更频繁"]
	await _snap_tscn(HALL_SCREEN_TSCN, {"state": long_summary_state, "commands": hall_cmds}, "core_hall_long_summary")
	await _snap_tscn(HALL_SCREEN_TSCN, {"state": hall_state, "commands": hall_cmds}, "core_hall_keyboard_focus", [], "续入此世 ›")


func _map_commands() -> Dictionary:
	return {"travel": func(_id): pass, "view_node": func(_id): pass, "save_run": func(): pass}


func _map_state() -> Dictionary:
	return {
		"nodes": [
			{"id": "past", "type": "event", "label": "旧寨石阶", "layer": 61, "next_ids": ["current"], "visibility": "past"},
			{"id": "current", "type": "combat", "label": "当前所在", "layer": 62, "next_ids": ["market", "elite", "event"], "visibility": "current", "current": true},
			{"id": "market", "type": "market", "label": "黑市商队", "layer": 63, "next_ids": ["rest"], "visibility": "reachable", "reachable": true},
			{"id": "elite", "type": "combat", "label": "雷泽伏杀", "layer": 63, "next_ids": ["rest", "shop"], "visibility": "reachable", "reachable": true},
			{"id": "event", "type": "event", "label": "无名异闻", "layer": 63, "next_ids": ["shop"], "visibility": "reachable", "reachable": true},
			{"id": "rest", "type": "rest", "label": "荒寺休整", "layer": 64, "next_ids": [], "visibility": "lookahead"},
			{"id": "shop", "type": "shop", "label": "百虫黑市", "layer": 64, "next_ids": [], "visibility": "lookahead"},
		],
		"resources": {"yuanstone": 128, "shouyuan": 41, "hunpo": 7},
		"contracts": ["孤注"], "anomalies": ["衰运"], "death_lines": {}, "toast": "",
	}


func _capture_map_batch() -> void:
	var map_state := _map_state()
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": map_state, "commands": _map_commands()}, "core_map_current")
	var candidate_a_state := map_state.duplicate(true)
	for node in candidate_a_state["nodes"]:
		if str(node.get("id", "")) != "market":
			node["reachable"] = false
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": candidate_a_state, "commands": _map_commands()}, "core_map_candidate_a_focus")
	var candidate_b_state := map_state.duplicate(true)
	for node in candidate_b_state["nodes"]:
		if str(node.get("id", "")) != "elite":
			node["reachable"] = false
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": candidate_b_state, "commands": _map_commands()}, "core_map_candidate_b_focus")
	var future_state := map_state.duplicate(true)
	for node in future_state["nodes"]:
		var id := str(node.get("id", ""))
		if id == "past" or id == "current":
			node["visibility"] = "past"
			node["current"] = false
			node["reachable"] = false
		elif id == "market":
			node["visibility"] = "current"
			node["current"] = true
			node["reachable"] = false
		elif id == "rest" or id == "shop":
			node["reachable"] = true
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": future_state, "commands": _map_commands()}, "core_map_future_camera")
	var history_state := map_state.duplicate(true)
	for node in history_state["nodes"]:
		if int(node.get("layer", 0)) <= 62:
			node["visibility"] = "past"
			node["current"] = false
		elif str(node.get("id", "")) == "market":
			node["visibility"] = "current"
			node["reachable"] = false
			node["current"] = true
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": history_state, "commands": _map_commands()}, "core_map_collapsed_history")
	var long_label_state := map_state.duplicate(true)
	for node in long_label_state["nodes"]:
		if str(node.get("id", "")) == "event":
			node["label"] = "雾瘴深处传来的无名蛊鸣与残碑异响"
			node["reachable"] = false
		elif str(node.get("id", "")) == "elite":
			node["label"] = "雷泽伏杀"
			node["reachable"] = true
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": long_label_state, "commands": _map_commands()}, "core_map_long_label")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	if not _compile_file("res://ui/_sample.guitkx"):
		quit(1)
	if not _compile_dir(WIDGET_DIR):
		quit(1)
	if not _compile_dir(SCREEN_DIR):
		quit(1)
	var batch := batch_from_args(OS.get_cmdline_user_args(), OS.get_cmdline_args())
	if batch == "hall":
		await _capture_hall_batch()
		print("HALL SNAPS DONE")
		quit()
		return
	if batch == "map":
		await _capture_map_batch()
		print("MAP SNAPS DONE")
		quit()
		return
	if not batch.is_empty():
		push_error("未知截图批次: %s" % batch)
		quit(1)
		return

	# ---- 大厅主菜单（含存档）----
	var hall_cmds := {
		"continue_run": func(): pass, "new_run": func(): pass,
		"open_schools": func(): pass, "open_contracts": func(): pass,
		"open_codex": func(): pass, "open_settings": func(): pass,
		"open_journal": func(): pass, "back_to_hall": func(): pass,
	}
	var hall_state := {
		"hall_subview": "main",
		"has_save": true,
		"brand_title": "問眞",
		"primary_action": "continue_run",
		"run_summary": {"route": "黑市交易后的山道", "rank": 4, "hp": 27},
		"available_schools": [
			{"id": "blood", "name": "血道", "summary": "以血饲蛊，愈伤愈强", "starter_gu_names": ["血牙蛊", "噬血蛊"]},
			{"id": "qi", "name": "气道", "summary": "以气驭蛊，绵长持久"},
			{"id": "force", "name": "力道", "summary": "以力破蛊，刚猛直进"},
			{"id": "soul", "name": "魂道", "summary": "以魂驭蛊，反噬转战力"},
			{"id": "refine", "name": "炼道", "summary": "临阵炼蛊，以变应敌"},
		],
		"contracts": ["自苦·血祭", "节流·魂敛"],
		"meta_stats": {"runs": 3, "endings": 1},
	}
	# 主菜单的有存档/无存档两态见上方 core_hall_running / core_hall_no_save（已迁 .tscn），
	# 此处只补子视图快照。
	var settings_state := hall_state.duplicate(true)
	settings_state["hall_subview"] = "settings"
	settings_state["master_volume"] = 80
	settings_state["resolution_index"] = 1
	settings_state["resolution_options"] = ["全屏", "1920×1080 · 窗口", "1600×900 · 窗口", "1280×720 · 窗口"]
	settings_state["dda_state_adaptive_enabled"] = true
	await _snap_tscn(HALL_SCREEN_TSCN, {"state": settings_state, "commands": hall_cmds}, "core_hall_settings")
	var codex_state := hall_state.duplicate(true)
	codex_state["hall_subview"] = "codex"
	codex_state["codex"] = {
		"gu": [
			{"id": "small_light_gu", "name": "小光蛊", "school": "光", "rarity": "普通", "unlocked": true},
			{"id": "moonlight_gu", "name": "月光蛊", "school": "光", "rarity": "稀有", "unlocked": false},
		],
		"enemies": [], "recipes": [], "inheritances": [], "relics": []
	}
	await _snap_tscn(HALL_SCREEN_TSCN, {"state": codex_state, "commands": hall_cmds}, "core_hall_codex")
	var journal_state := hall_state.duplicate(true)
	journal_state["hall_subview"] = "journal"
	journal_state["journal"] = {"entries": [{"title": "初到南疆", "body": "青茅山外圍的瘴气比预想更重。"}]}
	await _snap_tscn(HALL_SCREEN_TSCN, {"state": journal_state, "commands": hall_cmds}, "core_hall_journal")

	# ---- 地图 ----
	var map_cmds := {"travel": func(_id): pass, "view_node": func(_id): pass, "save_run": func(): pass}
	var map_state := {
		"zone_title": "青茅山外圍",
		"depth_label": "第 1 层",
		"realm_label": "一转",
		"nodes": [
			{"id": "n1", "type": "start", "label": "起始", "layer": 0, "visibility": "past"},
			{"id": "n2", "type": "combat", "label": "野蛊盘踞", "layer": 1, "visibility": "current"},
			{"id": "n3", "type": "event", "label": "残碑异响", "layer": 1, "visibility": "current"},
			{"id": "n4", "type": "rest", "label": "山涧静修", "layer": 2, "visibility": "lookahead", "reachable": true},
			{"id": "n5", "type": "shop", "label": "黑市", "layer": 2, "visibility": "lookahead", "reachable": true},
			{"id": "n6", "type": "combat", "label": "铁皮山猪", "layer": 3, "visibility": "lookahead"},
			{"id": "n7", "type": "boss", "label": "雷冠头狼", "layer": 4, "visibility": "lookahead"},
		],
		"current_node_id": "n1",
		"reachable_ids": ["n2", "n3"],
		"gu_satchel": [{"id": "g1", "name": "血牙蛊"}, {"id": "g2", "name": "噬血蛊"}],
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}},
	}
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": map_state, "commands": map_cmds}, "map_current")
	var leave_confirm_state := map_state.duplicate(true)
	leave_confirm_state["leave_confirm"] = true
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": leave_confirm_state, "commands": map_cmds}, "map_leave_confirm")
	var toast_state := map_state.duplicate(true)
	toast_state["toast"] = "已返回上次保存的行程。"
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": toast_state, "commands": map_cmds}, "map_toast")
	var future_map_state := map_state.duplicate(true)
	future_map_state["current_node_id"] = "n4"
	for node in future_map_state["nodes"]:
		if str(node.get("id", "")) == "n2" or str(node.get("id", "")) == "n3":
			node["visibility"] = "past"
		elif str(node.get("id", "")) == "n4":
			node["visibility"] = "current"
			node["reachable"] = false
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": future_map_state, "commands": map_cmds}, "map_future")
	var history_map_state := future_map_state.duplicate(true)
	for node in history_map_state["nodes"]:
		if int(node.get("layer", 0)) < 3:
			node["visibility"] = "past"
	await _snap_tscn(MAP_SCREEN_TSCN, {"state": history_map_state, "commands": map_cmds}, "map_collapsed_history")

	# ---- 战斗三区 ----
	var battle_cmds := {
		"play_card": func(_c, _t): pass, "end_turn": func(): pass,
		"ultimate": func(): pass, "refine": func(): pass, "flee": func(): pass,
	}
	var battle_state := {
		"enemies": [
			{"id": "e1", "name": "铁皮山猪", "hp": 20, "max_hp": 30, "shield": 4, "statuses": [{"name": "破绽", "stacks": 1}], "intent": {"type": "attack", "value": 12, "detail": "造成物理伤害"}},
			{"id": "e2", "name": "雷冠头狼", "hp": 15, "max_hp": 15, "shield": 0, "statuses": [], "intent": {"type": "charge", "value": 0, "detail": "蓄力"}},
			{"id": "e3", "name": "腐沼毒蝎", "hp": 12, "max_hp": 18, "shield": 2, "statuses": [{"name": "毒", "stacks": 2}], "intent": {"type": "defend", "value": 6, "detail": "为同伴护持"}},
		],
		"player": {"hp": 24, "max_hp": 30, "shield": 6, "primordial": 3, "soul": 4,
				"thoughts": 2, "used_this_turn": 0, "statuses": [{"name": "灼烧", "stacks": 2}]},
		"actions": {"max": 2, "left": 2, "used": 0},
		"hand": [
			{"id": "c1", "name": "血牙蛊", "cost": 1, "effect": "造成 6 伤害", "quality": "普通", "curse_warning": false, "executable": true, "target_type": "single_enemy", "valid_target_ids": ["e1", "e2", "e3"]},
			{"id": "c2", "name": "噬血蛊", "cost": 2, "effect": "造成 4 伤害并吸血 3", "quality": "稀有", "curse_warning": false},
			{"id": "c3", "name": "血祭蛊", "cost": 2, "cost_ex": "消耗3寿元", "effect": "对自身反噬 1 层，造成 18 伤害", "quality": "稀有", "curse_warning": true},
		],
		"can_ultimate": true,
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}, "hunpo": {"value": 4, "threshold": 4}, "backlash": {"value": 2, "threshold": 3}},
	}
	for enemy_count in [1, 2, 3]:
		var count_state := battle_state.duplicate(true)
		count_state["enemies"] = battle_state["enemies"].slice(0, enemy_count)
		await _snap_tscn(BATTLE_SCREEN_TSCN,
				{"state": count_state, "commands": battle_cmds},
				"battle_%d_enemies" % enemy_count)
	await _snap_tscn(BATTLE_SCREEN_TSCN,
			{"state": battle_state, "commands": battle_cmds},
			"battle_target_selection", ["血牙蛊"])

	# ---- 遭遇（含侧边状态）----
	var enc_cmds := {"choose_option": func(_id): pass, "confirm_danger": func(): pass, "leave": func(): pass}
	var enc_state := {
		"node": {"title": "幽林残碑", "desc": "林中残碑现出「以血饲蛊」四字，一股凶煞之气扑面而来。", "type": "event"},
		"actions": [
			{"id": "a1", "label": "细读碑文", "detail": "获得情报：此处曾为血道强者陨落之地。", "dangerous": false},
			{"id": "a2", "label": "以血祭碑", "detail": "消耗 5 寿元，夺取残碑蛊方，触发反噬 1 层。", "dangerous": true},
			{"id": "a3", "label": "转身离去", "detail": "不沾因果，就此离开。", "dangerous": false},
		],
		"intel": {"weakness": "敌人：铁皮山猪 · 弱点火弱", "cost": "已探查"},
		"player": {"hp": 24, "max_hp": 30, "primordial": 3, "soul": 4, "stone": 12, "gu_names": ["血牙蛊", "噬血蛊"]},
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}},
	}
	await _snap_tscn("res://scenes/ui/screens/encounter_screen.tscn",
			{"state": enc_state, "commands": enc_cmds},
			"dangerous_confirmation", ["确认此危险行动"])

	# ---- 结算 ----
	var ending_cmds := {"to_hall": func(): pass, "to_codex": func(): pass}
	var ending_state := {
		"title": "险中求胜",
		"ending_type": "success",
		"key_decisions": ["放弃强攻，改为诈降", "以魂魄强行镇压反噬"],
		"gains_losses": "夺得《血道真解》残卷，损耗寿元 8",
		"resource_balance": {"yuanstone": 20, "shouyuan": 52},
		"unlocks": ["图鉴：火蛊", "契约：自苦·血祭"],
		"aftermath": "可于大厅图鉴查阅本次所得",
	}
	await _snap_tscn("res://scenes/ui/screens/ending_screen.tscn",
			{"state": ending_state, "commands": ending_cmds}, "ending")

	# ---- 黑市（C3）----
	var gui_state := {
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}},
	}
	var shop_cmds := {"buy": func(_id): pass, "service": func(_sid = "", _tid = ""): pass, "leave": func(): pass}
	var shop_state := gui_state.duplicate()
	shop_state.merge({
		"title": "黑市 · 寨市",
		"npc_name": "地脉游商",
		"npc_stance": "中立",
		"inflation_note": "层数提升物价微涨 · 二次访问 +25%/次",
		"offers": [
			{"id": "o1", "name": "石甲蛊", "kind": "purchase", "price": "6 元石", "desc": "护盾 +8 · 防御型蛊", "quality": "稀有", "curse_warning": false},
			{"id": "o2", "name": "魂丹", "kind": "soul_boost", "price": "6 元石", "desc": "魂魄 +1 · 黑市高回报", "quality": "史诗", "curse_warning": false},
			{"id": "o3", "name": "寿元·脉冲鼓", "kind": "lifespan_deal", "price": "1 寿元", "desc": "代价交易 · 预检寿元", "quality": "稀有", "curse_warning": true},
			{"id": "o4", "name": "以物易物·迹眼", "kind": "barter", "price": "迹眼蛊", "desc": "换雾步蛊", "quality": "稀有", "curse_warning": false},
			{"id": "o5", "name": "洗刷恶名", "kind": "wash_notoriety", "price": "按声望", "desc": "降低恶名", "quality": "普通", "curse_warning": false},
		],
		"services": [
			{"id": "remove_card", "name": "移除蛊虫", "price": "120 元石", "remaining": 2, "note": "从蛊囊删除一只蛊 · 本局剩 2/2 次 · 每次使用涨价", "candidates": [{"id": "gi_1", "name": "石甲蛊", "price": ""}], "target_label": "选择要移除的蛊虫", "executable": true, "block_reason": ""},
			{"id": "remove_curse", "name": "净化诅咒", "price": "按诅咒定价", "remaining": 2, "note": "清除一层诅咒 · 本局剩 2/2 次 · 每次使用涨价", "candidates": [{"id": "gu_erosion", "name": "蛊蚀 ×1", "price": "40 元石"}], "target_label": "选择要净化的诅咒", "executable": true, "block_reason": ""},
			{"id": "wash_notoriety", "name": "洗刷恶名", "price": "10 寿元", "remaining": -1, "note": "恶名 -2 · 消耗寿元 · 无次数上限", "candidates": [], "target_label": "", "executable": true, "block_reason": ""},
		],
		"emergency_note": "元石不足可用气血 / 寿元 / 反噬 / 销毁组件应急支付（R6.7）",
	})
	await _snap_tscn("res://scenes/ui/screens/shop_screen.tscn",
			{"state": shop_state, "commands": shop_cmds}, "shop")

	# ---- 休整（C5）----
	var rest_cmds := {"choose": func(_id): pass, "confirm_wash": func(): pass, "cancel_confirm": func(): pass, "leave": func(): pass}
	var rest_state := gui_state.duplicate()
	rest_state.merge({
		"title": "闭关 · 休整",
		"note": "强制二选一，不可全拿",
		"choices": [
			{"id": "heal", "label": "调息回血", "detail": "回复 30 气血，恢复 2 真元", "cost": "", "disabled": false, "reason": "", "curse_warning": false},
			{"id": "nurture", "label": "温养一蛊", "detail": "强化一张卡 / 移除一张负面卡", "cost": "", "disabled": false, "reason": "", "curse_warning": false},
			{"id": "wash", "label": "洗髓换骨", "detail": "真元上限 +1（实时刷新）", "cost": "10 寿元 + 8 元石", "disabled": false, "reason": "一局一次 · 执行前预检寿元", "curse_warning": false},
		],
		"is_ascension": false,
		"growth": [],
		"confirming": "",
		"confirm_msg": "",
	})
	await _snap_tscn("res://scenes/ui/screens/rest_screen.tscn",
			{"state": rest_state, "commands": rest_cmds}, "rest")

	# ---- 炼蛊台（C6）----
	var refine_cmds := {"set_channel": func(_id): pass, "refine": func(_id): pass, "toggle_input": func(_id): pass, "dismantle": func(_id): pass, "confirm": func(): pass, "cancel_confirm": func(): pass, "leave": func(): pass}
	var refine_state := gui_state.duplicate()
	refine_state.merge({
		"title": "炼蛊台",
		"channels": [
			{"id": "fixed", "label": "定向配方"},
			{"id": "combine", "label": "组合标签"},
			{"id": "blind", "label": "盲盒随机"},
		],
		"active_channel": "fixed",
		"inputs": ["月光蛊", "小光蛊"],
		"slot_ok": true,
		"recipes": [
			{"id": "r1", "name": "月光蛊 + 小光蛊 → 月辉蛊", "output": "月辉蛊", "quality": "稀有", "fail_chance": "成功配方", "backlash": "无躁动", "curse": "", "unlocked": true},
			{"id": "r2", "name": "小光蛊 + 迹眼蛊 → 脉冲鼓", "output": "脉冲鼓", "quality": "稀有", "fail_chance": "失败率 30%", "backlash": "失败毁材 · 躁动 +1", "curse": "", "unlocked": true},
			{"id": "r3", "name": "盲盒（随机）", "output": "未知蛊", "quality": "随机", "fail_chance": "失败率 50% · 毁材", "backlash": "躁动 +2", "curse": "诅咒继承⚠", "unlocked": true},
		],
		"dismantle_slots": ["石甲蛊"],
		"streak_note": "连续失败第 2 次，下次成功率 +5%（Run 内清零，永不到 100%）",
		"confirming": "",
		"confirm_msg": "",
	})
	await _snap_tscn("res://scenes/ui/screens/refine_screen.tscn",
			{"state": refine_state, "commands": refine_cmds}, "refine")

	# ---- 奖励（C2）----
	var reward_cmds := {"take": func(_i): pass, "replace_and_take": func(_i): pass, "skip": func(): pass, "close": func(): pass}
	var reward_state := gui_state.duplicate()
	reward_state.merge({
		"title": "战利品 · 三选一",
		"rewards": [
			{"id": "r1", "name": "月光蛊", "kind": "蛊 · 战斗奖励", "quality": "稀有", "effect": "造成月光伤害并附加「月息」层", "cost": "获取即入蛊囊", "curse_warning": false},
			{"id": "r2", "name": "石甲蛊", "kind": "蛊 · 精英奖励", "quality": "史诗", "effect": "护盾 +8", "cost": "代价：躁动 +1", "curse_warning": false},
			{"id": "r3", "name": "元石 +15", "kind": "货币", "quality": "普通", "effect": "直接入账", "cost": "", "curse_warning": false},
		],
		"full_satchel": false,
		"pool_fallback_note": "（空池回退：已切至基础池）",
		"pity_note": "（保底：连续普通后，下次掉落品质有较大概率提升）",
	})
	await _snap_tscn("res://scenes/ui/screens/reward_screen.tscn",
			{"state": reward_state, "commands": reward_cmds}, "reward")

	# ---- NPC 交涉（C8）----
	var npc_cmds := {"talk": func(_id): pass, "buy": func(_id): pass, "barter": func(_id): pass, "flee": func(): pass, "leave": func(): pass}
	var npc_state := gui_state.duplicate()
	npc_state.merge({
		"npc_name": "游方医修",
		"stance": "中立",
		"stance_note": "交涉失败将种子化翻转敌视",
		"notoriety": 12,
		"notoriety_note": "恶名高亮：威慑部分路线",
		"offers": [
			{"id": "o1", "name": "回购货物", "price": "5 元石", "desc": "出手一批闲置物资"},
			{"id": "o2", "name": "情报买卖", "price": "3 元石", "desc": "换取下一片区域线索"},
		],
		"barter": [
			{"id": "b1", "name": "迹眼蛊 换 雾步蛊", "give": "迹眼蛊", "take": "雾步蛊", "note": "以物易物 · 需空位校验"},
			{"id": "b2", "name": "血苔 换 疗伤蛊", "give": "血苔 ×2", "take": "疗伤蛊", "note": "治疗系交易"},
		],
		"talk_options": [
			{"id": "t1", "label": "友善攀谈", "detail": "了解情报与需求", "danger": false},
			{"id": "t2", "label": "以物易物试探", "detail": "低风险试探底线", "danger": false},
			{"id": "t3", "label": "威胁勒索", "detail": "恶名威慑 · 可能翻脸", "danger": true},
		],
		"can_flee": true,
	})
	await _snap_tscn("res://scenes/ui/screens/npc_screen.tscn",
			{"state": npc_state, "commands": npc_cmds}, "npc")

	print("ALL SNAPS DONE")
	quit()
