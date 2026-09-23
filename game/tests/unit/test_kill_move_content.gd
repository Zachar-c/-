extends GutTest


# 杀招·已发布数据的回归（2026-09-11 起 `v1_battle.kill_moves` 不再为空）。
#
# 引擎行为已由 `test_v1_battle_resolver.gd` 用**注入数据**锁住（配方门禁、成本扣除、
# 配方蛊标记 used_this_turn、化解判定）。本套只补它覆盖不到的一层：
#   **真正写进 `data/v1_battle.json` 的那几条杀招**能否过目录校验、能否在对应流派的
#   开局蛊组里出现、释放后是否真按声明的数值结算。
#
# 设计契约：`docs/superpowers/specs/2026-09-11-kill-move-design.md`（P1 内容先行）。

const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")
const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _enemy() -> Dictionary:
	return {
		"id": "km_content_enemy", "label": "试招木人", "hp": 40,
		"intent": {"kind": "attack", "label": "测试意图", "damage": 0},
	}


func _battle_for_school(school: String) -> Dictionary:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.catalog = catalog
	controller.start_new_run(101, school, [])
	var battle: Dictionary = V1.start(controller.state, catalog, [_enemy()])
	controller.free()
	return battle


func _ids(battle: Dictionary) -> Array:
	var out: Array = []
	for km_value in battle.get("kill_moves", []):
		out.append(str((km_value as Dictionary).get("id", "")))
	return out


func test_shipped_kill_moves_pass_catalog_validation() -> void:
	var loaded: Dictionary = ContentCatalog.load_and_validate_all()
	assert_eq(loaded.get("errors", []), [], "真实目录（含 kill_moves）必须零校验错误")
	var moves: Array = loaded.get("catalog", {}).get("v1_battle", {}).get("kill_moves", [])
	assert_gt(moves.size(), 0, "`v1_battle.kill_moves` 不再是空数组")
	var seen := {}
	for km_value in moves:
		var km: Dictionary = km_value
		var km_id := str(km.get("id", ""))
		assert_ne(km_id, "", "每条杀招都有 id")
		assert_false(seen.has(km_id), "杀招 id 不得重复：%s" % km_id)
		seen[km_id] = true
		assert_gt((km.get("recipe", []) as Array).size(), 0, "%s 配方非空" % km_id)
		assert_ne(str(km.get("label", "")), "", "%s 有玩家可见标签" % km_id)


func test_light_starter_receives_authored_kill_moves() -> void:
	var battle := _battle_for_school("light")
	var ids := _ids(battle)
	assert_true(ids.has("km_light_converge"), "光道开局可见「凝光」；实际=%s" % str(ids))
	assert_true(ids.has("km_light_bulwark"), "光道开局可见「明光壁」")
	assert_eq(V1.kill_move_reason(battle, "km_light_converge"), "", "门禁放行「凝光」")
	assert_eq(V1.kill_move_reason(battle, "km_light_bulwark"), "", "门禁放行「明光壁」")


func test_release_authored_kill_move_pays_costs_and_deals_damage() -> void:
	var battle := _battle_for_school("light")
	var hp_before := int(battle["enemies"][0]["hp"])
	var qi_before := int(battle["player"]["true_qi"])
	var thoughts_before := int(battle["player"]["thoughts"])

	var out := V1.player_action(battle, {"type": "play_kill_move", "kill_move_id": "km_light_converge"})
	assert_true(out["result"]["ok"], "释放成功：%s" % str(out["result"]))
	var next: Dictionary = out["battle"]
	assert_eq(int(next["enemies"][0]["hp"]), hp_before - 4, "「凝光」组件合成 strike 3+1")
	assert_eq(int(next["player"]["true_qi"]), qi_before - 3, "真元扣 3")
	assert_eq(int(next["player"]["thoughts"]), thoughts_before - 1, "念头扣 1")


func test_kill_move_composes_component_effects_not_prefab_damage() -> void:
	var battle := _battle_for_school("force")
	assert_true(_ids(battle).has("km_force_avalanche"), "力量开局可见「崩山」")
	var hp_before := int(battle["enemies"][0]["hp"])
	var out := V1.player_action(battle, {"type": "play_kill_move", "kill_move_id": "km_force_avalanche"})
	assert_true(out["result"]["ok"], "组件合成杀招可释放：%s" % str(out["result"]))
	# L0：force_gu strike2 + bear_strength healing 兜底；预制 damage:8 仅 LEGACY。
	assert_eq(int(out["battle"]["enemies"][0]["hp"]), hp_before - 2,
		"空 effect + damage 8 仍按固定伤害结算")


func test_kill_move_hidden_when_recipe_gu_missing() -> void:
	var battle := _battle_for_school("")
	var ids := _ids(battle)
	assert_false(ids.has("km_light_converge"), "散修没有月光蛊 → 不可见（实际=%s）" % str(ids))
	assert_false(ids.has("km_force_avalanche"), "散修缺熊力蛊 → 不可见")
	assert_false(ids.has("km_sword_double_edge_1"), "散修无剑蛊 → 不可见")


func test_used_kill_move_locks_its_recipe_gu_for_the_turn() -> void:
	var battle := _battle_for_school("light")
	var out := V1.player_action(battle, {"type": "play_kill_move", "kill_move_id": "km_light_bulwark"})
	assert_true(out["result"]["ok"])
	var next: Dictionary = out["battle"]
	var locked := 0
	for slot_value in next["gu_slots"]:
		if bool((slot_value as Dictionary).get("used_this_turn", false)):
			locked += 1
	assert_eq(locked, 2, "配方两只蛊本回合均被标记已用（与单蛊释放互斥）")
	assert_eq(int(next["player"]["shield"]), 3, "「明光壁」组件合成 shield 3")
