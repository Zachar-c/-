extends GutTest


## V1 战斗引擎测试（蛊行动制，2026-08-30）。
## 规则锚点：《蛊真人同人 Roguelike V1 战斗规则完整文档》。
## 演示蛊定义注入 catalog 副本，避免扰动蛊池计数锁。


const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = _catalog_with_demo_gu()


func test_start_builds_player_resources_from_runstate() -> void:
	var run := _run_with_gu([{"definition_id": "small_light_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 2)])

	assert_eq(int(battle["player"]["hp"]), 80)
	assert_eq(int(battle["player"]["life_time"]), 60)
	assert_eq(int(battle["player"]["soul"]), 1)
	# 2026-08-31 统一行动点：魂魄底蕴 1 → 每回合 2 行动（念头）。
	assert_eq(int(battle["player"]["thoughts"]), 2)
	assert_eq(int(battle["player"]["used_this_turn"]), 0)
	# 丙等资质（开局）2 倍、一转境界基础 10 → 真元上限 20，回复 ceil(20×25%)=5。
	assert_eq(int(battle["player"]["true_qi"]), 20)
	assert_eq(int(battle["player"]["true_qi_max"]), 20)
	assert_eq(int(battle["player"]["regen"]), 5)
	assert_eq(str(battle["player"]["aptitude"]), "bing")
	assert_eq(str(battle["phase"]), "player_action")


func test_aptitude_jia_scales_true_qi_max() -> void:
	var run := _run_with_gu([])
	run.cultivator["aptitude"] = "jia"
	run.aptitude = "jia"
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	# 甲等 4 倍：一转基础 10 → 40；回复 ceil(40×35%)=14。
	assert_eq(int(battle["player"]["true_qi_max"]), 40)
	assert_eq(int(battle["player"]["true_qi"]), 40)
	assert_eq(int(battle["player"]["regen"]), 14)


func test_non_combat_gu_are_filtered_out() -> void:
	var run := _run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "v1_market_gu", "rank": 1},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	assert_eq((battle["gu_slots"] as Array).size(), 1)
	assert_eq(str(battle["gu_slots"][0]["definition_id"]), "small_light_gu")


func test_instant_gu_cast_spends_true_qi_thought_and_marks_used() -> void:
	var run := _run_with_gu([{"definition_id": "small_light_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])

	var out := V1.player_action(battle, {"type": "play_gu", "slot_index": 0})
	var next: Dictionary = out["battle"]

	assert_true(out["result"]["ok"])
	assert_eq(int(next["player"]["true_qi"]), 19)
	assert_eq(int(next["player"]["thoughts"]), 1)
	assert_eq(int(next["player"]["used_this_turn"]), 1)
	assert_true(bool(next["gu_slots"][0]["used_this_turn"]))
	assert_eq(int(next["enemies"][0]["hp"]), 9 - 1)


func test_gu_cast_rejections_have_distinct_reasons() -> void:
	var run := _run_with_gu([{"definition_id": "small_light_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	# 用掉两次行动（魂魄底蕴 4，上限充裕）后再验证各拒绝路径。
	battle["gu_slots"][0]["is_sealed"] = true
	assert_eq(str(V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["result"]["reason"]), "gu_sealed")

	var unsealed := V1.start(_run_with_gu([{"definition_id": "small_light_gu", "rank": 1}]), catalog, [_enemy("attack", 0)])
	unsealed["gu_slots"][0]["used_this_turn"] = true
	assert_eq(str(V1.player_action(unsealed, {"type": "play_gu", "slot_index": 0})["result"]["reason"]), "gu_used_this_turn")

	var no_qi := V1.start(_run_with_gu([{"definition_id": "small_light_gu", "rank": 1}]), catalog, [_enemy("attack", 0)])
	no_qi["player"]["true_qi"] = 0
	assert_eq(str(V1.player_action(no_qi, {"type": "play_gu", "slot_index": 0})["result"]["reason"]), "insufficient_true_qi")


func test_action_limit_equals_soul_capacity() -> void:
	var run := _run_with_gu([{"definition_id": "small_light_gu", "rank": 1}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["player"]["used_this_turn"] = 2  # 底蕴 1 → 每回合 2 行动，已满
	assert_eq(str(V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["result"]["reason"]), "action_limit_reached")
	assert_eq(str(V1.player_action(battle, {"type": "basic_attack"})["result"]["reason"]), "action_limit_reached")


func test_consume_on_use_permanent_destroys_and_buffs() -> void:
	var run := _run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "v1_flame_shield_gu", "rank": 1},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])

	var out := V1.player_action(battle, {"type": "play_gu", "slot_index": 1})
	var next: Dictionary = out["battle"]

	assert_true(out["result"]["ok"])
	assert_true(bool(next["gu_slots"][1]["consumed"]))
	assert_eq((next["active_permanents"] as Array).size(), 0)
	assert_eq(int(next["player"]["shield"]), 2)


func test_trigger_cost_permanent_blocks_once_and_closes_on_broke() -> void:
	var run := _run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "v1_blood_reflect_gu", "rank": 1},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 5)])
	# 激活血反蛊（TRIGGER_COST，trigger 1 真元 / block 2）。
	battle = V1.player_action(battle, {"type": "play_gu", "slot_index": 1})["battle"]
	assert_eq((battle["active_permanents"] as Array).size(), 1)

	# 敌人 5 伤 → 触发扣 1 真元挡 2 → 玩家掉 3 血。
	battle = V1.end_turn(battle)["battle"]
	assert_eq(int(battle["player"]["hp"]), 80 - 3)

	# 真元不足时蛊关闭、全额承伤。
	var broke := V1.start(run, catalog, [_enemy("attack", 5)])
	broke = V1.player_action(broke, {"type": "play_gu", "slot_index": 1})["battle"]
	broke["player"]["true_qi"] = 0
	broke = V1.end_turn(broke)["battle"]
	assert_eq(int(broke["player"]["hp"]), 80 - 5)
	assert_eq((broke["active_permanents"] as Array).size(), 0)


func test_per_turn_maintain_paid_or_all_close() -> void:
	var run := _run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "v1_iron_skin_gu", "rank": 1},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle = V1.player_action(battle, {"type": "play_gu", "slot_index": 1})["battle"]
	var qi_before := int(battle["player"]["true_qi"])

	# 维持扣费 1：真元充足 → 扣费后回合开始再回复。
	battle = V1.end_turn(battle)["battle"]
	assert_true((battle["active_permanents"] as Array).has("gu_002"))

	# 真元不足（回复前先压到底且上限为 0，回复后仍不足）→ 全部常驻关闭。
	battle["player"]["true_qi"] = 0
	battle["player"]["true_qi_max"] = 0
	battle = V1.end_turn(battle)["battle"]
	assert_eq((battle["active_permanents"] as Array).size(), 0)


func test_seal_blocks_gu_and_expires_by_countdown() -> void:
	var run := _run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "moonlight_gu", "rank": 1},
	])
	# 敌人每回合施放 2 回合封印：敌人回合上封印，玩家回合开始倒计时到 1 仍封印。
	var battle: Dictionary = V1.start(run, catalog, [_enemy("seal", 2)])
	battle = V1.end_turn(battle)["battle"]
	var sealed_slot := -1
	for i in (battle["gu_slots"] as Array).size():
		if bool(battle["gu_slots"][i]["is_sealed"]):
			sealed_slot = i
	assert_true(sealed_slot >= 0, "enemy seal intent must seal one gu")
	assert_eq(str(V1.player_action(battle, {"type": "play_gu", "slot_index": sealed_slot})["result"]["reason"]), "gu_sealed")

	# 倒计时归零解除封印（手动造 1 回合封印后结束回合验证）。
	var expiring := V1.start(_run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "moonlight_gu", "rank": 1},
	]), catalog, [_enemy("attack", 0)])
	expiring["gu_slots"][0]["is_sealed"] = true
	expiring["gu_slots"][0]["seal_turns"] = 1
	expiring = V1.end_turn(expiring)["battle"]
	assert_false(bool(expiring["gu_slots"][0]["is_sealed"]))


