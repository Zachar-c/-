extends SceneTree
## 统一验收驱动（B3 冒烟瘦身收编，2026-09-06）。
##
## 原六个独立 SceneTree 驱动——smoke_render / ui_capture / playthrough_smoke /
## crash_recovery_driver / integration_smoke / render_probe——收敛为单一入口，
## 由 --mode 显式选择；默认与未知模式只打印用法并以非零退出。
## 崩溃恢复（crash）仍保留三阶段（run/verify/tamper）语义，由外部
## tools/crash_recovery_check.ps1 负责备份、硬杀、重启与恢复。
##
## 用法：
##   smoke   godot --headless --path . -s res://scripts/acceptance_driver.gd -- --mode=smoke
##           RUITK 编译 + 组件/屏幕结构断言 + 主场景真实开局与推进流程。
##   capture godot --path . -s res://scripts/acceptance_driver.gd -- --mode=capture [--batch hall|map]
##           真实渲染器截图（非 headless），输出 scripts/core/.superpowers/ui_captures/wenzhen/*.png。
##   play    godot --headless --path . -s res://scripts/acceptance_driver.gd -- --mode=play
##           确定性整局游玩（PLAYTHROUGH_SEED/CONTRACTS/SCHOOL/BOSS_FIRST 环境变量生效）。
##   render  godot --path . -s res://scripts/acceptance_driver.gd -- --mode=render [scene=res://scenes/main.tscn]
##           通用像素探针：统计 SubViewport 内颜色分布，VERDICT=BLANK|OK。
##   crash   godot --headless --path . -s res://scripts/acceptance_driver.gd -- --mode=crash
##           读 CRASH_PHASE=run|verify|tamper 环境变量分流执行崩溃恢复阶段。
##
## 模式与运行条件：capture/render 需要真实渲染器（窗口），headless 下会得到
## 空白采样；smoke/play/crash 可 headless。

# ========== RUITK / 领域依赖 ==========
const Guitkx = preload("res://addons/reactive_ui_toolkit/guitkx/guitkx.gd")
const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")

# play / crash 模式才需要 domain 依赖；用惰性 load（_ensure_domains）而非
# preload，使不触域逻辑的 smoke/capture/render 模式不与领域脚本的编译状态耦合。
var RunControllerScript: GDScript
var ActionPreviewServiceScript: GDScript
var BattleCommandFacadeScript: GDScript
var V1BattleResolverScript: GDScript
var ResolverScript: GDScript
var SaveRepositoryScript: GDScript

const ROOT := "res://"
const WIDGET_DIR := "res://ui/widgets"
const SCREEN_DIR := "res://ui/screens"
const SAMPLE := "res://ui/_sample.guitkx"

# ========== 截图 / 捕获契约 ==========
const OUT_DIR := "res://scripts/core/.superpowers/ui_captures/wenzhen"
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

# 官方 .tscn 屏路径（smoke 挂载断言与 capture 截图共用）。
const HALL_SCREEN_TSCN := "res://scenes/ui/screens/hall_screen.tscn"
const MAP_SCREEN_TSCN := "res://scenes/ui/screens/map_screen.tscn"
const BATTLE_SCREEN_TSCN := "res://scenes/ui/screens/battle_screen.tscn"
const DEBUG_PANEL_TSCN := "res://scenes/ui/widgets/debug_panel.tscn"

# ========== 崩溃恢复契约 ==========
const MARKER_PATH := "user://crash_recovery_marker.json"

const MODES := ["smoke", "capture", "play", "render", "crash"]
const DEFAULT_SCENE := "res://scenes/main.tscn"

# ========== 成员状态 ==========
# smoke：RUI 挂载宿主追踪。
var _rui_roots: Array = []
var _mounted_hosts: Array[Node] = []
# capture：截图序号。
var _cur := 0
# play：游玩日志与止损检测。
var _log: Array[String] = []
var _last_view := ""
var _stuck_battle_id := ""
var _stuck_count := 0
var _stuck_enemy_hp := -1
# R-3 观测指标（Batch 1 总验收修复轮，provisional 调参的后续依据）：
# refinement 机会/实际探访/promotion 尝试与拒因直方图。
var _refine_visits := 0
var _promo_attempts := 0
var _promo_accepted := 0
var _promo_rejects := {}
# R-3 O→C 漏斗（2026-09-13 裁定新增出口指标）：探访时本派 promotion 材料
# 是否就绪，用于区分"没材料 / 有材没台 / 有台没去 / 去了失败"。
# Reachability-2（2026-09-13 二次裁定）扩为五段：gu_ready 一段前移。
var _visits_material_ready := 0
var _visits_gu_ready := 0
var _visits_full_ready := 0
# "材料就绪而输入蛊缺"的探访中缺失的输入蛊直方图（Reachability-2 Q1 证据）。
var _gu_missing_hist := {}
# Reachability-4（opt-in only）：假设全战斗 f1 opportunity pity 的测量状态。
# 这些字段只由 acceptance_driver 自己维护，不写入 controller.state / event_log。
var _f1_opportunity_pity_enabled := false
var _sim_f1_missing_streak := 0
var _sim_f1_threshold := 0
var _sim_legal_f1_ids: Array[String] = []
var _sim_actual_f1_count := 0
var _sim_forced_f1_count := 0
var _sim_battle_number := 0
var _sim_actual_common_battle_count := 0
var _sim_candidate_empty_count := 0
# 实际结算 tier 分布（Reachability-4 inbox §7 要求每局报告）。
var _sim_tier_counts := {}
# Reachability-5（opt-in only）：E6 loot-tier opportunity audit 测量状态。
# 只读：不写 controller.state / event_log / save，不改任何正式规则。
var _e6_enabled := false
var _e6_battle_number := 0
var _e6_legal_f1_ids: Array[String] = []
var _e6_actual_f1_count := 0
var _e6_visit_battle_marks: Array[int] = []
var _e6_by_tier := {}
var _e6_by_layer := {}
var _e6_by_template := {}
var _e6_by_actual := {}
var _e6_common_indices: Array[int] = []
var _e6_common_layers: Array[int] = []


# =====================================================================
# 入口分派
# =====================================================================

func _initialize() -> void:
	var mode := _arg("mode", "")
	match mode:
		"smoke":
			await _run_smoke()
			return
		"capture":
			await _run_capture()
			return
		"play":
			await _run_play()
			return
		"crash":
			await _run_crash()
			return
		"render":
			await _run_render(_arg("scene", DEFAULT_SCENE))
			return
	printerr("ACCEPTANCE usage: -- --mode=%s" % ",".join(MODES))
	quit(2)


# =====================================================================
# 通用小工具
# =====================================================================

func _ensure_domains() -> void:
	if RunControllerScript != null:
		return
	RunControllerScript = load("res://scripts/presentation/run_controller.gd")
	ActionPreviewServiceScript = load("res://scripts/domain/action_preview_service.gd")
	BattleCommandFacadeScript = load("res://scripts/domain/battle_command_facade.gd")
	V1BattleResolverScript = load("res://scripts/domain/v1_battle_resolver.gd")
	ResolverScript = load("res://scripts/domain/resolver.gd")
	SaveRepositoryScript = load("res://scripts/domain/save_repository.gd")


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


func _noop(_x = null) -> void:
	pass


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


func _compile_dir(dir_path: String) -> bool:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		# 目录已退役/为空（ui/screens 2026-09-06 全屏迁官方 .tscn 后清空）：
		# 无可编译 .guitkx，视为通过，不当作失败。
		return true
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.get_extension() == "guitkx":
			if not _compile_file(dir_path.path_join(fname)):
				return false
		fname = dir.get_next()
	dir.list_dir_end()
	return true


# ---- .tscn 屏挂载追踪（smoke）----

func _track_host(host: Node) -> void:
	_mounted_hosts.append(host)


func _mount_rui(container: Control, vnode) -> void:
	_track_host(container)
	_rui_roots.append(RuiRoot.create(container, vnode))


func _teardown_mounts() -> void:
	for mounted_root in _rui_roots:
		if mounted_root != null and mounted_root.has_method("unmount"):
			mounted_root.unmount()
	_rui_roots.clear()
	for host in _mounted_hosts:
		if host != null and is_instance_valid(host):
			host.free()
	_mounted_hosts.clear()


func _mount_tscn_props(path: String, props: Dictionary) -> Control:
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("tscn 组件无法加载 %s" % path)
		_teardown_mounts()
		quit(1)
	var inst := scene.instantiate()
	root.add_child(inst)
	_track_host(inst)
	if inst.has_method("set_props"):
		inst.set_props(props)
	return inst


func _mount_tscn_screen(path: String, snapshot: Dictionary, commands: Dictionary) -> Control:
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("tscn 场景无法加载 %s" % path)
		_teardown_mounts()
		quit(1)
	var inst := scene.instantiate()
	root.add_child(inst)
	_track_host(inst)
	if inst.has_method("mount_snapshot"):
		inst.mount_snapshot(snapshot, commands)
	return inst


# =====================================================================
# smoke 模式：RUITK 编译 + 组件/屏幕结构断言 + 主场景真实开局推进
# =====================================================================

func _run_smoke() -> void:
	if not await _smoke_body():
		quit(1)
		return
	await process_frame
	await process_frame
	quit(0)


