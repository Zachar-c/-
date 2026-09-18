extends GutTest


## Q8-IMPLEMENT Step 1（2026-09-12）：48 只显式 v1_effect 蛊全量逐只对拍（不是抽样）。
## 把每只蛊的当前引擎行为锁成基线；Grammar resolver 接管分发层后本测试必须逐只保持绿
## （行为保持承诺 R1/R2，docs/q8/GU_EFFECT_GRAMMAR_V2_FINAL.md §9、§12）。
## 期望值全部从 data/gu.json 显式 v1_effect 字段推导：
##   - 显式效果不做转数缩放（RANK_SCALED_KINDS 只作用于 role fallback，
##     v1_battle_resolver.gd:25、145-146）；
##   - 成本链 true_qi_cost -> essence_cost -> 缺省 1（v1_battle_resolver.gd:178）；
##   - shift 转译为 shield、缺省 amount 1（v1_battle_resolver.gd:424）；
##   - sword_intent 落 battle 级键（school_rules.gd:36，cap 5）；
##   - support 打出后登记 turn_supports[school]（v1_battle_resolver.gd:432-437），
##     同蛊自己的 strike 读不到自己这发（读在登记前，L393）。
## 例内蛊：test_slay_gu（aoe 形态专测）、blood_bat_gu（遗留 heal_and_strike 专测）。

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")


# 基线表 [id, 期望 true_qi, 期望敌 hp, 期望玩家 hp, 期望 shield, 期望 sword_intent, 期望 turn_supports]
# 敌基线 hp 9；玩家基线 hp 50（让 heal 可见）；true_qi 20 / thoughts 2；实例 rank 1（转数门按实例 rank）。
const BASELINE := [
	["small_light_gu", 19, 8, 50, 0, 0, {"light": 2}],
	["moonlight_gu", 18, 6, 50, 0, 0, {}],
	["moon_glow_gu", 18, 5, 50, 0, 0, {}],
	["force_gu", 19, 7, 50, 0, 0, {}],
	["stone_shell_gu", 19, 9, 50, 3, 0, {}],
	["blood_droplet_gu", 19, 7, 50, 0, 0, {}],
	# test_slay_gu / blood_bat_gu 见专测
	["sword_atk_4_01_gu", 19, 4, 50, 0, 0, {}],
	["sword_atk_5_02_gu", 19, 3, 50, 0, 0, {}],
	["sword_atk_5_03_gu", 19, 3, 50, 0, 0, {}],
	["sword_atk_5_04_gu", 19, 3, 50, 0, 0, {}],
	["sword_atk_1_05_gu", 19, 7, 50, 0, 0, {"sword": 1}],
	["sword_atk_1_06_gu", 19, 7, 50, 0, 0, {"sword": 1}],
	["sword_def_1_07_gu", 19, 9, 50, 3, 0, {}],
	["sword_mov_1_08_gu", 19, 9, 50, 1, 0, {}],
	["sword_heal_1_09_gu", 19, 9, 52, 0, 0, {}],
	["sword_rec_1_10_gu", 19, 9, 50, 0, 1, {}],
	["sword_log_1_11_gu", 19, 9, 51, 0, 0, {}],
	["sword_atk_2_12_gu", 19, 6, 50, 0, 0, {}],
	["sword_atk_2_13_gu", 19, 6, 50, 0, 0, {}],
	["sword_def_3_14_gu", 19, 9, 50, 5, 0, {}],
	["sword_mov_3_15_gu", 19, 9, 50, 1, 0, {}],
	["sword_heal_4_16_gu", 19, 9, 55, 0, 0, {}],
	["sword_rec_5_17_gu", 19, 9, 50, 0, 2, {}],
	["sword_log_1_18_gu", 19, 9, 51, 0, 0, {}],
	["sword_atk_2_19_gu", 19, 6, 50, 0, 0, {}],
	["sword_atk_2_20_gu", 19, 6, 50, 0, 0, {"sword": 1}],
	["sword_def_3_21_gu", 19, 9, 50, 5, 0, {}],
	["sword_mov_3_22_gu", 19, 9, 50, 1, 0, {}],
	["sword_heal_4_23_gu", 19, 9, 55, 0, 0, {}],
	["sword_rec_5_24_gu", 19, 9, 50, 0, 2, {}],
	["sword_log_1_25_gu", 19, 9, 51, 0, 0, {}],
	["sword_atk_2_26_gu", 19, 6, 50, 0, 0, {}],
	["sword_atk_2_27_gu", 19, 6, 50, 0, 0, {}],
	["sword_def_3_28_gu", 19, 9, 50, 5, 0, {}],
	["sword_mov_3_29_gu", 19, 9, 50, 1, 0, {}],
	["sword_heal_4_30_gu", 19, 9, 55, 0, 0, {}],
	["sword_rec_5_31_gu", 19, 9, 50, 0, 2, {}],
	["sword_log_1_32_gu", 19, 9, 51, 0, 0, {}],
	["sword_atk_2_33_gu", 19, 6, 50, 0, 0, {"sword": 1}],
	["sword_atk_2_34_gu", 19, 6, 50, 0, 0, {}],
	["sword_def_3_35_gu", 19, 9, 50, 5, 0, {}],
	["sword_mov_3_36_gu", 19, 9, 50, 1, 0, {}],
	["sword_heal_4_37_gu", 19, 9, 55, 0, 0, {}],
	["sword_rec_5_38_gu", 19, 9, 50, 0, 2, {}],
	["sword_log_1_39_gu", 19, 9, 51, 0, 0, {}],
	["sword_atk_2_40_gu", 19, 6, 50, 0, 0, {}],
]


