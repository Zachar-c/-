extends GutTest


## Q8-IMPLEMENT Step 2+3：Grammar 管线测试（docs/q8/GU_EFFECT_GRAMMAR_V2_FINAL.md §1、§12）。
## gate 段 = trigger + condition + selector 合法性 + consume_status 资格，
## 必须在 cost commit 之前调用（H1）；miss 零消耗 + 落事件。
## Step 3 覆盖：三谓词（self_hp_below / enemies_alive_gte / turn_gte）、
## 三选择器（self / enemy_first / enemy_all，H4 语义）、
## consume_status（H2 原子事务：线性公式 + 结算后清除 + 落空零成本）。
## 基线行为零漂移由 test_q8_grammar_baseline.gd 守护（378 asserts）。

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")
const Pipeline := preload("res://scripts/domain/v1_grammar_pipeline.gd")


# ---------- gate 段：trigger / condition / selector / consume 资格 ----------

func test_gate_default_on_play_passes() -> void:
	# 缺省（48 只显式蛊的现数据形态）＝ on_play、无 condition、无 selector -> 通过。
	assert_eq(Pipeline.gate_miss_reason({"kind": "strike", "amount": 2}, _battle()), "")


func test_gate_rejects_future_triggers() -> void:
	# FINAL §4：on_turn_end / on_kill 只是未来候选——批准为候选 != 批准实现。
	assert_eq(Pipeline.gate_miss_reason({"kind": "strike", "amount": 1, "trigger": "on_kill"}, _battle()), "trigger_unsupported")
	assert_eq(Pipeline.gate_miss_reason({"kind": "heal", "amount": 1, "trigger": "on_turn_end"}, _battle()), "trigger_unsupported")
	assert_eq(Pipeline.gate_miss_reason({"kind": "strike", "amount": 1, "trigger": "on_hit_taken"}, _battle()), "trigger_unsupported")


func test_condition_self_hp_below() -> void:
	# self_hp_below threshold：hp / max_hp < threshold 才资格成立（B1 残血构筑）。
	var cond := {"type": "self_hp_below", "threshold": 0.5}
	var low := _battle()
	low["player"]["hp"] = 30  # 30/80 = 0.375 < 0.5 -> 成立
	assert_true(Pipeline.evaluate_condition(low, cond), "30/80 below half")
	assert_eq(Pipeline.gate_miss_reason({"kind": "strike", "amount": 4, "condition": cond}, low), "")
	var high := _battle()
	high["player"]["hp"] = 50  # 50/80 = 0.625 >= 0.5 -> 不成立
	assert_false(Pipeline.evaluate_condition(high, cond), "50/80 not below half")
	assert_eq(Pipeline.gate_miss_reason({"kind": "strike", "amount": 4, "condition": cond}, high), "condition_miss")


func test_condition_enemies_alive_gte_and_turn_gte() -> void:
	# enemies_alive_gte count：存活敌数 >= count。
	var two_alive := _battle_two_enemies()
	assert_eq(Pipeline.gate_miss_reason({"kind": "strike", "amount": 1, "condition": {"type": "enemies_alive_gte", "count": 2}}, two_alive), "")
	assert_eq(Pipeline.gate_miss_reason({"kind": "strike", "amount": 1, "condition": {"type": "enemies_alive_gte", "count": 2}}, _battle()), "condition_miss")
	# turn_gte：battle.turn >= turn。
	var late := _battle()
	late["turn"] = 4
	assert_eq(Pipeline.gate_miss_reason({"kind": "heal", "amount": 2, "condition": {"type": "turn_gte", "turn": 3}}, late), "")
	assert_eq(Pipeline.gate_miss_reason({"kind": "heal", "amount": 2, "condition": {"type": "turn_gte", "turn": 3}}, _battle()), "condition_miss")


func test_condition_unknown_type_misses() -> void:
	# 未知谓词：资格不成立（零成本 miss），不静默放行。
	assert_eq(Pipeline.gate_miss_reason({"kind": "strike", "amount": 1, "condition": {"type": "enemy_hp_below", "threshold": 0.3}}, _battle()), "condition_miss")


