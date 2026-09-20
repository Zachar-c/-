extends GutTest


## SIDE-FIX 2026-09-19 A/B：敌人 phases 运行时 + essence_burn 结算。
## 语义来源：data/enemies.json → miasma_vein_lord._phases_note（唯一语义说明），
## 已与 wenzhen-web-lab/js/rules.js 的 activePhase/intentReady/selectIntent 核对一致。
## 多意图优先级数据未写明 → 取数据顺序（原型口径，见断言注释）。
## 本文件只经 BattleCommandFacade 提交命令；战斗中段血量用白盒直设（纯夹具捷径）。


const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const V1ResolverScript = preload("res://scripts/domain/v1_battle_resolver.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _reasons(battle: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for entry_value in (battle.get("log", []) as Array):
		out.append(str((entry_value as Dictionary).get("reason", "")))
	return out


func _wound(battle: Dictionary, enemy_id: String, hp: int) -> Dictionary:
	var next: Dictionary = battle.duplicate(true)
	for i in (next["enemies"] as Array).size():
		var enemy: Dictionary = next["enemies"][i]
		if str(enemy.get("id", "")) == enemy_id:
			var wounded: Dictionary = (enemy as Dictionary).duplicate(true)
			wounded["hp"] = hp
			if hp <= 0:
				wounded["alive"] = false
			next["enemies"][i] = wounded
	return next


func test_phases_carried_into_battle_with_initial_phase() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "thunder_crown_sovereign"}, state, catalog)
	var enemy: Dictionary = battle["enemies"][0]

	assert_eq((enemy.get("phases", []) as Array).size(), 2)
	assert_eq(int(enemy.get("phase_index", -99)), 0)
	assert_true((enemy.get("last_fired", {}) as Dictionary).is_empty())
	assert_eq(int(enemy["intent"].get("cooldown", -99)), 1)
	assert_eq(str(enemy["intent"].get("id", "")), "crown_bolt")


func test_active_phase_index_follows_hp_ratio() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "thunder_crown_sovereign"}, state, catalog)
	var max_hp := int(battle["enemies"][0]["max_hp"])

	assert_eq(V1ResolverScript.active_phase_index(battle["enemies"][0]), 0)
	# 恰好 50% 落入第二阶段（until_hp_ratio >= 当前血量比取最后一个）。
	var half: Dictionary = _wound(battle, "thunder_crown_sovereign", int(max_hp / 2))["enemies"][0]
	assert_eq(V1ResolverScript.active_phase_index(half), 1)
	var low: Dictionary = _wound(battle, "thunder_crown_sovereign", 1)["enemies"][0]
	assert_eq(V1ResolverScript.active_phase_index(low), 1)


func test_cooldown_gate_single_phase_boss_waits() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "thunder_crown_sovereign"}, state, catalog)
	var hp0 := int(battle["player"]["hp"])

	# T1：crown_bolt（cooldown 1）发出。
	var t1 := FacadeScript.apply_turn(battle, state, {"type": "end_turn"}, catalog)
	assert_true(bool(t1["accepted"]))
	assert_eq(int(t1["battle"]["player"]["hp"]), hp0 - 4)
	assert_eq(int((t1["battle"]["enemies"][0]["last_fired"] as Dictionary).get("crown_bolt", -1)), 1)

	# T2：唯一意图仍在冷却（2 < 1+1+1）→ cooldown_wait，什么都不做。
	var t2 := FacadeScript.apply_turn(t1["battle"], t1["state"], {"type": "end_turn"}, catalog)
	assert_true(bool(t2["accepted"]))
	assert_eq(int(t2["battle"]["player"]["hp"]), int(t1["battle"]["player"]["hp"]))
	assert_true(_reasons(t2["battle"]).has("cooldown_wait"))

	# T3：冷却完毕（3 >= 1+1+1）→ 再次发出。
	var t3 := FacadeScript.apply_turn(t2["battle"], t2["state"], {"type": "end_turn"}, catalog)
	assert_eq(int(t3["battle"]["player"]["hp"]), int(t2["battle"]["player"]["hp"]) - 4)


func test_phase_shift_logged_and_second_phase_intent_fires() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "thunder_crown_sovereign"}, state, catalog)
	var max_hp := int(battle["enemies"][0]["max_hp"])

	var t1 := FacadeScript.apply_turn(battle, state, {"type": "end_turn"}, catalog)
	var t2 := FacadeScript.apply_turn(t1["battle"], t1["state"], {"type": "end_turn"}, catalog)
	# 血量打到 50% 以下再进 T3：阶段切换必须有可观测记录。
	var wounded: Dictionary = _wound(t2["battle"], "thunder_crown_sovereign", int(max_hp / 2) - 1)
	var t3 := FacadeScript.apply_turn(wounded, t2["state"], {"type": "end_turn"}, catalog)

	assert_eq(int(t3["battle"]["enemies"][0]["phase_index"]), 1)
	assert_true(_reasons(t3["battle"]).has("phase_shift"))
	# T3 时 crown_bolt 冷却完毕（3 >= 1+1+1）→ 数据顺序第一条先发。
	assert_eq(int((t3["battle"]["enemies"][0]["last_fired"] as Dictionary).get("crown_bolt", -1)), 3)


