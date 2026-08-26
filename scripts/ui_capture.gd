extends SceneTree

# GUI 实跑截图：真实渲染器（非 headless）下逐屏挂载 RUI 屏组件，等布局帧后保存 PNG。
# 分辨率：1920x1080（16:9）。用离屏 SubViewport 精确控制输出尺寸，不受 Windows DPI 缩放影响。
# 用法：& <godot_gui.exe> --path . -s res://scripts/ui_capture.gd
# 输出：.superpowers/ui_captures/*.png（不污染仓库，.superpowers 已忽略）

const Guitkx = preload("res://addons/reactive_ui_toolkit/guitkx/guitkx.gd")
const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const ROOT := "res://"
const OUT_DIR := "C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/.superpowers/ui_captures"

const SHOT_W := 1920
const SHOT_H := 1080

const WIDGET_DIR := "res://ui/widgets"
const SCREEN_DIR := "res://ui/screens"

var _cur := 0

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


func _snap(component: String, props: Dictionary) -> void:
	var fn = VLib.comp("res://ui/screens/%s.gd" % component, "render")
	if not (fn is Callable):
		push_error("无组件 %s" % component)
		return
	# 离屏 SubViewport：固定 1920x1080，精确控制输出，不受窗口/DPI 影响
	var svp := SubViewport.new()
	svp.size = Vector2i(SHOT_W, SHOT_H)
	svp.transparent_bg = false
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(svp)
	# 墨青夜色全屏底
	var bg := ColorRect.new()
	bg.color = Color("0b0f14")
	bg.size = Vector2(SHOT_W, SHOT_H)
	svp.add_child(bg)
	# PanelContainer 强制唯一子（RUI 根）填满画幅，避免内容按最小尺寸收缩在左上角
	var inner := PanelContainer.new()
	inner.size = Vector2(SHOT_W, SHOT_H)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svp.add_child(inner)
	RuiRoot.create(inner, VLib.fc(fn, props))
	# 等逻辑帧确保 RUI 完成挂载与布局，再强制同步渲染一帧（不依赖窗口可见性，不会挂死）
	for i in range(6):
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var img := svp.get_texture().get_image()
	_cur += 1
	var p := OUT_DIR.path_join("%02d_%s.png" % [_cur, component])
	img.save_png(p)
	print("SNAP %s -> %s" % [component, p])
	svp.queue_free()
	await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	if not _compile_file("res://ui/_sample.guitkx"):
		quit(1)
	if not _compile_dir(WIDGET_DIR):
		quit(1)
	if not _compile_dir(SCREEN_DIR):
		quit(1)

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
	await _snap("hall_view", {"state": hall_state, "commands": hall_cmds})

	# ---- 地图 ----
	var map_cmds := {"travel": func(_id): pass, "view_node": func(_id): pass}
	var map_state := {
		"nodes": [
			{"id": "n1", "type": "start", "label": "起始", "layer": 0},
			{"id": "n2", "type": "combat", "label": "野蛊盘踞", "layer": 1},
			{"id": "n3", "type": "event", "label": "残碑异响", "layer": 1},
			{"id": "n4", "type": "rest", "label": "山涧静修", "layer": 2},
			{"id": "n5", "type": "shop", "label": "黑市", "layer": 2},
			{"id": "n6", "type": "combat", "label": "铁皮山猪", "layer": 3},
			{"id": "n7", "type": "boss", "label": "雷冠头狼", "layer": 4},
		],
		"current_node_id": "n1",
		"reachable_ids": ["n2", "n3"],
		"gu_satchel": [{"id": "g1", "name": "血牙蛊"}, {"id": "g2", "name": "噬血蛊"}],
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}},
	}
	await _snap("map_screen", {"state": map_state, "commands": map_cmds})

	# ---- 战斗三区 ----
	var battle_cmds := {
		"play_card": func(_c, _t): pass, "end_turn": func(): pass,
		"ultimate": func(): pass, "refine": func(): pass, "flee": func(): pass,
	}
	var battle_state := {
		"enemies": [
			{"id": "e1", "name": "铁皮山猪", "hp": 20, "max_hp": 30, "shield": 4, "intent": {"type": "attack", "value": 12, "detail": "造成物理伤害"}},
			{"id": "e2", "name": "雷冠头狼", "hp": 15, "max_hp": 15, "shield": 0, "intent": {"type": "charge", "value": 0, "detail": "蓄力"}},
		],
		"player": {"hp": 24, "max_hp": 30, "shield": 6, "primordial": 3, "soul": 4, "statuses": [{"name": "灼烧", "stacks": 2}]},
		"hand": [
			{"id": "c1", "name": "血牙蛊", "cost": 1, "effect": "造成 6 伤害", "quality": "普通", "curse_warning": false},
			{"id": "c2", "name": "噬血蛊", "cost": 2, "effect": "造成 4 伤害并吸血 3", "quality": "稀有", "curse_warning": false},
			{"id": "c3", "name": "血祭蛊", "cost": 2, "cost_ex": "消耗3寿元", "effect": "对自身反噬 1 层，造成 18 伤害", "quality": "稀有", "curse_warning": true},
		],
		"can_ultimate": true,
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}, "hunpo": {"value": 4, "threshold": 4}, "backlash": {"value": 2, "threshold": 3}},
	}
	await _snap("battle_screen", {"state": battle_state, "commands": battle_cmds})

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
	await _snap("encounter_screen", {"state": enc_state, "commands": enc_cmds})

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
	await _snap("ending_screen", {"state": ending_state, "commands": ending_cmds})

	# ---- 黑市（C3）----
	var gui_state := {
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}},
	}
	var shop_cmds := {"buy": func(_id): pass, "block": func(_id): pass, "use_service": func(_id): pass, "leave": func(): pass}
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
			{"id": "s1", "name": "刷新货架", "cost": "120 元石", "remaining": 2, "note": "本局剩余 2 次 · 通胀叠加"},
			{"id": "s2", "name": "移除蛊虫", "cost": "150 元石", "remaining": 2, "note": "本局剩余 2 次 · 价格递增"},
			{"id": "s3", "name": "池屏蔽", "cost": "200 元石", "remaining": 1, "note": "本局剩余 1 次 · 移除≠池排除"},
			{"id": "s4", "name": "洗炼", "cost": "80 元石", "remaining": 3, "note": "重骰一条被动"},
			{"id": "s5", "name": "净化躁动", "cost": "40 元石", "remaining": 3, "note": "清除蛊躁动"},
			{"id": "s6", "name": "魂丹", "cost": "6 元石", "remaining": 1, "note": "魂魄 +1"},
		],
		"emergency_note": "元石不足可用气血 / 寿元 / 反噬 / 销毁组件应急支付（R6.7）",
	})
	await _snap("shop_screen", {"state": shop_state, "commands": shop_cmds})

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
	await _snap("rest_screen", {"state": rest_state, "commands": rest_cmds})

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
	await _snap("refine_screen", {"state": refine_state, "commands": refine_cmds})

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
	await _snap("reward_screen", {"state": reward_state, "commands": reward_cmds})

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
	await _snap("npc_screen", {"state": npc_state, "commands": npc_cmds})

	print("ALL SNAPS DONE")
	quit()
