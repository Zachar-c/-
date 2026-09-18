extends GutTest


## Q7 阶段 B1（2026-09-12）：剑道 10 只辅助蛊显式 v1_effect。
## 分配（计划 §0-3）：sword_rec_1 → sword_intent +1；sword_rec_5 → +2（不进
## 缩放表，显式自控防 cap 5 秒满）；sword_log_1 → heal 1（后勤=恢复）。
## 文案一致性（红线）：效果断言 + 卡面文字断言同文件（阶段 C 模板复用）。

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")
const DisplayTextScript = preload("res://scripts/presentation/display_text.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_and_validate_all().get("catalog", {})
	DisplayTextScript.prime_from_catalog(catalog)


func _sword_gu(role: String) -> Array:
	var found: Array = []
	for gu_value in catalog.get("gu_by_id", {}).values():
		var gu: Dictionary = gu_value
		if str(gu.get("school", "")) == "sword" and str(gu.get("role", "")) == role:
			found.append(gu)
	return found


func test_sword_recon_gu_declare_sword_intent_effect() -> void:
	var recs := _sword_gu("recon")
	assert_eq(recs.size(), 5, "剑道 recon 5 只")
	for gu_value in recs:
		var gu: Dictionary = gu_value
		var effect: Dictionary = gu.get("v1_effect", {})
		assert_false(effect.is_empty(), "%s 必须显式 v1_effect" % str(gu.get("id", "")))
		assert_eq(str(effect.get("kind", "")), "sword_intent", "%s kind" % str(gu.get("id", "")))
		var expected := 1 if int(gu.get("rank", 1)) == 1 else 2
		assert_eq(int(effect.get("amount", 0)), expected, "%s amount 按 rank" % str(gu.get("id", "")))


func test_sword_logistics_gu_declare_heal_effect() -> void:
	var logs := _sword_gu("logistics")
	assert_eq(logs.size(), 5, "剑道 logistics 5 只")
	for gu_value in logs:
		var gu: Dictionary = gu_value
		var effect: Dictionary = gu.get("v1_effect", {})
		assert_false(effect.is_empty(), "%s 必须显式 v1_effect" % str(gu.get("id", "")))
		assert_eq(str(effect.get("kind", "")), "heal", "%s kind" % str(gu.get("id", "")))
		assert_eq(int(effect.get("amount", 0)), 1, "%s heal 1" % str(gu.get("id", "")))


func test_sword_support_gu_pass_catalog_validation() -> void:
	var errors := ContentCatalog.validate(catalog)
	assert_eq(errors.size(), 0, "全库校验零错误（含 sword_intent kind 登记）")


func test_sword_recon_behavior_adds_intent_in_battle() -> void:
	# 行为级：rank1 侦察蛊出蛊 → 剑意 +1（rank5 定义会被低修为门禁拦截，属正确行为）。
	var run := RunState.new_run(20260830)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_instances["gu_001"] = {
		"instance_id": "gu_001", "definition_id": "sword_rec_1_10_gu", "state": "refined", "rank": 1,
	}
	run.cave_aperture["stored_gu_instance_ids"].append("gu_001")
	run.sync_legacy_gu_projections()
	var battle: Dictionary = V1.start(run, catalog, [{
		"id": "e1", "label": "测试敌人", "hp": 9,
		"intent": {"kind": "attack", "damage": 0, "label": "测试意图"},
	}])
	assert_eq(str(battle["gu_slots"][0]["effect"].get("kind", "")), "sword_intent")
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	assert_eq(int(out.get("sword_intent", 0)), 1, "rec_1 出蛊 → 剑意 1")


func test_low_cultivation_cannot_drive_rank5_sword_recon() -> void:
	# 转数门禁回归：一转修为不能驱五转侦察蛊（预检拒绝，非静默）。
	var run := RunState.new_run(20260830)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_instances["gu_001"] = {
		"instance_id": "gu_001", "definition_id": "sword_rec_5_17_gu", "state": "refined", "rank": 1,
	}
	run.cave_aperture["stored_gu_instance_ids"].append("gu_001")
	run.sync_legacy_gu_projections()
	var battle: Dictionary = V1.start(run, catalog, [{
		"id": "e1", "label": "测试敌人", "hp": 9,
		"intent": {"kind": "attack", "damage": 0, "label": "测试意图"},
	}])
	assert_eq(str(V1.can_play_gu(battle, 0)), "insufficient_qi_quality", "低转驱高转被门禁拒绝")
