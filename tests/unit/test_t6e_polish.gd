extends GutTest


# T6-E 打磨批：跨屏一次性淡入 / tooltip 宣纸一致性 / 危险蛊强红角标 / 空池回退小字。
# 锁定：
#   - §3.4 动效预算：仅屏切换时对新挂载根 140ms 一次性淡入（同屏重渲染不闪屏）；
#     快速连切先杀旧 Tween；播完自然失效，无常驻循环动画
#   - §9/§16.5 tooltip 固定五段顺序恒定、缺段隐藏；PAPER 卷轴底 + INK 深字；
#     DANGER 仅保留给诅咒警示行
#   - R4.10 危险蛊：DANGER 描边 + 「咒」角标（DANGER 底 BONE 字）；封印态暗淡 + 「锁」标
#   - 空池回退小字：快照诚实默认（无领域标记不得常驻假提示）；奖励/商店屏
#     显示槽位接好（13px BONE_DIM），有标记才渲染


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const SnapshotBuilder = preload("res://scripts/presentation/run_snapshot_builder.gd")

var _rui_roots: Array = []
var _rui_hosts: Array = []


func _new_controller() -> RunController:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(101)
	return controller


func after_each() -> void:
	for r in _rui_roots:
		if r != null and r.has_method("unmount"):
			r.unmount()
	_rui_roots.clear()
	for h in _rui_hosts:
		if h != null and is_instance_valid(h):
			h.free()
	_rui_hosts.clear()


func _mount_screen(screen_path: String, props: Dictionary) -> Control:
	var fn = VLib.comp(screen_path, "render")
	assert_true(fn is Callable, screen_path + " must expose render")
	if not (fn is Callable):
		return Control.new()
	var host := Control.new()
	add_child(host)
	_rui_hosts.append(host)
	_rui_roots.append(RuiRoot.create(host, VLib.fc(fn, props)))
	return host


func _collect_labels(node: Node, out_labels: Array) -> void:
	if node is Label:
		out_labels.append(node)
	for c in node.get_children():
		_collect_labels(c, out_labels)


func _first_panel(node: Node) -> PanelContainer:
	if node is PanelContainer:
		return node
	for c in node.get_children():
		var found := _first_panel(c)
		if found != null:
			return found
	return null


func _find_label_exact(node: Node, wanted: String) -> Label:
	if node is Label and str(node.text) == wanted:
		return node
	for c in node.get_children():
		var found := _find_label_exact(c, wanted)
		if found != null:
			return found
	return null


func _nearest_panel_ancestor(node: Node) -> PanelContainer:
	var cur := node.get_parent()
	while cur != null:
		if cur is PanelContainer:
			return cur
		cur = cur.get_parent()
	return null


func _label_index(labels: Array, prefix: String) -> int:
	for i in labels.size():
		if str((labels[i] as Label).text).begins_with(prefix):
			return i
	return -1


func _gui_base_state() -> Dictionary:
	return {
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
	}


# ---- 1. tooltip 宣纸卷轴底 + 五段固定顺序 ----

func test_tooltip_paper_bg_ink_text_and_fixed_segment_order() -> void:
	var host := _mount_screen("res://ui/widgets/gu_tooltip_view.gd", {
		"title": "血祭蛊",
		"quality": "稀有",
		"effect": "吸取气血",
		"synergy": "与血道蛊联动增强",
		"cost": "消耗 3 寿元",
		"curse_warning": true,
	})
	var panel := _first_panel(host)
	assert_true(panel != null, "tooltip root must be a PanelContainer")
	if panel == null:
		return
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(sb != null and sb.bg_color.is_equal_approx(GuStyle.PAPER),
			"tooltip background must be PAPER scroll tone, not the old dark panel")
	var labels: Array = []
	_collect_labels(panel, labels)
	var idx_effect := _label_index(labels, "效果：")
	var idx_synergy := _label_index(labels, "联动：")
	var idx_cost := _label_index(labels, "代价：")
	var idx_curse := _label_index(labels, "诅咒警示：")
	assert_gt(idx_effect, -1, "effect segment present")
	assert_gt(idx_synergy, idx_effect, "synergy follows effect (fixed order)")
	assert_gt(idx_cost, idx_synergy, "cost follows synergy (fixed order)")
	assert_gt(idx_curse, idx_cost, "curse warning is the last segment")
	var effect_label: Label = labels[idx_effect]
	assert_true(effect_label.get_theme_color("font_color").is_equal_approx(GuStyle.INK),
			"body text must switch to deep ink on paper")
	var curse_label: Label = labels[idx_curse]
	assert_true(curse_label.get_theme_color("font_color").is_equal_approx(GuStyle.DANGER),
			"DANGER stays reserved for the curse warning line")


