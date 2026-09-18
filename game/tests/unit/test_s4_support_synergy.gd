extends GutTest


## Phase S4 (master plan): elemental synergy - support-type effect.
## 小光蛊「本回合月光系蛊伤害 +2」：同回合、同流派、按序结算；
## 战斗状态可见（battle.turn_supports，透明度红线）；回合结束清零。
## 演示蛊注入 catalog 副本，避免扰动蛊池计数锁（同 test_v1_battle_resolver）。


const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = _catalog_with_demo_gu()


func test_support_boosts_same_school_strike_same_turn() -> void:
	# 杀招语义最小验证（master plan §0.5.5）：小光蛊先手，随后月光蛊伤害 +2。
	var run := _run_with_gu([
		{"definition_id": "s4_small_light_gu"},
		{"definition_id": "s4_moonlight_gu"},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy(20)])
	battle = V1.play_gu(battle, 0)["battle"]  # 小光：strike 1 + 登记 light+2
	battle = V1.play_gu(battle, 1)["battle"]  # 月光：3 + 2 = 5
	var enemy: Dictionary = battle["enemies"][0]
	assert_eq(int(enemy["hp"]), 14, "1 + (3+2) = 14/20")


func test_support_skips_other_schools() -> void:
	# 支援只加成声明流派（light）的后续蛊，力道蛊不受影响。
	var run := _run_with_gu([
		{"definition_id": "s4_small_light_gu"},
		{"definition_id": "s4_force_gu"},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy(20)])
	battle = V1.play_gu(battle, 0)["battle"]
	battle = V1.play_gu(battle, 1)["battle"]  # 力道 2，无加成
	var enemy: Dictionary = battle["enemies"][0]
	assert_eq(int(enemy["hp"]), 17, "1 + 2 = 17/20, no cross-school boost")


func test_support_expires_on_end_turn() -> void:
	# 「本回合」语义：end_turn 清空支援，下一回合月光恢复基础伤害。
	var run := _run_with_gu([
		{"definition_id": "s4_small_light_gu"},
		{"definition_id": "s4_moonlight_gu"},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy(20)])
	battle = V1.play_gu(battle, 0)["battle"]
	battle = V1.end_turn(battle)["battle"]  # 敌方回合（0 伤）+ 新回合
	battle = V1.play_gu(battle, 1)["battle"]  # 月光：3，无加成
	var enemy: Dictionary = battle["enemies"][0]
	assert_eq(int(enemy["hp"]), 16, "1 + 3 = 16/20 after turn rollover")


func test_support_state_is_visible_in_battle() -> void:
	# 透明度红线：支援以 battle.turn_supports 落在战斗状态里，可被快照/预览读取。
	var run := _run_with_gu([
		{"definition_id": "s4_small_light_gu"},
		{"definition_id": "s4_moonlight_gu"},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy(20)])
	battle = V1.play_gu(battle, 0)["battle"]
	var supports: Dictionary = battle.get("turn_supports", {})
	assert_eq(int(supports.get("light", 0)), 2, "turn_supports[light] == 2")


# ---------- fixtures ----------


func _catalog_with_demo_gu() -> Dictionary:
	var cat := ContentCatalog.load_all()
	cat["gu_by_id"]["s4_small_light_gu"] = {
		"id": "s4_small_light_gu", "combat": "reveal_hidden_bonus", "school": "light",
		"role": "scout", "rarity": "common", "true_qi_cost": 1,
		"v1_effect": {"kind": "strike", "amount": 1, "support_school": "light", "support_bonus": 2},
	}
	cat["gu_by_id"]["s4_moonlight_gu"] = {
		"id": "s4_moonlight_gu", "combat": "moonlight_strike", "school": "light",
		"role": "attack", "rarity": "common", "true_qi_cost": 1,
		"v1_effect": {"kind": "strike", "amount": 3},
	}
	cat["gu_by_id"]["s4_force_gu"] = {
		"id": "s4_force_gu", "combat": "strike", "school": "force",
		"role": "attack", "rarity": "common", "true_qi_cost": 1,
		"v1_effect": {"kind": "strike", "amount": 2},
	}
	return cat


func _run_with_gu(entries: Array) -> RunState:
	var run := RunState.new_run(20260906)
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


func _enemy(hp: int) -> Dictionary:
	return {
		"id": "s4_enemy", "label": "测试敌人", "hp": hp, "alive": true,
		"intent": {"kind": "attack", "label": "测试意图", "damage": 0},
	}
