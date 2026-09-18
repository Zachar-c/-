extends GutTest


## Q8-IMPLEMENT Step 6：12 只验证蛊真实数据切片（docs/q8/Q8_12_GU_VERTICAL_SLICE.md）。
## 数据已落 data/gu.json（2026-09-12）；本测试用真实 ContentCatalog 逐只验证 Grammar 行为。
##   - A1-A4 显式化零漂移 [FACT]（A4 = recon fallback 等价显式化，rank1 无缩放/无梯度）；
##   - B1-B4 / C1-C2 / D1-D2 新语义 [DESIGN]，数值取切片文档已批值。
## 显式 effect 无 "self" 哨兵解析（哨兵仅 default_v1_effect 路径）——数据一律写实际流派名。

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")


func test_a1_sword_atk_4_01_strike5() -> void:
	var battle := _played("sword_atk_4_01_gu")
	assert_eq(int(battle["enemies"][0]["hp"]), 4, "strike 5, explicit no rank scaling")


func test_a2_stone_shell_shield3() -> void:
	var battle := _played("stone_shell_gu")
	assert_eq(int(battle["player"]["shield"]), 3)
	assert_eq(int(battle["player"]["true_qi"]), 19, "essence_cost 1")


func test_a3_sword_heal_1_09_heal2() -> void:
	var battle := _played("sword_heal_1_09_gu")
	assert_eq(int(battle["player"]["hp"]), 52, "heal 2 on hp 50")


func test_a4_wisdom_rec_marked_and_support() -> void:
	# A4 显式化等价：fallback marked1 + support1（rank1 无缩放/无梯度）。
	var battle := _played("wisdom_rec_1_20_gu")
	assert_eq(int((battle["enemies"][0] as Dictionary)["statuses"].get("marked", 0)), 1)
	assert_eq(battle["turn_supports"], {"wisdom": 1}, "support registered")


func test_b1_blood_farewell_condition_hit() -> void:
	# hit（hp 37.5% < 50%）：strike 4。miss 情形由 test_b1_blood_farewell_miss_is_zero_cost 覆盖。
	var run := _run([{"definition_id": "blood_farewell_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy()])
	battle["player"]["hp"] = 30
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 5, "9 - 4")
	assert_eq(int(out["battle"]["player"]["true_qi"]), 19, "condition hit -> cost committed")


func test_b1_blood_farewell_miss_is_zero_cost() -> void:
	var run := _run([{"definition_id": "blood_farewell_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy()])
	battle["player"]["hp"] = 50  # 62.5% >= 50% -> condition miss
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "condition_miss")
	assert_eq(int(out["battle"]["player"]["true_qi"]), 20, "zero cost on miss")
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 9)


func test_b2_water_consume_miss_then_hit() -> void:
	# 落空（无 marked）：consume_miss 零成本（D2）。
	var run := _run([{"definition_id": "water_atk_3_05_gu", "rank": 1}])
	run.cultivation = 10  # rank3 定义蛊，过转数门
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy()])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_false(bool(out["result"]["ok"]))
	assert_eq(str(out["result"]["reason"]), "consume_miss")
	assert_eq(int(out["battle"]["player"]["true_qi"]), 20)
	# 命中（marked 3）：final = 2 + 3*1 = 5，结算后清除（H2）。
	var run2 := _run([{"definition_id": "water_atk_3_05_gu", "rank": 1}])
	run2.cultivation = 10
	var battle2: Dictionary = V1.start(run2, _catalog(), [_enemy()])
	(battle2["enemies"][0] as Dictionary)["statuses"] = {"marked": 3}
	var out2: Dictionary = V1.player_action(battle2, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out2["result"]["ok"]))
	assert_eq(int(out2["battle"]["enemies"][0]["hp"]), 4, "9 - (2 + 3)")
	assert_false(((out2["battle"]["enemies"][0] as Dictionary).get("statuses", {}) as Dictionary).has("marked"))


