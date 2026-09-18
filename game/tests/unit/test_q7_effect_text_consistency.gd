extends GutTest


## Q7 阶段 C（2026-09-12）：effect→DisplayText 机器可验证一致性。
## 红线（§信息透明）：卡面文字必须与实际结算一致。两条机检：
## 1. 全仓 sweep：802 只战斗蛊的有效 effect（显式或兜底）经
##    SnapshotTextUtil._v1_effect_text 不得产出「效果未明」；
## 2. 通道关键词：每类 kind 的文案含结算语义关键词与数值；
## 3. 支援骑键（B2 recon 兜底）必须出现「同流派」与梯度数值。

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")
const TextUtil := preload("res://scripts/presentation/snapshots/snapshot_text_util.gd")

var catalog: Dictionary
var role_table: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_and_validate_all().get("catalog", {})
	role_table = V1.role_default_table(catalog)


func _effective_effect(gu: Dictionary) -> Dictionary:
	if gu.get("v1_effect") != null and not (gu.get("v1_effect") as Dictionary).is_empty():
		return gu.get("v1_effect")
	return V1.default_v1_effect(gu, role_table)


func _text_for(gu: Dictionary) -> String:
	var effect := _effective_effect(gu)
	var slot := {"effect": effect, "school": str(gu.get("school", ""))}
	return str(TextUtil._v1_effect_text(slot))


func test_no_combat_gu_shows_unknown_effect() -> void:
	var unknown: Array[String] = []
	for gu_value in catalog.get("gu_by_id", {}).values():
		var gu: Dictionary = gu_value
		var combat := str(gu.get("combat", ""))
		if combat.is_empty() or combat == "none":
			continue
		var text := _text_for(gu)
		if text == "效果未明":
			unknown.append(str(gu.get("id", "")))
	assert_eq(unknown.size(), 0, "战斗蛊文案不得为「效果未明」；实际=%s" % str(unknown))


func test_sword_intent_text_states_layers() -> void:
	var text := _text_for(catalog["gu_by_id"]["sword_rec_5_17_gu"])
	assert_true(text.contains("剑意"), "文案含「剑意」：%s" % text)
	assert_true(text.contains("2"), "文案含层数 2：%s" % text)


func test_sword_logistics_text_states_heal() -> void:
	var text := _text_for(catalog["gu_by_id"]["sword_log_1_11_gu"])
	assert_true(text.contains("恢复"), "文案含「恢复」：%s" % text)
	assert_true(text.contains("1"), "文案含数值 1：%s" % text)


func test_recon_default_text_covers_mark_and_support_rider() -> void:
	# B2 recon 兜底带支援骑键：文案必须同时披露刻痕与同流派支援（不许漏报）。
	var effect := V1.default_v1_effect({"id": "t", "school": "fire", "role": "recon", "rank": 3}, role_table)
	var slot := {"effect": effect, "school": "fire"}
	var text := str(TextUtil._v1_effect_text(slot))
	assert_true(text.contains("标记"), "含刻痕披露：%s" % text)
	assert_true(text.contains("同流派"), "含支援披露：%s" % text)
	assert_true(text.contains("3"), "含梯度数值 3：%s" % text)


func test_logistics_default_text_states_heal_amount() -> void:
	var effect := V1.default_v1_effect({"id": "t", "school": "soul", "role": "logistics", "rank": 4}, role_table)
	var slot := {"effect": effect, "school": "soul"}
	var text := str(TextUtil._v1_effect_text(slot))
	assert_true(text.contains("恢复 4 气血"), "rank4 后勤文案=恢复 4 气血：%s" % text)
