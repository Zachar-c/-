extends GutTest


## Q7 阶段 B2（2026-09-12）：default_effect_by_role 批量实义化。
## recon 兜底 = marked 1 + support_school:"self"（注入流派）+ support_bonus 1+(rank-1)；
## logistics 兜底 = heal 1（RANK_SCALED_KINDS 免费梯度 1+(rank-1)）。
## 抽查维度（批复条件 3）：流派×role×rank 极值组合断言。

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")

var catalog: Dictionary
var role_table: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_and_validate_all().get("catalog", {})
	role_table = V1.role_default_table(catalog)


func _default_for(school: String, role: String, rank: int) -> Dictionary:
	# 兜底按 (school, role, rank) 找真实蛊定义；找不到就合成最小定义。
	for gu_value in catalog.get("gu_by_id", {}).values():
		var gu: Dictionary = gu_value
		if str(gu.get("school", "")) == school and str(gu.get("role", "")) == role and int(gu.get("rank", 1)) == rank:
			return V1.default_v1_effect(gu, role_table)
	var synthetic := {"id": "synthetic", "school": school, "role": role, "rank": rank}
	return V1.default_v1_effect(synthetic, role_table)


func test_recon_default_marks_and_supports_own_school() -> void:
	var effect := _default_for("fire", "recon", 1)
	assert_eq(str(effect.get("kind", "")), "status", "recon 兜底仍走刻痕")
	assert_eq(str(effect.get("name", "")), "marked")
	assert_eq(str(effect.get("support_school", "")), "fire", "self 哨兵注入流派")
	assert_eq(int(effect.get("support_bonus", 0)), 1, "rank1 支援 1")


func test_recon_support_bonus_scales_with_rank() -> void:
	assert_eq(int(_default_for("wind", "recon", 5).get("support_bonus", 0)), 5, "wind rank5 → support 5")
	assert_eq(int(_default_for("wisdom", "recon", 5).get("support_bonus", 0)), 5, "wisdom rank5 → support 5")
	assert_eq(int(_default_for("gold", "recon", 1).get("support_bonus", 0)), 1, "rank1 → 1")
	assert_eq(int(_default_for("fire", "recon", 1).get("amount", -1)), 1, "marked 层数恒 1")


func test_logistics_default_heals_with_rank_gradient() -> void:
	assert_eq(str(_default_for("fire", "logistics", 2).get("kind", "")), "heal", "logistics 兜底 heal")
	assert_eq(int(_default_for("fire", "logistics", 2).get("amount", 0)), 2, "rank2 → heal 2")
	assert_eq(int(_default_for("soul", "logistics", 4).get("amount", 0)), 4, "soul rank4 epic → heal 4")
	assert_eq(int(_default_for("blood", "logistics", 3).get("amount", 0)), 3, "rank3 → heal 3")
	assert_eq(int(_default_for("human", "logistics", 3).get("amount", 0)), 3, "rank3 → heal 3")


func test_default_effects_pass_effect_reason_gate() -> void:
	# 兜底效果必须能过引擎 effect_reason 门（B1 教训：第二封闭清单）。
	for gu_value in catalog.get("gu_by_id", {}).values():
		var gu: Dictionary = gu_value
		if gu.get("v1_effect") != null:
			continue
		var combat := str(gu.get("combat", ""))
		if combat.is_empty() or combat == "none":
			continue
		var effect := V1.default_v1_effect(gu, role_table)
		assert_eq(str(V1.effect_reason(effect)), "", "%s 兜底效果必须合法" % str(gu.get("id", "")))


func test_catalog_validate_stays_clean() -> void:
	assert_eq(ContentCatalog.validate(catalog).size(), 0, "全库校验零错误")