# _smoke_body 返回 false 即失败（quit 请求由 _run_smoke 统一发出，避免
# 中途 quit 之后继续跑到集成段结尾时退出码被覆盖的隐患）。
func _smoke_body() -> bool:
	# 1) 先编译 _sample（保留既有断言）
	if not _compile_file(SAMPLE):
		_teardown_mounts()
		return false
	var sc := _mount("res://ui/_sample.gd", "render", {})
	print("OK SampleApp buttons=%d" % sc)

	# 2) 编译 ui/widgets 下全部 .guitkx（先于挂载，确保 import 的 .gd 已存在）
	if not _compile_dir(WIDGET_DIR):
		_teardown_mounts()
		return false

	# 3) 逐个挂载断言（编译产物已就绪，import 可解析）
	var b = _sample_button()

	_assert_widget("GuButton", "res://ui/widgets/gu_button.gd", {"label": "测试", "on_press": func(): pass})
	_assert_widget("GuResourceChip", "res://ui/widgets/gu_resource_chip.gd", {"kind": "yuanstone", "value": 12, "on_click": Callable(self, "_noop")})
	_assert_widget("GuStatBar", "res://ui/widgets/gu_stat_bar.gd",
		{"label": "生命", "value": 4, "max_value": 6, "color": GuStyle.JADE, "shield": 2, "on_inspect": Callable(self, "_noop")})
	_assert_widget("GuPanel", "res://ui/widgets/gu_panel.gd", {"title": "面板"}, [b])
	_assert_widget("GuCard", "res://ui/widgets/gu_card.gd", {"title": "卡片", "highlight": true}, [b])
	# T6-E：危险蛊强红变体——「咒」角标必须朱砂底 + 墨字（R4.10），描边朱砂加粗。
	# 术语注：规格旧稿称 BONE / DANGER；这两组别名已随主题迁移移除，
	# 现分别对应 INK_PRIMARY / CINNABAR（见 test_wenzhen_theme_migration）。
	var gc_danger := _mount_component("res://ui/widgets/gu_card.gd", "render",
		{"title": "血祭蛊", "curse_warning": true})
	var curse_glyph := _find_label_exact(gc_danger, "咒")
	if curse_glyph == null:
		push_error("GuCard 危险变体缺少「咒」角标")
		_teardown_mounts()
		return false
	if not curse_glyph.get_theme_color("font_color").is_equal_approx(GuStyle.INK_PRIMARY):
		push_error("GuCard「咒」角标字符必须墨色（朱砂底 + 墨字）")
		_teardown_mounts()
		return false
	var curse_chip := _nearest_panel_ancestor(curse_glyph)
	if curse_chip == null:
		push_error("GuCard「咒」角标必须是实底角标容器（PanelContainer）")
		_teardown_mounts()
		return false
	var curse_sb := curse_chip.get_theme_stylebox("panel") as StyleBoxFlat
	if curse_sb == null or not curse_sb.bg_color.is_equal_approx(GuStyle.CINNABAR):
		push_error("GuCard「咒」角标底色必须 DANGER 强红")
		_teardown_mounts()
		return false
	var gc_danger_panel := _find_first_panel(gc_danger)
	var danger_card_sb := gc_danger_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if danger_card_sb == null or not danger_card_sb.border_color.is_equal_approx(GuStyle.CINNABAR):
		push_error("GuCard 危险变体描边必须 DANGER")
		_teardown_mounts()
		return false
	print("OK GuCardDanger buttons=%d" % _count_buttons(gc_danger))
	# T6-E：封印态——保留「锁」标 + 整卡暗淡。
	var gc_sealed := _mount_component("res://ui/widgets/gu_card.gd", "render",
		{"title": "石甲蛊", "sealed": true})
	if _find_label_exact(gc_sealed, "锁") == null:
		push_error("GuCard 封印态缺少「锁」标")
		_teardown_mounts()
		return false
	if not is_equal_approx(_find_first_panel(gc_sealed).modulate.a, 0.55):
		push_error("GuCard 封印态必须整卡暗淡（modulate a=0.55）")
		_teardown_mounts()
		return false
	print("OK GuCardSealed buttons=%d" % _count_buttons(gc_sealed))
	_assert_widget("GuTopBar", "res://ui/widgets/gu_top_bar.gd",
		{
			"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
			"contracts": ["苦修契约"],
			"anomalies": ["衰运"],
			"death_lines": {"shouyuan": {"value": 55, "threshold": 60}, "hunpo": {"value": 4, "threshold": 4}, "backlash": {"value": 2, "threshold": 3}},
			"on_menu": func(): pass,
		})
	_assert_widget("GuTooltipView", "res://ui/widgets/gu_tooltip_view.gd",
		{"title": "火蛊", "quality": "稀有", "effect": "造成灼烧", "curse_warning": true, "on_detail": Callable(self, "_noop")})
	# T6-E：tooltip 宣纸卷轴底（PAPER）+ 深字 INK + 五段固定顺序（§16.5）。
	var tip := _mount_component("res://ui/widgets/gu_tooltip_view.gd", "render",
		{"title": "血祭蛊", "quality": "稀有", "effect": "吸取气血", "synergy": "与血道蛊联动",
			"cost": "消耗 3 寿元", "curse_warning": true})
	var tip_panel := _find_first_panel(tip)
	var tip_sb := tip_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if tip_sb == null or not tip_sb.bg_color.is_equal_approx(GuStyle.PAPER_BG):
		push_error("GuTooltipView 底色必须 PAPER 卷轴感（禁深底金字回潮）")
		_teardown_mounts()
		return false
	var tip_labels: Array = []
	_collect_labels(tip_panel, tip_labels)
	var tip_texts: Array[String] = []
	for tl in tip_labels:
		tip_texts.append(str((tl as Label).text))
	var idx_effect := _index_with_prefix(tip_texts, "效果：")
	var idx_synergy := _index_with_prefix(tip_texts, "联动：")
	var idx_cost := _index_with_prefix(tip_texts, "代价：")
	var idx_curse := _index_with_prefix(tip_texts, "诅咒警示：")
	if idx_effect < 0 or not (idx_effect < idx_synergy and idx_synergy < idx_cost and idx_cost < idx_curse):
		push_error("GuTooltipView 五段顺序必须恒定：效果→联动→代价→诅咒警示")
		_teardown_mounts()
		return false
	if not (tip_labels[idx_effect] as Label).get_theme_color("font_color").is_equal_approx(GuStyle.INK_PRIMARY):
		push_error("GuTooltipView 正文必须 INK 深字")
		_teardown_mounts()
		return false
	if not (tip_labels[idx_curse] as Label).get_theme_color("font_color").is_equal_approx(GuStyle.CINNABAR):
		push_error("GuTooltipView 诅咒警示行必须 DANGER 红字")
		_teardown_mounts()
		return false
	print("OK GuTooltipPaper labels=%d" % tip_texts.size())
	_assert_widget("GuConfirmDialog", "res://ui/widgets/gu_confirm_dialog.gd",
		{"message": "确认执行？", "on_confirm": func(): pass, "on_cancel": func(): pass})
	# T5-A D1：带语义化 title / warning_note 的确认弹窗变体
	_assert_widget("GuConfirmDialogTitled", "res://ui/widgets/gu_confirm_dialog.gd",
		{"message": "确认洗髓换骨？", "title": "⚠ 危险行动", "warning_note": "代价：10 寿元 + 8 元石 · 执行前预检寿元",
		"on_confirm": func(): pass, "on_cancel": func(): pass})
	# T5-B D2：死因查看浮层（L2 信息浮层，非确认语义；右上「关闭」；Fix1 移除余量行）
	var dco := _mount_component("res://ui/widgets/gu_death_cause_overlay.gd", "render",
		{"line": {"name": "寿元", "current": 12, "max": 60, "detail": "寿元耗尽即死。"}, "on_close": func(): pass})
	if _find_button_by_text(dco, "关闭") == null:
		push_error("GuDeathCauseOverlay 缺少「关闭」按钮")
		_teardown_mounts()
		return false
	if not (_host_has_label_text(dco, "死因 · 寿元") and _host_has_label_text(dco, "当前值：12 / 上限：60")
			and _host_has_label_text(dco, "成因：寿元耗尽即死。")):
		push_error("GuDeathCauseOverlay 缺少 名称/当前值/上限/成因 文案行")
		_teardown_mounts()
		return false
	if _host_has_label_text(dco, "距离死线余量"):
		push_error("GuDeathCauseOverlay 不应再渲染「距离死线余量」行（恒为 0）")
		_teardown_mounts()
		return false
	print("OK GuDeathCauseOverlay buttons=%d" % _count_buttons(dco))
	# T5-A D4：GuToast 纯展示组件（buttons>=0，控件必须存在）
	var toast_info := _mount_component("res://ui/widgets/gu_toast.gd", "render",
		{"text": "进度已保存 · 关闭游戏后可继续本次冒险", "tone": "info"})
	if toast_info.get_child_count() == 0:
		push_error("GuToast(info) 未渲染出任何控件")
		_teardown_mounts()
		return false
	print("OK GuToast buttons=%d" % _count_buttons(toast_info))
	var toast_warn := _mount_component("res://ui/widgets/gu_toast.gd", "render",
		{"text": "大厅存档版本差异较大，建议在设置中清除后重新开始", "tone": "warn"})
	if toast_warn.get_child_count() == 0:
		push_error("GuToast(warn) 未渲染出任何控件")
		_teardown_mounts()
		return false
	print("OK GuToastWarn buttons=%d" % _count_buttons(toast_warn))
	_assert_widget("GuScrollBox", "res://ui/widgets/gu_scroll_box.gd", {}, [b])

	# 4) 编译 ui/screens 下全部 .guitkx（widgets 已先编译，import 可解析）
	if not _compile_dir(SCREEN_DIR):
		_teardown_mounts()
		return false

	# 5) 大厅屏断言：四分支至少 4 个按钮；有存档时含「继续」共 5 个
	var cmds := {
		"continue_run": Callable(self, "_noop"),
		"new_run": Callable(self, "_noop"),
		"open_codex": Callable(self, "_noop"),
		"open_settings": Callable(self, "_noop"),
	}
	var hall_states = [
		{"has_save": true, "available_schools": ["血道", "气道", "力道", "魂道", "炼道"], "contracts": ["自苦·血祭", "节流·魂敛"], "meta_stats": {"runs": 3, "endings": 1}},
		{"has_save": false, "available_schools": ["血道"], "contracts": [], "meta_stats": {}},
	]
	# 大厅已迁到 Godot 官方 .tscn（六个子视图预置在树里靠 visible 切换）。
	for hs in hall_states:
		var hall := _mount_tscn_screen(HALL_SCREEN_TSCN, hs, cmds)
		await process_frame
		var cnt := _count_buttons(hall)
		if cnt < 4:
			push_error("大厅按钮数 %d < 4 (state=%s)" % [cnt, str(hs)])
			_teardown_mounts()
			return false
		print("OK TscnHallScreen buttons=%d" % cnt)

	# 遭遇屏断言（含空 action 兜底离开按钮）。已整体迁 .tscn，见 _verify_tscn_encounter。

	var enc_cmds := {
		"choose_option": Callable(self, "_noop"),
		"confirm_danger": Callable(self, "_noop"),
		"leave": Callable(self, "_noop"),
	}
	var enc_state := {
		"node": {"title": "幽林遭遇", "desc": "林中传来异响。", "type": "contact"},
		"actions": [
			{"id": "a1", "label": "探查", "detail": "仔细查看四周。", "dangerous": false},
			{"id": "a2", "label": "强夺", "detail": "消耗 5 寿元夺取宝物，触发反噬。", "dangerous": true},
			{"id": "leave", "label": "离开", "detail": "", "dangerous": false},
		],
		"intel": {},
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		# T5-B：快照死线条目全形（value/threshold 进度语义 + remaining/max 实际值 + detail 成因）；
		# 危险判定与顶栏一致（value>=threshold），此处寿元已触线。
		"death_lines": {
			"shouyuan": {"id": "shouyuan", "name": "寿元", "value": 60, "threshold": 60,
				"remaining": 0, "max": 60, "danger": true, "cause_id": "death_cause_lifespan", "detail": "寿元耗尽即死。"},
		},
	}

	# 地图屏断言（网状收敛地图，按层分组；至少 1 个节点按钮；含存档按钮 + Toast 行）。
	var map_cmds := {
		"travel": Callable(self, "_noop"),
		"view_node": Callable(self, "_noop"),
		"save_run": Callable(self, "_noop"),
	}
	var map_state := {
		"nodes": [
			{"id": "n1", "type": "start", "label": "起始", "layer": 0},
			{"id": "n2", "type": "combat", "label": "战", "layer": 1},
			{"id": "n3", "type": "event", "label": "事件", "layer": 1},
			{"id": "n4", "type": "boss", "label": "突破", "layer": 3},
		],
		"current_node_id": "n1",
		"reachable_ids": ["n2", "n3"],
		"toast": "进度已保存 · 关闭游戏后可继续本次冒险",
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}},
	}
	# 地图已迁到 Godot 官方 .tscn（镜头/拓扑是绝对定位，_ready() 后才有布局）。
	var map_container := _mount_tscn_screen(MAP_SCREEN_TSCN, map_state, map_cmds)
	await process_frame
	var mc := _count_buttons(map_container)
	if mc < 1:
		push_error("地图按钮数 %d < 1" % mc)
		_teardown_mounts()
		return false
	if _find_button_by_text(map_container, "存档") == null:
		push_error("地图屏缺少「存档」按钮")
		_teardown_mounts()
		return false
	var map_node_count := 0
	for node in map_container.find_children("map_node_*", "Button", true, false):
		map_node_count += 1
	if map_node_count != map_state["nodes"].size():
		push_error("地图节点按钮数 %d != 快照节点数 %d" % [map_node_count, map_state["nodes"].size()])
		_teardown_mounts()
		return false
	print("OK TscnMapScreen buttons=%d nodes=%d" % [mc, map_node_count])

	# 战斗屏断言（敌方意图数值+效果、生命护盾分条、手牌 tooltip、操作按钮）。
	var battle_cmds := {
		"play_card": Callable(self, "_noop"),
		"end_turn": Callable(self, "_noop"),
		"ultimate": Callable(self, "_noop"),
		"refine": Callable(self, "_noop"),
		"flee": Callable(self, "_noop"),
	}
	var battle_state := {
		"enemies": [
			{"id": "e1", "name": "铁皮山猪", "hp": 20, "max_hp": 30, "shield": 4, "intent": {"type": "attack", "value": 12, "detail": "造成物理伤害"}},
			{"id": "e2", "name": "雷冠头狼", "hp": 15, "max_hp": 15, "intent": {"type": "charge", "value": 0, "detail": "蓄力"}},
		],
		"player": {"hp": 24, "max_hp": 30, "shield": 6, "primordial": 3, "soul": 4,
				"thoughts": 2, "used_this_turn": 0, "statuses": [{"name": "灼烧", "stacks": 2}]},
		"actions": {"max": 2, "left": 2, "used": 0},
		"hand": [
			{"id": "c1", "name": "火蛊", "cost": 1, "effect": "灼烧", "quality": "普通", "curse_warning": false},
			# dangerous：走「弹确认后再下发」分支。
			{"id": "c2", "name": "血祭蛊", "cost": 2, "cost_ex": "消耗3寿元", "effect": "吸血", "quality": "稀有", "curse_warning": true, "dangerous": true},
			# target_type=single_enemy：走「先选敌人再下发」分支。
			{"id": "c3", "name": "月芒蛊", "cost": 1, "effect": "穿透", "quality": "史诗", "curse_warning": false, "target_type": "single_enemy", "valid_target_ids": ["e1", "e2"]},
		],
		"can_ultimate": true,
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		# T5-B：快照死线条目全形（同遭遇屏）；魂魄触线为危险行，其余两行安全行。
		"death_lines": {
			"shouyuan": {"id": "shouyuan", "name": "寿元", "value": 55, "threshold": 60,
				"remaining": 5, "max": 60, "danger": false, "cause_id": "death_cause_lifespan", "detail": "寿元耗尽即死。"},
			"hunpo": {"id": "hunpo", "name": "魂魄", "value": 4, "threshold": 4,
				"remaining": 1, "max": 6, "danger": true, "cause_id": "death_cause_soul", "detail": "魂魄耗尽即死。"},
			"backlash": {"id": "backlash", "name": "反噬", "value": 2, "threshold": 3,
				"remaining": 2, "max": 3, "danger": false, "cause_id": "death_cause_backlash", "detail": "反噬达上限即死。"},
		},
	}

	# 结算屏断言（统一结算模块，由 ending_type 驱动；三种结局数据形态）。
	var ending_cmds := {
		"to_hall": Callable(self, "_noop"),
		"to_codex": Callable(self, "_noop"),
	}
	var ending_success := {
		"title": "险中求胜",
		"ending_type": "success",
		"achievement": "五转功成，渡劫飞升，完整走完晋升之路",
		"max_rank": 2,
		"route_summary": [
			{"layer": 1, "types": ["接触", "黑市"], "boss": false},
			{"layer": 2, "types": ["交锋"], "boss": true},
		],
		"run_record": {"synthesis_attempts": 2, "synthesis_ok": 1, "synthesis_fail": 1, "boss_phase_shifts": 1, "dda_triggers": 0},
		"key_decisions": ["放弃强攻，改为诈降", "以魂魄强行镇压反噬"],
		"gains_losses": "夺得《血道真解》残卷，损耗寿元 8",
		"resource_balance": {"yuanstone": 20, "shouyuan": 52},
		"unlocks": ["图鉴：火蛊", "契约：自苦·血祭"],
		"aftermath": "可于大厅图鉴查阅本次所得",
	}

	# 10) T4 剩余节点屏断言（C2 奖励 / C3 黑市 / C5 休整 / C6 炼蛊 / C8 NPC）
	var gui_state := {
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}},
	}

	var shop_state := gui_state.duplicate()
	shop_state.merge({
		"title": "黑市 · 寨市",
		"npc_name": "地脉游商",
		"npc_stance": "中立",
		"inflation_note": "层数提升物价微涨 · 二次访问 +25%/次",
		"offers": [
			{"id": "o1", "name": "石甲蛊", "kind": "purchase", "price": "6 元石", "desc": "护盾 +8", "quality": "稀有", "curse_warning": false},
			{"id": "o2", "name": "魂丹", "kind": "soul_boost", "price": "6 元石", "desc": "魂魄 +1", "quality": "史诗", "curse_warning": false},
			{"id": "o3", "name": "寿元·脉冲鼓", "kind": "lifespan_deal", "price": "1 寿元", "desc": "高回报代价交易", "quality": "稀有", "curse_warning": true},
		],
		"services": [
			{"id": "remove_card", "name": "移除蛊虫", "price": "120 元石", "remaining": 2, "note": "从蛊囊删除一只蛊 · 本局剩 2/2 次 · 每次使用涨价", "candidates": [], "target_label": "选择要移除的蛊虫", "executable": false, "block_reason": "没有可移除的目标"},
			{"id": "wash_notoriety", "name": "洗刷恶名", "price": "10 寿元", "remaining": -1, "note": "恶名 -2 · 消耗寿元 · 无次数上限", "candidates": [], "target_label": "", "executable": false, "block_reason": "当前没有恶名可洗"},
		],
		"emergency_note": "元石不足可用气血 / 寿元 / 反噬 / 销毁组件应急支付",
	})
	var shop_cmds := {"buy": Callable(self, "_noop"), "service": Callable(self, "_noop"), "leave": Callable(self, "_noop")}

	var rest_state := gui_state.duplicate()
	rest_state.merge({
		"title": "闭关 · 休整",
		"note": "强制二选一，不可全拿",
		"choices": [
			{"id": "heal", "label": "调息回血", "detail": "回复 30 气血", "cost": "", "disabled": false, "reason": "", "curse_warning": false},
			{"id": "nurture", "label": "温养一蛊", "detail": "强化一张卡 / 移除负面", "cost": "", "disabled": false, "reason": "", "curse_warning": false},
			{"id": "wash", "label": "洗髓换骨", "detail": "真元上限 +1（实时刷新）", "cost": "10 寿元 + 8 元石", "disabled": false, "reason": "一局一次 · 执行前预检寿元", "curse_warning": false},
		],
		"is_ascension": false,
		"growth": [],
		"confirming": "",
		"confirm_msg": "",
	})
	var rest_cmds := {"choose": Callable(self, "_noop"), "confirm_wash": Callable(self, "_noop"), "cancel_confirm": Callable(self, "_noop"), "leave": Callable(self, "_noop")}

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
			{"id": "r2", "name": "盲盒（随机）", "output": "未知蛊", "quality": "随机", "fail_chance": "失败率 50% · 毁材", "backlash": "躁动 +2", "curse": "诅咒继承⚠", "unlocked": true},
		],
		"dismantle_slots": ["石甲蛊"],
		"streak_note": "连续失败第 2 次，下次成功率 +5%",
		"confirming": "",
		"confirm_msg": "",
	})
	var refine_cmds := {"set_channel": Callable(self, "_noop"), "refine": Callable(self, "_noop"), "toggle_input": Callable(self, "_noop"), "dismantle": Callable(self, "_noop"), "confirm": Callable(self, "_noop"), "cancel_confirm": Callable(self, "_noop"), "leave": Callable(self, "_noop")}

	var reward_state := gui_state.duplicate()
	reward_state.merge({
		"title": "战利品",
		"rewards": [
			{"id": "r1", "name": "月光蛊", "kind": "蛊 · 战斗奖励", "quality": "稀有", "effect": "造成月光伤害并附加「月息」层", "cost": "获取即入蛊囊", "curse_warning": false},
			{"id": "r2", "name": "元石 +15", "kind": "货币", "quality": "普通", "effect": "直接入账", "cost": "", "curse_warning": false},
			{"id": "r3", "name": "血祭蛊", "kind": "蛊 · 诅咒蛊", "quality": "稀有", "effect": "吸取气血", "cost": "每次使用反噬 +1", "curse_warning": true},
		],
		"full_satchel": false,
		"pool_fallback_note": "（空池回退：已切至基础池）",
		"pity_note": "（保底：连续普通后，下次掉落品质有较大概率提升）",
	})
	var reward_cmds := {"take": Callable(self, "_noop"), "replace_and_take": Callable(self, "_noop"), "skip": Callable(self, "_noop"), "close": Callable(self, "_noop")}

	var npc_state := gui_state.duplicate()
	npc_state.merge({
		"npc_name": "游方医修",
		"stance": "中立",
		"stance_note": "交涉失败将种子化翻转敌视",
		"notoriety": 12,
		"notoriety_note": "恶名高亮：威慑部分路线",
		"offers": [
			{"id": "o1", "name": "回购货物", "price": "5 元石", "desc": "出手一批闲置物资"},
		],
		"barter": [
			{"id": "b1", "name": "迹眼蛊 换 雾步蛊", "give": "迹眼蛊", "take": "雾步蛊", "note": "以物易物 · 需空位校验"},
		],
		"talk_options": [
			{"id": "t1", "label": "友善攀谈", "detail": "了解情报与需求", "danger": false},
			{"id": "t3", "label": "威胁勒索", "detail": "恶名威慑 · 可能翻脸", "danger": true},
		],
		"can_flee": true,
	})
	var npc_cmds := {"talk": Callable(self, "_noop"), "buy": Callable(self, "_noop"), "barter": Callable(self, "_noop"), "flee": Callable(self, "_noop"), "leave": Callable(self, "_noop")}

	# 11) T5-D D5：开发者调试面板（直接 mount 组件，不走控制器门控）。
	# 展开态：红字「调试」角标 + 加蛊/资源/跳层/池情报/快照打印；折叠态：只剩把手条。
	var dp_cmds := {
		"toggle_open": Callable(self, "_noop"),
		"set_gu_input": Callable(self, "_noop"),
		"add_gu": Callable(self, "_noop"),
		"set_res_kind": Callable(self, "_noop"),
		"set_res_value": Callable(self, "_noop"),
		"apply_resource": Callable(self, "_noop"),
		"set_travel_node": Callable(self, "_noop"),
		"travel": Callable(self, "_noop"),
		"snapshot_dump": Callable(self, "_noop"),
	}
	var dp_info := {"pity": {"loot_pity": 2, "material_pity": 1, "synthesis_fail_streak": 0}, "excluded": [], "seed": 101, "event_count": 7, "dda_percentile": ""}
	var dp_open := {
		"open": true,
		"feedback": "",
		"info": dp_info,
		"gu_input": "",
		"res_kind": "yuanstone",
		"res_value": "",
		"travel_options": [{"id": "n1", "label": "[n1] 拦路散修"}],
		"travel_selected": "",
		"commands": dp_cmds,
	}
	var dpc := _mount_tscn_props(DEBUG_PANEL_TSCN, dp_open)
	await process_frame
	if _find_label_exact(dpc, "调试") == null:
		push_error("DebugPanel 缺少红字「调试」角标")
		_teardown_mounts()
		return false
	var dp_badge := _find_label_exact(dpc, "调试")
	if not dp_badge.get_theme_color("font_color").is_equal_approx(GuStyle.CINNABAR):
		push_error("DebugPanel「调试」角标必须 DANGER 红字（§16.22 视觉区分）")
		_teardown_mounts()
		return false
	for wanted in ["加蛊", "应用", "跳", "打印 RunData 快照"]:
		if _find_button_by_text(dpc, wanted) == null:
			push_error("DebugPanel 展开态缺少按钮 %s" % wanted)
			_teardown_mounts()
			return false
	if not _host_has_label_text(dpc, "保底计数 · 蛊 2 / 材料 1"):
		push_error("DebugPanel 池情报缺少保底计数行")
		_teardown_mounts()
		return false
	if not _host_has_label_text(dpc, "当前种子 101 · 事件数 7"):
		push_error("DebugPanel 缺少种子/事件数行")
		_teardown_mounts()
		return false
	print("OK DebugPanelOpen buttons=%d" % _count_buttons(dpc))
	var dp_closed := dp_open.duplicate(true)
	dp_closed["open"] = false
	var dpcc := _mount_tscn_props(DEBUG_PANEL_TSCN, dp_closed)
	await process_frame
	if _count_buttons(dpcc) != 1:
		push_error("DebugPanel 折叠态只剩把手条，期望 1 个按钮，实得 %d" % _count_buttons(dpcc))
		_teardown_mounts()
		return false
	if not _host_has_label_text(dpcc, "DEV ONLY"):
		push_error("DebugPanel 折叠态把手条须保留 DEV 标识")
		_teardown_mounts()
		return false
	print("OK DebugPanelCollapsed buttons=%d" % _count_buttons(dpcc))
	var dp_feedback := dp_open.duplicate(true)
	dp_feedback["feedback"] = "调试失败：蛊囊已满（12/12），无法加入 月光蛊"
	var dpcf := _mount_tscn_props(DEBUG_PANEL_TSCN, dp_feedback)
	await process_frame
	if not _host_has_label_text(dpcf, "蛊囊已满"):
		push_error("DebugPanel 操作反馈必须经 Toast 行展示")
		_teardown_mounts()
		return false
	print("OK DebugPanelFeedback buttons=%d" % _count_buttons(dpcf))

	# Godot 官方 .tscn 节点树屏（过渡期与 .guitkx 双轨并存，全部转完后合并）。
	# 表驱动：每个已迁屏给一组 {name: [state, cmds]}，新增屏只加一行。
	var cases := {
		"shop": [shop_state, shop_cmds],
		"rest": [rest_state, rest_cmds],
		"reward": [reward_state, reward_cmds],
		"npc": [npc_state, npc_cmds],
		"encounter": [enc_state, enc_cmds],
		"refine": [refine_state, refine_cmds],
		"ending": [ending_success, ending_cmds],
		"battle": [battle_state, battle_cmds],
	}
	if not await _verify_tscn_screens(cases):
		return false

	# 12) 集成段：真实主场景开局 + 提交命令推进一屏（原 integration_smoke）。
	_teardown_mounts()
	await process_frame
	await process_frame
	return await _integration_flow()


