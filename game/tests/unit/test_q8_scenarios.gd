extends GutTest


## Q8-IMPLEMENT Step 7：6 个决策场景回放（docs/q8/Q8_12_GU_VERTICAL_SLICE.md §F + §G.2）。
## 验收方式（§G.2 已批）：固定 seed + 固定敌配各跑 A/B 分支，事件日志断言对应键。
## R2 验收标准：A/B 双合理，理由差异非纯数值——断言落在行为分岔与资源结构差异上。
## S5 落法说明：文档「selector 指定乙」在 FINAL §5 冻结三选择器（self/enemy_first/enemy_all）
## 下不可表达（enemy_all 被 SELECTOR_MATRIX 拒绝；per-target 指定属未批空间）。
## B 分支以 H4 语义表达「弱化乙」的实战路径：甲将死（hp 0）-> enemy_first 跳过死敌落乙。

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")


# ---------- S1 速攻 vs 挂伤（A1 vs A4） ----------

func test_s1_a_direct_strike_for_short_fight() -> void:
	# 敌 hp 12（预计 3 回合内解决）：确定性 strike 5 最优。
	var run := _run([{"definition_id": "sword_atk_4_01_gu", "rank": 1}])
	run.cultivation = 10  # rank4 定义蛊，过转数门
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(12, 0)])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 7, "12 - 5 direct")
	assert_true(_has_event(out["battle"], "struck"), "single strike event")


