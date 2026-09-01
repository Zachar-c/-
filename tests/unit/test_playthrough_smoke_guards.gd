extends GutTest

# 发布阻断修复 6：playthrough_smoke 的非蛊商品名称与离场失败的可观测性。
# 非 gu 商品（魂丹/材料/配方/服务）此前按 offer.gu_id 取名 → 空串；所有
# leave_node 调用此前吞掉结果 → 失败后每步原样重试 = 静默空转 900 步。
# 本测试锁定两个助手的行为；冒烟脚本本身经 _step 返回 leave_blocked 终止。

const SmokeScript = preload("res://scripts/playthrough_smoke.gd")


func test_gu_offer_label_prefers_gu_name() -> void:
	assert_eq(SmokeScript.offer_label({"gu_id": "stone_shell_gu", "id": "purchase_stone_shell"}), DisplayText.gu("stone_shell_gu"))


func test_non_gu_offers_never_produce_empty_names() -> void:
	# 魂丹（soul_boost，无 gu_id）
	var soul: String = SmokeScript.offer_label({"id": "soul_pill", "kind": "soul_boost", "card_key": "soul_pill"})
	assert_false(soul.is_empty(), "soul_boost offer must not render as empty name")
	# 材料购买
	var material: String = SmokeScript.offer_label({"id": "purchase_moon_blue_petal", "kind": "material_purchase", "material_id": "moon_blue_petal", "card_key": "purchase.moon_blue_petal"})
	assert_false(material.is_empty(), "material offer must not render as empty name")
	# 服务与无任何可读字段的兜底
	var service: String = SmokeScript.offer_label({"id": "wash_notoriety", "kind": "wash_notoriety", "card_key": "wash.notoriety"})
	assert_false(service.is_empty(), "service offer must not render as empty name")
	var bare: String = SmokeScript.offer_label({"id": "mystery_item"})
	assert_false(bare.is_empty(), "bare offer must fall back to its id")


func test_leave_verdict_flags_rejection() -> void:
	assert_true(SmokeScript.leave_result_ok({"result": {"ok": true}}), "ok leave passes")
	assert_false(SmokeScript.leave_result_ok({"result": {"ok": false, "reason": "feud_no_escape"}}), "rejected leave must be visible")
	assert_false(SmokeScript.leave_result_ok({"ok": false, "reason": "rest_choice_required"}), "nested-result rejection must be visible too")