# =====================================================================
# smoke：RUITK 挂载与断言 helpers
# =====================================================================

func _mount(rel_gd: String, component: String, props: Dictionary) -> int:
	var fn = VLib.comp(rel_gd, component)
	if not (fn is Callable):
		push_error("%s 无组件 %s" % [rel_gd, component])
		_teardown_mounts()
		quit(1)
	var container := Control.new()
	root.add_child(container)
	_mount_rui(container, VLib.fc(fn, props))
	return _count_buttons(container)


func _mount_children(rel_gd: String, component: String, props: Dictionary, children: Array) -> int:
	var fn = VLib.comp(rel_gd, component)
	if not (fn is Callable):
		push_error("%s 无组件 %s" % [rel_gd, component])
		_teardown_mounts()
		quit(1)
	var container := Control.new()
	root.add_child(container)
	_mount_rui(container, VLib.fc(fn, props, children))
	return _count_buttons(container)


func _count_buttons(node: Node) -> int:
	var n := 0
	if node is Button:
		n += 1
	for c in node.get_children():
		n += _count_buttons(c)
	return n


## 只数**可见**按钮。顶栏把死线行 / 菜单按钮预置在节点树里（靠 visible 控制），
## _count_buttons 会把这些隐藏节点也算进去，断言"只有 N 个动作"时必须用这个。
func _count_visible_buttons(node: Node) -> int:
	var n := 0
	if node is Button and (node as Button).is_visible_in_tree():
		n += 1
	for c in node.get_children():
		n += _count_visible_buttons(c)
	return n


func _find_button_by_text(node: Node, wanted: String) -> Button:
	if node is Button and node.text == wanted:
		return node
	for c in node.get_children():
		var found := _find_button_by_text(c, wanted)
		if found != null:
			return found
	return null


# 卡面按钮文本是多行卡面（〔稀有〕\n名字\n◆ 消耗\n效果…），不能用精确匹配；
# 手牌/敌人这类动态按钮按「文本包含名字」定位（旧 smoke 时期卡面为纯名字，
# 断言用精确 == 曾静默假绿——battle 屏在旧驱动的 quit 覆盖下从未真正验证过）。
func _find_button_by_text_contains(node: Node, wanted: String) -> Button:
	if node is Button and str(node.text).contains(wanted):
		return node
	for c in node.get_children():
		var found := _find_button_by_text_contains(c, wanted)
		if found != null:
			return found
	return null


## 卡名自 2026-09-11 卡面层级重构起走 `card_name` meta（Button.text 不再含卡名）。
## 与 test_wenzhen_card_fsm._button_match 同约定：meta 与 text 双来源 contains 匹配。
func _find_card_button_by_name_contains(node: Node, wanted: String) -> Button:
	if node is Button:
		var btn := node as Button
		if str(btn.text).contains(wanted) or str(btn.get_meta("card_name", "")).contains(wanted):
			return btn
	for c in node.get_children():
		var found := _find_card_button_by_name_contains(c, wanted)
		if found != null:
			return found
	return null


func _host_has_label_text(node: Node, wanted: String) -> bool:
	if node is Label and str(node.text).contains(wanted):
		return true
	for c in node.get_children():
		if _host_has_label_text(c, wanted):
			return true
	return false


# T5-C：精确匹配标签（供配色断言取回具体 Label 节点）。
func _find_label_exact(node: Node, wanted: String) -> Label:
	if node is Label and str(node.text) == wanted:
		return node
	for c in node.get_children():
		var found := _find_label_exact(c, wanted)
		if found != null:
			return found
	return null


# T6-E：取子树第一个 PanelContainer（读 stylebox 断言底色/描边用）。
func _find_first_panel(node: Node) -> PanelContainer:
	if node is PanelContainer:
		return node
	for c in node.get_children():
		var found := _find_first_panel(c)
		if found != null:
			return found
	return null


func _collect_labels(node: Node, out_labels: Array) -> void:
	if node is Label:
		out_labels.append(node)
	for c in node.get_children():
		_collect_labels(c, out_labels)


func _index_with_prefix(texts: Array[String], prefix: String) -> int:
	for i in texts.size():
		if texts[i].begins_with(prefix):
			return i
	return -1


# T6-E：从角标字符向上爬到最近的 PanelContainer 祖先（角标实底容器）。
func _nearest_panel_ancestor(node: Node) -> PanelContainer:
	var cur := node.get_parent()
	while cur != null:
		if cur is PanelContainer:
			return cur
		cur = cur.get_parent()
	return null


func _mount_component(rel_gd: String, component: String, props: Dictionary) -> Control:
	var fn = VLib.comp(rel_gd, component)
	if not (fn is Callable):
		push_error("%s 无组件 %s" % [rel_gd, component])
		_teardown_mounts()
		quit(1)
	var container := Control.new()
	root.add_child(container)
	_mount_rui(container, VLib.fc(fn, props))
	return container


func _assert_widget(name: String, rel_gd: String, props: Dictionary, children := []) -> void:
	var count := 0
	if children.is_empty():
		count = _mount(rel_gd, "render", props)
	else:
		count = _mount_children(rel_gd, "render", props, children)
	if count < 1:
		push_error("控件 %s 按钮数 %d < 1" % [name, count])
		_teardown_mounts()
		quit(1)
	print("OK %s buttons=%d" % [name, count])


func _sample_button() -> Variant:
	return VLib.fc(VLib.comp("res://ui/widgets/gu_button.gd", "render"), {"label": "测试", "on_press": func(): pass})


# =====================================================================
# smoke：.tscn 屏表驱动 verify（返回 false 即失败）
# =====================================================================

func _verify_tscn_screens(cases: Dictionary) -> bool:
	var shop_state: Dictionary = cases["shop"][0]
	var shop_cmds: Dictionary = cases["shop"][1]
	var shop := _mount_tscn_screen(
			"res://scenes/ui/screens/shop_screen.tscn", shop_state, shop_cmds)
	# .tscn 屏靠 @onready 绑定节点，而 -s 模式下 _ready() 推迟到首帧，必须等一帧再断言。
	await process_frame
	var buttons := _count_buttons(shop)
	if buttons < 1:
		push_error("tscn 黑市按钮数 %d < 1" % buttons)
		_teardown_mounts()
		return false

	var offer_list := shop.get_node(
			"Root/ShopStage/StageContent/PrimarySurface/OfferColumn/OfferScroll/OfferList")
	var expected_offers: int = shop_state["offers"].size()
	if offer_list.get_child_count() != expected_offers:
		push_error("tscn 黑市货架卡数 %d != %d" % [offer_list.get_child_count(), expected_offers])
		_teardown_mounts()
		return false

	# 重复项卡片必须直接挂在货架列表下，不得再套一层带框的决策面板
	# （旧 test_wenzhen_secondary_screens 的文本断言平移到真实节点树上）。
	if expected_offers > 0 and offer_list.get_child(0).get_parent() != offer_list:
		push_error("tscn 黑市货架卡不得嵌套在其他面板里")
		_teardown_mounts()
		return false

	var service_path := ("Root/ShopStage/StageContent/PrimarySurface/ServiceColumn/ServicePanel/ServicePanelMargin"
			+ "/ServicePanelBox/ServiceScroll/ServiceList")
	var service_list := shop.get_node(service_path)
	var expected_services: int = shop_state["services"].size()
	if service_list.get_child_count() != expected_services:
		push_error("tscn 黑市服务行数 %d != %d" % [service_list.get_child_count(), expected_services])
		_teardown_mounts()
		return false

	# 初始态不得自行弹出确认弹窗；危险交易要等玩家点购买才弹。
	var dialog := shop.get_node("Root/ConfirmDialog")
	if dialog.visible:
		push_error("tscn 黑市初始不得展示确认弹窗")
		_teardown_mounts()
		return false

	# 空池回退小字为条件槽位：未标记不渲染，标记后按 13px INK_SOFT 出现。
	# 这两条是旧 ui/screens/shop_screen.guitkx 实现删除后平移过来的等价覆盖。
	var fallback_label: Label = shop.get_node(
			"Root/ShopStage/StageContent/PrimarySurface/OfferColumn/PoolFallbackLabel")
	if fallback_label.visible:
		push_error("tscn 黑市未标记回退时不得渲染回退小字")
		_teardown_mounts()
		return false
	var marked_state := shop_state.duplicate(true)
	marked_state["pool_fallback_note"] = "（空池回退：已切至基础池）"
	var marked := _mount_tscn_screen(
			"res://scenes/ui/screens/shop_screen.tscn", marked_state, shop_cmds)
	await process_frame
	var marked_label: Label = marked.get_node(
			"Root/ShopStage/StageContent/PrimarySurface/OfferColumn/PoolFallbackLabel")
	if not marked_label.visible or marked_label.text != "（空池回退：已切至基础池）":
		push_error("tscn 黑市标记回退后必须渲染小字槽位")
		_teardown_mounts()
		return false
	if (marked_label.get_theme_font_size("font_size") != 13
			or not marked_label.get_theme_color("font_color").is_equal_approx(GuStyle.INK_SOFT)):
		push_error("tscn 黑市回退小字必须 INK_SOFT 13px")
		_teardown_mounts()
		return false
	print("OK TscnShopScreen buttons=%d offers=%d services=%d"
			% [buttons, expected_offers, expected_services])
	if not await _verify_tscn_rest(cases["rest"][0], cases["rest"][1]):
		return false
	if not await _verify_tscn_reward(cases["reward"][0], cases["reward"][1]):
		return false
	if not await _verify_tscn_npc(cases["npc"][0], cases["npc"][1]):
		return false
	if not await _verify_tscn_encounter(cases["encounter"][0], cases["encounter"][1]):
		return false
	if not await _verify_tscn_refine(cases["refine"][0], cases["refine"][1]):
		return false
	if not await _verify_tscn_ending(cases["ending"][0], cases["ending"][1]):
		return false
	if not await _verify_tscn_battle(cases["battle"][0], cases["battle"][1]):
		return false
	return true


## 战斗屏（.tscn 版）挂载回归：出牌三分支 + 选敌 + 操作按钮。
## 出牌判定顺序是核心契约：需选目标 → 进选敌；危险 → 弹确认；其余 → 直接下发。
func _verify_tscn_battle(battle_state: Dictionary, battle_cmds: Dictionary) -> bool:
	var log: Array = []
	var cmds := {
		"play_card": func(cid = "", tid = ""): log.append("play_card:%s/%s" % [cid, tid]),
		"end_turn": func(): log.append("end_turn"),
		"refine": func(): log.append("refine"),
		"flee": func(): log.append("flee"),
	}
	var battle := _mount_tscn_screen(
			"res://scenes/ui/screens/battle_screen.tscn", battle_state, cmds)
	await process_frame

	var ops := battle.get_node("Root/BattleStage/battle_field/OpsDock/OpsRow")
	if ops.get_child_count() < 3:
		push_error("tscn 战斗屏操作按钮不足（应有 结束回合 / 炼蛊 / 撤退）")
		_teardown_mounts()
		return false
	# mode 用空 Label 的 name 承载（test_wenzhen_card_fsm 按此定位），初始为 idle。
	# 水墨去框重构后 ModeHost 位于 battle_field 之内。
	var mode_host := battle.get_node("Root/BattleStage/battle_field/ModeHost")
	if mode_host.get_child_count() != 1 or mode_host.get_child(0).name != "battle_idle":
		push_error("tscn 战斗屏初始 mode 应为 battle_idle")
		_teardown_mounts()
		return false

	# 1) 危险卡 → 只弹确认，不下发
	var danger_btn := _find_card_button_by_name_contains(battle, "血祭蛊")
	if danger_btn == null:
		push_error("tscn 战斗屏手牌未渲染「血祭蛊」")
		_teardown_mounts()
		return false
	danger_btn.pressed.emit()
	await process_frame
	if not battle.get_node("Root/ConfirmDialog").visible:
		push_error("tscn 战斗屏危险卡必须弹确认")
		_teardown_mounts()
		return false
	if not log.is_empty():
		push_error("tscn 战斗屏危险卡确认前不得下发命令: " + str(log))
		_teardown_mounts()
		return false
	var confirm_btn := _find_button_by_text(battle.get_node("Root/ConfirmDialog"), "确认")
	if confirm_btn == null:
		push_error("tscn 战斗屏确认弹窗缺少「确认」")
		_teardown_mounts()
		return false
	confirm_btn.pressed.emit()
	await process_frame
	if log != ["play_card:c2/"]:
		push_error("tscn 战斗屏确认后应下发 play_card:c2/: " + str(log))
		_teardown_mounts()
		return false

	# 2) 需选目标的卡 → 进入 target_select，敌人变可选
	log.clear()
	var target_btn := _find_card_button_by_name_contains(battle, "月芒蛊")
	if target_btn == null:
		push_error("tscn 战斗屏手牌未渲染「月芒蛊」")
		_teardown_mounts()
		return false
	target_btn.pressed.emit()
	await process_frame
	# target_select 模式下 ModeHost 含模式标签 + 「取消目标」按钮两个子节点。
	if mode_host.get_child_count() < 1 or mode_host.get_child(0).name != "battle_target_select":
		push_error("tscn 战斗屏选目标卡应进入 battle_target_select")
		_teardown_mounts()
		return false
	if not log.is_empty():
		push_error("tscn 战斗屏选敌阶段不得下发命令: " + str(log))
		_teardown_mounts()
		return false
	var enemy_btn := _find_card_button_by_name_contains(battle, "铁皮山猪")
	if enemy_btn == null or not enemy_btn.visible:
		push_error("tscn 战斗屏选敌时敌人应变为可选按钮")
		_teardown_mounts()
		return false
	enemy_btn.pressed.emit()
	await process_frame
	if log != ["play_card:c3/e1"]:
		push_error("tscn 战斗屏选中敌人后应带目标下发: " + str(log))
		_teardown_mounts()
		return false

	# 3) 操作按钮
	log.clear()
	for t in ["结束回合", "炼蛊", "撤退"]:
		var b := _find_button_by_text(battle, t)
		if b != null:
			b.pressed.emit()
	if log != ["end_turn", "refine", "flee"]:
		push_error("tscn 战斗屏操作按钮未全部接线: " + str(log))
		_teardown_mounts()
		return false
	print("OK TscnBattleScreen ops=%d" % ops.get_child_count())
	return true


