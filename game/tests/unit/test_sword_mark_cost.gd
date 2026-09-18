extends GutTest


## 剑道 T16 残锋降转（2026-09-12 规格 §2；2026-09-15 修正 D16-4）。
##
## 原文（重查报告 §2-M7）：剑痕索命「永久性地耗费剑道仙蛊中的道痕……无法回复。
## 这样一来，剑道仙蛊会越来越弱。次数达到一定程度之后，就会引来质变，使得
## 六转仙蛊跌落到五转凡级」。
##
## 🔴 规格修正（D16-4）：原规格建议「只影响转数门禁」。但本仓门禁是
## `can_activate(cultivator, gu_rank) = cultivator >= gu_rank`，且真元成本为
## `native * mult(gu_rank) / mult(cultivator)`——**降低转数只会让蛊更易催动、更便宜**，
## 即「残锋」会变成纯收益，与原文「越来越弱」正好相反。
## 故本条实现取 D16-4(b)：降转**同时**下调该实例 RANK_SCALED_KINDS 的显式 amount。
## 未降转的实例（sword_downgrades == 0）行为与改动前逐值一致（行为保持）。

const Facade := preload("res://scripts/domain/battle_command_facade.gd")
const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")
const SwordMarkRules := preload("res://scripts/domain/sword_mark_rules.gd")
const GuInstanceScript := preload("res://scripts/domain/gu_instance.gd")

const GU_MARK := "v1_sword_mark_gu"
const GU_PLAIN := "v1_sword_plain_gu"
const KM_MARK := "km_test_sword_mark"
const KM_PLAIN := "km_test_sword_plain"
const ENEMY := "v1_test_enemy"

const MARK_AMOUNT := 6


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()
	catalog["gu_by_id"] = (catalog["gu_by_id"] as Dictionary).duplicate(true)
	catalog["v1_battle"] = (catalog["v1_battle"] as Dictionary).duplicate(true)
	catalog["enemy_by_id"] = (catalog["enemy_by_id"] as Dictionary).duplicate(true)

	catalog["gu_by_id"][GU_MARK] = {
		"id": GU_MARK, "combat": "sword_mark", "school": "sword", "role": "attack",
		"rarity": "epic", "rank": 5, "true_qi_cost": 1, "sword_mark_cost": true,
		"v1_effect": {"kind": "strike", "amount": MARK_AMOUNT},
	}
	catalog["gu_by_id"][GU_PLAIN] = {
		"id": GU_PLAIN, "combat": "sword_plain", "school": "sword", "role": "attack",
		"rarity": "common", "rank": 1, "true_qi_cost": 1,
		"v1_effect": {"kind": "strike", "amount": 2},
	}
	catalog["enemy_by_id"][ENEMY] = {
		"id": ENEMY, "label": "测试敌人", "hp": 60,
		"intent": {"kind": "attack", "damage": 0, "label": "测试意图"},
	}
	var moves: Array = (catalog["v1_battle"]["kill_moves"] as Array).duplicate(true)
	moves.append({
		"id": KM_MARK, "label": "测试残锋杀招", "tag": "sword",
		"recipe": [GU_MARK, GU_PLAIN], "true_qi_cost": 0, "thought_cost": 1,
		"damage": 3, "effect": {},
	})
	moves.append({
		"id": KM_PLAIN, "label": "测试寻常杀招", "tag": "sword",
		"recipe": [GU_PLAIN], "true_qi_cost": 0, "thought_cost": 1,
		"damage": 3, "effect": {},
	})
	catalog["v1_battle"]["kill_moves"] = moves


# ---------- 夹具 ----------

func _run(entries: Array) -> RunState:
	var run := RunState.new_run(20260915)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var instance_id := "gu_%03d" % (index + 1)
		var instance := GuInstanceScript.new_instance(str(entry["definition_id"]), instance_id, catalog)
		for key in entry:
			if str(key) != "definition_id":
				instance[key] = entry[key]
		run.gu_instances[instance_id] = instance
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()
	return run


func _battle(state: RunState) -> Dictionary:
	return Facade.start({"enemy_kind": ENEMY, "layer": 1}, state, catalog)


func _slot(battle: Dictionary, instance_id: String) -> Dictionary:
	for slot_value in (battle.get("gu_slots", []) as Array):
		var slot: Dictionary = slot_value
		if str(slot.get("instance_id", "")) == instance_id:
			return slot
	return {}


func _turn(state: RunState, battle: Dictionary, command: Dictionary) -> Dictionary:
	return Facade.apply_turn(battle, state, command, catalog)


# ---------- 1. 行为保持：未降转实例与旧行为逐值一致 ----------

