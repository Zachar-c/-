class_name DisplayText
extends RefCounted


# Task 5 removal wording (R4.3): deleting a card from the satchel must never be
# confused with pool exclusion, which is a future feature and not implemented.
const REMOVAL_LABEL := "移除（从蛊囊删除这只）"
const POOL_EXCLUSION_LABEL := "池排除（本局不再刷出，尚未实装）"


const NODES := {
	"neutral_wanderer": "中立散修",
	"ridge_caravan": "山脊商队",
	"refinement_hollow": "炼蛊石穴",
	"cultivation_spring": "修行山泉",
	"stage_one_ledger": "第一阶段养蛊总账",
	"toxic_mountain_path": "毒瘴山道",
	"flooded_cave": "积水石窟",
	"black_mud_marsh": "黑泥沼地",
	"moonlit_trail": "月下小径",
	"blood_moss_grove": "血苔林",
	"mist_shrine": "雾隐祠",
	"village_short_work": "山村短工",
	"ridge_market": "山脊市集",
	"caravan_missing_goods": "商队失货",
	"herbalist_commission": "药师委托",
	"beast_swarm_pass": "兽群隘口",
	"greedy_wanderer": "贪客拦路",
	"faction_guard_checkpoint": "势力关卡",
	"earth_vein_contest": "地脉之争",
	"sealed_earth_vein": "封存地脉",
	"poison_fog_vein": "毒雾地脉",
	"body_imprint_ritual": "体印仪式",
	"ridge_black_market": "山脊黑市",
	"echo_cave": "回声石洞",
	"ascension_window": "升仙之机",
}

const TYPES := {
	"contact": "接触",
	"refinement": "炼蛊",
	"cultivation": "修行",
	"ledger": "总账",
	"hazard": "险地",
	"inheritance": "传承",
	"wild_gu": "野蛊",
	"market": "市集",
	"caravan": "商队",
	"commission": "委托",
	"combat": "交锋",
	"pursuit": "追击",
	"earth_vein": "地脉",
	"seclusion": "静修",
	"shop": "黑市",
	"event": "异象",
	"ascension": "升仙",
}

const ACTIONS := {
	"accept": "接取",
	"ally": "结盟",
	"attempt_ascension": "冲击升仙",
	"buy_information": "购买情报",
	"buy": "买蛊",
	"claim": "占取",
	"cross": "穿越",
	"deceive": "欺瞒",
	"fight": "交锋",
	"harvest": "采集",
	"inspect": "查验",
	"leave": "离开",
	"lure": "诱引",
	"meditate": "静修",
	"open": "开启",
	"prepare": "筹备",
	"pressure": "施压",
	"probe": "试探",
	"retreat": "撤离",
	"refine": "炼蛊",
	"cultivate": "冲击二转",
	"settle_feeding": "结清养护",
	"accept_debt": "欠下人情",
	"scout": "探查",
	"scheme": "设局",
	"take_imprint": "承受体印",
	"trade": "交易",
	"withdraw": "退回",
	"work": "做工",
}

const GU := {
	"small_light_gu": "小光蛊",
	"trail_eye_gu": "寻迹眼蛊",
	"blood_moss_gu": "血苔蛊",
	"thorn_whip_gu": "棘鞭蛊",
	"mist_step_gu": "雾步蛊",
	"venom_thread_gu": "毒丝蛊",
	"stone_shell_gu": "石甲蛊",
	"shadow_veil_gu": "影幕蛊",
	"pulse_drum_gu": "脉冲鼓蛊",
	"moonlight_gu": "月光蛊",
	"moon_glow_gu": "月华蛊",
	"phantom_moon_gu": "幻月蛊",
	"moon_shadow_gu": "月影蛊",
	"blood_droplet_gu": "血滴子蛊",
	"blood_bat_gu": "幽血蝙蝠蛊",
	"blood_wing_gu": "血翼蛊",
	"blood_farewell_gu": "爱别离蛊",
	"force_gu": "力量蛊",
	"bear_strength_gu": "熊力蛊",
	"qi_wall_gu": "气墙蛊",
}

