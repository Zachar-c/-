extends GutTest


## 2026-09-07 补缺：V1 战斗结算边界。
## 目标：钉住 胜利/失败/撤退 三态的结算标记与关键成本路径，
## 补 test_v1_battle_resolver 未覆盖的 hp 归零、盾吸收、撤退标记。
## 规则锚点：《蛊真人同人 Roguelike V1 战斗规则完整文档》。


const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")
const FacadeScript := preload("res://scripts/domain/battle_command_facade.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()
	catalog["gu_by_id"]["v1_hp_battle_gu"] = {
		"id": "v1_hp_battle_gu", "combat": "strike", "school": "blood", "role": "attack", "rarity": "common",
		"true_qi_cost": 1, "v1_effect": {"kind": "strike", "amount": 2},
	}


func test_player_hp_zero_marks_defeat_with_hp_cause() -> void:
	var run := _run_with_gu([{"definition_id": "v1_hp_battle_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 3)])
	battle["player"]["hp"] = 3
	battle["player"]["life_time"] = 60
	battle["player"]["soul"] = 5
	var out := V1.end_turn(battle)
	assert_eq(str(out["battle"]["phase"]), "defeat")
	assert_eq(str(out["battle"]["result"]["outcome"]), "death")
	assert_eq(str(out["battle"]["result"]["cause"]), "hp")


func test_player_life_cost_zero_marks_defeat_with_life_cause() -> void:
	var run := _run_with_gu([])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["player"]["hp"] = 50
	battle["player"]["life_time"] = 0
	battle["player"]["soul"] = 5
	var out := V1.end_turn(battle)
	assert_eq(str(out["battle"]["phase"]), "defeat")
	assert_eq(str(out["battle"]["result"]["outcome"]), "death")
	assert_eq(str(out["battle"]["result"]["cause"]), "life_cost")


func test_player_soul_zero_marks_defeat_with_soul_cause() -> void:
	var run := _run_with_gu([])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["player"]["hp"] = 50
	battle["player"]["life_time"] = 60
	battle["player"]["soul"] = 0
	var out := V1.end_turn(battle)
	assert_eq(str(out["battle"]["phase"]), "defeat")
	assert_eq(str(out["battle"]["result"]["outcome"]), "death")
	assert_eq(str(out["battle"]["result"]["cause"]), "soul")


func test_strike_consumes_enemy_shield_before_hp() -> void:
	var run := _run_with_gu([{"definition_id": "v1_hp_battle_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["enemies"][0]["shield"] = 3
	battle["enemies"][0]["hp"] = 9
	# 2 伤：盾 3 → 1，hp 不变
	battle = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	assert_eq(int(battle["enemies"][0]["shield"]), 1)
	assert_eq(int(battle["enemies"][0]["hp"]), 9)
	assert_eq(str(battle["phase"]), "player_action", "shield soak must not end the battle")


func test_strike_pierces_shield_and_kills_enemy_marks_victory() -> void:
	var run := _run_with_gu([{"definition_id": "v1_hp_battle_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["enemies"][0]["shield"] = 1
	battle["enemies"][0]["hp"] = 1
	battle = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	assert_eq(int(battle["enemies"][0]["shield"]), 0)
	assert_eq(int(battle["enemies"][0]["hp"]), 0)
	assert_false(bool(battle["enemies"][0]["alive"]))
	assert_eq(str(battle["phase"]), "victory")


func test_victory_phase_blocks_further_player_actions() -> void:
	var run := _run_with_gu([{"definition_id": "v1_hp_battle_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["enemies"][0]["hp"] = 1
	battle = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	assert_eq(str(battle["phase"]), "victory")
	var after := V1.player_action(battle, {"type": "basic_attack"})
	assert_false(bool(after["result"]["ok"]), "actions after victory must be rejected")


func test_retreat_marks_battle_over_via_facade() -> void:
	var run := _run_with_gu([{"definition_id": "v1_hp_battle_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	# F-01：撤离门禁与预览同源后，开放地形是放行条件之一（真实战斗由
	# RunBattleFlow.battle_terrain 透传；V1 裸 battle 无地形一律不放行）。
	battle["terrain"] = "path"
	var out := FacadeScript.apply_turn(battle, run, {"type": "retreat"})
	assert_true(bool(out.get("accepted", false)))
	assert_eq(str(out.get("result", "")), "retreat")
	assert_true(bool(out.get("finished", false)))


func test_facade_retreat_rejected_in_boss_battle() -> void:
	var run := _run_with_gu([{"definition_id": "v1_hp_battle_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["flags"]["boss_battle"] = true
	var out := FacadeScript.apply_turn(battle, run, {"type": "retreat"})
	assert_false(bool(out.get("accepted", false)))
	assert_eq(str(out.get("result", "")), "rejected")
	assert_true((out.get("feeds", []) as Array).has("retreat_forbidden"))


# ---------- 测试工具 ----------

func _run_with_gu(entries: Array) -> RunState:
	var run := RunState.new_run(20260907)
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


func _enemy(kind: String, amount: int) -> Dictionary:
	var intent: Dictionary = {"kind": kind, "label": "测试意图"}
	if kind == "attack":
		intent["damage"] = amount
	return {"id": "v1_test_enemy", "label": "测试敌人", "hp": 9, "intent": intent}