func test_un_downgraded_instance_keeps_legacy_rank_and_amount() -> void:
	var run := _run([{"definition_id": GU_MARK}, {"definition_id": GU_PLAIN}])
	var battle := _battle(run)
	var slot := _slot(battle, "gu_001")
	assert_eq(int(slot.get("rank", 0)), 5, "未降转：门禁转数仍为 5")
	assert_eq(int((slot.get("effect", {}) as Dictionary).get("amount", 0)), MARK_AMOUNT,
			"未降转：显式 amount 不被改写（行为保持）")
	assert_eq(int(slot.get("sword_downgrades", -1)), 0, "未降转：sword_downgrades 为 0")


func test_dao_marks_defaults_to_config_init() -> void:
	var run := _run([{"definition_id": GU_MARK}])
	var battle := _battle(run)
	var slot := _slot(battle, "gu_001")
	var expected := int((catalog["v1_battle"] as Dictionary).get("sword_dao_marks_init", 5))
	assert_eq(int(slot.get("dao_marks", -1)), expected, "旧实例缺 dao_marks 键 → 按配置初值读取")


# ---------- 2. 逆炼：只有带标记的配方蛊扣余量 ----------

func test_marked_recipe_gu_loses_one_mark_others_untouched() -> void:
	var run := _run([{"definition_id": GU_MARK}, {"definition_id": GU_PLAIN}])
	var battle := _battle(run)
	var out := _turn(run, battle, {"type": "play_kill_move", "kill_move_id": KM_MARK})
	var next_state: RunState = out["state"]
	var marked: Dictionary = next_state.gu_instances["gu_001"]
	var plain: Dictionary = next_state.gu_instances["gu_002"]
	assert_eq(int(marked.get("dao_marks", -1)), 4, "带 sword_mark_cost 的配方蛊余量 -1")
	assert_false(plain.has("dao_marks"), "无该标记的配方蛊不产生残锋记账")


func test_kill_move_without_mark_costs_nothing() -> void:
	var run := _run([{"definition_id": GU_PLAIN}])
	var battle := _battle(run)
	var out := _turn(run, battle, {"type": "play_kill_move", "kill_move_id": KM_PLAIN})
	var next_state: RunState = out["state"]
	assert_false((next_state.gu_instances["gu_001"] as Dictionary).has("dao_marks"),
			"配方无残锋标记 → 零逆炼")


# ---------- 3. 质变：余量归零 → 降 1 转且显式 amount 同步下调 ----------

func test_mark_exhaustion_downgrades_rank_and_amount() -> void:
	catalog["v1_battle"]["sword_dao_marks_init"] = 1
	catalog["v1_battle"]["sword_downgrade_every"] = 1
	var run := _run([{"definition_id": GU_MARK}, {"definition_id": GU_PLAIN}])
	var battle := _battle(run)
	assert_eq(int(_slot(battle, "gu_001").get("rank", 0)), 5, "降转前门禁转数 5")
	var out := _turn(run, battle, {"type": "play_kill_move", "kill_move_id": KM_MARK, "confirmed": true})
	var next_state: RunState = out["state"]
	var instance: Dictionary = next_state.gu_instances["gu_001"]
	assert_eq(int(instance.get("sword_downgrades", 0)), 1, "余量归零 → 质变一次")
	assert_eq(int(instance.get("rank", 0)), 5, "持有转数不被直接改写（升阶语义保留）")
	# 下一场战斗按降转后的等效转数开局。
	var next_battle := _battle(next_state)
	var slot := _slot(next_battle, "gu_001")
	assert_eq(int(slot.get("rank", 0)), 4, "降转后门禁转数 5→4")
	assert_eq(int((slot.get("effect", {}) as Dictionary).get("amount", 0)), MARK_AMOUNT - 1,
			"降转后显式 amount 同步 -1（D16-4b：原文『仙蛊会越来越弱』）")


func test_downgrade_never_drops_rank_below_one() -> void:
	catalog["v1_battle"]["sword_dao_marks_init"] = 1
	catalog["v1_battle"]["sword_downgrade_every"] = 1
	var run := _run([{"definition_id": GU_PLAIN, "rank": 1}])
	var battle := _battle(run)
	var out := _turn(run, battle, {"type": "play_kill_move", "kill_move_id": KM_PLAIN})
	var next_state: RunState = out["state"]
	# 该配方蛊无 sword_mark_cost，不会逆炼；直接对 1 转实例施加 3 次侵蚀验下限。
	var eroded := SwordMarkRules.apply_erosion(run, ["gu_001"], catalog)
	assert_true(int((eroded["state"].gu_instances["gu_001"] as Dictionary).get("sword_downgrades", 0)) >= 1,
			"侵蚀计入降转次数")
	var battle2 := V1.start(eroded["state"], catalog, [{"id": ENEMY, "label": "测试敌人", "hp": 60,
			"intent": {"kind": "attack", "damage": 0, "label": "x"}}])
	assert_eq(int(_slot(battle2, "gu_001").get("rank", 0)), 1, "等效转数下限为 1（凡级封顶）")