## 结算屏（.tscn 版）挂载回归：成功 / 死亡 / 极简三种形态。
## 死亡与极简两份快照只在本函数用到，就地定义以免污染主流程。
func _verify_tscn_ending(ending_success: Dictionary, ending_cmds: Dictionary) -> bool:
	var ending_death := {
		"title": "命丧密林",
		"ending_type": "death",
		"death_cause_id": "death_cause_backlash",
		"death_cause": "反噬爆发而亡——诅咒层数越过临界，真元与魂魄俱溃。",
		"death_cause_short": "反噬爆发",
		"achievement": "寿元、魂魄或反噬一线归零，身死道消",
		"key_decisions": ["孤身追猎未探虚实"],
		"gains_losses": "反噬爆发，真元枯竭而亡",
		"resource_balance": {"yuanstone": 0, "shouyuan": 0},
		"unlocks": [],
		"aftermath": "残魂归于大地，修行札记已留存",
	}
	var ending_minimal := {
		"title": "保命而退",
		"ending_type": "retreat",
		"achievement": "机缘未至而主动抽身，保命另寻出路",
		"key_decisions": [],
		"gains_losses": "",
		"resource_balance": {},
		"unlocks": [],
		"aftermath": "",
	}
	var success := _mount_tscn_screen("res://scenes/ui/screens/ending_screen.tscn",
			ending_success, ending_cmds)
	await process_frame
	if _count_visible_buttons(success) < 1:
		push_error("tscn 结算(成功)按钮数 < 1")
		_teardown_mounts()
		return false
	# 非死亡结局不得出现死因徽章，也不展开精准死因面板。
	if _host_has_label_text(success, "死因 · "):
		push_error("tscn 非死亡结局不得渲染死因徽章")
		_teardown_mounts()
		return false
	if success.get_node("primary_decision_surface/DeathCausePanel").visible:
		push_error("tscn 非死亡结局不得展开精准死因面板")
		_teardown_mounts()
		return false
	if not _host_has_label_text(success, "达成：" + str(ending_success["achievement"])):
		push_error("tscn 结算缺少达成条件链行")
		_teardown_mounts()
		return false
	# 路线缩略图：Boss 层必须 EMBER 高亮。
	var boss_chip := _find_label_exact(success, "第2层 交锋")
	if boss_chip == null or not boss_chip.get_theme_color("font_color").is_equal_approx(GuStyle.RARITY_EPIC):
		push_error("tscn 路线缩略图 Boss 层必须 EMBER 高亮")
		_teardown_mounts()
		return false
	if not _host_has_label_text(success, "战斗合成：2 次 · 成 1 / 败 1"):
		push_error("tscn 结算缺少合成计数行")
		_teardown_mounts()
		return false
	if _host_has_label_text(success, "DDA 触发"):
		push_error("tscn DDA 预留位无数据时必须整行隐藏")
		_teardown_mounts()
		return false
	var new_chip := _find_label_exact(success, "★新 图鉴：火蛊")
	if new_chip == null or not new_chip.get_theme_color("font_color").is_equal_approx(GuStyle.ANOMALY_YELLOW):
		push_error("tscn 解锁列表项必须带 ★新 前缀")
		_teardown_mounts()
		return false
	if not _host_has_label_text(success, "离局清零"):
		push_error("tscn 资源结余面板缺少「离局清零」小字")
		_teardown_mounts()
		return false

	# 死亡结局：死因徽章并列 + 精准死因面板展开。
	var death := _mount_tscn_screen("res://scenes/ui/screens/ending_screen.tscn",
			ending_death, ending_cmds)
	await process_frame
	if not _host_has_label_text(death, "死因 · 反噬爆发"):
		push_error("tscn 死亡结局须并列死因徽章")
		_teardown_mounts()
		return false
	if not death.get_node("primary_decision_surface/DeathCausePanel").visible:
		push_error("tscn 死亡结局须展开精准死因面板")
		_teardown_mounts()
		return false

	# 极简 run：只有两个动作，路线与本局记录整块隐藏。
	var minimal := _mount_tscn_screen("res://scenes/ui/screens/ending_screen.tscn",
			ending_minimal, ending_cmds)
	await process_frame
	# 动作区按钮数按 ActionRow 统计：2026-09-06 顶栏(背包/设置 icon 按钮)
	# 已 instance 进全屏，全屏按钮总数含顶栏 2 个，不再是纯动作数。
	var ending_action_row := minimal.get_node_or_null(
			"primary_decision_surface/ActionBlock/ActionRow")
	if ending_action_row == null or _count_visible_buttons(ending_action_row) != 2:
		push_error("tscn 极简结算动作区应只有两个按钮，实得 %d"
				% (0 if ending_action_row == null else _count_visible_buttons(ending_action_row)))
		_teardown_mounts()
		return false
	if (_find_button_by_text(minimal, "返回大厅") == null
			or _find_button_by_text(minimal, "查看图鉴") == null):
		push_error("tscn 结算动作必须是 返回大厅 与 查看图鉴（无读档回溯）")
		_teardown_mounts()
		return false
	if minimal.get_node("primary_decision_surface/RoutePanel").visible:
		push_error("tscn 无记录 run 不得渲染路线条")
		_teardown_mounts()
		return false
	# 本局记录块在 B2 结局回顾格（RecapGrid）之内。
	if minimal.get_node("primary_decision_surface/RecapGrid/RecordPanel").visible:
		push_error("tscn 无记录 run 不得渲染本局记录块")
		_teardown_mounts()
		return false
	print("OK TscnEndingScreen buttons=%d" % _count_visible_buttons(success))
	return true


## 炼蛊屏（.tscn 版）挂载回归。
func _verify_tscn_refine(refine_state: Dictionary, refine_cmds: Dictionary) -> bool:
	var refine := _mount_tscn_screen(
			"res://scenes/ui/screens/refine_screen.tscn", refine_state, refine_cmds)
	await process_frame
	var buttons := _count_buttons(refine)
	if buttons < 1:
		push_error("tscn 炼蛊按钮数 %d < 1" % buttons)
		_teardown_mounts()
		return false
	var recipe_list: Node = refine.get_node(
			"Root/RefineStage/StageContent/primary_decision_surface/MainColumn/RecipePanel").content_host.get_node(
			"RecipeScroll/List")
	var expected: int = refine_state["recipes"].size()
	if recipe_list.get_child_count() != expected:
		push_error("tscn 炼蛊配方数 %d != %d" % [recipe_list.get_child_count(), expected])
		_teardown_mounts()
		return false
	# 通道 Tab 是纯屏内过滤：切到「盲盒随机」后配方列表应为空并给出提示。
	var blind_tab := _find_button_by_text(refine, "盲盒随机")
	if blind_tab == null:
		push_error("tscn 炼蛊必须有通道 Tab")
		_teardown_mounts()
		return false
	blind_tab.pressed.emit()
	await process_frame
	if not _host_has_label_text(refine, "（无可用配方）"):
		push_error("tscn 炼蛊切到无配方通道时必须给出空态提示")
		_teardown_mounts()
		return false
	print("OK TscnRefineScreen buttons=%d recipes=%d" % [buttons, expected])
	return true


## 遭遇屏（.tscn 版）挂载回归。
func _verify_tscn_encounter(enc_state: Dictionary, enc_cmds: Dictionary) -> bool:
	var enc := _mount_tscn_screen(
			"res://scenes/ui/screens/encounter_screen.tscn", enc_state, enc_cmds)
	await process_frame
	var buttons := _count_buttons(enc)
	if buttons < 1:
		push_error("tscn 遭遇按钮数 %d < 1" % buttons)
		_teardown_mounts()
		return false
	# 死线只驱动既有资源栏的风险反馈，不应重建为独立行或死因浮层。
	if enc.get_node_or_null("Root/CauseOverlay") != null or _host_has_label_text(enc, "☠"):
		push_error("tscn 遭遇屏不得渲染独立三死线或死因浮层")
		_teardown_mounts()
		return false
	var list: Node = enc.get_node(
			"Root/EncounterStage/StageContent/primary_decision_surface/MainColumn/ActionScroll/ActionList")
	if list.get_child_count() != enc_state["actions"].size():
		push_error("tscn 遭遇行动卡数 %d != %d" % [list.get_child_count(), enc_state["actions"].size()])
		_teardown_mounts()
		return false
	# 空行动列表：仍要给出离开出口（否则玩家卡死在遭遇节点）。
	var empty_state := {
		"node": {"title": "空径", "desc": "无甚异常。", "type": "rest"},
		"actions": [], "intel": {}, "resources": {},
		"contracts": [], "anomalies": [], "death_lines": {},
	}
	var empty := _mount_tscn_screen(
			"res://scenes/ui/screens/encounter_screen.tscn", empty_state, enc_cmds)
	await process_frame
	if _count_buttons(empty) < 1:
		push_error("tscn 遭遇空列表必须保留离开出口")
		_teardown_mounts()
		return false
	print("OK TscnEncounterScreen buttons=%d actions=%d"
			% [buttons, enc_state["actions"].size()])
	return true


## 休整屏（.tscn 版）挂载回归。
func _verify_tscn_rest(rest_state: Dictionary, rest_cmds: Dictionary) -> bool:
	var rest := _mount_tscn_screen(
			"res://scenes/ui/screens/rest_screen.tscn", rest_state, rest_cmds)
	await process_frame
	var buttons := _count_buttons(rest)
	if buttons < 1:
		push_error("tscn 休整按钮数 %d < 1" % buttons)
		_teardown_mounts()
		return false
	# 休整主决策面滚动化后，选项行在 ChoiceHost/ChoiceScroll 之下（2026-09-11 重构）。
	var choice_row := rest.get_node(
			"Root/RestStage/StageContent/primary_decision_surface/PanelMargin/PanelBody/ContentHost/ChoiceHost/ChoiceScroll/ChoiceRow")
	var expected: int = rest_state["choices"].size()
	if choice_row.get_child_count() != expected:
		push_error("tscn 休整选项卡数 %d != %d" % [choice_row.get_child_count(), expected])
		_teardown_mounts()
		return false
	# LeaveRow 是休整软锁红线：常驻跳过入口必须始终存在（AGENTS.md 工作边界）。
	var leave_button: Node = rest.get_node_or_null(
			"Root/RestStage/StageContent/LeaveRow/LeaveButton")
	if leave_button == null or not leave_button.visible:
		push_error("tscn 休整必须常驻可见 LeaveRow 跳过入口")
		_teardown_mounts()
		return false
	# 移除目标面板是条件槽位，未点「温养一蛊」前不得展开。
	if rest.get_node("Root/RestStage/StageContent/RemovePanel").visible:
		push_error("tscn 休整初始不得展开移除目标面板")
		_teardown_mounts()
		return false
	print("OK TscnRestScreen buttons=%d choices=%d" % [buttons, expected])
	return true


## 战利品屏（.tscn 版）挂载回归。
func _verify_tscn_reward(reward_state: Dictionary, reward_cmds: Dictionary) -> bool:
	var reward := _mount_tscn_screen(
			"res://scenes/ui/screens/reward_screen.tscn", reward_state, reward_cmds)
	await process_frame
	var buttons := _count_buttons(reward)
	if buttons < 1:
		push_error("tscn 战利品按钮数 %d < 1" % buttons)
		_teardown_mounts()
		return false
	var row := reward.get_node("Root/primary_decision_surface/RewardRow")
	var expected: int = reward_state["rewards"].size()
	if row.get_child_count() != expected:
		push_error("tscn 战利品卡数 %d != %d" % [row.get_child_count(), expected])
		_teardown_mounts()
		return false
	# 诅咒蛊同样走 GuCard 强红角标（R4.10）。
	if _find_label_exact(reward, "咒") == null:
		push_error("tscn 战利品诅咒蛊缺少「咒」角标")
		_teardown_mounts()
		return false
	# 标记回退时渲染 13px INK_SOFT 小字。
	var note: Label = reward.get_node("Root/NoteRow/PoolFallbackLabel")
	if not note.visible:
		push_error("tscn 战利品标记回退后必须渲染小字")
		_teardown_mounts()
		return false
	if (note.get_theme_font_size("font_size") != 13
			or not note.get_theme_color("font_color").is_equal_approx(GuStyle.INK_SOFT)):
		push_error("tscn 战利品回退小字必须 INK_SOFT 13px")
		_teardown_mounts()
		return false
	# 未标记时不得出现常驻假提示。
	var clean := reward_state.duplicate(true)
	clean.erase("pool_fallback_note")
	var clean_screen := _mount_tscn_screen(
			"res://scenes/ui/screens/reward_screen.tscn", clean, reward_cmds)
	await process_frame
	if clean_screen.get_node("Root/NoteRow/PoolFallbackLabel").visible:
		push_error("tscn 战利品未标记回退时不得渲染回退小字")
		_teardown_mounts()
		return false
	print("OK TscnRewardScreen buttons=%d rewards=%d" % [buttons, expected])
	return true


## NPC 交涉屏（.tscn 版）挂载回归。
func _verify_tscn_npc(npc_state: Dictionary, npc_cmds: Dictionary) -> bool:
	var npc := _mount_tscn_screen(
			"res://scenes/ui/screens/npc_screen.tscn", npc_state, npc_cmds)
	await process_frame
	var buttons := _count_buttons(npc)
	if buttons < 1:
		push_error("tscn NPC 按钮数 %d < 1" % buttons)
		_teardown_mounts()
		return false
	var surface := "Root/primary_decision_surface/"
	var offer_list: Node = npc.get_node(
			surface + "TradeColumn/TradePanel").content_host.get_node("OfferScroll/List")
	# 易物面板已独立为第三列（TalkColumn/TradeColumn/BarterColumn 三列布局）。
	var barter_list: Node = npc.get_node(
			surface + "BarterColumn/BarterPanel").content_host.get_node("BarterScroll/List")
	var talk_list: Node = npc.get_node(
			surface + "TalkColumn/TalkPanel").content_host.get_node("TalkScroll/List")
	if offer_list.get_child_count() != npc_state["offers"].size():
		push_error("tscn NPC 交易项数 %d != %d" % [offer_list.get_child_count(), npc_state["offers"].size()])
		_teardown_mounts()
		return false
	if barter_list.get_child_count() != npc_state["barter"].size():
		push_error("tscn NPC 易物项数不符")
		_teardown_mounts()
		return false
	if talk_list.get_child_count() != npc_state["talk_options"].size():
		push_error("tscn NPC 交涉项数不符")
		_teardown_mounts()
		return false
	# 极度仇恨禁逃：撤退按钮整体隐藏，不留"能点但注定失败"的死按钮。
	var no_flee := npc_state.duplicate(true)
	no_flee["can_flee"] = false
	var caged := _mount_tscn_screen(
			"res://scenes/ui/screens/npc_screen.tscn", no_flee, npc_cmds)
	await process_frame
	if caged.get_node(surface + "TalkColumn/FleeButton").visible:
		push_error("tscn NPC 禁逃时不得展示撤退按钮")
		_teardown_mounts()
		return false
	print("OK TscnNpcScreen buttons=%d offers=%d talks=%d"
			% [buttons, npc_state["offers"].size(), npc_state["talk_options"].size()])
	return true