func test_s1_b_marked_for_long_fight() -> void:
	# 同局况选 B：挂 marked 建立复利载体 + 支援登记（长恶战每回合跳伤）。
	var run := _run([{"definition_id": "wisdom_rec_1_20_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(12, 0)])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int((out["battle"]["enemies"][0] as Dictionary)["statuses"].get("marked", 0)), 1)
	assert_eq(out["battle"]["turn_supports"], {"wisdom": 1})
	assert_true(_has_event(out["battle"], "status"), "status applied event")


# ---------- S2 先防 vs 先埋（A2 vs B3） ----------

func test_s2_a_shield_first_absorbs_blow() -> void:
	# 敌意图攻击 6、盾 0：盾 3 确定性减伤 -> 盾吃 3、血扣 3。
	var run := _run([{"definition_id": "stone_shell_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(10, 6)])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int(out["battle"]["player"]["shield"]), 3)
	var ended: Dictionary = V1.end_turn(out["battle"])["battle"]
	assert_eq(int(ended["player"]["shield"]), 0, "shield 3 absorbed")
	assert_eq(int(ended["player"]["hp"]), 97, "100 - 3 leftover")
	assert_eq(int(ended["enemies"][0]["hp"]), 10, "no damage dealt")


func test_s2_b_delay_accepts_blow_for_tempo() -> void:
	# 同局况选 B：埋火延迟 1 回合，本回合硬吃 6 -> 下回合确定性兑现 3。
	var run := _run([{"definition_id": "fire_atk_2_01_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(10, 6)])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_true(_has_event(out["battle"], "delayed_scheduled"), "scheduled at play time")
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 10, "deferred, no immediate damage")
	var ended: Dictionary = V1.end_turn(out["battle"])["battle"]
	assert_eq(int(ended["player"]["hp"]), 94, "100 - 6, hard eat the blow")
	assert_eq(int(ended["enemies"][0]["hp"]), 7, "10 - 3 fired")
	assert_true(_has_event(ended, "delayed_fired"), "fired event")
	assert_eq((ended.get("delayed_effects", []) as Array).size(), 0, "table drained")


# ---------- S3 保留 vs 引爆（A4 + B2） ----------

func test_s3_a_stack_marked_for_compound_interest() -> void:
	# 敌 marked 2、预计战斗还剩 >=3 回合：再挂 1 层（复利路径）。
	var run := _run([{"definition_id": "wisdom_rec_1_20_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(20, 0)])
	(battle["enemies"][0] as Dictionary)["statuses"] = {"marked": 2}
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int((out["battle"]["enemies"][0] as Dictionary)["statuses"].get("marked", 0)), 3, "2 -> 3 kept")
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 20, "no detonation")


func test_s3_b_detonate_for_locked_value() -> void:
	# 同局况选 B：引爆 2 层 -> final = 2 + 2*1 = 4，兑现锁定并清层（H2 原子）。
	var run := _run([{"definition_id": "water_atk_3_05_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(20, 0)])
	(battle["enemies"][0] as Dictionary)["statuses"] = {"marked": 2}
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 16, "20 - (2 + 2)")
	assert_false(((out["battle"]["enemies"][0] as Dictionary).get("statuses", {}) as Dictionary).has("marked"), "consumed & cleared")
	assert_true(_has_event(out["battle"], "struck"), "strike event")


# ---------- S4 封 vs 弱（C1 vs C2） ----------

func test_s4_a_seal_negates_heavy_blow() -> void:
	# 敌意图攻击 8 超出血线边际：sealed 门禁 -> 这一击不存在（不发 vs 打小）。
	var run := _run([{"definition_id": "soul_def_2_10_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(20, 8)])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_true(_has_event(out["battle"], "sealed_applied"), "seal applied event")
	var ended: Dictionary = V1.end_turn(out["battle"])["battle"]
	assert_eq(int(ended["player"]["hp"]), 100, "intent does not exist -> zero damage")
	assert_true(_has_event(ended, "sealed_consumed"), "consumed on gate")
	assert_false(((ended["enemies"][0] as Dictionary).get("statuses", {}) as Dictionary).has("sealed"))


func test_s4_b_weaken_shaves_heavy_blow() -> void:
	# 同局况选 B：weaken 2 -> 8 打到 6（削幅保续航，持久观）。
	var run := _run([{"definition_id": "wisdom_atk_3_13_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(20, 8)])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_true(_has_event(out["battle"], "weaken_applied"), "weaken applied event")
	var ended: Dictionary = V1.end_turn(out["battle"])["battle"]
	assert_eq(int(ended["player"]["hp"]), 94, "100 - (8 - 2)")
	assert_true(_has_event(ended, "weaken_consumed"), "consumed on resolve")
	assert_eq(int((ended["enemies"][0] as Dictionary).get("intent_weaken", 0)), 0, "cleared after use")


# ---------- S5 弱化谁（C2 selector 分岔） ----------

func test_s5_a_weaken_default_first_threat() -> void:
	# 双敌：甲意图攻击 7（先手）/ 乙意图攻击 3。默认序 = enemy_first 削甲。
	var run := _run([{"definition_id": "wisdom_atk_3_13_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), _two_enemies())
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int((out["battle"]["enemies"][0] as Dictionary).get("intent_weaken", 0)), 2, "alpha weakened")
	assert_eq(int((out["battle"]["enemies"][1] as Dictionary).get("intent_weaken", 0)), 0, "beta untouched")
	var ended: Dictionary = V1.end_turn(out["battle"])["battle"]
	assert_eq(int(ended["player"]["hp"]), 92, "100 - (7-2) - 3")
	assert_true(_has_target_event(ended, "weaken_applied", "alpha"))


func test_s5_b_weaken_follows_alive_queue_h4() -> void:
	# B 分支（H4 活体）：甲将死（hp 0）-> enemy_first 跳过死敌落乙——
	# 「乙才是长线威胁」的引擎合法表达；文档「selector 指定乙」差异见文件头。
	var run := _run([{"definition_id": "wisdom_atk_3_13_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), _two_enemies())
	(battle["enemies"][0] as Dictionary)["hp"] = 0  # alpha dying
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int((out["battle"]["enemies"][1] as Dictionary).get("intent_weaken", 0)), 2, "beta weakened via H4")
	# 引擎事实（本步核实）：hp 0 的敌不经死亡清理仍照常行动（清理另有时机），
	# 故 end_turn 血量不在 S5 验收面——「弱化谁」= weaken_applied 落点 + 落点值。
	assert_true(_has_target_event(out["battle"], "weaken_applied", "beta"))


# ---------- S6 燃寿 vs 耗元（D1 vs D2） ----------

func test_s6_a_burn_life_to_finish_boss() -> void:
	# Boss hp 6、真元 7 / 寿元 22 / 念头 3：strike 8 当场收——寿元买断风险。
	var run := _run([{"definition_id": "blood_atk_5_02_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(6, 0)])
	battle["player"]["true_qi"] = 7
	battle["player"]["life_time"] = 22
	battle["player"]["thoughts"] = 3
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(str(out["battle"]["phase"]), "victory", "boss finished")
	assert_eq(int(out["battle"]["player"]["life_time"]), 20, "life 2 paid even on kill")
	assert_eq(int(out["battle"]["player"]["true_qi"]), 6, "qi 1 paid")
	assert_eq(int(out["battle"]["player"]["thoughts"]), 2, "thought_cost defaults to 1 (FINAL §4)")


func test_s6_b_spend_qi_to_finish_boss() -> void:
	# 同局况选 B：strike 6 恰好收——寿元不可回复故保住；真元可再生故可枯竭。
	var run := _run([{"definition_id": "qi_atk_5_02_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(6, 0)])
	battle["player"]["true_qi"] = 7
	battle["player"]["life_time"] = 22
	battle["player"]["thoughts"] = 3
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(str(out["battle"]["phase"]), "victory", "boss finished at exact damage")
	assert_eq(int(out["battle"]["player"]["true_qi"]), 1, "qi 6 spent -> near drain")
	assert_eq(int(out["battle"]["player"]["life_time"]), 22, "life line intact")
	assert_eq(int(out["battle"]["player"]["thoughts"]), 1, "thoughts 3 - 2")


# ---------- 测试工具 ----------

func _catalog() -> Dictionary:
	return ContentCatalog.load_all()


func _run(entries: Array) -> RunState:
	var run := RunState.new_run(20260912)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var instance_id := "gu_%03d" % (index + 1)
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": str(entry["definition_id"]),
			"state": "refined",
			"rank": int(entry.get("rank", 1)),
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()
	return run


func _enemy(hp: int, damage: int) -> Dictionary:
	return {
		"id": "scenario_enemy", "label": "场景敌", "hp": hp,
		"intent": {"kind": "attack", "damage": damage, "label": "猛击"},
	}


func _two_enemies() -> Array:
	return [
		{"id": "alpha", "label": "甲", "hp": 9, "intent": {"kind": "attack", "damage": 7, "label": "重压"}},
		{"id": "beta", "label": "乙", "hp": 9, "intent": {"kind": "attack", "damage": 3, "label": "撕咬"}},
	]


func _has_event(battle: Dictionary, reason: String) -> bool:
	return _has_target_event(battle, reason, "")


func _has_target_event(battle: Dictionary, reason: String, target: String) -> bool:
	for entry in battle["log"] as Array:
		var item: Dictionary = entry
		if str(item.get("reason", "")) != reason:
			continue
		if target == "" or str(item.get("target", "")) == target:
			return true
	return false
