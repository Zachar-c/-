extends GutTest


## 2026-09-07 补缺：V1 蛊效果生效细粒度守卫。
## 目标：钉住 _apply_effect 各 effect kind 的结算语义
## （strike 盾吸收/heal 封顶/buff 叠加/status 叠加/shift/aoe/支援加成），
## 补 test_v1_battle_resolver 未逐 kind 覆盖的效果分支。
## 规则锚点：《蛊真人同人 Roguelike V1 战斗规则完整文档》S4 元素协同。


const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()
	catalog["gu_by_id"]["v1_effect_test_gu"] = {
		"id": "v1_effect_test_gu", "combat": "strike", "school": "blood", "role": "attack", "rarity": "common",
		"true_qi_cost": 1, "v1_effect": {"kind": "strike", "amount": 2},
	}


func test_heal_effect_clamps_to_max_hp() -> void:
	var battle := _battle([{"definition_id": "v1_effect_test_gu", "rank": 1}], _enemy("attack", 0))
	battle["player"]["hp"] = 5
	battle = _play(battle, 0)
	# heal 不在 v1_effect_test_gu 上，这里直接通过注入 heal 蛊验证
	var heal_slot: Dictionary = battle["gu_slots"][0].duplicate(true)
	heal_slot["effect"] = {"kind": "heal", "amount": 99}
	heal_slot["used_this_turn"] = false
	battle["gu_slots"][0] = heal_slot
	var healed := V1.play_gu(battle, 0)
	assert_eq(int(healed["battle"]["player"]["hp"]),
			int(battle["player"]["max_hp"]), "heal must clamp to max_hp")


func test_heal_effect_ignores_negative_amount() -> void:
	var battle := _battle([{"definition_id": "v1_effect_test_gu", "rank": 1}], _enemy("attack", 0))
	battle["player"]["hp"] = 30
	var heal_slot: Dictionary = battle["gu_slots"][0].duplicate(true)
	heal_slot["effect"] = {"kind": "heal", "amount": -10}
	battle["gu_slots"][0] = heal_slot
	var out := V1.play_gu(battle, 0)
	assert_eq(int(out["battle"]["player"]["hp"]), 30, "negative heal must be no-op")


func test_buff_effect_stacks_across_casts() -> void:
	var battle := _battle([{"definition_id": "v1_effect_test_gu", "rank": 1}], _enemy("attack", 0))
	var buff_slot: Dictionary = battle["gu_slots"][0].duplicate(true)
	buff_slot["effect"] = {"kind": "buff", "name": "force", "amount": 1}
	battle["gu_slots"][0] = buff_slot
	battle = V1.play_gu(battle, 0)["battle"]
	battle["gu_slots"][0]["used_this_turn"] = false
	battle["player"]["true_qi"] = 5
	battle = V1.play_gu(battle, 0)["battle"]
	assert_eq(int(battle["player"]["buffs"].get("force", 0)), 2,
			"buff must stack across casts")


func test_status_effect_stacks_on_enemy() -> void:
	var battle := _battle([{"definition_id": "v1_effect_test_gu", "rank": 1}], _enemy("attack", 0))
	var status_slot: Dictionary = battle["gu_slots"][0].duplicate(true)
	status_slot["effect"] = {"kind": "status", "name": "marked", "amount": 1}
	battle["gu_slots"][0] = status_slot
	battle = V1.play_gu(battle, 0)["battle"]
	assert_eq(int(battle["enemies"][0]["statuses"].get("marked", 0)), 1)
	assert_eq(str(battle.get("last_effect_target", "")), "v1_test_enemy")


func test_shift_effect_moves_player_position() -> void:
	var battle := _battle([{"definition_id": "v1_effect_test_gu", "rank": 1}], _enemy("attack", 0))
	var shift_slot: Dictionary = battle["gu_slots"][0].duplicate(true)
	shift_slot["effect"] = {"kind": "shift", "amount": 2}
	battle["gu_slots"][0] = shift_slot
	var out := V1.play_gu(battle, 0)
	assert_eq(int(out["battle"]["player"].get("position", 0)), 2)


func test_shield_effect_adds_to_player_shield() -> void:
	var battle := _battle([{"definition_id": "v1_effect_test_gu", "rank": 1}], _enemy("attack", 0))
	var shield_slot: Dictionary = battle["gu_slots"][0].duplicate(true)
	shield_slot["effect"] = {"kind": "shield", "amount": 3}
	battle["gu_slots"][0] = shield_slot
	battle["player"]["shield"] = 2
	var out := V1.play_gu(battle, 0)
	assert_eq(int(out["battle"]["player"]["shield"]), 5)


func test_aoe_strike_hits_all_living_enemies() -> void:
	var second := _enemy("attack", 0)
	second["id"] = "v1_test_enemy_2"
	var battle := _battle([{"definition_id": "v1_effect_test_gu", "rank": 1}],
			_enemy("attack", 0), second)
	var aoe_slot: Dictionary = battle["gu_slots"][0].duplicate(true)
	aoe_slot["effect"] = {"kind": "strike", "amount": 2, "aoe": true}
	battle["gu_slots"][0] = aoe_slot
	var out := V1.play_gu(battle, 0)
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 7)
	assert_eq(int(out["battle"]["enemies"][1]["hp"]), 7)


func test_support_bonus_adds_same_school_strike_damage() -> void:
	var battle := _battle([{"definition_id": "v1_effect_test_gu", "rank": 1}], _enemy("attack", 0))
	battle["turn_supports"] = {"blood": 2}
	var out := V1.play_gu(battle, 0)
	# base 2 + support 2 = 4 伤；敌 hp 9 → 5
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), 5,
			"support bonus must add to strike damage (9-4=5)")


# ---------- 测试工具 ----------

func _battle(entries: Array, enemy: Dictionary, extra: Dictionary = {}) -> Dictionary:
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
	var enemies := [enemy]
	if not extra.is_empty():
		enemies.append(extra)
	return V1.start(run, catalog, enemies)


func _play(battle: Dictionary, slot_index: int) -> Dictionary:
	return V1.player_action(battle, {"type": "play_gu", "slot_index": slot_index})["battle"]


func _enemy(kind: String, amount: int) -> Dictionary:
	var intent: Dictionary = {"kind": kind, "label": "测试意图"}
	if kind == "attack":
		intent["damage"] = amount
	return {"id": "v1_test_enemy", "label": "测试敌人", "hp": 9, "intent": intent}