func test_tooltip_hides_empty_segments_but_keeps_order_slots() -> void:
	var host := _mount_screen("res://ui/widgets/gu_tooltip_view.gd", {
		"title": "月光蛊",
		"effect": "造成月光伤害",
	})
	var labels: Array = []
	_collect_labels(host, labels)
	assert_true(_label_index(labels, "效果：") > -1, "provided segment renders")
	assert_eq(_label_index(labels, "联动："), -1, "empty synergy hides its segment")
	assert_eq(_label_index(labels, "代价："), -1, "empty cost hides its segment")
	assert_eq(_label_index(labels, "诅咒警示："), -1, "non-curse cards hide the warning")


# ---- 2. 危险蛊强红角标 / 封印锁态 ----

func test_gu_card_danger_curse_badge_uses_danger_bg_bone_glyph() -> void:
	var host := _mount_screen("res://ui/widgets/gu_card.gd", {"title": "血祭蛊", "curse_warning": true})
	var glyph := _find_label_exact(host, "咒")
	assert_true(glyph != null, "danger card must carry the 咒 corner badge")
	if glyph == null:
		return
	assert_true(glyph.get_theme_color("font_color").is_equal_approx(GuStyle.BONE),
			"badge glyph must be BONE on the danger fill")
	var chip := _nearest_panel_ancestor(glyph)
	assert_true(chip != null, "badge must be a filled chip, not a bare colored label")
	if chip != null:
		var sb := chip.get_theme_stylebox("panel") as StyleBoxFlat
		assert_true(sb != null and sb.bg_color.is_equal_approx(GuStyle.DANGER),
				"badge fill must be strong DANGER red")
	var outer := _first_panel(host)
	assert_true(outer != null)
	if outer != null:
		var osb := outer.get_theme_stylebox("panel") as StyleBoxFlat
		assert_true(osb != null and osb.border_width_left == 2,
				"danger cards keep the thick border treatment")
		assert_true(osb.border_color.is_equal_approx(GuStyle.DANGER),
				"danger border color must be DANGER")


func test_gu_card_sealed_state_keeps_lock_glyph_and_dimming() -> void:
	var host := _mount_screen("res://ui/widgets/gu_card.gd", {"title": "石甲蛊", "sealed": true})
	assert_true(_find_label_exact(host, "锁") != null, "sealed card keeps the 锁 marker")
	var outer := _first_panel(host)
	assert_true(outer != null)
	if outer != null:
		assert_almost_eq(outer.modulate.a, 0.55, 0.02, "sealed card stays dimmed")


# ---- 3. 空池回退小字 ----

func test_reward_screen_renders_fallback_smallprint_only_when_marked() -> void:
	var cmds := {"take": func(_idx = 0): pass, "replace_and_take": func(_idx = 0): pass,
		"skip": func(): pass, "close": func(): pass}
	var with_rewards := _gui_base_state()
	with_rewards["title"] = "战利品"
	with_rewards["rewards"] = [{"id": "r1", "name": "月光蛊", "kind": "蛊", "quality": "稀有",
		"effect": "月光伤害", "cost": "", "curse_warning": false}]
	with_rewards["full_satchel"] = false
	with_rewards["pity_note"] = "（保底暗示）"
	var clean_host := _mount_screen("res://ui/screens/reward_screen.gd", {"state": with_rewards, "commands": cmds})
	assert_false(_host_or_descendant_has_text(clean_host, "已切换至基础池"),
			"no fake fallback note when nothing fell back")

	var flagged := with_rewards.duplicate(true)
	flagged["rewards"] = []
	flagged["pool_fallback_note"] = "（空池回退：已切至基础池）"
	var marked_host := _mount_screen("res://ui/screens/reward_screen.gd", {"state": flagged, "commands": cmds})
	var note := _find_label_exact(marked_host, "（空池回退：已切至基础池）")
	assert_true(note != null, "marked fallback renders the small-print slot")
	if note != null:
		assert_true(note.get_theme_font_size("font_size") == 13, "fallback small print is 13px")
		assert_true(note.get_theme_color("font_color").is_equal_approx(GuStyle.BONE_DIM),
				"fallback small print uses BONE_DIM")