# =====================================================================
# smoke：集成段（原 integration_smoke）——真实主场景开局 + 命令推进
# =====================================================================

## 返回 false 即失败。start_new_run 后断言 RUI 宿主已挂载渲染；
## 再经 submit_command 推进一屏，断言无报错。
func _integration_flow() -> bool:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var rc = main.get_node("RunController")
	if rc == null:
		push_error("找不到 RunController")
		quit(1)
	rc.ensure_ui()

	# 2) 开新局，断言 RUI 宿主已挂载并渲染了地图屏。
	rc.start_new_run(12345, "force")
	var host = rc.get_node("RUIHost")
	if host == null or host.get_child_count() <= 0:
		push_error("RUI 宿主未挂载任何控件")
		quit(1)
	if rc.current_view_name() != "Map":
		push_error("开新局后未进入地图屏: %s" % rc.current_view_name())
		quit(1)
	print("INTEGRATION step1: host children=%d view=%s" % [host.get_child_count(), rc.current_view_name()])

	# 3) 经 submit_command 推进到可达节点（遭遇或战斗），断言屏切换且宿主仍渲染无报错。
	var reach := MapGenerator.reachable_nodes(rc.route, rc.state)
	if reach.is_empty():
		push_error("没有任何可达节点，无法推进")
		quit(1)
	var target_id := str(reach[0]["id"])
	rc.submit_command({"type": "travel", "node_id": target_id})
	var view = rc.current_view_name()
	if view != "Encounter" and view != "Battle":
		push_error("推进后未进入遭遇/战斗屏: %s" % view)
		quit(1)
	if host.get_child_count() <= 0:
		push_error("推进后宿主无控件")
		quit(1)
	print("INTEGRATION step2: after travel view=%s host children=%d" % [view, host.get_child_count()])

	print("INTEGRATION OK")
	return true


# =====================================================================
# render 模式：通用像素探针（原 render_probe）
# =====================================================================

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


# =====================================================================
# capture 模式：GUI 实跑截图（原 ui_capture）
# =====================================================================

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


func _run_capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	if not _compile_file(SAMPLE):
		quit(1)
		return
	if not _compile_dir(WIDGET_DIR):
		quit(1)
		return
	if not _compile_dir(SCREEN_DIR):
		quit(1)
		return
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


# =====================================================================
# play 模式：玩家视角整局游玩冒烟（原 playthrough_smoke）
# =====================================================================

## 修复 6：非蛊商品（魂丹/材料/配方/服务）不能按 gu_id 取名落成空串。
static func offer_label(offer: Dictionary) -> String:
	var gu_id := str(offer.get("gu_id", ""))
	if not gu_id.is_empty():
		return DisplayText.gu(gu_id)
	var output_gu_id := str(offer.get("output_gu_id", ""))
	if not output_gu_id.is_empty():
		return DisplayText.gu(output_gu_id)
	var material_id := str(offer.get("material_id", ""))
	if not material_id.is_empty():
		return DisplayText.material(material_id)
	var card_key := str(offer.get("card_key", ""))
	if not card_key.is_empty():
		return card_key
	return str(offer.get("id", "商品"))


## 修复 6：离场命令结果的 ok/reason 检查（会话路径 ok 在嵌套 result 里）。
static func leave_result_ok(result: Dictionary) -> bool:
	var payload: Dictionary = result.get("result", result) as Dictionary
	return bool(payload.get("ok", false))


## 修复 6：统一离场——失败即终止冒烟，绝不静默循环重试。
func _leave(controller, context: String) -> bool:
	var result: Dictionary = controller.submit_command({"type": "leave_node"})
	if leave_result_ok(result):
		_tell("%s：已离场" % context)
		return true
	var payload: Dictionary = result.get("result", result) as Dictionary
	_tell("%s：离场被拒（%s）——终止冒烟以防静默空转" % [context, str(payload.get("reason", "unknown"))])
	return false


const STONE_RESERVE := 1


func _run_play() -> void:
	_ensure_domains()
	var controller = RunControllerScript.new()
	controller.catalog = ContentCatalog.load_all()
	# 发散试玩参数：PLAYTHROUGH_SEED / PLAYTHROUGH_CONTRACTS（逗号分隔，空=无契约）。
	var seed_env := OS.get_environment("PLAYTHROUGH_SEED")
	var seed_value := int(seed_env) if not seed_env.is_empty() else 20260927
	var contract_env := OS.get_environment("PLAYTHROUGH_CONTRACTS")
	var contracts: Array[String] = []
	if not contract_env.is_empty():
		for piece in contract_env.split(",", false):
			contracts.append(piece.strip_edges())
	var school_env := OS.get_environment("PLAYTHROUGH_SCHOOL")
	# 2026-09-12：不再白名单 5 个流派——凡 schools.json 登记的流派都可驱动。
	# 旧白名单让新流派（如剑道）永远进不了端到端验收。
	var known_schools: Dictionary = ContentCatalog.load_all().get("schools", {})
	var school := school_env if known_schools.has(school_env) else ""
	# 玩家真实开局路径：大厅选择流派与契约后开新局（controller 内部执行 swearing）。
	controller.start_new_run(seed_value, school, contracts)
	# Q8-G Batch 1 总验收：PLAYTHROUGH_FULL=1 把 slice 收口（ending_after_stage，
	# 生产配置为 "one"）推迟到第五层——验收局需要完整 5 层拓扑验证 promotion 链。
	# 必须在 start_new_run 之后打补丁（start_new_run 会重载 catalog），而收口
	# 判定发生在战斗胜利时（读 controller.catalog），此处补丁恰好生效。
	# 只改验收局 catalog，不动生产 pacing.json。
	if OS.get_environment("PLAYTHROUGH_FULL") == "1":
		controller.catalog["pacing"]["ending_after_stage"] = "five"
		_tell("总验收模式：完整 5 层拓扑（ending_after_stage -> five）")
	_init_f1_opportunity_pity_simulation(controller)
	_init_e6_tier_audit(controller)
	_tell("开局 seed=%d | 起点=%s | 元石=%d | 气血=%d/%d | 魂魄=%d | 契约=%s" % [
		seed_value, controller.state.current_node_id,
		int(controller.state.stone), int(controller.state.health),
		int(controller.state.max_health), int(controller.state.cultivator.get("soul", 0)),
		str(controller.state.contracts),
	])

	var steps := 0
	var outcome := "ongoing"
	# 拓扑 v2 一局 160–220 节点（含每层 Boss 台），900 步预算必然中途截断。
	while steps < 900 and outcome == "ongoing":
		steps += 1
		outcome = _step(controller)
		if controller.state != null and controller.state.is_terminal():
			outcome = "terminal"
	_tell("-- 游玩结束 --")
	_tell("总步数: %d | 结局: %s" % [steps, outcome])
	_tell("终局状态: 节点=%s | 元石=%d | 气血=%d/%d | 蛊=%d | 契约=%s | 图鉴=%d | 事件=%d" % [
		controller.state.current_node_id, int(controller.state.stone),
		int(controller.state.health), int(controller.state.max_health),
		(controller.state.gu_instances as Dictionary).size(),
		str(controller.state.contracts), (controller.state.global_codex_ids as Array).size(),
		(controller.state.event_log as Array).size(),
	])
	var dda_triggers := 0
	for event in controller.state.event_log:
		if str(event.get("action", "")) == "dda_marker":
			dda_triggers += 1
	_tell("DDA 标记触发: %d 次" % dda_triggers)
	_tell("中途进程: %s" % ["失败(无进展)" if steps >= 900 else "正常"])
	_run_play_acceptance_report(controller, school)
	controller.free()
	quit(0)


## Q8-G Batch 1 总验收（Gate A/B/C）终局报告：从不可变事件日志读真实循环数据。
## Gate A 战斗是否合理赚钱（产石收入 vs promotion 石耗）；
## Gate B 高 Rank 是否可通过游玩获得（promotion 次数 + 持有最高 rank）；
## Gate C 是否完成至少一条本流派 1→5 promotion链（4 次链内 promotion + rank5 在手）。
func _run_play_acceptance_report(controller, school: String) -> void:
	var promotions: Array = []
	var stone_earned := 0
	var loot_events := 0
	for event in controller.state.event_log:
		match str(event.get("reason", "")):
			"promotion_succeeded":
				var output_id := ""
				var recipe_id := ""
				for target_value in event.get("targets", []):
					var target := str(target_value)
					if target.begins_with("recipe:"):
						recipe_id = target.trim_prefix("recipe:")
					elif output_id.is_empty():
						output_id = target
				promotions.append({"recipe": recipe_id, "output": output_id})
			"loot_stone_gained":
				stone_earned += int(event["after"]["stone"]) - int(event["before"]["stone"])
				loot_events += 1
	var battles := loot_events  # 每场胜利结算恰一条产石事件
	_tell("-- Batch 1 总验收（Gate A/B/C，流派=%s）--" % [school if not school.is_empty() else "(默认)"])
	_tell("战斗胜利结算: %d | 战斗产石合计: %d | 终局元石: %d" % [battles, stone_earned, int(controller.state.stone)])
	# R-3 观测指标（provisional 调参的后续校准依据）：机会 = 路线上 refinement 节点数。
	var refine_opportunities := 0
	for node_value in controller.route:
		if str((node_value as Dictionary).get("type", "")) == "refinement":
			refine_opportunities += 1
	_tell("R-3 观测: refinement 节点 %d 个 | 实际探访 %d 次（材料就绪 %d 次）| 本流派 promotion 尝试 %d 次（成功 %d）" % [
		refine_opportunities, _refine_visits, _visits_material_ready, _promo_attempts, _promo_accepted,
	])
	# Reachability-2 五段漏斗（2026-09-13 裁定）：gu_ready → mat_ready →
	# 全条件就绪 → 尝试 → 成功；gu_missing 直方图回答"材料就绪为何尝试 0"。
	var final_readiness: Dictionary = _promotion_readiness(controller)
	_tell("R-4 漏斗: 探访 %d | gu_ready %d | mat_ready %d | 全条件就绪 %d | 尝试 %d / 成功 %d" % [
		_refine_visits, _visits_gu_ready, _visits_material_ready, _visits_full_ready,
		_promo_attempts, _promo_accepted,
	])
	_tell("R-4 终局就绪: 蛊=%s 材料=%s 全条件=%s | 机会→探访转换 %d/%d" % [
		"是" if bool(final_readiness["gu_ok"]) else "否",
		"是" if bool(final_readiness["mat_ok"]) else "否",
		"是" if bool(final_readiness["full_ok"]) else "否",
		_refine_visits, refine_opportunities,
	])
	for missing_gu_id in _gu_missing_hist:
		_tell("  gu_missing（材料就绪而蛊缺）%s ×%d" % [missing_gu_id, int(_gu_missing_hist[missing_gu_id])])
	for reject_reason in _promo_rejects:
		_tell("  promotion 拒因 %s ×%d" % [reject_reason, int(_promo_rejects[reject_reason])])
	# 材料经济观测：战斗掉落按材料直方图（本流派四段带量），对账"断在哪一带"。
	var mat_gained := {}
	for event in controller.state.event_log:
		if str(event.get("reason", "")) != "loot_materials_gained":
			continue
		for material_id_value in event.get("targets", []):
			var material_id := str(material_id_value)
			mat_gained[material_id] = int(mat_gained.get(material_id, 0)) + 1
	var gained_total := 0
	for material_id in mat_gained:
		gained_total += int(mat_gained[material_id])
	_tell("材料掉落合计 %d 件" % gained_total)
	if not school.is_empty():
		for band in range(1, 5):
			var band_mat := "mat_%s_%d" % [school, band]
			_tell("  掉落 %s ×%d | 剩余 ×%d" % [
				band_mat, int(mat_gained.get(band_mat, 0)),
				int(controller.state.materials.get(band_mat, 0)),
			])
	_tell("promotion 完成: %d 次" % promotions.size())
	for promo in promotions:
		_tell("  promotion: %s -> %s" % [promo["recipe"], promo["output"]])
	var highest_rank := 0
	for instance_value in controller.state.gu_instances.values():
		if str(instance_value.get("state", "")) == "refined":
			highest_rank = maxi(highest_rank, int(instance_value.get("rank", 1)))
	_tell("持有蛊最高 rank: %d" % highest_rank)
	if not school.is_empty():
		for band in range(1, 5):
			var band_mat := "mat_%s_%d" % [school, band]
			_tell("主材 %s 剩余 ×%d" % [band_mat, int(controller.state.materials.get(band_mat, 0))])
	# Gate A：产石为正且 ≥ 首步 promotion 石耗（本验收口径下最低石耗 6）。
	var gate_a := battles > 0 and stone_earned >= 6
	_tell("Gate A 战斗合理赚钱: %s" % ["PASS" if gate_a else "FAIL"])
	# Gate B：高 Rank 通过游玩获得（≥3 次 promotion 即抵达 rank4，rank5 为满分）。
	var gate_b := promotions.size() >= 3 and highest_rank >= 4
	_tell("Gate B 高转可玩获得: %s" % ["PASS" if gate_b else "FAIL"])
	# Gate C：本流派 1→5 链完成（4 次链内 promotion + rank5 在手）。
	var school_promotions := 0
	for promo in promotions:
		if str(promo["recipe"]).begins_with("promote_%s_" % school):
			school_promotions += 1
	var gate_c := (not school.is_empty()) and school_promotions >= 4 and highest_rank >= 5
	_tell("Gate C 1→5 链完成: %s（本流派链内 promotion %d 次）" % ["PASS" if gate_c else "FAIL", school_promotions])
	if _f1_opportunity_pity_enabled:
		_tell("R-4 actual funnel: visits=%d gu_ready=%d mat_ready=%d full_ready=%d attempts=%d successes=%d" % [
			_refine_visits, _visits_gu_ready, _visits_material_ready, _visits_full_ready,
			_promo_attempts, _promo_accepted,
		])
		_tell("R-4 actual gates: gate_b=%s gate_c=%s promotions=%d highest_rank=%d school_promotions=%d" % [
			"PASS" if gate_b else "FAIL", "PASS" if gate_c else "FAIL",
			promotions.size(), highest_rank, school_promotions,
		])
		_tell("R-4 SIM summary: actual_f1_count=%d simulated_forced_f1_count=%d actual_common_battle_count=%d candidate_empty_count=%d f1_missing_final=%d threshold=%d legal_f1=%s tier_distribution=%s" % [
			_sim_actual_f1_count, _sim_forced_f1_count, _sim_actual_common_battle_count,
			_sim_candidate_empty_count, _sim_f1_missing_streak, _sim_f1_threshold,
			str(_sim_legal_f1_ids), str(_sim_tier_counts),
		])
	_e6_summary(controller, gate_b, gate_c)


func _step(controller) -> String:
	var view: String = controller.current_view_name()
	if view == "Battle" and _last_view != "Battle":
		_tell("开战于 %s（%s）" % [
			controller.state.current_node_id,
			str(controller.current_node.get("enemy_kind", "")),
		])
	if view == "Refine" and _last_view != "Refine":
		_tell("打开炼蛊子屏于 %s" % controller.state.current_node_id)
	_last_view = view
	match view:
		"Map":
			return _step_map(controller)
		"Shop":
			return _step_shop(controller)
		"Encounter":
			return _step_encounter(controller)
		"Rest":
			return _step_via_cards(controller, "休整")
		"Refine":
			# 玩家策略（Q8-G Batch 1 总验收）：先试 promotion（谱系链 completion
			# 是本验收目标），再做同名升阶（质量换预算）。
			for recipe_value in controller.catalog.get("refinement_recipes", []):
				var promo_recipe: Dictionary = recipe_value
				if str(promo_recipe.get("kind", "")) != "promotion":
					continue
				var promo_result: Dictionary = controller.submit_command({"type": "refine_gu", "recipe_id": str(promo_recipe.get("id", ""))})
				var promo_payload_check: Dictionary = promo_result.get("result", promo_result) as Dictionary
				var promo_ok: bool = bool(promo_result.get("ok", false)) or bool(promo_payload_check.get("ok", false))
				_note_promo_attempt(controller, str(promo_recipe.get("id", "")), promo_ok,
						str(promo_payload_check.get("reason", "unknown")))
				if promo_ok:
					_tell("炼蛊台：promotion %s" % str(promo_recipe.get("id", "")))
					return "ongoing"
				if str(promo_recipe.get("id", "")).begins_with("promote_%s_" % controller.state.school):
					var promo_payload: Dictionary = promo_result.get("result", promo_result) as Dictionary
					_tell("promotion 被拒 %s（%s）" % [str(promo_recipe.get("id", "")), str(promo_payload.get("reason", "unknown"))])
			for recipe_value in controller.catalog.get("refinement_recipes", []):
				var recipe: Dictionary = recipe_value
				if str(recipe.get("kind", "")) != "advance":
					continue
				var result: Dictionary = controller.submit_command({"type": "refine_gu", "recipe_id": str(recipe.get("id", ""))})
				if bool(result.get("ok", false)) or bool((result.get("result", {}) as Dictionary).get("ok", false)):
					_tell("炼蛊台：同名升阶 %s" % str(recipe.get("id", "")))
					return "ongoing"
			if not _leave(controller, "炼蛊台"):
				return "leave_blocked"
			return "ongoing"
		"Reward":
			if not _leave(controller, "战利品"):
				return "leave_blocked"
			return "ongoing"
		"Npc":
			if not _leave(controller, "NPC"):
				return "leave_blocked"
			return "ongoing"
		"Battle":
			return _step_battle(controller)
		"Ending", "Title", "Hall", "Settings", "Codex", "Journal":
			return str(view).to_lower()
		_:
			_tell("未知视口 %s：尝试离开" % view)
			if not _leave(controller, "未知视口"):
				return "leave_blocked"
			return "ongoing"


