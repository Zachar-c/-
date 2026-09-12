class_name SnapshotTextUtil
extends RefCounted


# Shared read-only text-formatting helpers for per-screen snapshot builders
# (W12 split). Pure projection: never mutates run state.


## NPC 展示名与立场的单一来源：Npc 屏与 Shop 屏共用，玩家在两屏看到的
## 必须是同一个人（§16.5 一致性）；无 npc_id 的节点回落各自的通用名。
static func _npc_display_name(npc_id: String, node_type: String) -> String:
	match npc_id:
		"caravan_steward":
			return "商队执事"
		"earth_vein_scout":
			return "地脉斥候"
		"wandering_healer":
			return "游方医修"
		"ridge_extortionist":
			return "山岭索贿者"
		"wandering_peddler":
			return "散修货郎"
	return "拦路散修" if node_type == "contact" else "无名散修"


static func _npc_stance(state: Variant) -> String:
	if state != null and state.node_flags != null:
		if str(state.node_flags.get("reputation_extreme_stance", "")) == "true":
			return "极度仇恨"
		if str(state.node_flags.get("reputation_hostile", "")) == "true":
			return "敌视"
	return "中立"


static func _school_display_name(catalog: Dictionary, school_id: String) -> String:
	if school_id.is_empty():
		return "无（散修开局）"
	var entry: Dictionary = catalog.get("schools", {}).get(school_id, {})
	return str(entry.get("name", school_id))


static func _buff_label(key: String) -> String:
	match key:
		"force": return "力道"
		"yi_zhang": return "仪仗"
	return key


static func _status_label(status_name: String) -> String:
	match status_name:
		"marked": return "标记"
		"bound": return "束缚"
		"poison": return "中毒"
	return status_name if not status_name.is_empty() else "状态"


static func _v1_effect_text(source: Dictionary) -> String:
	var effect: Dictionary = source.get("effect", {})
	var kind := str(effect.get("kind", ""))
	var text := ""
	match kind:
		"strike":
			text = "造成 %d 伤害" % int(effect.get("amount", 0))
		"shield":
			text = "获得 %d 护盾" % int(effect.get("amount", 0))
		"buff":
			text = "%s +%d" % [_buff_label(str(effect.get("name", "force"))), int(effect.get("amount", 0))]
		"heal":
			text = "恢复 %d 气血" % int(effect.get("amount", 0))
		"heal_and_strike":
			text = "恢复 %d 气血并造成 %d 伤害" % [int(effect.get("heal", 0)), int(effect.get("amount", 0))]
		"status":
			text = "%s %d 层" % [_status_label(str(effect.get("name", ""))), int(effect.get("amount", 0))]
		"shift":
			# Q8 裁定：位移转译为防御，卡牌文字与实际结算一致。
			text = "退守：护盾 +%d" % int(effect.get("amount", 1))
		"sword_intent":
			# Q7 阶段 A：剑意叠层（跨回合存续，回合末减半；结算=剑道出蛊伤害加成）。
			text = "剑意 +%d 层" % int(effect.get("amount", 0))
		_:
			return "效果未明"
	# Q7 阶段 C：支援骑键必须随文案披露（recon 兜底=刻痕+同流派支援双通道）。
	var support_bonus := int(effect.get("support_bonus", 0))
	if support_bonus > 0 and not str(effect.get("support_school", "")).is_empty():
		text += "；下一次同流派蛊伤害 +%d" % support_bonus
	return text