func test_soul_drain_intent_lowers_cap_and_can_kill() -> void:
	var run := _run_with_gu([])
	run.cultivator["soul"] = 4  # 显式底蕴 4：抽 3 → 剩 1，行动分档随之降档
	var battle: Dictionary = V1.start(run, catalog, [_enemy("soul_drain", 3)])
	battle = V1.end_turn(battle)["battle"]
	assert_eq(int(battle["player"]["soul"]), 1)
	# 下一次灵魂耗竭致死。
	var dying := V1.start(run, catalog, [_enemy("soul_drain", 5)])
	dying = V1.end_turn(dying)["battle"]
	assert_eq(str(dying["phase"]), "defeat")
	assert_eq(str(dying["result"]["cause"]), "soul")


func test_life_cost_intent_kills() -> void:
	var run := _run_with_gu([])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("life_cost", 99)])
	battle = V1.end_turn(battle)["battle"]
	assert_eq(str(battle["phase"]), "defeat")
	assert_eq(str(battle["result"]["cause"]), "life_cost")


func test_life_cost_gu_dies_before_effect() -> void:
	var run := _run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "v1_desperate_strike_gu", "rank": 1},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])

	var out := V1.player_action(battle, {"type": "play_gu", "slot_index": 1})
	var next: Dictionary = out["battle"]

	assert_false(out["result"]["ok"])
	assert_eq(str(out["result"]["reason"]), "life_cost_depleted")
	assert_eq(str(next["phase"]), "defeat")
	# 效果不执行：敌人满血。
	assert_eq(int(next["enemies"][0]["hp"]), 9)