## R-3 观测：只计本流派链内 promotion 尝试（跨派配方必然缺输入，计入只是噪声）。
func _note_promo_attempt(controller, recipe_id: String, ok: bool, reason: String) -> void:
	if not recipe_id.begins_with("promote_%s_" % controller.state.school):
		return
	_promo_attempts += 1
	if ok:
		_promo_accepted += 1
	else:
		_promo_rejects[reason] = int(_promo_rejects.get(reason, 0)) + 1


func _step_via_cards(controller, label: String) -> String:
	# 通用节点策略：按官方动作预览逐张消费可执行卡（含休整双选/地脉探查），
	# 全部处置完或只剩离场时离开。硬编码单一动作会撞 R8.1 rest_choice 门禁。
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(
		controller.state, controller.current_node, controller.catalog)
	var node_type := str(controller.current_node.get("type", ""))
	# 总验收策略：炼蛊台 promotion 卡优先（谱系链是 Gate B/C 目标），
	# advance/其余卡次之；配方卡顺序按目录序，不重排会先吃掉无关可执行卡。
	if node_type == "refinement":
		var promo_cards: Array[Dictionary] = []
		var tail_cards: Array[Dictionary] = []
		for card in cards:
			if str(card.get("id", "")).begins_with("refine.promote_"):
				promo_cards.append(card)
			else:
				tail_cards.append(card)
		var ordered: Array[Dictionary] = []
		for card in promo_cards:
			ordered.append(card)
		for card in tail_cards:
			ordered.append(card)
		cards = ordered
	var acted := false
	for card in cards:
		var card_id := str(card.get("id", ""))
		if not bool(card.get("executable", false)):
			continue
		if str(card_id) == "node.leave":
			continue
		# free_mix（自由配对）需在 UI 中逐对选择输入实例；卡片命令携带全部
		# 候选实例，盲提交必然超 craft_cap——驱动器不冒充配对选择。
		if str(card_id) == "refine.free_mix":
			continue
		# 玩家理财：元石要留给战力构筑；商店与炼蛊台之外不为情报/服务掏钱
		# （promotion/advance 的元石与材料正是战力构筑本身的支出）。
		var cost: Dictionary = card.get("cost", {})
		if int(cost.get("stone", 0)) > 0 and node_type != "shop" and node_type != "refinement":
			continue
		var command: Dictionary = card.get("command", {})
		if command.is_empty():
			continue
		command = command.duplicate(true)
		command["type"] = "action_card"
		command["action_id"] = card_id
		command["state_version"] = controller.state.event_log.size()
		var result: Dictionary = controller.submit_command(command)
		# 会话路径返回 {state, session, feed, result}：ok 在内层 result 里。
		var payload: Dictionary = result.get("result", result) as Dictionary
		var card_ok: bool = bool(payload.get("ok", false))
		if card_id.begins_with("refine."):
			_note_promo_attempt(controller, str(card_id).trim_prefix("refine."), card_ok,
					str(payload.get("reason", "unknown")))
		var battle_started: bool = bool(payload.get("start_battle", false)) \
			or controller.current_view_name() == "Battle"
		if battle_started or card_ok:
			_tell("%s：执行 %s" % [label, card_id])
			acted = true
			break
		# 2026-09-12：被拒不再中断循环——继续试下一张卡。旧实现 break 后落到
		# leave_node，被 rest_choice_required 拦下即误判为「软锁」而终止冒烟
		# （refinement/cultivation 节点在元石不足时必现）。
		_tell("%s：%s 被拒（%s）" % [label, card_id, str(payload.get("reason", "unknown"))])
	if not acted:
		# 休整族节点（rest / refinement / cultivation）在「所有选项都不可用」时，
		# 领域提供 rest mode=skip 消费探访（rest_rules._rest_skip，落 rest_skipped）。
		# 动作预览不暴露该卡，故此处按领域全集兜底，与 rest_snapshot 的 skip 等价。
		var skip_result: Dictionary = controller.submit_command({"type": "rest", "mode": "skip"})
		var skip_payload: Dictionary = skip_result.get("result", skip_result) as Dictionary
		if bool(skip_payload.get("ok", false)):
			_tell("%s：跳过（rest mode=skip）" % label)
			return "ongoing"
		if not _leave(controller, label):
			return "leave_blocked"
		_tell("%s：已无可用动作，离场" % label)
	return "ongoing"


func _step_map(controller) -> String:
	# 玩家生存本能：带伤先吃粮（材料「直接使用」通路），气血不满才优先休整。
	if int(controller.state.health) < int(controller.state.max_health):
		for mat_id in ["beast_blood", "beast_bone"]:
			if int(controller.state.materials.get(mat_id, 0)) > 0:
				var eaten: Dictionary = controller.submit_command({"type": "use_material", "material_id": mat_id})
				var eaten_result: Dictionary = eaten.get("result", eaten) as Dictionary
				if bool(eaten_result.get("ok", false)):
					_tell("服用 %s 调理气血（气血=%d）" % [mat_id, int(controller.state.health)])
					return "ongoing"

	var visible: Array = controller.visible_route_nodes(2)

	var visited: Dictionary = controller.state.node_flags
	# 候选顺序：默认玩家策略为「攒实力、Boss 放最后」——先清其余节点，
	# 气血不足六成或战力未成型也不碰任何关底 Boss（拓扑 v2 每大层都有
	# layer_boss_stand_N 关底台，旧逻辑只认 final_boss_stand 全局门）；
	# 仅当别无可走时才硬闯（或用 PLAYTHROUGH_BOSS_FIRST=1 还原旧的 Boss 优先）。
	# 可见 ≠ 可达，逐个尝试直到成功。
	var boss_first := OS.get_environment("PLAYTHROUGH_BOSS_FIRST") == "1"
	var hurt := int(controller.state.health) * 10 < int(controller.state.max_health) * 6
	var strong_enough := (controller.state.gu_instances as Dictionary).size() >= 2 \
		or int(controller.state.stone) >= 10
	var boss_ready := (not hurt) and strong_enough
	var candidates: Array[Dictionary] = []
	var reposition: Array[Dictionary] = []
	var boss_node := {}
	for node in visible:
		var node_id := str(node.get("id", ""))
		if _is_boss_stand(node):
			boss_node = node
			continue
		# 前瞻节点（reachable=false）会让 travel 必被拒，会浪费步数与刷
		# unreachable_route_node 噪声；先只收当前可达的候选。Boss/已访
		# 问节点保留特殊路径在下面单独处理。
		if not bool(node.get("reachable", false)):
			continue
		if visited.has(node_id):
			# 领域允许沿前向边重走已访问节点：困在无 Boss 边的行末时可
			# 绕行到有 Boss 边的节点——兜底重定位目标，优先级最低。
			reposition.append(node)
			continue
		candidates.append(node)
	# 冲仙五项收集优先（玩家策略：升仙前集齐条件节点）；气血不满就主动
	# 补休整（防带伤抵达 Boss 台后无路可退），其余节点随后。
	var sources := ["body_imprint_ritual", "earth_vein_contest", "sealed_earth_vein", "mist_shrine", "poison_fog_vein"]
	# P1-a（R-3 校准，仅测量口径）：mid 行锚点错过即整层无 bench，单看当前可达集
	# 会系统性低估探访上限。利用已取回的 2 层视野预判"走这里能否够到炼蛊台"。
	var visible_by_id: Dictionary = {}
	for node_value in visible:
		visible_by_id[str((node_value as Dictionary).get("id", ""))] = node_value
	var prioritized: Array[Dictionary] = []
	var refine_first: Array[Dictionary] = []
	var refine_leading: Array[Dictionary] = []
	var rest_first: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	var optional_combat: Array[Dictionary] = []
	for candidate in candidates:
		var node_id := str(candidate.get("id", ""))
		var candidate_type := str(candidate.get("type", ""))
		if _is_ascension_source(candidate, sources):
			prioritized.append(candidate)
		elif candidate_type == "refinement":
			# 总验收策略：炼蛊台主动求访（promotion 链是 Gate B/C 目标）——
			# 旧策略把它压在 others，rest/combat 永远先走，整局到不了炼蛊台。
			refine_first.append(candidate)
		elif int(controller.state.health) < int(controller.state.max_health) and candidate_type == "rest":
			rest_first.append(candidate)
		elif _leads_to_refinement(candidate, visible_by_id):
			# 带明确炼蛊意图的玩家会朝 2 层视野内的 bench 走（P1-a 实验设计）。
			refine_leading.append(candidate)
		elif candidate_type in ["combat", "pursuit"]:
			optional_combat.append(candidate)
		else:
			others.append(candidate)
	candidates = prioritized
	for refine_node in refine_first:
		candidates.append(refine_node)
	for rest_node in rest_first:
		candidates.append(rest_node)
	for lead_node in refine_leading:
		candidates.append(lead_node)
	# Q8-G Batch 1 总验收开关：战斗是主生产者，验收局主动求战（opt-in，
	# 不改变既有 play 冒烟的"战斗垫底"默认策略）。
	var combat_first := OS.get_environment("PLAYTHROUGH_COMBAT_FIRST") == "1" and not hurt
	if combat_first:
		for combat_node in optional_combat:
			candidates.append(combat_node)
	for other in others:
		candidates.append(other)
	if not combat_first:
		for combat_node in optional_combat:
			candidates.append(combat_node)
	# 未访问节点全部走完后，允许沿前向边重走已访问节点（领域不拒 visited），
	# 绕到有 Boss 边的节点——单向链上不再困死。
	if candidates.is_empty():
		for rep in reposition:
			candidates.append(rep)
	if not boss_node.is_empty():
		if boss_first or boss_ready or candidates.is_empty():
			if boss_first:
				candidates.push_front(boss_node)
			else:
				candidates.append(boss_node)
	var traveled := false
	for target in candidates:
		var node_id := str(target.get("id", ""))
		var result: Dictionary = controller.submit_command({"type": "travel", "node_id": node_id})
		if bool(result.get("ok", false)):
			# R-3 观测：炼蛊台探访次数按「到达 refinement 节点」计（卡路径
			# 不开 Refine 子屏，按子屏计数会恒为 0）；同时记录 O→C 漏斗的
			# "探访时材料就绪"环。
			if str(target.get("type", "")) == "refinement":
				_refine_visits += 1
				var readiness: Dictionary = _promotion_readiness(controller)
				if bool(readiness["mat_ok"]):
					_visits_material_ready += 1
				if bool(readiness["gu_ok"]):
					_visits_gu_ready += 1
				if bool(readiness["full_ok"]):
					_visits_full_ready += 1
				if bool(readiness["mat_ok"]) and not bool(readiness["gu_ok"]):
					for missing_id_value in readiness["missing_gu"]:
						var missing_id := str(missing_id_value)
						_gu_missing_hist[missing_id] = int(_gu_missing_hist.get(missing_id, 0)) + 1
				# Reachability-5：探访时点标记（已完成的战斗数），用于
				# common 战斗 vs refinement 探访的时序对照。
				if _e6_enabled:
					_e6_visit_battle_marks.append(_e6_battle_number)
			_tell("行至 %s (%s)：元石=%d 气血=%d" % [
				node_id, str(target.get("type", "")),
				int(controller.state.stone), int(controller.state.health),
			])
			traveled = true
			break
		_tell("行至被拒 %s：%s" % [node_id, str(result.get("reason", "unknown"))])
	# 兜底：候选里全是不可达的未访问节点（如下一大层被 Boss 门禁锁住）
	# 时，Boss 台仍在当前可达集内——硬着头皮也要试（困死比战败更糟）。
	if not traveled and not boss_node.is_empty():
		var boss_id := str(boss_node.get("id", ""))
		var boss_travel: Dictionary = controller.submit_command({"type": "travel", "node_id": boss_id})
		if bool(boss_travel.get("ok", false)):
			_tell("行至 %s (boss)：元石=%d 气血=%d" % [
				boss_id, int(controller.state.stone), int(controller.state.health),
			])
			return "ongoing"
		_tell("行至被拒 %s：%s" % [boss_id, str(boss_travel.get("reason", "unknown"))])
	if not traveled:
		_tell("地图无新节点可走（路线尽头）")
		return "no_route"
	return "ongoing"


func _is_ascension_source(node: Dictionary, sources: Array) -> bool:
	var node_id := str(node.get("id", ""))
	var template_id := str(node.get("template_id", ""))
	return sources.has(node_id) or sources.has(template_id)


## P1-a：候选节点沿 next_ids 下行 2 步内是否够得到 refinement 节点。
## 只在 visible_route_nodes(2) 取回的视野内查——视野外按够不到处理（保守估计）。
func _leads_to_refinement(candidate: Dictionary, visible_by_id: Dictionary) -> bool:
	var frontier: Array = [str(candidate.get("id", ""))]
	for _depth in 2:
		var next_frontier: Array = []
		for node_id_value in frontier:
			var node: Dictionary = visible_by_id.get(str(node_id_value), {})
			for next_id_value in node.get("next_ids", []):
				var next_id := str(next_id_value)
				var next_node: Dictionary = visible_by_id.get(next_id, {})
				if next_node.is_empty():
					continue
				if str(next_node.get("type", "")) == "refinement":
					return true
				next_frontier.append(next_id)
		frontier = next_frontier
	return false


## Reachability-2（2026-09-13 裁定）：本派 promotion 配方在当前状态的
## 五段漏斗前两环判定。gu_ok = 持有输入蛊且 rank ≥ input_min_rank；
## mat_ok = 材料齐；full_ok = 单配方三条件（蛊/材料/元石）全齐。
## missing_gu 收集"材料就绪而蛊缺"场景下缺失的输入蛊 id。
func _promotion_readiness(controller) -> Dictionary:
	var school := str(controller.state.school)
	var held_rank: Dictionary = {}
	for inst_value in controller.state.gu_instances.values():
		var inst: Dictionary = inst_value
		# 已消耗实例（promotion 输入/卖掉/放生等）不属持有：与预览卡 refined_gu_ids 口径一致。
		if str(inst.get("state", "")) == "consumed":
			continue
		var owned_id := str(inst.get("definition_id", ""))
		var owned_rank := int(inst.get("rank", 1))
		if owned_rank > int(held_rank.get(owned_id, 0)):
			held_rank[owned_id] = owned_rank
	var gu_ok := false
	var mat_ok := false
	var full_ok := false
	var missing_gu: Array[String] = []
	for recipe_value in controller.catalog.get("refinement_recipes", []):
		var recipe: Dictionary = recipe_value
		if str(recipe.get("kind", "")) != "promotion":
			continue
		if not str(recipe.get("id", "")).begins_with("promote_%s_" % school):
			continue
		var recipe_gu_ok := true
		for input_id_value in recipe.get("input_gu_ids", []):
			var input_id := str(input_id_value)
			if int(held_rank.get(input_id, 0)) < maxi(1, int(recipe.get("input_min_rank", 1))):
				recipe_gu_ok = false
				if not missing_gu.has(input_id):
					missing_gu.append(input_id)
		var recipe_mat_ok := true
		for material_id_value in (recipe.get("materials", {}) as Dictionary):
			var material_id := str(material_id_value)
			if int(controller.state.materials.get(material_id, 0)) < int(recipe["materials"][material_id]):
				recipe_mat_ok = false
		var recipe_stone_ok := int(controller.state.stone) >= int(recipe.get("stone_cost", 0))
		gu_ok = gu_ok or recipe_gu_ok
		mat_ok = mat_ok or recipe_mat_ok
		full_ok = full_ok or (recipe_gu_ok and recipe_mat_ok and recipe_stone_ok)
	return {"gu_ok": gu_ok, "mat_ok": mat_ok, "full_ok": full_ok, "missing_gu": missing_gu}