func test_b3_fire_delay_defers() -> void:
	var run := _run([{"definition_id": "fire_atk_2_01_gu", "rank": 1}])
	run.cultivation = 10  # rank2 定义蛊，过转数门
	var battle: Dictionary = V1.start(run, _catalog(), [_attacker()])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	var played: Dictionary = out["battle"]
	assert_eq(int(played["player"]["true_qi"]), 19, "paid at play time")
	assert_eq(int(played["enemies"][0]["hp"]), 9, "deferred")
	assert_eq((played.get("delayed_effects", []) as Array).size(), 1)
	var ended: Dictionary = V1.end_turn(played)["battle"]
	assert_eq(int(ended["enemies"][0]["hp"]), 6, "9 - 3 fired next turn")


func test_b4_blood_atk_support() -> void:
	var battle := _played("blood_atk_1_08_gu")
	assert_eq(int(battle["enemies"][0]["hp"]), 7, "strike 2")
	assert_eq(battle["turn_supports"], {"blood": 1}, "support registered with real school name")


func test_c1_soul_def_sealed_gates_intent() -> void:
	var run := _run([{"definition_id": "soul_def_2_10_gu", "rank": 1}])
	run.cultivation = 10  # rank2 定义蛊，过转数门
	var battle: Dictionary = V1.start(run, _catalog(), [_attacker()])
	var played: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	assert_eq(int((played["enemies"][0] as Dictionary)["statuses"].get("sealed", 0)), 1)
	var ended: Dictionary = V1.end_turn(played)["battle"]
	assert_eq(int(ended["player"]["hp"]), 80, "damage intent gated by sealed")
	assert_false(((ended["enemies"][0] as Dictionary).get("statuses", {}) as Dictionary).has("sealed"), "consumed")


func test_c2_wisdom_weaken_reduces_intent() -> void:
	var run := _run([{"definition_id": "wisdom_atk_3_13_gu", "rank": 1}])
	run.cultivation = 10  # rank3 定义蛊，过转数门
	var battle: Dictionary = V1.start(run, _catalog(), [_attacker()])
	var played: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	assert_eq(int((played["enemies"][0] as Dictionary).get("intent_weaken", 0)), 2)
	var ended: Dictionary = V1.end_turn(played)["battle"]
	assert_eq(int(ended["player"]["hp"]), 79, "3 - 2 weaken = 1 damage")
	assert_eq(int((ended["enemies"][0] as Dictionary).get("intent_weaken", 0)), 0, "consumed -> cleared")


func test_d1_blood_atk_life_cost() -> void:
	# 预检通道（battle_snapshot.gd:227-230 展示）；此处验结算：life 2 先付、strike 8。
	var run := _run([{"definition_id": "blood_atk_5_02_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy()])
	assert_eq(int(battle["player"]["life_time"]), 60)
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int(out["battle"]["player"]["life_time"]), 58, "life_cost 2 paid")
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 1, "9 - 8")


func test_d2_qi_atk_high_cost() -> void:
	var run := _run([{"definition_id": "qi_atk_5_02_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy()])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int(out["battle"]["player"]["true_qi"]), 14, "true_qi_cost 6")
	assert_eq(int(out["battle"]["player"]["thoughts"]), 0, "thought_cost 2")
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 3, "9 - 6")


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


func _enemy() -> Dictionary:
	return {
		"id": "slice_enemy", "label": "切片敌人", "hp": 9,
		"intent": {"kind": "attack", "damage": 0, "label": "蓄力"},
	}


func _attacker() -> Dictionary:
	return {
		"id": "slice_attacker", "label": "切片攻击敌", "hp": 9,
		"intent": {"kind": "attack", "damage": 3, "label": "猛击"},
	}


## 单敌 hp9 / 玩家 hp 50 标定局 + 打出该蛊（成功路径）。
func _played(gu_id: String) -> Dictionary:
	var run := _run([{"definition_id": gu_id, "rank": 1}])
	if V1.can_play_gu(V1.start(run, _catalog(), [_enemy()]), 0) == "insufficient_qi_quality":
		run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy()])
	battle["player"]["hp"] = 50
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]), gu_id + " playable")
	return out["battle"]