func test_kill_move_requires_recipe_and_pays_costs() -> void:
	var run := _run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "moonlight_gu", "rank": 1},
	])
	catalog["v1_battle"]["kill_moves"] = [{
		"id": "km_moon_beam", "label": "月芒贯杀", "tag": "moon",
		"recipe": ["small_light_gu", "moonlight_gu"],
		"true_qi_cost": 8, "thought_cost": 1, "life_cost": 0,
		"damage": 6,
	}]
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	var qi_before := int(battle["player"]["true_qi"])

	var out := V1.player_action(battle, {"type": "play_kill_move", "kill_move_id": "km_moon_beam"})
	var next: Dictionary = out["battle"]

	assert_true(out["result"]["ok"])
	assert_eq(int(next["player"]["true_qi"]), qi_before - 8)
	assert_eq(int(next["player"]["thoughts"]), 1)
	# 配方蛊本回合不可再单独释放。
	assert_true(bool(next["gu_slots"][0]["used_this_turn"]))
	assert_true(bool(next["gu_slots"][1]["used_this_turn"]))
	assert_eq(int(next["enemies"][0]["hp"]), 9 - 6)


func test_kill_move_counter_hidden_reveals_and_nullifies() -> void:
	var run := _run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "moonlight_gu", "rank": 1},
	])
	catalog["v1_battle"]["kill_moves"] = [{
		"id": "km_moon_beam", "label": "月芒贯杀", "tag": "moon",
		"recipe": ["small_light_gu", "moonlight_gu"],
		"true_qi_cost": 8, "thought_cost": 1, "life_cost": 0,
		"damage": 6,
	}]
	var battle: Dictionary = V1.start(run, catalog, [_enemy("counter", 0)])
	battle["enemies"][0]["counter_hidden"] = ["moon"]

	var out := V1.player_action(battle, {"type": "play_kill_move", "kill_move_id": "km_moon_beam"})
	var next: Dictionary = out["battle"]

	assert_true(out["result"]["ok"])
	assert_eq(str(out["result"]["reason"]), "countered")
	# 资源照扣但效果无效，敌人满血。
	assert_eq(int(next["enemies"][0]["hp"]), 9)
	assert_true((next["enemies"][0]["counter_revealed"] as Array).has("moon"))


func test_kill_move_rejected_when_recipe_sealed() -> void:
	var run := _run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "moonlight_gu", "rank": 1},
	])
	catalog["v1_battle"]["kill_moves"] = [{
		"id": "km_moon_beam", "label": "月芒贯杀", "tag": "moon",
		"recipe": ["small_light_gu", "moonlight_gu"],
		"true_qi_cost": 8, "thought_cost": 1, "life_cost": 0,
		"damage": 6,
	}]
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["gu_slots"][0]["is_sealed"] = true

	var out := V1.player_action(battle, {"type": "play_kill_move", "kill_move_id": "km_moon_beam"})

	assert_false(out["result"]["ok"])
	assert_eq(str(out["result"]["reason"]), "kill_move_recipe_sealed")


func test_basic_attack_costs_thought_and_uses_force_buff() -> void:
	var run := _run_with_gu([])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["player"]["buffs"]["force"] = 2

	var out := V1.player_action(battle, {"type": "basic_attack"})
	var next: Dictionary = out["battle"]

	assert_true(out["result"]["ok"])
	assert_eq(int(next["player"]["thoughts"]), 1)
	assert_eq(int(next["player"]["used_this_turn"]), 1)
	# 基础 1 + 力道 2 = 3。
	assert_eq(int(next["enemies"][0]["hp"]), 9 - 3)