## Reachability-4：初始化 hypothetical opportunity pity。所有候选都从真实
## catalog 派生：本派 promotion chain ∩ common material_pool ∩ crude。
func _init_f1_opportunity_pity_simulation(controller) -> void:
	_f1_opportunity_pity_enabled = OS.get_environment("PLAYTHROUGH_F1_OPPORTUNITY_PITY") == "1"
	_sim_f1_missing_streak = 0
	_sim_f1_threshold = 0
	_sim_legal_f1_ids.clear()
	_sim_actual_f1_count = 0
	_sim_forced_f1_count = 0
	_sim_actual_common_battle_count = 0
	_sim_candidate_empty_count = 0
	_sim_battle_number = 0
	_sim_tier_counts = {}
	if not _f1_opportunity_pity_enabled:
		return
	var material_pity: Dictionary = controller.catalog.get("loot_tables", {}).get("pity", {}).get("material_pity", {})
	_sim_f1_threshold = int(material_pity.get("threshold", 0))
	_sim_legal_f1_ids = _legal_f1_candidates(controller)
	_tell("R-4 模拟开启：full-battle f1 opportunity pity | threshold=%d | legal_f1=%s | 仅 Common 强制" % [
		_sim_f1_threshold, str(_sim_legal_f1_ids),
	])


## 与正式 P2-a 目标集合同源但独立实现，便于把本轮测量边界固定在报告中。
## 不调用、改写或注入 LootResolver 的任何状态。
func _legal_f1_candidates(controller) -> Array[String]:
	var school := str(controller.state.school)
	var chain_material_ids: Dictionary = {}
	if school.is_empty():
		return []
	for recipe_value in controller.catalog.get("refinement_recipes", []):
		var recipe: Dictionary = recipe_value
		if str(recipe.get("kind", "")) != "promotion":
			continue
		if not str(recipe.get("id", "")).begins_with("promote_%s_" % school):
			continue
		for material_id_value in (recipe.get("materials", {}) as Dictionary):
			chain_material_ids[str(material_id_value)] = true
	var common_table: Dictionary = controller.catalog.get("loot_tables", {}).get("loot", {}).get("common", {})
	var material_by_id: Dictionary = controller.catalog.get("material_by_id", {})
	var candidates: Array[String] = []
	for entry_value in common_table.get("material_pool", []):
		var material_id := ""
		if entry_value is String:
			material_id = str(entry_value)
		elif entry_value is Dictionary:
			material_id = str((entry_value as Dictionary).get("id", ""))
		if material_id.is_empty() or not chain_material_ids.has(material_id) or candidates.has(material_id):
			continue
		var material: Dictionary = material_by_id.get(material_id, {})
		if str(material.get("quality_band", "")) == "crude":
			candidates.append(material_id)
	return candidates


## The settlement tier is read from the actual loot event first. Fallback uses
## the returned battle.enemy_kind, matching LootResolver's unknown/multi-enemy
## common fallback rather than reading current_node.enemy_kind.
func _actual_settlement_tier(controller, battle: Dictionary) -> String:
	var node_id := str(controller.current_node.get("id", ""))
	var events: Array = controller.state.event_log
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("reason", "")) != "loot_stone_gained":
			continue
		if str(event.get("node_id", "")) != node_id:
			continue
		var targets: Array = event.get("targets", [])
		if not targets.is_empty():
			return str(targets[0])
	var enemy_kind := str(battle.get("enemy_kind", ""))
	for enemy_value in controller.catalog.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if str(enemy.get("id", "")) == enemy_kind:
			return str(enemy.get("tier", "common"))
	return "common"


## Record only hypothetical local measurements. A material-empty battle leaves
## the simulated counter unchanged; a legal f1 hit clears it; otherwise a
## material-bearing battle accumulates. A forced redemption consumes the
## configured threshold only on a Common settlement and never changes live
## loot/state.
func _record_f1_opportunity_battle(controller, result: Dictionary) -> void:
	if not _f1_opportunity_pity_enabled:
		return
	_sim_battle_number += 1
	var outcome := str(result.get("result", ""))
	var battle: Dictionary = result.get("battle", {}) as Dictionary
	var loot: Dictionary = battle.get("loot", {}) as Dictionary
	var material_ids: Array = loot.get("material_ids", [])
	var actual_f1_count := 0
	for material_id_value in material_ids:
		if _sim_legal_f1_ids.has(str(material_id_value)):
			actual_f1_count += 1
	var settled := outcome == "victory"
	var tier := _actual_settlement_tier(controller, battle) if settled else "unsettled"
	var actual_common := 1 if tier == "common" else 0
	var candidate_empty := 1 if actual_common == 1 and _sim_legal_f1_ids.is_empty() else 0
	var streak_before := _sim_f1_missing_streak
	var forced := 0
	var material_count := material_ids.size()
	if settled:
		if actual_common == 1:
			_sim_actual_common_battle_count += 1
		_sim_candidate_empty_count += candidate_empty
		_sim_tier_counts[tier] = int(_sim_tier_counts.get(tier, 0)) + 1
	_sim_actual_f1_count += actual_f1_count
	if material_count > 0:
		if actual_f1_count > 0:
			_sim_f1_missing_streak = 0
		elif settled and tier == "common" and not _sim_legal_f1_ids.is_empty() \
				and _sim_f1_threshold > 0 and streak_before >= _sim_f1_threshold:
			# Existing pity timing is pre-roll: after threshold misses, the next
			# eligible Common settlement is the hypothetical forced redemption.
			forced = 1
			_sim_forced_f1_count += 1
			_sim_f1_missing_streak = 0
		else:
			_sim_f1_missing_streak += 1
	var streak_after := _sim_f1_missing_streak
	_tell("R-4 battle #%d: outcome=%s node=%s enemy_kind=%s tier=%s actual_f1_count=%d simulated_forced_f1_count=%d actual_common_battle_count=%d candidate_empty_count=%d f1_missing_before=%d f1_missing_after=%d" % [
		_sim_battle_number, outcome, str(controller.current_node.get("id", "")),
		str(battle.get("enemy_kind", "")), tier, actual_f1_count, forced, actual_common,
		candidate_empty, streak_before, streak_after,
	])


## Reachability-5（inbox §14）：E6 loot-tier opportunity audit，opt-in 只读测量。
## resolved tier 以正式结算同源为准：battle.enemy_kind 查 enemy_by_id，
## 空/未知（多敌战斗）按 LootResolver 口径兜底 common。
func _init_e6_tier_audit(controller) -> void:
	_e6_enabled = OS.get_environment("PLAYTHROUGH_E6_TIER_AUDIT") == "1"
	_e6_battle_number = 0
	_e6_actual_f1_count = 0
	_e6_visit_battle_marks.clear()
	_e6_by_tier = {}
	_e6_by_layer = {}
	_e6_by_template = {}
	_e6_by_actual = {}
	_e6_common_indices.clear()
	_e6_common_layers.clear()
	if not _e6_enabled:
		return
	_e6_legal_f1_ids = _legal_f1_candidates(controller)
	_tell("R-5 audit on: legal_f1=%s（只读测量，不改变任何正式规则）" % str(_e6_legal_f1_ids))


func _e6_resolved_tier(controller, battle: Dictionary) -> String:
	var enemy_kind := str(battle.get("enemy_kind", ""))
	if not enemy_kind.is_empty():
		var enemy: Dictionary = (controller.catalog.get("enemy_by_id", {}) as Dictionary).get(enemy_kind, {})
		if not enemy.is_empty():
			return str(enemy.get("tier", "common"))
	return "common"


func _e6_record_battle(controller, result: Dictionary) -> void:
	if not _e6_enabled:
		return
	_e6_battle_number += 1
	var outcome := str(result.get("result", ""))
	var battle: Dictionary = result.get("battle", {}) as Dictionary
	var node: Dictionary = controller.current_node
	var node_layer := int(battle.get("layer", 0))
	if node_layer <= 0:
		node_layer = int(node.get("layer", 1))
	var tier := "unsettled"
	var grade := ""
	var rank := -1
	var material_ids: Array = []
	if outcome == "victory":
		tier = _e6_resolved_tier(controller, battle)
		material_ids = (battle.get("loot", {}) as Dictionary).get("material_ids", [])
	var enemy_kind := str(battle.get("enemy_kind", ""))
	if not enemy_kind.is_empty():
		var enemy: Dictionary = (controller.catalog.get("enemy_by_id", {}) as Dictionary).get(enemy_kind, {})
		grade = str(enemy.get("grade", ""))
		rank = int(enemy.get("rank", -1))
	var layer_cfg: Dictionary = (controller.catalog.get("pacing", {}).get("layers", {}) as Dictionary).get(str(node_layer), {})
	var rank_min := int(layer_cfg.get("enemy_rank_min", -1))
	var rank_max := int(layer_cfg.get("enemy_rank_max", -1))
	var weights: Dictionary = layer_cfg.get("enemy_weights", (controller.catalog.get("pacing", {}) as Dictionary).get("enemy_weights", {}))
	var f1_hit := 0
	for material_id_value in material_ids:
		if _e6_legal_f1_ids.has(str(material_id_value)):
			f1_hit += 1
	_e6_actual_f1_count += f1_hit
	_e6_by_tier[tier] = int(_e6_by_tier.get(tier, 0)) + 1
	_e6_by_layer[node_layer] = int(_e6_by_layer.get(node_layer, 0)) + 1
	var template_kind := str(node.get("enemy_kind", ""))
	_e6_by_template[template_kind] = int(_e6_by_template.get(template_kind, 0)) + 1
	_e6_by_actual[enemy_kind] = int(_e6_by_actual.get(enemy_kind, 0)) + 1
	var is_common := outcome == "victory" and tier == "common"
	if is_common:
		_e6_common_indices.append(_e6_battle_number)
		_e6_common_layers.append(node_layer)
	_tell("R-5 battle: idx=%d outcome=%s stage=%d node=%s tmpl_kind=%s battle_kind=%s battle_kinds=%s tier=%s grade=%s rank=%d layer=%d rank_min=%d rank_max=%d weights=%s mat_tier=%s mats=%s f1_hit=%d school=%s" % [
		_e6_battle_number, outcome, int(controller.state.stage), str(node.get("id", "")),
		template_kind, enemy_kind, str(battle.get("enemy_kinds", [])), tier, grade, rank,
		node_layer, rank_min, rank_max, str(weights), tier if outcome == "victory" else "unsettled",
		str(material_ids), f1_hit, str(controller.state.school),
	])


func _e6_summary(controller, gate_b: bool, gate_c: bool) -> void:
	if not _e6_enabled:
		return
	var first_mark := -1
	for mark in _e6_visit_battle_marks:
		first_mark = mark if first_mark < 0 else mini(first_mark, mark)
	var last_mark := 0
	for mark in _e6_visit_battle_marks:
		last_mark = maxi(last_mark, mark)
	var before_first := 0
	var after_last := 0
	for index in _e6_common_indices:
		if first_mark < 0 or index <= first_mark:
			before_first += 1
		if index > last_mark:
			after_last += 1
	_tell("R-5 summary: battles=%d by_tier=%s by_layer=%s by_template=%s by_actual=%s common_indices=%s common_layers=%s common_before_first_refinement=%d common_after_last_refinement=%d visit_marks=%s visits=%d f1_count=%d f1_zero=%s mat_ready=%d full_ready=%d attempts=%d successes=%d gate_b=%s gate_c=%s" % [
		_e6_battle_number, str(_e6_by_tier), str(_e6_by_layer), str(_e6_by_template),
		str(_e6_by_actual), str(_e6_common_indices), str(_e6_common_layers),
		before_first, after_last, str(_e6_visit_battle_marks), _refine_visits, _e6_actual_f1_count,
		"yes" if _e6_actual_f1_count == 0 else "no",
		_visits_material_ready, _visits_full_ready, _promo_attempts, _promo_accepted,
		"PASS" if gate_b else "FAIL", "PASS" if gate_c else "FAIL",
	])


func _is_boss_stand(node: Dictionary) -> bool:
	# 关底 Boss 台：拓扑 v2 层 Boss（template_id=layer_boss_stand_N，实例 id
	# 是 L{层}R{行}N{序}）+ 五层终局 final_boss_stand。
	var node_id := str(node.get("id", ""))
	if node_id == "final_boss_stand":
		return true
	return str(node.get("template_id", "")).begins_with("layer_boss_stand")


func _owned_count(state, gid: String) -> int:
	var count := 0
	for inst in state.gu_instances.values():
		if str(inst.get("definition_id", "")) == gid:
			count += 1
	return count


func _step_shop(controller) -> String:
	# 玩家视角：把元石花成战力——优先未持有的战力蛊，已持有的同名卡再买
	# 也有价值（多一张手牌 + 同名升阶的原料）；灵魂丹在魂魄不满时补；
	# 货阶高于当前大层的不碰（shop_tier_locked 必拒）。留 2 元石应急。
	var node_type := str(controller.current_node.get("type", ""))
	var state = controller.state
	var max_tier: int = ResolverScript.shop_max_tier(state, controller.catalog)
	if node_type == "caravan":
		var caravan_offers: Array[Dictionary] = []
		for offer_value in controller.catalog.get("caravan_offer_by_id", {}).values():
			var offer: Dictionary = offer_value
			if str(offer.get("kind", "")) != "buy":
				continue
			caravan_offers.append(offer)
		caravan_offers.sort_custom(func(a, b): return int(a.get("stone_cost", 0)) < int(b.get("stone_cost", 0)))
		for offer in caravan_offers:
			var price := int(offer.get("stone_cost", 0))
			if int(state.stone) - price >= STONE_RESERVE:
				var bought: Dictionary = controller.submit_command({"type": "buy_gu", "offer_id": str(offer.get("id", ""))})
				var bought_payload: Dictionary = bought.get("result", bought) as Dictionary
				if bool(bought_payload.get("ok", false)):
					_tell("商队购入 %s（%d 元石）" % [offer_label(offer), price])
		if not _leave(controller, "商队"):
			return "leave_blocked"
		return "ongoing"
	var shop_offers: Array[Dictionary] = []
	for offer_value in controller.catalog.get("shop_offer_by_id", {}).values():
		var offer: Dictionary = offer_value
		var kind := str(offer.get("kind", ""))
		var tier := int(offer.get("tier", 1))
		if tier > max_tier:
			continue
		# 玩家优先级：战力蛊（purchase）> 魂丹（soul_boost，魂魄不满才买）。
		if kind == "purchase":
			shop_offers.append(offer)
		elif kind == "soul_boost" and int(state.cultivator.get("soul", 0)) < int(state.cultivator.get("soul_max", 0)):
			shop_offers.append(offer)
	shop_offers.sort_custom(func(a, b):
		var a_owned := _owned_count(state, str(a.get("gu_id", "")))
		var b_owned := _owned_count(state, str(b.get("gu_id", "")))
		if a_owned != b_owned:
			return a_owned < b_owned
		return int(a.get("stone_cost", 0)) < int(b.get("stone_cost", 0)))
	for offer in shop_offers:
		var price := int(offer.get("stone_cost", 0))
		if price <= 0 or int(state.stone) - price < STONE_RESERVE:
			continue
		var bought: Dictionary = controller.submit_command({"type": "shop_purchase", "offer_id": str(offer.get("id", ""))})
		var bought_payload: Dictionary = bought.get("result", bought) as Dictionary
		if bool(bought_payload.get("ok", false)):
			_tell("黑市购入 %s（%d 元石）" % [offer_label(offer), price])
		else:
			_tell("黑市购入被拒：%s（%s）" % [offer_label(offer), str(bought_payload.get("reason", "unknown"))])
	if not _leave(controller, "黑市"):
		return "leave_blocked"
	return "ongoing"