func test_essence_burn_deducts_true_qi_with_log() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "thunder_crown_sovereign"}, state, catalog)
	var max_hp := int(battle["enemies"][0]["max_hp"])

	var t1 := FacadeScript.apply_turn(battle, state, {"type": "end_turn"}, catalog)
	var t2 := FacadeScript.apply_turn(t1["battle"], t1["state"], {"type": "end_turn"}, catalog)
	var wounded: Dictionary = _wound(t2["battle"], "thunder_crown_sovereign", int(max_hp / 2) - 1)
	var t3 := FacadeScript.apply_turn(wounded, t2["state"], {"type": "end_turn"}, catalog)
	# T4：crown_bolt 在冷却（4 < 3+1+1），第二条 paralyzing_howl（焚元 2）发出。
	var qi_before := int(t3["battle"]["player"]["true_qi"])
	var qi_max := int(t3["battle"]["player"]["true_qi_max"])
	var regen := int(t3["battle"]["player"]["regen"])
	var hp_before := int(t3["battle"]["player"]["hp"])
	var t4 := FacadeScript.apply_turn(t3["battle"], t3["state"], {"type": "end_turn"}, catalog)

	assert_eq(int((t4["battle"]["enemies"][0]["last_fired"] as Dictionary).get("paralyzing_howl", -1)), 4,
			"howl must have fired on T4 while crown_bolt rested")
	assert_true(_reasons(t4["battle"]).has("essence_burn"))
	assert_eq(int(t4["battle"]["player"]["true_qi"]), mini(qi_max, qi_before - 2 + regen))
	assert_eq(int(t4["battle"]["player"]["hp"]), hp_before, "howl damage is 0")


func test_seal_kind_phase_intent_settles() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "clan_patriarch"}, state, catalog)
	var max_hp := int(battle["enemies"][0]["max_hp"])

	var t1 := FacadeScript.apply_turn(battle, state, {"type": "end_turn"}, catalog)
	# T1 发出 clan_wrath；压血进二阶段后 T2 wrath 在冷却 → clan_muster（seal 2）发出。
	var wounded: Dictionary = _wound(t1["battle"], "clan_patriarch", int(max_hp / 2) - 1)
	var t2 := FacadeScript.apply_turn(wounded, t1["state"], {"type": "end_turn"}, catalog)

	assert_eq(int(t2["battle"]["enemies"][0]["phase_index"]), 1)
	assert_true(_reasons(t2["battle"]).has("sealed"))


func test_single_intent_cooldown_gate() -> void:
	var probe := catalog.duplicate(true)
	probe["enemy_by_id"]["cooldown_probe"] = {
		"id": "cooldown_probe", "label": "试敌", "hp": 30,
		"intent": {"id": "probe_hit", "kind": "attack", "damage": 2, "label": "扑击", "cooldown": 1},
	}
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "cooldown_probe"}, state, probe)
	var hp0 := int(battle["player"]["hp"])

	var t1 := FacadeScript.apply_turn(battle, state, {"type": "end_turn"}, probe)
	assert_eq(int(t1["battle"]["player"]["hp"]), hp0 - 2)
	var t2 := FacadeScript.apply_turn(t1["battle"], t1["state"], {"type": "end_turn"}, probe)
	assert_eq(int(t2["battle"]["player"]["hp"]), int(t1["battle"]["player"]["hp"]))
	assert_true(_reasons(t2["battle"]).has("cooldown_wait"))
	var t3 := FacadeScript.apply_turn(t2["battle"], t2["state"], {"type": "end_turn"}, probe)
	assert_eq(int(t3["battle"]["player"]["hp"]), int(t2["battle"]["player"]["hp"]) - 2)


func test_zero_cooldown_enemies_unaffected() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var hp0 := int(battle["player"]["hp"])

	var t1 := FacadeScript.apply_turn(battle, state, {"type": "end_turn"}, catalog)
	assert_eq(int(t1["battle"]["player"]["hp"]), hp0 - 2)
	# cooldown 缺省 0 → 每回合就绪，行为与补线前一致。
	var t2 := FacadeScript.apply_turn(t1["battle"], t1["state"], {"type": "end_turn"}, catalog)
	assert_eq(int(t2["battle"]["player"]["hp"]), int(t1["battle"]["player"]["hp"]) - 2)
	assert_false(_reasons(t2["battle"]).has("cooldown_wait"))


func test_non_attack_kind_burn_still_deducts() -> void:
	# SIDE-FIX 收尾 B：焚元对任何 kind 生效。合成夹具 kind=seal + essence_burn=2。
	var probe := catalog.duplicate(true)
	probe["enemy_by_id"]["burn_seal_probe"] = {
		"id": "burn_seal_probe", "label": "试敌", "hp": 30,
		"intent": {"id": "seal_burn", "kind": "seal", "seal_turns": 1, "essence_burn": 2, "label": "封印焚元", "cooldown": 0},
	}
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "burn_seal_probe"}, state, probe)
	var qi_before := int(battle["player"]["true_qi"])
	var qi_max := int(battle["player"]["true_qi_max"])
	var regen := int(battle["player"]["regen"])

	var t1 := FacadeScript.apply_turn(battle, state, {"type": "end_turn"}, probe)

	assert_true(_reasons(t1["battle"]).has("essence_burn"), "seal-kind intent with burn must settle burn")
	assert_eq(int(t1["battle"]["player"]["true_qi"]), mini(qi_max, qi_before - 2 + regen))
