class_name SnapshotTextUtil
extends RefCounted


# Shared read-only text-formatting helpers for per-screen snapshot builders
# (W12 split). Pure projection: never mutates run state.


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
	match kind:
		"strike":
			return "造成 %d 伤害" % int(effect.get("amount", 0))
		"shield":
			return "获得 %d 护盾" % int(effect.get("amount", 0))
		"buff":
			return "%s +%d" % [_buff_label(str(effect.get("name", "force"))), int(effect.get("amount", 0))]
		"heal":
			return "恢复 %d 气血" % int(effect.get("amount", 0))
		"heal_and_strike":
			return "恢复 %d 气血并造成 %d 伤害" % [int(effect.get("heal", 0)), int(effect.get("amount", 0))]
		"status":
			return "%s %d 层" % [_status_label(str(effect.get("name", ""))), int(effect.get("amount", 0))]
		"shift":
			return "位移 %d 格" % int(effect.get("amount", 1))
	return "效果未明"