const INHERITANCES := {
	"moonlit_trace": "月下寻迹",
	"bloodwood_reversal": "血木回生",
	"venomous_mist_escape": "毒雾遁行",
}

const ENEMIES := {
	"beast_swarm": "兽群",
	"greedy_wanderer": "贪婪散修",
	"faction_guard": "势力守卫",
	"resolute_elite": "悍勇强敌",
	"neutral_stone_wanderer": "石甲散修",
	"ridge_hound": "山脊猎犬",
	"ridge_elite_scout": "山脊悍客",
	"miasma_vein_lord": "瘴脉蛊主",
}

const FACTS := {
	"ledger_evidence": "账册证据",
	"earth_vein_entry": "地脉入口",
	"caravan_suspicion": "商队疑心",
	"caravan_reinforcements_arrived": "商队援手已至",
	"iron_bone_defense": "铁骨护身",
	"iron_bone_stealth_drawback": "铁骨难以藏形",
	"ice_skin_cold_resistance": "冰肤耐寒",
	"ice_skin_cold_injury": "冰寒损身",
	"three_watch_vigilance": "三更警觉",
	"heaven_earth_qi_unsecured": "天地二气未备",
	"bought_gu": "购得蛊虫的机会",
	"bought_information": "购得情报",
	"bought_service": "购得服务",
	"bought_favor": "换得人情",
	"bought_escape_condition": "取得脱身条件",
	"commission_accepted": "接下药师委托",
	"temporary_ally": "得到临时援手",
	"claimed_opportunity": "占得一线机缘",
	"site_clue": "掌握地势线索",
	"route_left_behind": "放弃此处路线",
	"lured_threat": "引开了眼前威胁",
	"route_scouted": "探明前方路径",
	"withdrawn_safely": "暂时全身而退",
}

const REACTIONS := {
	"caution": "对方保持谨慎。",
	"contempt": "对方流露轻慢。",
	"sympathy": "对方显出怜悯。",
	"exploit": "对方试图趁伤压价。",
	"examining": "对方正在核验你的说辞。",
	"guarded": "对方已提高戒备。",
}

const MATERIALS := {
	"feed_points": "饲点",
	"beast_blood": "兽血",
	"beast_bone": "兽骨",
	"venom_sac": "毒囊",
	"moon_dew": "月华露",
}

const CURSES := {
	"gu_erosion": "蛊蚀",
	"essence_bloat": "元石滞胀",
	"meridian_seal": "经脉封蛊",
}

const OUTCOMES := {
	"success": "功成升仙",
	"risky_success": "险中功成",
	"survived_failure": "保命而退",
}

const BATTLE_RESULTS := {
	"victory": "此战告捷。",
	"retreated": "你付出代价后撤离。",
	"defeat": "此战失利。",
	"ongoing": "交锋仍在继续。",
}

const ACTION_RESULTS := {
	"accept": "你接下了这桩委托，后续人情已记在身上。",
	"ally": "你暂得一位同路人相助。",
	"buy_information": "你付出元石，换得了可用情报。",
	"claim": "你抢先占住了这线机缘。",
	"cross": "你耗去真元，穿过了眼前险处。",
	"deceive": "你暂时瞒过对方，却提高了被追查的风险。",
	"harvest": "你从此处采得了可用的元石收获。",
	"inspect": "你细查现场，掌握了一条地势线索。",
	"leave": "你放下眼前收益，保留了退路。",
	"lure": "你设下诱饵，引开了眼前威胁。",
	"meditate": "你静修片刻，恢复了一点真元。",
	"open": "地脉入口被你撬开，升仙地点有了着落。",
	"prepare": "你提前布置护持，为升仙留下准备。",
	"retreat": "你选择撤离，追击的压力随之增加。",
	"scout": "你探明前路，留下了可靠的路径情报。",
	"scheme": "你设局牵制外扰，冲仙局势有所缓和。",
	"take_imprint": "你承下铁骨体印，护身与藏形的代价一并留下。",
	"trade": "你付出元石，换得了一项可调用的服务。",
	"withdraw": "你及时收手，暂时全身而退。",
	"work": "你做完短工，换得了元石。",
}