func _step_encounter(controller) -> String:
	var node: Dictionary = controller.current_node
	var node_type := str(node.get("type", ""))
	# 战后阶段：胜利后结算再离场（玩家视角的战后处理）。
	if str(controller.state.encounter_session.get("phase", "")) == "post_battle":
		if not _leave(controller, "战后结算"):
			return "leave_blocked"
		return "ongoing"
	# 升仙窗：玩家终局抉择（需先击败 Boss，choice=now 是真实命令契约）。
	if node_type == "ascension":
		# 玩家策略（规格：可补足一个短板后冲仙）：先在窗口内筹备护道，
		# 再冲仙；结果从嵌套 result 里读取（attempt_ascension 的 ok/outcome）。
		var prepared: Dictionary = controller.submit_command({"type": "choose_action", "action_id": "prepare"})
		if bool(prepared.get("ok", false)):
			_tell("升仙窗口：护道筹备完成")
		var attempted: Dictionary = controller.submit_command({"type": "attempt_ascension", "choice": "now"})
		var nested: Dictionary = attempted.get("result", attempted) as Dictionary
		var outcome := str(nested.get("outcome", ""))
		if outcome.is_empty():
			outcome = str(nested.get("reason", "unknown"))
		_tell("尝试飞升：%s（条件 %s）" % [outcome, str(nested.get("conditions", {}))])
		if controller.current_view_name() == "Ending":
			_tell("已进入统一结算页 Ending")
			return "ending"
		_tell("飞升未成（%s），本次旅途结束" % outcome)
		return "retreat_end"
	# 总账：先结清养蛊开支（玩家必做项）。
	if node_type == "ledger":
		var settled: Dictionary = controller.submit_command({"type": "settle_feeding"})
		if not bool(settled.get("ok", false)):
			controller.submit_command({"type": "choose_action", "action_id": "accept_debt"})
		_tell("总账结清：元石=%d" % int(controller.state.stone))
		if not _leave(controller, "总账"):
			return "leave_blocked"
		return "ongoing"
	if node_type == "event":
		var choices: Array = node.get("choices", [])
		if not choices.is_empty():
			var taken: Dictionary = controller.submit_command({"type": "choose_action", "action_id": str(choices[0])})
			_tell("事件选项 %s: %s" % [str(choices[0]), "接受" if bool(taken.get("ok", false)) else "被拒(%s)" % str(taken.get("reason", ""))])
		if not _leave(controller, "事件"):
			return "leave_blocked"
		return "ongoing"
	# 其余节点（险地/传承/野蛊/地脉/闭关等）：按预览卡逐张处置后离场。
	return _step_via_cards(controller, "遭遇")


func _step_battle(controller) -> String:
	var battle: Dictionary = controller.current_battle
	var living_enemies := _living_enemies(battle)
	var enemy_hp := _total_enemy_hp(living_enemies)
	var node_id := str(controller.current_node.get("id", "battle"))
	if node_id != _stuck_battle_id:
		_stuck_battle_id = node_id
		_stuck_count = 0
		_stuck_enemy_hp = enemy_hp
	elif enemy_hp == _stuck_enemy_hp:
		_stuck_count += 1
	else:
		_stuck_count = 0
		_stuck_enemy_hp = enemy_hp
	var intent_damage := _incoming_damage(living_enemies)
	var player: Dictionary = battle.get("player", {})
	var hp := int(player.get("hp", 0))
	var max_hp := maxi(1, int(player.get("max_hp", 1)))
	var can_flee: bool = not BattleCommandFacadeScript.boss_blocks_retreat(battle)
	# V1 蛊行动制选牌：按 v1_effect 种类挑攻击/守护蛊（瞬发或常驻皆可）。
	var attack_gu := _pick_effect_gu(battle, ["strike"])
	var guard_gu := _pick_effect_gu(battle, ["shield", "buff"])
	var finish_now := enemy_hp <= 1
	var immediate_kill := finish_now and not attack_gu.is_empty()
	var guarded: bool = int(player.get("shield", 0)) > 0
	var command: Dictionary
	if immediate_kill:
		command = _play_gu_command(battle, attack_gu)
	elif can_flee and finish_now and attack_gu.is_empty():
		command = _battle_turn_command(controller, "retreat")
	elif can_flee and (hp <= 1 or intent_damage >= hp or intent_damage * 2 >= hp or _stuck_count >= 6):
		# P4（R-3 校准，仅测量口径）：危险意图预撤——下一击会打到半血以下
		# 就先撤，不等致死线；驱动器不许替游戏"送死"污染生存数据。
		command = _battle_turn_command(controller, "retreat")
	elif can_flee and hp * 10 < max_hp * 6:
		# P4（R-3 校准，仅测量口径）：止损线 40%→60%——"系统是否能完成目标"
		# 的验证不得因 driver 无谓送死而失真；不作为游戏生存率结论依据。
		command = _battle_turn_command(controller, "retreat")
	elif not can_flee:
		# Boss 死战节奏：攻击与守护交替，危险线守护优先，收头窗口搏命，
		# 僵局 4 步强制恢复进攻。
		var kill_window := enemy_hp <= 4
		var danger := hp <= intent_damage * 2
		var must_attack := (not attack_gu.is_empty()) and (not danger or kill_window or guarded or _stuck_count >= 4)
		if must_attack:
			command = _play_gu_command(battle, attack_gu)
		elif danger and not guarded and not guard_gu.is_empty():
			command = _play_gu_command(battle, guard_gu)
		elif not guard_gu.is_empty() and guard_gu != attack_gu:
			command = _play_gu_command(battle, guard_gu)
		else:
			command = _battle_turn_command(controller, "basic_attack")
	else:
		# 常规战：敌方大伤害先守护，否则攻击，无牌收势换回合。
		if intent_damage >= 2 and not guarded and not guard_gu.is_empty():
			command = _play_gu_command(battle, guard_gu)
		elif not attack_gu.is_empty():
			command = _play_gu_command(battle, attack_gu)
		else:
			command = _battle_turn_command(controller, "end_turn")
	var pre_hp := hp
	var result: Dictionary = controller.submit_command(command)
	if bool(result.get("finished", false)):
		_tell("战斗结束：%s（我方气血 %d/%d）" % [
			str(result.get("result", "unknown")),
			int(player.get("hp", 0)), max_hp,
		])
		# Reachability-4：opt-in hypothetical 测量，只在模拟开关开启时生效。
		_record_f1_opportunity_battle(controller, result)
		# Reachability-5：opt-in 只读 E6 tier audit，只在审计开关开启时生效。
		_e6_record_battle(controller, result)
		if str(result.get("result", "")) == "retreat":
			if not _leave(controller, "止损撤离"):
				return "leave_blocked"
			_tell("止损撤离，离开该节点")
		return "ongoing"
	# 拒绝回退：命令被拒不推进时依次回退 肉体搏斗 → 收势，避免原地空转。
	var live_battle: Dictionary = controller.current_battle
	var live_player: Dictionary = live_battle.get("player", {})
	if int(live_player.get("hp", 0)) == pre_hp and _stuck_count >= 1:
		var punch: Dictionary = controller.submit_command(_battle_turn_command(controller, "basic_attack"))
		if not bool(punch.get("finished", false)) and int(live_battle["player"].get("hp", 0)) == pre_hp:
			controller.submit_command(_battle_turn_command(controller, "end_turn"))
	return "ongoing"


func _pick_effect_gu(battle: Dictionary, kinds: Array) -> String:
	# V1：按 v1_effect 种类挑一张本回合可释放的战斗蛊（瞬发/常驻皆可）。
	var slots: Array = battle.get("gu_slots", [])
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if bool(slot.get("consumed", false)) or bool(slot.get("is_sealed", false)) or bool(slot.get("used_this_turn", false)):
			continue
		if str(slot.get("effect", {}).get("kind", "")) not in kinds:
			continue
		if V1BattleResolverScript.can_play_gu(battle, i) != "":
			continue
		return str(slot.get("instance_id", ""))
	return ""


func _play_gu_command(battle: Dictionary, instance_id: String) -> Dictionary:
	return {"type": "use_gu", "instance_id": instance_id}


func _battle_turn_command(controller, command_type: String) -> Dictionary:
	return {"type": command_type}


func _living_enemies(battle: Dictionary) -> Array[Dictionary]:
	var living: Array[Dictionary] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", int(enemy.get("hp", 0)) > 0)):
			living.append(enemy)
	return living


func _total_enemy_hp(enemies: Array[Dictionary]) -> int:
	var total := 0
	for enemy in enemies:
		total += maxi(0, int(enemy.get("hp", 0)))
	return total


func _incoming_damage(enemies: Array[Dictionary]) -> int:
	var total := 0
	for enemy in enemies:
		total += maxi(0, int((enemy.get("intent", {}) as Dictionary).get("damage", 0)))
	return total


func _tell(text: String) -> void:
	_log.append(text)
	print("[play] %s" % text)


# =====================================================================
# crash 模式：进程级崩溃恢复三阶段（原 crash_recovery_driver）
# =====================================================================
#
# 由 env CRASH_PHASE 选择阶段，每个阶段一个 Godot 进程；外部编排器
# tools/crash_recovery_check.ps1 负责硬杀、重启与玩家存档备份恢复。
#
#   run    — boot the real controller, play via official commands, save_run
#            after every step and append a marker log; the orchestrator
#            hard-kills this process at an arbitrary point.
#   verify — a fresh process must resume the run from the last durable
#            save: checksum valid, state matches one recorded checkpoint,
#            non-terminal, and the run can still travel + save.
#   tamper — a corrupted save must be rejected by the checksum, a leftover
#            .tmp file must be ignored, and the original save must load
#            again afterwards.

func _run_crash() -> void:
	_ensure_domains()
	var phase := OS.get_environment("CRASH_PHASE")
	print("CRASH phase=%s pid=%d" % [phase, OS.get_process_id()])
	match phase:
		"run":
			_phase_run()
		"verify":
			_phase_verify()
		"tamper":
			_phase_tamper()
		_:
			printerr("CRASH unknown phase")
			quit(2)


func _marker_log() -> Array:
	var entries: Array = []
	if FileAccess.file_exists(MARKER_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARKER_PATH))
		if parsed is Array:
			entries = parsed
	return entries


func _write_marker_log(entries: Array) -> void:
	var file := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(entries))
	file.flush()
	file.close()


func _new_controller():
	var controller = RunControllerScript.new()
	controller.catalog = ContentCatalog.load_all()
	return controller


## Phase run: play + save in a loop until the orchestrator kills us.
func _phase_run() -> void:
	var controller = _new_controller()
	controller.start_new_run(777, "", [])
	print("CRASH started node=%s" % controller.state.current_node_id)
	var save_budget := maxi(1, int(OS.get_environment("CRASH_SAVE_BUDGET")))
	var iterations := 0
	var saves := 0
	while iterations < 100000:
		iterations += 1
		# 会话内不能直接行军：遭遇节点先离场回地图（真实游玩顺序）。
		if controller.current_view_name() != "Map":
			controller.submit_command({"type": "leave_node"})
		var saved: Dictionary = controller.submit_command({"type": "save_run"})
		if not bool(saved.get("ok", false)):
			printerr("CRASH save failed")
			quit(3)
			return
		# Marker AFTER the save: the durable save may be one step ahead of
		# the marker, never behind it.
		var entries := _marker_log()
		entries.append({
			"node_id": str(controller.state.current_node_id),
			"events": int(controller.state.event_log.size()),
			"iteration": iterations,
		})
		_write_marker_log(entries)
		saves += 1
		print("CRASH save #%d node=%s events=%d" % [
			saves, controller.state.current_node_id, int(controller.state.event_log.size())])
		if saves >= save_budget:
			# 预算已满：空转等待编排器硬杀——存档点已固化，击杀落在何处
			# 不再影响「最后一次原子存档必须可恢复」的被验性质。
			while true:
				OS.delay_msec(200)
		var moved := false
		for node_value in controller.visible_route_nodes(2):
			var node: Dictionary = node_value
			var node_id := str(node.get("id", ""))
			if _is_verification_dead_end(node):
				continue
			if controller.state.node_flags.has(node_id):
				continue
			var travel: Dictionary = controller.submit_command({"type": "travel", "node_id": node_id})
			if bool(travel.get("ok", false)):
				moved = true
				break
		if not moved:
			# Route exhausted: keep saving (kill target stays valid).
			pass
	print("CRASH iteration budget exhausted")
	quit(0)


## Phase verify: a fresh process resumes the run.
func _phase_verify() -> void:
	var controller = _new_controller()
	var loaded = controller.load_saved_run()
	if not loaded:
		printerr("CRASH verify FAILED: load_saved_run returned false")
		quit(1)
		return
	var state = controller.state
	var events := int(state.event_log.size())
	var node_id := str(state.current_node_id)
	print("CRASH resumed node=%s events=%d" % [node_id, events])
	if state.is_terminal():
		printerr("CRASH verify FAILED: resumed state is terminal")
		quit(1)
		return
	# The durable save must be one of the recorded checkpoints (the kill may
	# have landed mid-write, in which case the previous checkpoint is kept).
	var matched := false
	for entry in _marker_log():
		var checkpoint: Dictionary = entry
		if str(checkpoint.get("node_id", "")) == node_id and int(checkpoint.get("events", -1)) == events:
			matched = true
			break
	if not matched:
		printerr("CRASH verify FAILED: resumed state matches no recorded checkpoint (node=%s events=%d)" % [node_id, events])
		quit(1)
		return
	# The run must still be playable: travel somewhere and save again.
	if controller.current_view_name() != "Map":
		controller.submit_command({"type": "leave_node"})
	var traveled := false
	for node_value in controller.visible_route_nodes(2):
		var node2: Dictionary = node_value
		var node_id2 := str(node2.get("id", ""))
		if _is_verification_dead_end(node2):
			continue
		if controller.state.node_flags.has(node_id2):
			continue
		var travel: Dictionary = controller.submit_command({"type": "travel", "node_id": node_id2})
		if bool(travel.get("ok", false)):
			traveled = true
			break
	if not traveled and _has_open_destination(controller):
		printerr("CRASH verify FAILED: reachable unvisited node exists but travel failed")
		quit(1)
		return
	# 五层拓扑的终局（只剩 Boss 台可走）允许无路可走——存档能力即充分证据。
	var saved: Dictionary = controller.submit_command({"type": "save_run"})
	if not bool(saved.get("ok", false)):
		printerr("CRASH verify FAILED: post-crash save_run rejected")
		quit(1)
		return
	print("CRASH verify PASS")
	quit(0)


## Phase tamper: checksum rejection + tmp tolerance + clean restore.
func _phase_tamper() -> void:
	var controller = _new_controller()
	controller.start_new_run(778, "", [])
	controller.submit_command({"type": "travel", "node_id": _first_destination(controller)})
	var saved: Dictionary = controller.submit_command({"type": "save_run"})
	if not bool(saved.get("ok", false)):
		printerr("CRASH tamper FAILED: baseline save_run rejected")
		quit(1)
		return
	var raw := FileAccess.get_file_as_string(SaveRepositoryScript.SAVE_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		printerr("CRASH tamper FAILED: save file is not valid JSON")
		quit(1)
		return
	# 1. Tamper with gameplay data, keep the JSON valid: checksum must reject.
	var tampered: Dictionary = parsed
	var state_data: Dictionary = tampered["state"]
	state_data["stone"] = int(state_data.get("stone", 0)) + 999
	var file := FileAccess.open(SaveRepositoryScript.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(tampered))
	file.flush()
	file.close()
	var tamper_controller = _new_controller()
	if tamper_controller.load_saved_run():
		printerr("CRASH tamper FAILED: tampered save was accepted")
		quit(1)
		return
	print("CRASH tampered save rejected")
	# 2. Leftover .tmp (crash during a save write) must be ignored.
	var tmp := FileAccess.open(SaveRepositoryScript.TEMP_PATH, FileAccess.WRITE)
	tmp.store_string("{ this is not json")
	tmp.flush()
	tmp.close()
	var tmp_controller = _new_controller()
	controller.start_new_run(779, "", [])
	controller.submit_command({"type": "travel", "node_id": _first_destination(controller)})
	controller.submit_command({"type": "save_run"})
	if not tmp_controller.load_saved_run():
		printerr("CRASH tamper FAILED: leftover tmp file broke loading")
		quit(1)
		return
	print("CRASH leftover tmp ignored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveRepositoryScript.TEMP_PATH))
	print("CRASH tamper PASS")
	quit(0)


## 游走回路避开关底 Boss 台与升仙窗：Boss 未败时它们是终点站，
## 进去之后「无路可走」是正确游戏行为，不是恢复缺陷。
func _has_open_destination(controller) -> bool:
	for node_value in controller.visible_route_nodes(2):
		var node: Dictionary = node_value
		if _is_verification_dead_end(node):
			continue
		if not controller.state.node_flags.has(str(node.get("id", ""))):
			return true
	return false


func _is_verification_dead_end(node: Dictionary) -> bool:
	if str(node.get("id", "")) == "ascension_window":
		return true
	return int(node.get("layer_boss", 0)) > 0


func _first_destination(controller) -> String:
	for node_value in controller.visible_route_nodes(2):
		var node_id := str((node_value as Dictionary).get("id", ""))
		if not controller.state.node_flags.has(node_id):
			return node_id
	return ""
