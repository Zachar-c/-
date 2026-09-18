extends GutTest


## Q8-POST 收口：HP=0 敌人仍继续行动 / 胜利不触发（战斗语义完整性缺陷，2026-09-12）。
##
## 缺陷本体：存活判定存在**两个事实来源**——
##   - v1_grammar_pipeline.gd 用 `hp > 0`（H4 落档定义）；
##   - v1_battle_resolver.gd 用 `alive` 字段。
## 当 hp 归零而 alive 未同步（外部改写、或未来新增的扣血通道），两处结论相反：
## 管线认为已死（selector 正确跳过），行动队列认为还活着（照常出手），
## 且 _check_victory 永远看不到「全灭」——战斗结果不可预见。
##
## 修复口径：`hp > 0` 为存活唯一事实来源，与管线 / 预览层 / 快照层三方对齐。
## （action_preview_service.gd:168、battle_snapshot.gd:379 本就是 `alive && hp > 0`。）

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")


# ---------- 死亡敌人不行动 ----------

func test_zero_hp_enemy_does_not_act() -> void:
	# 甲 hp=0（alive 遗留 true，模拟未同步态）、乙存活：end_turn 只应见乙出手。
	var battle := _battle(_two_enemies())
	(battle["enemies"][0] as Dictionary)["hp"] = 0

	var ended: Dictionary = V1.end_turn(battle)["battle"]
	# 乙 3 伤落账；甲 7 伤不得出现。
	assert_eq(int(ended["player"]["hp"]), 77, "only beta's 3 damage lands (80 - 3)")
	# enemy_attack 事件的 target 是意图 label（见 _resolve_enemy_intent 的 _log 调用）。
	assert_true(_has_target_event(ended, "enemy_attack", "撕咬"), "beta acted")
	assert_false(_has_target_event(ended, "enemy_attack", "重压"), "alpha must not act at hp 0")


func test_zero_hp_single_enemy_is_victory() -> void:
	# 唯一敌 hp=0：不应出手，且应立刻判胜（原本 alive=true 会永远打不死）。
	var battle := _battle([_enemy(5, 6)])
	(battle["enemies"][0] as Dictionary)["hp"] = 0

	var ended: Dictionary = V1.end_turn(battle)["battle"]
	assert_eq(str(ended["phase"]), "victory", "all-zero-hp enemies = victory")
	assert_eq(int(ended["player"]["hp"]), 80, "no enemy attack at hp 0")


# ---------- 存活事实来源统一 ----------

func test_strike_lethal_sets_victory() -> void:
	# 常规致死路径（回归保护）：strike 打空血 -> alive=false + victory。
	var run := _run([{"definition_id": "blood_atk_5_02_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), [_enemy(4, 0)])
	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 0)
	assert_false(bool(out["battle"]["enemies"][0]["alive"]))
	assert_eq(str(out["battle"]["phase"]), "victory")


func test_marked_settlement_lethal_sets_victory() -> void:
	# 刻痕结算通道致死（回归保护）：_settle_marks 打空血 -> victory。
	var battle := _battle([_enemy(1, 0)])
	(battle["enemies"][0] as Dictionary)["statuses"] = {"marked": 3}

	var ended: Dictionary = V1.end_turn(battle)["battle"]
	assert_eq(int(ended["enemies"][0]["hp"]), 0)
	assert_eq(str(ended["phase"]), "victory", "mark scratch lethal -> victory")


# ---------- selector 与行动队列口径一致 ----------

func test_selector_and_action_queue_agree_on_zero_hp() -> void:
	# 同一 battle：weaken 落乙（管线的 hp>0 口径）+ end_turn 只有乙出手（行动口径）。
	# 修复前两者相反——这条测试就是缺陷的「同源」断言。
	var run := _run([{"definition_id": "wisdom_atk_3_13_gu", "rank": 1}])
	run.cultivation = 10
	var battle: Dictionary = V1.start(run, _catalog(), _two_enemies())
	(battle["enemies"][0] as Dictionary)["hp"] = 0

	var out: Dictionary = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	assert_eq(int((out["battle"]["enemies"][1] as Dictionary).get("intent_weaken", 0)), 2,
		"pipeline (hp>0) targets beta")

	var ended: Dictionary = V1.end_turn(out["battle"])["battle"]
	assert_true(_has_target_event(ended, "enemy_attack", "撕咬"), "beta acted")
	assert_false(_has_target_event(ended, "enemy_attack", "重压"),
		"action queue must use the same hp>0 source as the pipeline")


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


func _battle(enemies: Array) -> Dictionary:
	var run := _run([{"definition_id": "stone_shell_gu", "rank": 1}])
	return V1.start(run, _catalog(), enemies)


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


func _has_target_event(battle: Dictionary, reason: String, target: String) -> bool:
	for entry in battle["log"] as Array:
		var item: Dictionary = entry
		if str(item.get("reason", "")) != reason:
			continue
		if target == "" or str(item.get("target", "")) == target:
			return true
	return false