func test_shop_screen_carries_conditional_fallback_slot() -> void:
	var cmds := {"buy": func(_oid = ""): pass, "block": func(_oid = ""): pass,
		"use_service": func(_sid = ""): pass, "leave": func(): pass}
	var plain := _gui_base_state()
	plain["offers"] = []
	plain["services"] = []
	var plain_host := _mount_screen("res://ui/screens/shop_screen.gd", {"state": plain, "commands": cmds})
	assert_false(_host_or_descendant_has_text(plain_host, "已切换至基础池"),
			"shop hides the fallback slot when unmarked")

	var flagged := plain.duplicate(true)
	flagged["pool_fallback_note"] = "（空池回退：已切至基础池）"
	var marked_host := _mount_screen("res://ui/screens/shop_screen.gd", {"state": flagged, "commands": cmds})
	var note := _find_label_exact(marked_host, "（空池回退：已切至基础池）")
	assert_true(note != null, "shop renders the fallback small print when marked")
	if note != null:
		assert_true(note.get_theme_font_size("font_size") == 13, "shop fallback small print is 13px")


func test_snapshot_defaults_are_honest_about_fallback() -> void:
	var controller := _new_controller()
	var reward_snap: Dictionary = SnapshotBuilder.reward(controller)
	assert_eq(str(reward_snap.get("pool_fallback_note")), "",
			"builder must not ship an always-on fake fallback note")
	assert_ne(str(reward_snap.get("pity_note")), "", "pity hint stays as the existing nudge")
	assert_eq(SnapshotBuilder._reward_fallback_note([]), "（空池回退：已切至基础池）",
			"empty reward list is the sanctioned proxy signal")
	assert_eq(SnapshotBuilder._reward_fallback_note([{"id": "r1"}]), "")
	var shop_snap: Dictionary = SnapshotBuilder.shop(controller)
	assert_true(shop_snap.has("pool_fallback_note"), "shop snapshot carries the display slot")
	assert_eq(str(shop_snap["pool_fallback_note"]), "", "shop slot starts empty (no domain marker yet)")


func _host_or_descendant_has_text(node: Node, wanted: String) -> bool:
	var labels: Array = []
	_collect_labels(node, labels)
	for l in labels:
		if str((l as Label).text).contains(wanted):
			return true
	return false


# ---- 2b. 遭遇行动 tooltip 代价段（§16.5 缺段隐藏 + 数值写死） ----

func test_encounter_cost_note_formats_numbers_and_hides_when_empty() -> void:
	var priced := SnapshotBuilder._enc_action({"id": "a", "title": "强夺", "summary": "夺取宝物", "cost": {"stone": 5, "time": 1}})
	assert_eq(str(priced["cost"]), "元石 ×5 · 时辰 ×1",
			"dict cost must format into fixed-number readable text")
	var gu_cost := SnapshotBuilder._enc_action({"id": "a", "title": "献祭", "summary": "耗蛊炼化", "cost": {"gu_ids": ["moonlight_gu"]}})
	assert_true(str(gu_cost["cost"]).begins_with("耗蛊："),
			"gu_ids cost must list consumed gu names")
	var free := SnapshotBuilder._enc_action({"id": "a", "title": "探查", "summary": "查看四周", "cost": {}})
	assert_eq(str(free["cost"]), "", "empty cost must hide its tooltip segment")


