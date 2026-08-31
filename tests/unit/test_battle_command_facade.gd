extends GutTest


## V1 战斗门面测试（2026-08-30 全量替换卡牌战斗）：路由经
## BattleCommandFacade → V1BattleResolver（蛊行动制）。


const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const V1Script = preload("res://scripts/domain/v1_battle_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_start_builds_v1_battle_with_enemy_mapping() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)

	assert_eq((battle["enemies"] as Array).size(), 1)
	assert_eq(str(battle["enemies"][0]["id"]), "beast_swarm")
	assert_eq(int(battle["enemies"][0]["hp"]), 4)
	# 敌人无 kind 字段 → 默认 attack，伤害透传。
	assert_eq(str(battle["enemies"][0]["intent"]["kind"]), "attack")
	assert_eq(int(battle["enemies"][0]["intent"]["damage"]), 2)
	# 玩家资源：丙等×一转基础 10 → 真元 20。
	assert_eq(int(battle["player"]["true_qi_max"]), 20)
	# 战斗元信息透传。
	assert_eq(str(battle["enemy_kind"]), "beast_swarm")


func test_use_gu_routes_to_v1_and_spends_true_qi() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var instance_id := str(battle["gu_slots"][0]["instance_id"])

	var result: Dictionary = FacadeScript.apply_turn(battle, state, {
		"type": "use_gu", "instance_id": instance_id,
	}, catalog)

	assert_eq(result["result"], "ongoing")
	assert_eq(int(result["battle"]["player"]["true_qi"]), 19)
	assert_eq(int(result["battle"]["enemies"][0]["hp"]), 3)


func test_action_card_passthrough_basic_punch() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	battle["battle_id"] = "v1"

	var result: Dictionary = FacadeScript.apply_turn(battle, state, {
		"type": "action_card",
		"action_id": "battle.v1.basic.punch",
	}, catalog)

	assert_eq(result["result"], "ongoing")
	# 底蕴 1 → 每回合 2 念头；拳脚耗 1 → 剩 1。
	assert_eq(int(result["battle"]["player"]["thoughts"]), 1)


func test_unsupported_action_card_and_commands_rejected() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)

	var card: Dictionary = FacadeScript.apply_turn(battle, state, {
		"type": "action_card", "action_id": "battle.v1.some_card", "card_id": "x",
	}, catalog)
	assert_eq(card["result"], "rejected")
	assert_eq(card["feeds"], ["unsupported_battle_action"])

	var dodge: Dictionary = FacadeScript.apply_turn(battle, state, {"type": "basic_dodge"}, catalog)
	assert_eq(dodge["result"], "rejected")

	var unknown: Dictionary = FacadeScript.apply_turn(battle, state, {"type": "not_a_battle_command"}, catalog)
	assert_eq(unknown["result"], "rejected")
	assert_eq(unknown["feeds"], ["unsupported_battle_action"])


func test_facade_rejects_empty_and_terminal_battle() -> void:
	var state := RunState.new_run(101)
	var empty: Dictionary = FacadeScript.apply_turn({}, state, {"type": "end_turn"}, catalog)
	assert_eq(empty["result"], "rejected")
	assert_eq(empty["feeds"], ["battle_missing"])

	state = state.finalize_death()
	var terminal: Dictionary = FacadeScript.apply_turn({"phase": "player"}, state, {"type": "end_turn"}, catalog)
	assert_eq(terminal["result"], "rejected")
	assert_eq(terminal["feeds"], ["terminal_run"])


func test_end_turn_resolves_enemy_and_reopens_player_turn() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)

	var result: Dictionary = FacadeScript.apply_turn(battle, state, {"type": "end_turn"}, catalog)

	assert_eq(result["result"], "ongoing")
	# 敌人 2 伤，玩家气血 80→78；真元按回复 +5（20 满则不变）。
	assert_eq(int(result["battle"]["player"]["hp"]), 78)
	assert_eq(int(result["battle"]["turn"]), 2)
	assert_eq(int(result["battle"]["player"]["thoughts"]), 2)


func test_victory_marks_finished() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var instance_id := str(battle["gu_slots"][0]["instance_id"])
	# 小光蛊 1 伤/回合（usedThisTurn 每回合一次），4 回合击毙 4 血敌人。
	var out: Dictionary = {}
	for turn_count in 5:
		out = FacadeScript.apply_turn(battle, state, {"type": "use_gu", "instance_id": instance_id}, catalog)
		battle = out["battle"]
		state = out["state"]
		if out["result"] == "victory":
			break
		if out["result"] == "death":
			break
		out = FacadeScript.apply_turn(battle, state, {"type": "end_turn"}, catalog)
		battle = out["battle"]
		state = out["state"]

	assert_eq(out["result"], "victory")
	assert_true(bool(out["finished"]))


func test_retreat_finishes_battle() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)

	var result: Dictionary = FacadeScript.apply_turn(battle, state, {"type": "retreat"}, catalog)

	assert_eq(result["result"], "retreat")
	assert_true(bool(result["finished"]))


func test_boss_identity_flows_into_flags_and_blocks_retreat() -> void:
	var state := RunState.new_run(101)
	# 敌方定义为 tier=="boss" → start() 自动落 flags.boss_battle。
	var boss: Dictionary = FacadeScript.start({"enemy_kind": "miasma_vein_lord"}, state, catalog)
	assert_true(bool(boss["flags"].get("boss_battle", false)),
			"boss-tier enemy must set flags.boss_battle")
	var retreat: Dictionary = FacadeScript.apply_turn(boss, state, {"type": "retreat"}, catalog)
	assert_eq(retreat["result"], "rejected")
	assert_eq(retreat["feeds"], ["retreat_forbidden"])
	# 关底台 layer_boss 透传（_start_battle → encounter）→ 同样禁撤。
	var stand: Dictionary = FacadeScript.start({"enemy_kind": "ridge_hound", "layer_boss": 2}, state, catalog)
	assert_true(bool(stand["flags"].get("boss_battle", false)),
			"layer_boss stand must set flags.boss_battle")
	# 普通战斗不落 Boss 旗标、可撤。
	var common: Dictionary = FacadeScript.start({"enemy_kind": "ridge_hound"}, state, catalog)
	assert_false(bool(common["flags"].get("boss_battle", false)), "trivial fight must not be a boss")
	var out: Dictionary = FacadeScript.apply_turn(common, state, {"type": "retreat"}, catalog)
	assert_eq(out["result"], "retreat")


func test_enemy_first_mover_resolves_before_player() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm", "first_mover": "enemy"}, state, catalog)

	var pre: Dictionary = FacadeScript.apply_enemy_pre_turn(battle, state, catalog)

	assert_eq(int(pre["battle"]["player"]["hp"]), 78)
	# 敌人先手一次完整回合后，战斗进入第 2 回合（玩家行动阶段）。
	assert_eq(int(pre["battle"]["turn"]), 2)
	assert_eq(pre["finished"], false)


func test_facade_is_deterministic_for_same_seed_and_command_sequence() -> void:
	assert_eq(_run_sequence(4242), _run_sequence(4242))


func _run_sequence(seed_value: int) -> Dictionary:
	var state := RunState.new_run(seed_value)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var instance_id := str(battle["gu_slots"][0]["instance_id"])
	var first: Dictionary = FacadeScript.apply_turn(battle, state, {"type": "use_gu", "instance_id": instance_id}, catalog)
	return {
		"battle": first["battle"],
		"result": first["result"],
		"feeds": first["feeds"],
	}