const JOURNAL_HEADINGS := {
	"Aperture foundation": "空窍根基",
	"Heaven and earth qi": "天地二气",
	"Ascension site": "升仙地点",
	"Protection": "护持",
	"External interference": "外来干扰",
	"Stone balance": "元石收支",
	"Cultivation": "修为进境",
	"Body imprint": "体印后患",
	"Lifespan consequence": "寿元代价",
	"Caravan relationship": "商队关系",
	"Key turning point": "关键转折",
	"Outcome": "最终结局",
}


static var _names: Dictionary = {}
static var _names_loaded := false


static func _load_names() -> Dictionary:
	if _names_loaded:
		return _names
	_names_loaded = true
	if not FileAccess.file_exists("res://data/names.json"):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/names.json"))
	if parsed is Dictionary:
		_names = parsed
	return _names


static func _lookup(table_key: String, id: String, fallback: Variant) -> String:
	var table: Variant = _load_names().get(table_key, {})
	if table is Dictionary and (table as Dictionary).has(id):
		return str(table[id])
	return str(fallback)


static func node(id: String) -> String:
	return _lookup("nodes", id, NODES.get(id, "未知地点"))


static func type(id: String) -> String:
	return _lookup("types", id, TYPES.get(id, "未知类型"))


static func action(id: String) -> String:
	return _lookup("actions", id, ACTIONS.get(id, "未知行动"))


static var _extra_gu_names := {}
static var _extra_gu_names_loaded := false