func test_selector_matrix_rejects_invalid_combination() -> void:
	# operation × selector 合法矩阵：heal + enemy_first 非法 -> 零消耗拒绝。
	var effect := {"kind": "heal", "amount": 2, "selector": "enemy_first"}
	assert_eq(Pipeline.gate_miss_reason(effect, _battle()), "selector_unsupported")
	assert_eq(Pipeline.gate_miss_reason({"kind": "shield", "amount": 2, "selector": "enemy_all"}, _battle()), "selector_unsupported")
	# 合法组合照常通过。
	assert_eq(Pipeline.gate_miss_reason({"kind": "heal", "amount": 2, "selector": "self"}, _battle()), "")
	assert_eq(Pipeline.gate_miss_reason({"kind": "strike", "amount": 2, "selector": "enemy_all"}, _battle_two_enemies()), "")


# ---------- selector 解析（H4 语义） ----------

func test_selector_enemy_first_targets_first_alive() -> void:
	# H4：enemy_first = 行动队列第一个**存活**目标，不是数组第一个元素。
	var battle := _battle_two_enemies()
	(battle["enemies"][0] as Dictionary)["hp"] = 0
	var targets: Array = Pipeline.resolve_targets(battle, {"kind": "strike", "selector": "enemy_first"}, "")
	assert_eq(targets, ["e2"], "skips dead first enemy")


func test_selector_enemy_all_returns_alive_only() -> void:
	var battle := _battle_two_enemies()
	(battle["enemies"][1] as Dictionary)["hp"] = 0
	var targets: Array = Pipeline.resolve_targets(battle, {"kind": "strike", "selector": "enemy_all"}, "")
	assert_eq(targets, ["v1_test_enemy"], "dead enemy excluded")


func test_legacy_aoe_key_equals_enemy_all() -> void:
	# 遗留 aoe 键（test_slay_gu 现状）等价 selector enemy_all，行为零漂移。
	var targets: Array = Pipeline.resolve_targets(_battle_two_enemies(), {"kind": "strike", "amount": 999, "aoe": true}, "")
	assert_eq(targets, ["v1_test_enemy", "e2"])


# ---------- modifier：consume_status（H2 原子事务） ----------

