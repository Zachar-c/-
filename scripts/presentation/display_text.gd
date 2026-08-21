class_name DisplayText
extends RefCounted


const NODES := {
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
	"ascension_window": "升仙之机",
}

const TYPES := {
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
	"ascension": "升仙",
}

const ACTIONS := {
	"accept": "接取",
	"ally": "结盟",
	"attempt_ascension": "尝试升仙",
	"buy_information": "购买情报",
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
	"pulse_drum_gu": "脉鼓蛊",
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
}

const REACTIONS := {
	"caution": "对方保持谨慎。",
	"contempt": "对方流露轻慢。",
	"sympathy": "对方显出怜悯。",
	"exploit": "对方试图趁伤压价。",
	"examining": "对方正在核验你的说辞。",
	"guarded": "对方已提高戒备。",
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


static func node(id: String) -> String:
	return str(NODES.get(id, "未知地点"))


static func type(id: String) -> String:
	return str(TYPES.get(id, "未知类型"))


static func action(id: String) -> String:
	return str(ACTIONS.get(id, "未知行动"))


static func gu(id: String) -> String:
	return str(GU.get(id, "未知蛊虫"))


static func inheritance(id: String) -> String:
	return str(INHERITANCES.get(id, "未知杀招"))


static func enemy(id: String) -> String:
	return str(ENEMIES.get(id, "未知敌手"))


static func fact(id: String) -> String:
	return str(FACTS.get(id, "未知情报"))


static func facts(ids: Array[String]) -> String:
	var labels: Array[String] = []
	for id in ids:
		labels.append(fact(id))
	return "、".join(labels) if not labels.is_empty() else "暂无"


static func outcome(id: String) -> String:
	return str(OUTCOMES.get(id, "未知结果"))


static func battle_result(id: String) -> String:
	return str(BATTLE_RESULTS.get(id, "交锋结果未明。"))


static func result(payload: Dictionary) -> String:
	if not bool(payload.get("ok", true)):
		return "行动未能完成。"
	if payload.has("outcome"):
		return "升仙结果：%s。" % outcome(str(payload["outcome"]))
	if payload.has("battle_result"):
		return battle_result(str(payload["battle_result"]))
	var dialogue_text := _dialogue_text(payload)
	if not dialogue_text.is_empty():
		return dialogue_text
	if payload.has("npc_reaction"):
		return str(REACTIONS.get(str(payload["npc_reaction"]), "对方的态度难以判断。"))
	return "行动已经落实。"


static func journal_heading(heading: String) -> String:
	return str(JOURNAL_HEADINGS.get(heading, "修行记录"))


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