func test_end_turn_regen_resets_thoughts_and_used() -> void:
	var run := _run_with_gu([])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["player"]["true_qi"] = 10
	battle["player"]["thoughts"] = 1
	battle["player"]["used_this_turn"] = 3

	battle = V1.end_turn(battle)["battle"]

	# 敌人 0 伤；回合 +1 后：真元回复 +5（10→15）、念头回满=魂魄分档行动数、行动清零。
	assert_eq(int(battle["turn"]), 2)
	assert_eq(int(battle["player"]["true_qi"]), 15)
	assert_eq(int(battle["player"]["thoughts"]), 2)
	assert_eq(int(battle["player"]["used_this_turn"]), 0)


func test_victory_when_all_enemies_dead() -> void:
	var run := _run_with_gu([
		{"definition_id": "small_light_gu", "rank": 1},
		{"definition_id": "moonlight_gu", "rank": 1},
	])
	var battle: Dictionary = V1.start(run, catalog, [{"id": "v1_test_enemy", "label": "测试敌人", "hp": 4, "intent": {"kind": "attack", "damage": 0, "label": "蓄力"}}])

	battle = V1.player_action(battle, {"type": "play_gu", "slot_index": 1})["battle"]  # 3 伤
	battle = V1.player_action(battle, {"type": "play_gu", "slot_index": 0})["battle"]  # 1 伤

	assert_eq(str(battle["phase"]), "victory")
	assert_eq(str(battle["result"]["outcome"]), "victory")


func test_thoughts_zero_blocks_actions_until_turn_reset() -> void:
	var run := _run_with_gu([])
	var battle: Dictionary = V1.start(run, catalog, [_enemy("attack", 0)])
	battle["player"]["thoughts"] = 0

	assert_eq(str(V1.player_action(battle, {"type": "basic_attack"})["result"]["reason"]), "insufficient_thought")


# ---------- 测试工具 ----------

func _catalog_with_demo_gu() -> Dictionary:
	var cat := ContentCatalog.load_all()
	cat["gu_by_id"]["v1_market_gu"] = {"id": "v1_market_gu", "combat": "none", "school": "refine", "role": "logistics", "rarity": "common"}
	cat["gu_by_id"]["v1_flame_shield_gu"] = {
		"id": "v1_flame_shield_gu", "combat": "shield", "school": "qi", "role": "defense", "rarity": "common",
		"is_permanent": true, "durability_mode": "CONSUME_ON_USE", "duration_turn": 2,
		"true_qi_cost": 2, "v1_effect": {"kind": "shield", "amount": 2},
	}
	cat["gu_by_id"]["v1_blood_reflect_gu"] = {
		"id": "v1_blood_reflect_gu", "combat": "reflect", "school": "blood", "role": "defense", "rarity": "common",
		"is_permanent": true, "durability_mode": "TRIGGER_COST",
		"true_qi_cost": 1, "trigger_qi_cost": 1, "trigger_block": 2, "v1_effect": {"kind": "strike", "amount": 1},
	}
	cat["gu_by_id"]["v1_iron_skin_gu"] = {
		"id": "v1_iron_skin_gu", "combat": "iron_skin", "school": "force", "role": "defense", "rarity": "common",
		"is_permanent": true, "durability_mode": "PER_TURN_MAINTAIN",
		"true_qi_cost": 1, "maintain_qi_cost": 1, "v1_effect": {"kind": "buff", "name": "force", "amount": 1},
	}
	cat["gu_by_id"]["v1_desperate_strike_gu"] = {
		"id": "v1_desperate_strike_gu", "combat": "desperate", "school": "blood", "role": "attack", "rarity": "common",
		"true_qi_cost": 1, "life_cost": 61, "v1_effect": {"kind": "strike", "amount": 10},
	}
	return cat


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


func _enemy(kind: String, amount: int) -> Dictionary:
	var intent: Dictionary = {"kind": kind, "label": "测试意图"}
	match kind:
		"attack":
			intent["damage"] = amount
		"seal":
			intent["seal_turns"] = maxi(1, amount)
		"soul_drain":
			intent["soul_drain"] = amount
		"life_cost":
			intent["life_cost"] = amount
		"counter":
			intent["counter_tag"] = "moon"
	return {"id": "v1_test_enemy", "label": "测试敌人", "hp": 9, "intent": intent}