# 思头成本特例：数据显式声明 thought_cost 2（其余缺省 1）→ 打出后 thoughts = 2 - 2 = 0。
const THOUGHTS_AFTER := {
	"sword_atk_2_20_gu": 0,
	"sword_atk_2_33_gu": 0,
}


func test_all_46_gu_baseline() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	for row in BASELINE:
		var gu_id := str(row[0])
		var run := _run_with_gu([{"definition_id": gu_id, "rank": 1}])
		# 转数门同时卡定义 rank（探针 2026-09-12：rank 2+ 定义蛊一转被拒
		# insufficient_qi_quality）；对拍统一十转解除门槛，效果数值与实例 rank 无关。
		run.cultivation = 10
		var battle: Dictionary = V1.start(run, catalog, [_enemy()])
		battle["player"]["hp"] = 50
		var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
		assert_true(bool(out["result"]["ok"]), gu_id + " playable")
		if not bool(out["result"]["ok"]):
			continue
		var next: Dictionary = out["battle"]
		assert_eq(int(next["player"]["true_qi"]), int(row[1]), gu_id + " true_qi")
		assert_eq(int(next["player"]["thoughts"]), int(THOUGHTS_AFTER.get(gu_id, 1)), gu_id + " thoughts")
		assert_eq(int(next["enemies"][0]["hp"]), int(row[2]), gu_id + " enemy hp")
		assert_eq(int(next["player"]["hp"]), int(row[3]), gu_id + " player hp")
		assert_eq(int(next["player"]["shield"]), int(row[4]), gu_id + " shield")
		assert_eq(int(next.get("sword_intent", 0)), int(row[5]), gu_id + " sword_intent")
		assert_eq(next.get("turn_supports", {}), row[6], gu_id + " turn_supports")


func test_blood_bat_legacy_heal_and_strike() -> void:
	# 遗留复合通道：heal 1 + strike 1（v1_battle_resolver.gd:414）。存量保留、不新增。
	var catalog: Dictionary = ContentCatalog.load_all()
	var run := _run_with_gu([{"definition_id": "blood_bat_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	battle["player"]["hp"] = 50
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	var next: Dictionary = out["battle"]
	assert_eq(int(next["enemies"][0]["hp"]), 8, "blood_bat strike 1")
	assert_eq(int(next["player"]["hp"]), 51, "blood_bat heal 1")


func test_aoe_strike_current_shape() -> void:
	# test_slay_gu v1_effect 带 "aoe": true。现状形态（探针 2026-09-12）：双敌全灭、
	# phase 直接 victory——e1 hp 也归 0。按现状固化；目标语义（enemy_first/enemy_all）
	# 与 aoe 键的真实含义在 Grammar 层 selector 实现时重新裁定。
	var catalog: Dictionary = ContentCatalog.load_all()
	var run := _run_with_gu([{"definition_id": "test_slay_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_enemy(), _enemy()])
	battle["player"]["hp"] = 50
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	var next: Dictionary = out["battle"]
	assert_eq(int(next["enemies"][0]["hp"]), 0, "first enemy killed by 999")
	assert_eq(int(next["enemies"][1]["hp"]), 0, "current shape: all enemies down")
	assert_eq(str(next["phase"]), "victory", "battle ends immediately")


func test_support_synergy_two_sword_strikes_same_turn() -> void:
	# S4 支援链：第一发登记 turn_supports["sword"]，同回合第二发同流派 strike 吃加成。
	var catalog: Dictionary = ContentCatalog.load_all()
	var run := _run_with_gu([
		{"definition_id": "sword_atk_1_05_gu", "rank": 1},
		{"definition_id": "sword_atk_2_12_gu", "rank": 1},
	])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	battle["player"]["hp"] = 50
	battle = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	assert_eq(int(battle["enemies"][0]["hp"]), 7, "first strike 2, cannot eat own support")
	assert_eq(battle["turn_supports"], {"sword": 1}, "support registered")
	battle = V1.player_action(battle, {"type": "play_gu", "slot_index": 1})["battle"]
	assert_eq(int(battle["enemies"][0]["hp"]), 3, "second strike 3 + 1 support = 4")


# ---------- 测试工具（模式取自 test_v1_battle_resolver.gd fixture） ----------

func _run_with_gu(entries: Array) -> RunState:
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
		"id": "v1_test_enemy",
		"label": "对拍敌人",
		"hp": 9,
		"intent": {"kind": "attack", "damage": 0, "label": "测试意图"},
	}