static func gu(id: String) -> String:
	if not _names_loaded:
		_load_names()
	var gu_names: Variant = _names.get("gu", {})
	if gu_names is Dictionary and (gu_names as Dictionary).has(id):
		return str(gu_names[id])
	if GU.has(id):
		return str(GU[id])
	if not _extra_gu_names_loaded:
		_extra_gu_names_loaded = true
		var file := FileAccess.open("res://data/gu_names.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_extra_gu_names = parsed
	return str(_extra_gu_names.get(id, "未知蛊虫"))


static func inheritance(id: String) -> String:
	return _lookup("inheritances", id, INHERITANCES.get(id, "未知杀招"))


static func enemy(id: String) -> String:
	return _lookup("enemies", id, ENEMIES.get(id, "未知敌手"))


static func material(id: String) -> String:
	return _lookup("materials", id, MATERIALS.get(id, "养料"))


static func curse(id: String) -> String:
	return _lookup("curses", id, CURSES.get(id, "未知反噬"))


# R5.2 elite cost transparency (UI 信息透明约束): the numbers are printed
# verbatim — no vague copy for backlash layers or notoriety stacks.
static func elite_cost(cost: Dictionary) -> String:
	match str(cost.get("kind", "")):
		"backlash":
			return "精英代价：反噬加深，「%s」叠加 %d 层。" % [curse(str(cost.get("curse_id", ""))), int(cost.get("layers", 1))]
		"notoriety":
			return "精英代价：恶名增加 %d 点。" % int(cost.get("amount", 1))
	return ""


static func fact(id: String) -> String:
	return _lookup("facts", id, FACTS.get(id, "未知情报"))


static func facts(ids: Array[String]) -> String:
	var labels: Array[String] = []
	for id in ids:
		labels.append(fact(id))
	return "、".join(labels) if not labels.is_empty() else "暂无"


static func outcome(id: String) -> String:
	return _lookup("outcomes", id, OUTCOMES.get(id, "未知结果"))


static func battle_result(id: String) -> String:
	return _lookup("battle_results", id, BATTLE_RESULTS.get(id, "交锋结果未明。"))


static func death_line(id: String) -> String:
	return _lookup("death_lines", id, id)


static func death_line_detail(id: String) -> String:
	return _lookup("death_line_details", id, "")


static func death_cause(id: String) -> String:
	return _lookup("death_causes", id, "死因未明")


static func result(payload: Dictionary) -> String:
	if not bool(payload.get("ok", true)):
		return "行动未能完成。"
	if payload.has("outcome"):
		return "升仙结果：%s。" % outcome(str(payload["outcome"]))
	if payload.has("battle_result"):
		return battle_result(str(payload["battle_result"]))
	var action_id := str(payload.get("action_id", ""))
	if ACTION_RESULTS.has(action_id) or (_load_names().get("action_results", {}) is Dictionary and (_load_names()["action_results"] as Dictionary).has(action_id)):
		return _lookup("action_results", action_id, ACTION_RESULTS.get(action_id, "行动已经落实。"))
	var dialogue_text := _dialogue_text(payload)
	if not dialogue_text.is_empty():
		return dialogue_text
	if payload.has("npc_reaction"):
		return _lookup("reactions", str(payload["npc_reaction"]), "对方的态度难以判断。")
	return "行动已经落实。"


static func journal_heading(heading: String) -> String:
	return _lookup("journal_headings", heading, JOURNAL_HEADINGS.get(heading, "修行记录"))


static func journal_body(entry: Dictionary) -> String:
	var values: Array = entry.get("values", [])
	match str(entry.get("body_key", "")):
		"condition_ready":
			return "此项条件已在升仙之机前备妥。"
		"condition_missing":
			return "升仙之机到来时，此项条件仍未补全。"
		"stone_balance":
			return "最终尚余 %d 枚元石。" % int(values[0])
		"cultivation_progress":
			return "最终修为停在一转第 %d 阶。" % int(values[0])
		"body_imprint":
			return "所承体印“%s”留下了长久的代价。" % _imprint_value(str(values[0]))
		"lifespan_debt":
			return "最终抉择时仍背负 %d 份寿债。" % int(values[0])
		"relationship":
			return "你与商队的关系最终定为“%s”。" % _stance_value(str(values[0]))
		"turning_point":
			return "一次记入行迹的取舍改变了通往升仙之机的道路。"
		"success":
			return "完整的筹备支撑你越过了最后一关。"
		"risky_success":
			return "你险中功成，累积的风险仍将伴随往后的路。"
		"survived_failure_retreat":
			return "此番机缘已过，你仍带着性命踏上后路。"
		"survived_failure_debt":
			return "此番机缘已过，沉重代价仍不可回避。"
		"survived_failure_imprint":
			return "此番机缘已过，体印留下了无法忘却的教训。"
	return "这段经历尚未留下可辨的文字。"


static func _dialogue_text(payload: Dictionary) -> String:
	var dialogue: Variant = payload.get("dialogue", {})
	if not dialogue is Dictionary:
		return ""
	var text: Variant = dialogue.get("text", "")
	if not text is String:
		return ""
	var candidate := str(text).strip_edges()
	return candidate if _is_chinese_player_text(candidate) else ""


static func _is_chinese_player_text(text: String) -> bool:
	var has_cjk := false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		if (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122):
			return false
		if codepoint >= 0x4e00 and codepoint <= 0x9fff:
			has_cjk = true
	return has_cjk


static func _imprint_value(ids: String) -> String:
	var labels: Array[String] = []
	for id in ids.split(", "):
		match id:
			"iron_bone": labels.append("铁骨")
			"ice_skin": labels.append("冰肤")
			"three_watch": labels.append("三更守")
			_: labels.append("未知体印")
	return "、".join(labels)


static func _stance_value(id: String) -> String:
	match id:
		"helpful": return "愿意相助"
		"suspicious": return "心存疑虑"
		"neutral": return "不偏不倚"
	return "难以判断"