# ---------- 4. 红线：触发降转前必须确认，未确认不执行 ----------

func test_downgrade_requires_confirmation_and_charges_nothing() -> void:
	catalog["v1_battle"]["sword_dao_marks_init"] = 1
	catalog["v1_battle"]["sword_downgrade_every"] = 1
	var run := _run([{"definition_id": GU_MARK}, {"definition_id": GU_PLAIN}])
	var battle := _battle(run)
	var out := _turn(run, battle, {"type": "play_kill_move", "kill_move_id": KM_MARK})
	assert_eq(str(out.get("result", "")), "rejected", "未确认 → 拒绝执行")
	assert_has(out.get("feeds", []), "sword_mark_confirm_required", "拒绝原因须为确认请求")
	var kept: Dictionary = (out["state"] as RunState).gu_instances["gu_001"]
	assert_eq(SwordMarkRules.remaining_marks(kept, catalog), 1, "未确认 → 余量不扣（不得静默惩罚）")
	assert_false(kept.has("sword_downgrades"), "未确认 → 不质变")


func test_confirmed_downgrade_executes() -> void:
	catalog["v1_battle"]["sword_dao_marks_init"] = 1
	catalog["v1_battle"]["sword_downgrade_every"] = 1
	var run := _run([{"definition_id": GU_MARK}, {"definition_id": GU_PLAIN}])
	var battle := _battle(run)
	var out := _turn(run, battle, {"type": "play_kill_move", "kill_move_id": KM_MARK, "confirmed": true})
	assert_true(bool(out.get("accepted", false)), "已确认 → 正常执行")
	var instance: Dictionary = (out["state"] as RunState).gu_instances["gu_001"]
	assert_eq(int(instance.get("sword_downgrades", 0)), 1, "已确认 → 质变落地")


func test_downgrade_warning_is_visible_before_submitting() -> void:
	catalog["v1_battle"]["sword_dao_marks_init"] = 1
	catalog["v1_battle"]["sword_downgrade_every"] = 1
	var run := _run([{"definition_id": GU_MARK}, {"definition_id": GU_PLAIN}])
	var battle := _battle(run)
	assert_true(V1.kill_move_downgrade_pending(battle, KM_MARK), "出招前必须可预检到降转")
	assert_false(V1.kill_move_downgrade_pending(battle, KM_PLAIN), "无残锋配方无预警")


# ---------- 5. 不可逆：无回复路径 + 跨战斗持久化 ----------

func test_dao_marks_have_no_recovery_path() -> void:
	var run := _run([{"definition_id": GU_MARK}, {"definition_id": GU_PLAIN}])
	var battle := _battle(run)
	var out := _turn(run, battle, {"type": "play_kill_move", "kill_move_id": KM_MARK})
	var next_state: RunState = out["state"]
	var second := _turn(next_state, out["battle"], {"type": "end_turn"})
	var after: RunState = second["state"]
	var marks := int((after.gu_instances["gu_001"] as Dictionary).get("dao_marks", -1))
	assert_eq(marks, 4, "过回合不得回复道痕（原文『无法回复』）")


func test_dao_marks_survive_save_roundtrip() -> void:
	var instance := GuInstanceScript.new_instance(GU_MARK, "gu_001", catalog)
	instance["dao_marks"] = 2
	instance["sword_downgrades"] = 1
	var saved := GuInstanceScript.to_save_data(instance)
	assert_eq(int(saved.get("dao_marks", -1)), 2, "存档白名单保留 dao_marks")
	assert_eq(int(saved.get("sword_downgrades", -1)), 1, "存档白名单保留 sword_downgrades")
	var restored := GuInstanceScript.from_save_data(saved)
	assert_eq(int(restored.get("dao_marks", -1)), 2, "读档 roundtrip 一致")


func test_legacy_instance_without_key_reads_config_init() -> void:
	var legacy := {"instance_id": "gu_009", "definition_id": GU_MARK, "state": "refined", "rank": 5}
	assert_eq(SwordMarkRules.remaining_marks(legacy, catalog),
			int((catalog["v1_battle"] as Dictionary).get("sword_dao_marks_init", 5)),
			"旧存档缺 dao_marks 键 → 按配置初值（免 SAVE_VERSION 迁移）")