func test_encounter_screen_feeds_formatted_cost_and_hides_empty() -> void:
	var cmds := {"choose_option": func(_aid = ""): pass, "confirm_danger": func(_aid = ""): pass,
		"leave": func(): pass}
	var st := _gui_base_state()
	st["node"] = {"title": "幽林遭遇", "desc": "林中异响。", "type": "contact"}
	st["actions"] = [{"id": "a1", "label": "强夺", "detail": "危险行动。", "dangerous": true,
		"quality": "", "effect": "夺取宝物", "synergy": "", "cost": "寿元 ×5", "curse_warning": true}]
	var host := _mount_screen("res://ui/screens/encounter_screen.gd", {"state": st, "commands": cmds})
	assert_true(_find_label_exact(host, "代价：寿元 ×5") != null,
			"formatted cost string feeds the cost segment verbatim")
	var plain := st.duplicate(true)
	plain["actions"] = [{"id": "a1", "label": "探查", "detail": "", "dangerous": false,
		"quality": "", "effect": "查看四周", "synergy": "", "cost": "", "curse_warning": false}]
	var clean_host := _mount_screen("res://ui/screens/encounter_screen.gd", {"state": plain, "commands": cmds})
	assert_true(_find_label_exact(clean_host, "代价：") == null,
			"empty cost hides its segment (never renders raw dict junk)")


func test_shop_cursed_offer_renders_strong_red_badge() -> void:
	var cmds := {"buy": func(_oid = ""): pass, "block": func(_oid = ""): pass,
		"use_service": func(_sid = ""): pass, "leave": func(): pass}
	var st := _gui_base_state()
	st["title"] = "黑市 · 寨市"
	st["npc_name"] = "地脉游商"
	st["npc_stance"] = "中立"
	st["inflation_note"] = ""
	st["emergency_note"] = ""
	st["offers"] = [{"id": "o1", "name": "血祭蛊", "kind": "lifespan_deal", "price": "10 寿元",
		"desc": "以寿元代付", "quality": "普通", "curse_warning": true, "will_emergency_pay": false}]
	st["services"] = []
	var host := _mount_screen("res://ui/screens/shop_screen.gd", {"state": st, "commands": cmds})
	assert_true(_find_label_exact(host, "咒") != null,
			"cursed shop offer must render the 咒 badge through GuCard")


# ---- 4. 跨屏一次性淡入（仅屏切换；同屏重渲染不闪屏） ----

func test_screen_fade_runs_on_view_switch_only_and_completes() -> void:
	var controller := _new_controller()
	var host: Control = controller._rui_host
	assert_true(host != null, "controller mounts its RUI host")
	if host == null:
		return
	var first_tween = controller._screen_tween
	assert_true(first_tween != null, "initial mount starts a fade tween")
	assert_almost_eq(host.modulate.a, 0.0, 0.001, "freshly mounted root starts transparent")
	await get_tree().create_timer(0.04).timeout
	controller._render()
	assert_true(first_tween.is_valid(), "same-view re-render must not kill the running fade")
	assert_true(controller._screen_tween == first_tween, "same-view re-render must not start a new fade")
	controller._show_title()
	assert_false(first_tween.is_valid(), "a real screen switch kills the previous fade")
	assert_true(controller._screen_tween != first_tween, "switch starts a fresh fade tween")
	assert_almost_eq(host.modulate.a, 0.0, 0.001, "switch restarts from transparent")
	await get_tree().create_timer(0.3).timeout
	assert_almost_eq(host.modulate.a, 1.0, 0.001, "one-shot fade completes fully")
	assert_false(controller._screen_tween.is_valid(), "finished tween releases (no lingering animation)")


func test_reward_cursed_reward_feeds_strong_red_badge() -> void:
	var cmds := {"take": func(_idx = 0): pass, "replace_and_take": func(_idx = 0): pass,
		"skip": func(): pass, "close": func(): pass}
	var st := _gui_base_state()
	st["title"] = "战利品"
	st["rewards"] = [{"id": "r1", "name": "血祭蛊", "kind": "蛊", "quality": "稀有",
		"effect": "吸取气血", "cost": "每次使用反噬 +1", "curse_warning": true}]
	st["full_satchel"] = false
	st["pity_note"] = ""
	var host := _mount_screen("res://ui/screens/reward_screen.gd", {"state": st, "commands": cmds})
	assert_true(_find_label_exact(host, "咒") != null,
			"cursed reward must render the 咒 badge through GuCard")
