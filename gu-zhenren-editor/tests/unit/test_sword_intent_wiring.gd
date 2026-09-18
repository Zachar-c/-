extends GutTest


## 阶段 A（Q7 辅助蛊实义化 2026-09-12）：sword_intent 引擎接线。
## 裁定（计划 §0-2）：不消费——持续增益，回合末 decay_sword_intent 减半；
## 作用域硬边界：加成只在 _apply_effect 的 strike 分支按 slot.school=="sword"
## 计算，随 amount 传入 _strike_enemy（本体零改动）——杀招/刻痕划伤/拳脚/
## heal_and_strike 结构性吃不到剑意。

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")
const SchoolRules := preload("res://scripts/domain/school_rules.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()
	# 剑道演示蛊（显式 v1_effect，注入 catalog 副本不扰动蛊池计数锁）。
	catalog["gu_by_id"]["v1_sword_intent_gu"] = {
		"id": "v1_sword_intent_gu", "combat": "sword_intent", "school": "sword", "role": "recon", "rarity": "common",
		"true_qi_cost": 1, "v1_effect": {"kind": "sword_intent", "amount": 2},
	}
	catalog["gu_by_id"]["v1_sword_strike_gu"] = {
		"id": "v1_sword_strike_gu", "combat": "sword_strike", "school": "sword", "role": "attack", "rarity": "common",
		"true_qi_cost": 1, "v1_effect": {"kind": "strike", "amount": 1},
	}
	catalog["gu_by_id"]["v1_blood_strike_gu"] = {
		"id": "v1_blood_strike_gu", "combat": "blood_strike", "school": "blood", "role": "attack", "rarity": "common",
		"true_qi_cost": 1, "v1_effect": {"kind": "strike", "amount": 1},
	}


func _run_with_gu(entries: Array) -> RunState:
	var run := RunState.new_run(20260830)
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
	return {"id": "v1_test_enemy", "label": "测试敌人", "hp": 9,
			"intent": {"kind": "attack", "damage": 0, "label": "测试意图"}}


func _play(battle: Dictionary, slot_index: int) -> Dictionary:
	return V1.player_action(battle, {"type": "play_gu", "slot_index": slot_index})["battle"]


func test_sword_intent_kind_adds_layers() -> void:
	var battle: Dictionary = V1.start(_run_with_gu([{"definition_id": "v1_sword_intent_gu"}]), catalog, [_enemy()])
	var next := _play(battle, 0)
	assert_eq(SchoolRules.sword_intent(next), 2, "sword_intent kind 入层")


func test_sword_strike_bonus_applies_only_to_sword_strikes() -> void:
	# 剑意 2 层：剑道 strike 1 → 3 伤；血道 strike 1 仍 1 伤。
	var run := _run_with_gu([
		{"definition_id": "v1_sword_intent_gu"},
		{"definition_id": "v1_sword_strike_gu"},
		{"definition_id": "v1_blood_strike_gu"},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	# 放宽行动上限夹具：上限读 used_this_turn 计数（ActionPoints.per_turn）。
	battle["player"]["thoughts"] = 9
	battle["player"]["used_this_turn"] = 0
	battle = _play(battle, 0)
	battle["player"]["thoughts"] = 9
	battle["player"]["used_this_turn"] = 0
	battle = _play(battle, 1)
	assert_eq(int(battle["enemies"][0]["hp"]), 9 - 3, "剑道 strike 吃剑意（1+2）")
	battle["player"]["thoughts"] = 9
	battle["player"]["used_this_turn"] = 0
	battle = _play(battle, 2)
	assert_eq(int(battle["enemies"][0]["hp"]), 9 - 3 - 1, "非剑道 strike 不吃剑意")


func test_basic_attack_does_not_eat_intent() -> void:
	var run := _run_with_gu([{"definition_id": "v1_sword_intent_gu"}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	battle = _play(battle, 0)
	var out: Dictionary = V1.player_action(battle, {"type": "basic_attack"})["battle"]
	# 拳脚 = fight_damage_base(1) + force/yi_zhang(0)，剑意不加；剑意蛊本身零伤害。
	assert_eq(int(out["enemies"][0]["hp"]), 9 - 1, "basic_attack 不吃剑意")


func test_end_turn_decays_intent_and_persists_across_turns() -> void:
	var run := _run_with_gu([{"definition_id": "v1_sword_intent_gu"}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	battle = _play(battle, 0)
	assert_eq(SchoolRules.sword_intent(battle), 2)
	battle = V1.end_turn(battle)["battle"]
	assert_eq(SchoolRules.sword_intent(battle), 1, "回合末减半 2→1")
	# 与 turn_supports 不同：剑意跨回合存续，不被 end_turn 清零。
	assert_true(battle.has("sword_intent"), "键存续（不被回合边界清除）")


func test_marks_scratch_does_not_scale_with_intent() -> void:
	# T15 刻痕独立通道：marked 划伤 = 层数×per_layer，不吃剑意。
	var run := _run_with_gu([{"definition_id": "v1_sword_intent_gu"}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	battle = _play(battle, 0)
	battle["enemies"][0]["statuses"] = {"marked": 2}
	var hp_before := int(battle["enemies"][0]["hp"])
	var out := V1.end_turn(battle)
	var after: Dictionary = out["battle"]
	assert_eq(int(after["enemies"][0]["hp"]), hp_before - 2, "刻痕 2 层=2 伤，剑意不加成")