func test_consume_status_atomic_strike_and_clear() -> void:
	# H2：验证（gate）-> 计算（base + stacks * per_stack）-> 提交结算 -> 清除。
	# 敌预置 marked 3 层：strike 2 + per_stack 1 -> 5 伤；结算后 marked 清零。
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog["gu_by_id"]["q8_consume_gu"] = {
		"id": "q8_consume_gu", "combat": "strike", "school": "water", "role": "attack",
		"rarity": "common", "rank": 3,
		"v1_effect": {"kind": "strike", "amount": 2, "consume_status": {"name": "marked", "per_stack": 1}},
	}
	var run := _run_with_gu([{"definition_id": "q8_consume_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	(battle["enemies"][0] as Dictionary)["statuses"] = {"marked": 3}
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	var next: Dictionary = out["battle"]
	assert_eq(int(next["enemies"][0]["hp"]), 4, "9 - (2 + 3*1) = 4")
	var statuses: Dictionary = (next["enemies"][0] as Dictionary).get("statuses", {})
	assert_false(statuses.has("marked"), "marked cleared after settle (H2 clear step)")
	assert_eq(int(next["player"]["true_qi"]), 19, "cost committed exactly once")


func test_consume_status_miss_is_zero_cost() -> void:
	# D2：消费落空（目标无 marked）= 零成本资格路径，事件 consume_miss。
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog["gu_by_id"]["q8_consume_gu"] = {
		"id": "q8_consume_gu", "combat": "strike", "school": "water", "role": "attack",
		"rarity": "common", "rank": 3,
		"v1_effect": {"kind": "strike", "amount": 2, "consume_status": {"name": "marked", "per_stack": 1}},
	}
	var run := _run_with_gu([{"definition_id": "q8_consume_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_false(bool(out["result"]["ok"]), "rejected")
	assert_eq(str(out["result"]["reason"]), "consume_miss")
	var next: Dictionary = out["battle"]
	assert_eq(int(next["enemies"][0]["hp"]), 9, "enemy untouched")
	assert_eq(int(next["player"]["true_qi"]), 20, "zero cost on consume miss")
	var reasons := []
	for entry in (next["log"] as Array):
		reasons.append(str(entry["reason"]))
	assert_has(reasons, "consume_miss")
	assert_false(reasons.has("spent"), "no cost committed")


func test_consume_with_enemy_all_rejected() -> void:
	# consume_status 只许单目标；enemy_all / aoe 组合 gate 拒绝（越面即拒）。
	var effect_all := {"kind": "strike", "amount": 2, "selector": "enemy_all", "consume_status": {"name": "marked", "per_stack": 1}}
	assert_eq(Pipeline.gate_miss_reason(effect_all, _battle_two_enemies()), "consume_selector_unsupported")
	var effect_aoe := {"kind": "strike", "amount": 2, "aoe": true, "consume_status": {"name": "marked", "per_stack": 1}}
	assert_eq(Pipeline.gate_miss_reason(effect_aoe, _battle_two_enemies()), "consume_selector_unsupported")


# ---------- Step 4：weaken_intent / sealed 门禁（H3） ----------

func test_weaken_intent_reduces_next_damage_intent() -> void:
	# weaken 2 vs 敌 attack 3 -> 本次 intent 伤害 1；消费即清零（weaken_consumed）。
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog["gu_by_id"]["q8_weaken_gu"] = {
		"id": "q8_weaken_gu", "combat": "weaken", "school": "wisdom", "role": "attack",
		"rarity": "rare", "rank": 3,
		"v1_effect": {"kind": "weaken_intent", "amount": 2},
	}
	var run := _run_with_gu([{"definition_id": "q8_weaken_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_attacker_enemy()])
	var played: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	assert_eq(int((played["enemies"][0] as Dictionary).get("intent_weaken", 0)), 2, "weaken applied per-target")
	var ended: Dictionary = V1.end_turn(played)["battle"]
	assert_eq(int(ended["player"]["hp"]), 79, "3 - 2 weaken = 1 damage")
	assert_eq(int((ended["enemies"][0] as Dictionary).get("intent_weaken", 0)), 0, "consumed -> cleared")
	var reasons := []
	for entry in (ended["log"] as Array):
		reasons.append(str(entry["reason"]))
	assert_has(reasons, "weaken_applied")
	assert_has(reasons, "weaken_consumed")


func test_weaken_damage_floor_zero() -> void:
	# weaken 5 vs damage 3 -> 0 伤（减免不把意图变成非伤害意图）。
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog["gu_by_id"]["q8_weaken_gu"] = {
		"id": "q8_weaken_gu", "combat": "weaken", "school": "wisdom", "role": "attack",
		"rarity": "rare", "rank": 3,
		"v1_effect": {"kind": "weaken_intent", "amount": 5},
	}
	var run := _run_with_gu([{"definition_id": "q8_weaken_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_attacker_enemy()])
	var played: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	var ended: Dictionary = V1.end_turn(played)["battle"]
	assert_eq(int(ended["player"]["hp"]), 80, "damage floored to 0")


func test_sealed_gates_damage_intent() -> void:
	# sealed 最小纵切：下一次 damage intent 被门禁（意图不存在）——
	# 玩家不掉血、sealed 消费即清（sealed_consumed）。
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog["gu_by_id"]["q8_seal_gu"] = {
		"id": "q8_seal_gu", "combat": "seal", "school": "soul", "role": "defense",
		"rarity": "rare", "rank": 2,
		"v1_effect": {"kind": "status", "name": "sealed", "amount": 1},
	}
	var run := _run_with_gu([{"definition_id": "q8_seal_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_attacker_enemy()])
	var played: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	assert_eq(int((played["enemies"][0] as Dictionary)["statuses"].get("sealed", 0)), 1, "sealed applied")
	var ended: Dictionary = V1.end_turn(played)["battle"]
	assert_eq(int(ended["player"]["hp"]), 80, "damage intent gated")
	assert_false(((ended["enemies"][0] as Dictionary).get("statuses", {}) as Dictionary).has("sealed"), "consumed -> cleared")
	var reasons := []
	for entry in (ended["log"] as Array):
		reasons.append(str(entry["reason"]))
	assert_has(reasons, "sealed_applied")
	assert_has(reasons, "sealed_consumed")


func test_non_damage_intent_not_gated_by_sealed() -> void:
	# H3：sealed 只门禁 damage intent——counter 类意图照常执行，sealed 不被消耗。
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog["gu_by_id"]["q8_seal_gu"] = {
		"id": "q8_seal_gu", "combat": "seal", "school": "soul", "role": "defense",
		"rarity": "rare", "rank": 2,
		"v1_effect": {"kind": "status", "name": "sealed", "amount": 1},
	}
	var run := _run_with_gu([{"definition_id": "q8_seal_gu", "rank": 1}])
	run.cultivation = 10
	var counter_enemy := {
		"id": "counter_enemy", "label": "设伏敌", "hp": 9,
		"intent": {"kind": "counter", "counter_tag": "moon", "label": "设伏"},
	}
	var battle: Dictionary = V1.start(run, catalog, [counter_enemy])
	var played: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]
	var ended: Dictionary = V1.end_turn(played)["battle"]
	assert_true(((ended["enemies"][0] as Dictionary)["counter_hidden"] as Array).has("moon"), "counter intent executed")
	assert_eq(int((ended["enemies"][0] as Dictionary)["statuses"].get("sealed", 0)), 1, "sealed untouched by non-damage intent")


# ---------- Step 5：delay（先付费后延迟，形态锁定） ----------

func test_delay_shape_rejected_for_illegal_combos() -> void:
	# FINAL §3：只允许 on_play + delay + operation 一种形态，越组合 shape 拒绝。
	var base := {"kind": "strike", "amount": 3, "delay": {"turns": 1}}
	assert_eq(Pipeline.gate_miss_reason({"kind": "strike", "amount": 1, "delay": {"turns": 0}}, _battle()), "delay_shape_rejected", "turns must be >= 1")
	assert_eq(Pipeline.gate_miss_reason({
		"kind": "strike", "amount": 3, "delay": {"turns": 1},
		"condition": {"type": "turn_gte", "turn": 2},
	}, _battle()), "delay_shape_rejected", "delay + condition forbidden")
	assert_eq(Pipeline.gate_miss_reason({
		"kind": "strike", "amount": 3, "delay": {"turns": 1},
		"consume_status": {"name": "marked", "per_stack": 1},
	}, _battle()), "delay_shape_rejected", "delay + consume_status forbidden")
	assert_eq(Pipeline.gate_miss_reason({
		"kind": "strike", "amount": 3, "delay": {"turns": 1},
		"support_school": "sword", "support_bonus": 1,
	}, _battle()), "delay_shape_rejected", "delay + support forbidden")
	assert_eq(Pipeline.gate_miss_reason({
		"kind": "strike", "amount": 3, "delay": {"turns": 1}, "trigger": "on_hit_taken",
	}, _battle()), "delay_shape_rejected", "delay requires on_play")
	# 合法形态通过。
	assert_eq(Pipeline.gate_miss_reason(base, _battle()), "")


func test_delay_defers_operation_and_pays_now() -> void:
	# 先付费后延迟：打出时 qi 已扣、敌不掉血、登记 delayed_effects；
	# 下一回合开始时结算（delayed_fired），表清空。
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog["gu_by_id"]["q8_delay_gu"] = {
		"id": "q8_delay_gu", "combat": "strike", "school": "fire", "role": "attack",
		"rarity": "common", "rank": 2,
		"v1_effect": {"kind": "strike", "amount": 3, "delay": {"turns": 1}},
	}
	var run := _run_with_gu([{"definition_id": "q8_delay_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_attacker_enemy()])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	var played: Dictionary = out["battle"]
	assert_eq(int(played["player"]["true_qi"]), 19, "cost paid at play time")
	assert_eq(int(played["enemies"][0]["hp"]), 9, "operation deferred")
	var pending: Array = played.get("delayed_effects", [])
	assert_eq((pending as Array).size(), 1, "registered")
	assert_eq(int((pending[0] as Dictionary)["due_turn"]), 2, "due next turn")
	var reasons := []
	for entry in (played["log"] as Array):
		reasons.append(str(entry["reason"]))
	assert_has(reasons, "delayed_scheduled")
	# 回合推进：敌人打 3 伤，然后延迟的 strike 3 落地。
	var ended: Dictionary = V1.end_turn(played)["battle"]
	assert_eq(int(ended["player"]["hp"]), 77, "enemy intent 3 damage")
	assert_eq(int(ended["enemies"][0]["hp"]), 6, "delayed strike 3 fired")
	assert_eq((ended.get("delayed_effects", []) as Array).size(), 0, "table cleared after firing")
	var end_reasons := []
	for entry in (ended["log"] as Array):
		end_reasons.append(str(entry["reason"]))
	assert_has(end_reasons, "delayed_fired")


# ---------- Step 2 端到端回归 ----------

func test_play_gu_condition_miss_is_zero_cost() -> void:
	# H1 端到端：condition miss 短路在 cost commit 之前（真元/念头/行动/敌 hp 不变）。
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog["gu_by_id"]["q8_gate_cond_gu"] = {
		"id": "q8_gate_cond_gu", "combat": "strike", "school": "qi", "role": "attack",
		"rarity": "common", "rank": 1, "true_qi_cost": 2, "thought_cost": 1,
		"v1_effect": {"kind": "strike", "amount": 4, "condition": {"type": "self_hp_below", "threshold": 0.5}},
	}
	var run := _run_with_gu([{"definition_id": "q8_gate_cond_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_false(bool(out["result"]["ok"]), "rejected")
	assert_eq(str(out["result"]["reason"]), "condition_miss")
	var next: Dictionary = out["battle"]
	assert_eq(int(next["player"]["true_qi"]), int(battle["player"]["true_qi"]), "true_qi untouched")
	assert_eq(int(next["player"]["thoughts"]), int(battle["player"]["thoughts"]), "thoughts untouched")
	assert_eq(int(next["player"]["used_this_turn"]), int(battle["player"]["used_this_turn"]), "action count untouched")
	assert_eq(int(next["enemies"][0]["hp"]), 9, "enemy hp untouched")
	var reasons := []
	for entry in (next["log"] as Array):
		reasons.append(str(entry["reason"]))
	assert_has(reasons, "condition_miss", "gate miss logged")
	assert_false(reasons.has("spent"), "no cost committed before condition")


func test_play_gu_normal_gu_passes_gate_and_settles() -> void:
	# 无 trigger/condition/selector 键的普通蛊照常结算（gate 对现数据全通过）。
	var catalog: Dictionary = ContentCatalog.load_all()
	var run := _run_with_gu([{"definition_id": "small_light_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy()])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 8, "strike 1 settled")
	assert_eq(int(out["battle"]["player"]["true_qi"]), 19, "cost committed after gate")


func test_play_gu_selector_enemy_all_settles_both_enemies() -> void:
	# Step 3 端到端：selector enemy_all 双敌各结算一次，事件序 struck,struck,strike_aoe。
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog["gu_by_id"]["q8_sweep_gu"] = {
		"id": "q8_sweep_gu", "combat": "strike", "school": "wind", "role": "attack",
		"rarity": "common", "rank": 2,
		"v1_effect": {"kind": "strike", "amount": 2, "selector": "enemy_all"},
	}
	var run := _run_with_gu([{"definition_id": "q8_sweep_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, catalog, [_enemy(), _enemy("e2")])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_true(bool(out["result"]["ok"]))
	var next: Dictionary = out["battle"]
	assert_eq(int(next["enemies"][0]["hp"]), 7, "first enemy -2")
	assert_eq(int(next["enemies"][1]["hp"]), 7, "second enemy -2")


# ---------- 测试工具 ----------

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


func _enemy(enemy_id: String = "v1_test_enemy") -> Dictionary:
	return {
		"id": enemy_id,
		"label": "管线敌人",
		"hp": 9,
		"intent": {"kind": "attack", "damage": 0, "label": "测试意图"},
	}


func _attacker_enemy() -> Dictionary:
	# 每回合打 3 伤的敌人（Step 4 weaken/sealed 门禁验证用）。
	return {
		"id": "v1_attacker",
		"label": "攻击敌",
		"hp": 9,
		"intent": {"kind": "attack", "damage": 3, "label": "猛击"},
	}


func _battle() -> Dictionary:
	return V1.start(_run_with_gu([]), ContentCatalog.load_all(), [_enemy()])


func _battle_two_enemies() -> Dictionary:
	return V1.start(_run_with_gu([]), ContentCatalog.load_all(), [_enemy(), _enemy("e2")])
