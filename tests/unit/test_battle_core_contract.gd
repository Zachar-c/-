extends GutTest


## 第三阶段 Task 1：战斗核心模块契约测试（状态机 + 单一入口 + 拒绝语义）。
## 覆盖：absent → player_action → 敌意结算 → player_action → victory/defeat/retreat。
## 本文件只经 BattleCommandFacade 提交命令，不直接读写 V1BattleResolver 内部状态。


const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const ActionPointsScript = preload("res://scripts/domain/action_points.gd")
## Task 3：战斗行动预览是门禁与结构化命令的唯一来源。
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const V1ResolverScript = preload("res://scripts/domain/v1_battle_resolver.gd")

## Task 4：battle.phase 只允许这三个取值。
const PHASES := ["player_action", "victory", "defeat"]
## apply_turn 的稳定返回结构（Task 4）。
const TURN_KEYS := ["battle", "state", "result", "feeds", "accepted", "finished"]
## Task 3 十键契约（计划原文）：预览产出的每张战斗卡都必须齐备这些键。
const CARD_KEYS := [
	"id", "type", "executable", "block_reason", "costs",
	"target_type", "valid_target_ids", "command", "state_version", "expected_phase",
]
## 只承载展示性门禁、领域不设对应拦截的卡（撤离的元石/地形条件是遗留预览语义，
## 领域 retreat 分支目前只拦 Boss）。差异不在本文件断言方向，登记为待裁定项。
const PREVIEW_ONLY_GATES := ["battle.retreat"]

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


# ---------- 状态机构建 ----------

func test_start_creates_player_action_phase_and_public_intent() -> void:
	var state := RunState.new_run(101)
	var battle := _start(state, _probe_catalog())

	assert_eq(str(battle["phase"]), "player_action")
	assert_eq(int(battle["turn"]), 1)
	assert_eq((battle["enemies"] as Array).size(), 1, "start must build the encounter enemies")
	var intent: Dictionary = battle["enemies"][0]["intent"]
	assert_eq(str(intent["kind"]), "attack")
	assert_eq(int(intent["damage"]), 2)
	assert_true(not str(intent["label"]).is_empty(), "enemy intent must be public at battle start")
	# 念头预算 = 魂魄底蕴分档；真元上限 = 境界基础 × 资质倍率。
	assert_eq(int(battle["player"]["thoughts"]), ActionPointsScript.per_turn(int(battle["player"]["soul"])))
	assert_eq(int(battle["player"]["used_this_turn"]), 0)


func test_use_gu_spends_true_qi_and_thoughts_once_per_turn() -> void:
	var state := RunState.new_run(101)
	var battle := _start(state, _probe_catalog())
	var instance_id := str(battle["gu_slots"][0]["instance_id"])
	var slot: Dictionary = battle["gu_slots"][0]

	var first := FacadeScript.apply_turn(battle, state, {"type": "use_gu", "instance_id": instance_id}, catalog)
	assert_true(bool(first["accepted"]))
	assert_eq(str(first["result"]), "ongoing")
	assert_true(first.has("finished"))
	assert_false(bool(first["finished"]))
	assert_eq(int(first["battle"]["player"]["true_qi"]), int(battle["player"]["true_qi"]) - int(slot["true_qi_cost"]))
	assert_eq(int(first["battle"]["player"]["thoughts"]), int(battle["player"]["thoughts"]) - int(slot["thought_cost"]))
	assert_eq(int(first["battle"]["player"]["used_this_turn"]), 1)

	var second := FacadeScript.apply_turn(first["battle"], first["state"], {"type": "use_gu", "instance_id": instance_id}, catalog)
	assert_eq(second["result"], "rejected")
	assert_eq(second["feeds"], ["gu_used_this_turn"], "one gu slot may only fire once per turn")
	assert_eq(second["battle"], first["battle"], "a rejected command must not touch the battle")


func test_end_turn_resolves_public_intent_and_opens_next_turn() -> void:
	var state := RunState.new_run(101)
	var battle := _start(state, _probe_catalog())
	var instance_id := str(battle["gu_slots"][0]["instance_id"])
	var used := FacadeScript.apply_turn(battle, state, {"type": "use_gu", "instance_id": instance_id}, catalog)

	var turn := FacadeScript.apply_turn(used["battle"], used["state"], {"type": "end_turn"}, catalog)

	assert_true(bool(turn["accepted"]))
	assert_eq(str(turn["result"]), "ongoing")
	assert_eq(int(turn["battle"]["turn"]), 2)
	assert_eq(str(turn["battle"]["phase"]), "player_action")
	assert_eq(int(turn["battle"]["player"]["hp"]), int(battle["player"]["hp"]) - 2, "end_turn must resolve the public intent")
	assert_eq(int(turn["battle"]["player"]["used_this_turn"]), 0, "a new turn resets the per-turn budget")
	# 每回合一次的限制随回合边界解除。
	var again := FacadeScript.apply_turn(turn["battle"], turn["state"], {"type": "use_gu", "instance_id": instance_id}, catalog)
	assert_true(bool(again["accepted"]), "the per-turn gu lock must clear on the next turn")


func test_enemy_first_and_player_end_turn_share_one_settlement_path() -> void:
	var first_state := RunState.new_run(101)
	var first_battle := _start(first_state, _probe_catalog(), {"first_mover": "enemy"})
	var pre := FacadeScript.apply_enemy_pre_turn(first_battle, first_state, catalog)

	var second_state := RunState.new_run(101)
	var second_battle := _start(second_state, _probe_catalog(), {"first_mover": "enemy"})
	var manual := FacadeScript.apply_turn(second_battle, second_state, {"type": "end_turn"}, catalog)

	assert_eq(pre["battle"], manual["battle"],
			"enemy pre-turn and a manual end_turn must settle to the same battle state")
	assert_eq(pre["state"].event_log.size(), manual["state"].event_log.size(),
			"enemy pre-turn must use the same settlement path (and logging) as a manual end_turn")
	assert_eq(pre["state"].current_battle2_ledger, manual["state"].current_battle2_ledger,
			"the round ledger must advance the same way on both paths")


func test_end_turn_is_rejected_after_victory_defeat_and_retreat() -> void:
	# victory
	var vstate := RunState.new_run(101)
	var vbattle := _start(vstate, _probe_catalog(1))
	var vhit := FacadeScript.apply_turn(vbattle, vstate, {"type": "basic_attack"}, catalog)
	assert_eq(str(vhit["result"]), "victory")
	_assert_over(vhit, "victory")

	# defeat
	var dstate := RunState.new_run(101)
	dstate.health = 1
	var dbattle := _start(dstate, _probe_catalog(4))
	var dhit := FacadeScript.apply_turn(dbattle, dstate, {"type": "end_turn"}, catalog)
	assert_eq(str(dhit["result"]), "death")
	_assert_over(dhit, "defeat")

	# retreat：撤离是显式终局路径，此后同样不得再行动。
	var rstate := RunState.new_run(101)
	var rbattle := _start(rstate, _probe_catalog())
	var rout := FacadeScript.apply_turn(rbattle, rstate, {"type": "retreat"}, catalog)
	assert_eq(str(rout["result"]), "retreat")
	assert_true(bool(rout["finished"]))
	assert_eq(str(rout["battle"]["phase"]), "player_action", "retreat closes the session without a phase change")
	_assert_over(rout, "player_action")


func test_boss_retreat_forbidden_while_ordinary_retreat_is_explicit() -> void:
	var state := RunState.new_run(101)
	var boss := _start(state, _probe_catalog(4, 2, "boss"))
	var blocked := FacadeScript.apply_turn(boss, state, {"type": "retreat"}, catalog)
	assert_eq(blocked["result"], "rejected")
	assert_eq(blocked["feeds"], ["retreat_forbidden"])
	assert_false(bool(blocked["accepted"]))
	assert_eq(blocked["battle"], boss, "a forbidden retreat must not touch the battle")

	var common_battle := _start(state, _probe_catalog())
	var escaped := FacadeScript.apply_turn(common_battle, state, {"type": "retreat"}, catalog)
	assert_true(bool(escaped["accepted"]))
	assert_eq(str(escaped["result"]), "retreat")
	assert_true(bool(escaped["finished"]))


# ---------- 会话边界（Task 2） ----------

func test_start_session_opens_ledger_and_finalize_session_hands_it_back() -> void:
	var state := RunState.new_run(101)
	var session := FacadeScript.start_session(_encounter(), state, _probe_catalog())

	assert_eq(str(session["result"]), "ongoing")
	assert_same(session["state"], state, "start_session must hand back the prepared run state")
	assert_eq(str(session["battle"]["phase"]), "player_action")
	assert_false(session["state"].current_battle2_ledger.is_empty(),
			"start_session must open the battle round ledger")

	var opened: Dictionary = session["state"].current_battle2_ledger.duplicate(true)
	var finalized := FacadeScript.finalize_session(session["battle"], session["state"], "victory")

	assert_eq(finalized["ledger"], opened, "finalize_session must hand back the round ledger snapshot")
	assert_true(finalized["state"].current_battle2_ledger.is_empty(),
			"finalize_session must clear the session ledger")


# ---------- 拒绝语义 ----------

func test_rejected_command_leaves_battle_and_log_identical() -> void:
	var state := RunState.new_run(101)
	var battle := _start(state, _probe_catalog())
	var before: Dictionary = battle.duplicate(true)
	var log_size := state.event_log.size()

	var cases := [
		{"type": "use_gu", "instance_id": "no_such_instance"},
		{"type": "not_a_battle_command"},
		{"type": "basic_dodge"},
		{"type": "play_kill_move", "kill_move_id": "no_such_kill_move"},
	]
	for command in cases:
		var out := FacadeScript.apply_turn(battle, state, command, catalog)
		assert_false(bool(out["accepted"]), "rejected command must report accepted=false: %s" % str(command))
		assert_eq(str(out["result"]), "rejected")
		assert_false((out["feeds"] as Array).is_empty(), "a rejection must carry a reason: %s" % str(command))
		assert_eq(out["battle"], before, "rejected command must not mutate the battle: %s" % str(command))
		assert_eq(out["state"].event_log.size(), log_size, "rejected command must not append events: %s" % str(command))

	var missing := FacadeScript.apply_turn({}, state, {"type": "end_turn"}, catalog)
	assert_eq(missing["feeds"], ["battle_missing"])
	assert_eq(missing["battle"], {})
	assert_eq(missing["state"].event_log.size(), log_size)


func test_apply_turn_returns_stable_shape() -> void:
	var state := RunState.new_run(101)
	var battle := _start(state, _probe_catalog())
	var instance_id := str(battle["gu_slots"][0]["instance_id"])

	var accepted := FacadeScript.apply_turn(battle, state, {"type": "use_gu", "instance_id": instance_id}, catalog)
	_assert_shape(accepted)
	assert_true(bool(accepted["accepted"]))
	assert_false(bool(accepted["finished"]))

	var rejected := FacadeScript.apply_turn(battle, state, {"type": "not_a_battle_command"}, catalog)
	_assert_shape(rejected)
	assert_false(bool(rejected["accepted"]))
	assert_false(bool(rejected["finished"]))


func test_phase_never_leaves_the_declared_set() -> void:
	var state := RunState.new_run(101)
	var battle := _start(state, _probe_catalog(3))
	var instance_id := str(battle["gu_slots"][0]["instance_id"])
	var phases: Array[String] = []
	var out := {"battle": battle, "state": state}
	for step in 8:
		out = FacadeScript.apply_turn(out["battle"], out["state"], {"type": "use_gu", "instance_id": instance_id}, catalog)
		phases.append(str(out["battle"]["phase"]))
		if bool(out["finished"]):
			break
		out = FacadeScript.apply_turn(out["battle"], out["state"], {"type": "end_turn"}, catalog)
		phases.append(str(out["battle"]["phase"]))
		if bool(out["finished"]):
			break
	for phase in phases:
		assert_true(PHASES.has(phase), "battle.phase left the declared set: %s" % phase)


# ---------- 事件日志与回合账本 ----------

func test_accepted_action_appends_exactly_one_battle_v1_event() -> void:
	var state := RunState.new_run(101)
	var battle := _start(state, _probe_catalog())
	var instance_id := str(battle["gu_slots"][0]["instance_id"])

	var before := _count_actions(state, "battle_v1")
	var used := FacadeScript.apply_turn(battle, state, {"type": "use_gu", "instance_id": instance_id}, catalog)
	assert_eq(_count_actions(used["state"], "battle_v1"), before + 1,
			"one accepted action must append exactly one battle_v1 event")
	assert_eq(str(used["state"].event_log.back()["source"]), "battle_facade")

	var turn := FacadeScript.apply_turn(used["battle"], used["state"], {"type": "end_turn"}, catalog)
	assert_eq(_count_actions(turn["state"], "battle_v1"), before + 2,
			"end_turn is one accepted action and appends exactly one more event")


func test_facade_never_appends_the_lifecycle_finished_event() -> void:
	# Task 4：战斗结束事件只由生命周期层（run_battle_flow）追加一条。门面自身
	# 即使把战斗结算到终局，也不得写 battle_finished。
	var state := RunState.new_run(101)
	var battle := _start(state, _probe_catalog(1))

	var out := FacadeScript.apply_turn(battle, state, {"type": "basic_attack"}, catalog)

	assert_eq(str(out["result"]), "victory")
	assert_true(bool(out["finished"]), "a victory must mark the session finished")
	assert_eq(_count_actions(out["state"], "battle_finished"), 0,
			"battle_finished belongs to the lifecycle layer, never to the battle facade")


# ---------- 行动预览与执行统一（Task 3） ----------

func test_preview_cards_satisfy_the_ten_key_contract() -> void:
	var state := RunState.new_run(101)
	var battle := _with_probe_commands(_start(state, _probe_catalog()))
	var cards := ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog)

	var ids: Array[String] = []
	for card_value in cards:
		var card: Dictionary = card_value
		var card_id := str(card.get("id", ""))
		ids.append(card_id)
		for key in CARD_KEYS:
			assert_true(card.has(key), "%s must carry the Task 3 key %s" % [card_id, key])
		assert_true(card["executable"] is bool)
		assert_true(card["command"] is Dictionary)
		assert_eq(int(card["state_version"]), state.event_log.size(),
				"%s state_version must ride the run event log" % card_id)
		assert_eq(str(card["expected_phase"]), str(battle["phase"]),
				"%s expected_phase must mirror the battle phase" % card_id)
		assert_eq(card["costs"], card["cost"],
				"%s must expose the same costs the existing consumers read" % card_id)

	assert_true(ids.has("gu.probe_strike"), "every gu slot must project a card")
	assert_true(ids.has("basic_attack"))
	assert_true(ids.has("kill_move.probe_km"))
	assert_true(ids.has("battle.end_turn"))
	assert_true(ids.has("battle.retreat"))
	# 唯一性：同 ID 两张卡会让 UI 的去重保护失效。
	var unique := {}
	for card_id in ids:
		assert_false(unique.has(card_id), "duplicate preview card id: %s" % card_id)
		unique[card_id] = true


func test_preview_executability_matches_the_domain_gates() -> void:
	var state := RunState.new_run(101)
	var battle := _with_probe_commands(_start(state, _probe_catalog()))
	var gates := _preview_by_id(battle, state)
	var slot_index := _probe_slot_index(battle, "probe_strike")

	var gu_reason := V1ResolverScript.can_play_gu(battle, slot_index)
	assert_eq(str(gates["gu.probe_strike"]["reason"]), gu_reason,
			"the gu card must name the very reason the resolver returns")
	assert_eq(bool(gates["gu.probe_strike"]["executable"]), gu_reason.is_empty())

	var attack_reason := V1ResolverScript.basic_attack_reason(battle)
	assert_eq(str(gates["basic_attack"]["reason"]), attack_reason)
	assert_eq(bool(gates["basic_attack"]["executable"]), attack_reason.is_empty())

	var kill_reason := V1ResolverScript.kill_move_reason(battle, "probe_km")
	assert_eq(str(gates["kill_move.probe_km"]["reason"]), kill_reason)
	assert_eq(bool(gates["kill_move.probe_km"]["executable"]), kill_reason.is_empty())

	# 指向规则：只有 strike 类蛊需要选敌，目标面 = 当前全部存活敌人。
	assert_eq(str(gates["gu.probe_strike"]["target_type"]), "single_enemy")
	assert_eq(gates["gu.probe_strike"]["valid_target_ids"], ["core_probe"])
	assert_eq(str(gates["basic_attack"]["target_type"]), "single_enemy")
	assert_eq(str(gates["battle.end_turn"]["target_type"]), "none")
	assert_eq(gates["battle.end_turn"]["valid_target_ids"], [])
	# 收势必须始终可提交——它是玩家在没有可用蛊时的唯一出口。
	assert_true(bool(gates["battle.end_turn"]["executable"]))


func test_preview_shows_one_reason_per_domain_gate() -> void:
	var cases := [
		{"label": "true_qi", "expected": "insufficient_true_qi", "player": {"true_qi": 0}},
		{"label": "thought", "expected": "insufficient_thought", "player": {"thoughts": 0}},
		{"label": "action_limit", "expected": "action_limit_reached", "player": {"used_this_turn": 2}},
		{"label": "used_this_turn", "expected": "gu_used_this_turn", "slot": {"used_this_turn": true}},
		{"label": "sealed", "expected": "gu_sealed", "slot": {"is_sealed": true}},
		{"label": "consumed", "expected": "gu_consumed", "slot": {"consumed": true}},
		{"label": "rank", "expected": "insufficient_qi_quality", "slot": {"rank": 5}},
	]
	for case_value in cases:
		var case: Dictionary = case_value
		var label := str(case["label"])
		var state := RunState.new_run(101)
		var battle := _with_probe_commands(_start(state, _probe_catalog()), case.get("slot", {}))
		battle["player"] = _patched(battle["player"], case.get("player", {}))

		var card: Dictionary = _preview_by_id(battle, state)["gu.probe_strike"]
		assert_false(bool(card["executable"]), "%s must disable the gu card" % label)
		assert_eq(str(card["reason"]), str(case["expected"]), "%s must name the domain reason" % label)
		assert_false(str(card["block_reason"]).is_empty(), "%s must show a player-facing reason" % label)
		assert_ne(str(card["block_reason"]), str(case["expected"]),
				"%s must not leak the raw reason code into UI text" % label)

		# 同源证据：提交这张卡的命令，领域拒绝的 feeds 就是卡上写的那个 reason。
		var out := FacadeScript.apply_turn(battle, state,
				{"type": "use_gu", "instance_id": "probe_strike"}, catalog)
		assert_false(bool(out["accepted"]), "%s must be rejected by the domain too" % label)
		assert_eq(out["feeds"], [str(case["expected"])],
				"%s: preview reason and domain rejection must be one source" % label)


func test_preview_executable_commands_are_accepted_and_disabled_ones_rejected() -> void:
	var state := RunState.new_run(101)
	var battle := _with_probe_commands(_start(state, _probe_catalog()))
	var cards := ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog)
	assert_true(cards.size() > 0)

	for card_value in cards:
		var card: Dictionary = card_value
		var card_id := str(card["id"])
		if not bool(card["executable"]) and PREVIEW_ONLY_GATES.has(card_id):
			# battle.retreat 的元石/地形条件是遗留预览语义，领域 retreat 分支只拦
			# Boss——该差异登记为待裁定项，不在本测试里捏造方向断言。
			continue
		# 每张卡都在一场全新战斗上提交：前一张卡花掉的念头/真元不得干扰后一张。
		var case_state := RunState.new_run(101)
		var case_battle := _with_probe_commands(_start(case_state, _probe_catalog()))
		var payload: Dictionary = (card["command"] as Dictionary).duplicate(true)
		var targets: Array = card["valid_target_ids"]
		if str(card["target_type"]) == "single_enemy" and not targets.is_empty():
			payload["target_id"] = str(targets[0])
		var out := FacadeScript.apply_turn(case_battle, case_state, payload, catalog)
		if bool(card["executable"]):
			assert_true(bool(out["accepted"]),
					"an executable card must be accepted: %s (%s)" % [card_id, str(out["feeds"])])
		else:
			assert_false(bool(out["accepted"]),
					"a disabled card must be rejected: %s" % card_id)
			assert_true((out["feeds"] as Array).has(str(card["reason"])),
					"the rejection must quote the card reason: %s -> %s" % [card_id, str(out["feeds"])])


func test_multi_enemy_target_id_reaches_the_actual_hit() -> void:
	var state := RunState.new_run(101)
	var battle := _with_probe_commands(_start(state, _duo_probe_catalog(),
			{"enemy_roll": ["core_probe", "core_probe_alt"]}))
	assert_eq(_living_enemy_ids(battle).size(), 2, "fixture must be a two-enemy battle")

	var card: Dictionary = _preview_by_id(battle, state)["gu.probe_strike"]
	assert_eq(card["valid_target_ids"], ["core_probe", "core_probe_alt"],
			"the target face must list every living enemy")

	var out := FacadeScript.apply_turn(battle, state,
			{"type": "use_gu", "instance_id": "probe_strike", "target_id": "core_probe_alt"}, catalog)
	assert_true(bool(out["accepted"]))
	assert_eq(_enemy_hp(out["battle"], "core_probe_alt"), 3, "the named target must take the strike")
	assert_eq(_enemy_hp(out["battle"], "core_probe"), 4, "the other enemy must stay untouched")
	# 结算与事件日志同源：日志记的是实际命中目标，而不是命令里想要的字符串。
	assert_eq(str(out["battle"]["last_effect_target"]), "core_probe_alt")
	assert_eq(str(out["state"].event_log.back()["info"]["effect"]["target_id"]), "core_probe_alt")


# ---------- 辅助 ----------

func _encounter(extra: Dictionary = {}) -> Dictionary:
	var encounter := {"enemy_kind": "core_probe", "terrain": "path", "layer": 1}
	for key in extra:
		encounter[str(key)] = extra[key]
	return encounter


func _start(state: RunState, battle_catalog: Dictionary, extra: Dictionary = {}) -> Dictionary:
	return FacadeScript.start(_encounter(extra), state, battle_catalog)


## 战斗探针目录：可控 hp/damage 的普通敌人（可选 tier）。
func _probe_catalog(hp: int = 4, damage: int = 2, tier: String = "") -> Dictionary:
	var out := catalog.duplicate(true)
	var definition := {
		"id": "core_probe",
		"label": "试敌",
		"hp": hp,
		"intent": {"kind": "attack", "damage": damage, "label": "扑击"},
	}
	if not tier.is_empty():
		definition["tier"] = tier
	out["enemy_by_id"]["core_probe"] = definition
	return out


## 终局后任何行动都必须被拒，且 battle 不被修改。
func _assert_over(finished_turn: Dictionary, expected_phase: String) -> void:
	var battle: Dictionary = finished_turn["battle"]
	var before: Dictionary = battle.duplicate(true)
	var log_size: int = finished_turn["state"].event_log.size()
	assert_eq(str(battle["phase"]), expected_phase)
	for command in [
		{"type": "end_turn"},
		{"type": "basic_attack"},
		{"type": "use_gu", "instance_id": str((battle["gu_slots"] as Array)[0]["instance_id"])},
	]:
		var out := FacadeScript.apply_turn(battle, finished_turn["state"], command, catalog)
		assert_false(bool(out["accepted"]), "a finished battle must reject %s" % str(command))
		assert_eq(out["feeds"], ["battle_over"], "a finished battle must answer battle_over for %s" % str(command))
		assert_eq(out["battle"], before, "a finished battle must stay frozen for %s" % str(command))
		assert_eq(out["state"].event_log.size(), log_size)


func _assert_shape(turn: Dictionary) -> void:
	for key in TURN_KEYS:
		assert_true(turn.has(key), "apply_turn result must always expose %s" % key)
	assert_true(turn["battle"] is Dictionary)
	assert_true(turn["state"] is RunState)
	assert_true(turn["result"] is String)
	assert_true(turn["feeds"] is Array)
	assert_true(turn["accepted"] is bool)
	assert_true(turn["finished"] is bool)


func _count_actions(state: RunState, action: String) -> int:
	var total := 0
	for event in state.event_log:
		if str(event.get("action", "")) == action:
			total += 1
	return total


# ---------- Task 3 辅助 ----------

## 双敌探针目录：两只同名模板但 id 不同的敌人，用于验证 target_id 落点。
func _duo_probe_catalog() -> Dictionary:
	var out := _probe_catalog()
	out["enemy_by_id"]["core_probe_alt"] = {
		"id": "core_probe_alt",
		"label": "试敌乙",
		"hp": 4,
		"intent": {"kind": "attack", "damage": 2, "label": "扑击"},
	}
	return out


## 战斗探针命令面：一只可控 strike 蛊 + 一条空配方杀招。内容目录的随机性不参与
## 本组断言，预览/执行一致性只由这一段固定夹具证明。
func _with_probe_commands(battle: Dictionary, slot_overrides: Dictionary = {}) -> Dictionary:
	var out: Dictionary = battle.duplicate(true)
	var slot := _probe_strike_slot()
	for key in slot_overrides:
		slot[str(key)] = slot_overrides[key]
	var slots: Array[Dictionary] = [slot]
	out["gu_slots"] = slots
	var kill_moves: Array[Dictionary] = []
	kill_moves.assign(out.get("kill_moves", []))
	kill_moves.append({
		"id": "probe_km",
		"label": "试招",
		"tag": "",
		"recipe": [],
		"sword_mark_recipe": [],
		"true_qi_cost": 1,
		"thought_cost": 1,
		"life_cost": 0,
		"damage": 2,
		"effect": {"kind": "strike", "amount": 2},
		"reveals": false,
	})
	out["kill_moves"] = kill_moves
	return out


## 与 V1BattleResolver._build_gu_slots 同形状的最小蛊槽（1 转、1 念头、1 真元）。
func _probe_strike_slot() -> Dictionary:
	return {
		"instance_id": "probe_strike",
		"definition_id": "probe_strike",
		"school": "",
		"rank": 1,
		"rank_held": 1,
		"sword_downgrades": 0,
		"dao_marks": 0,
		"sword_mark_cost": false,
		"low_rank_exception": false,
		"is_sealed": false,
		"seal_turns": 0,
		"used_this_turn": false,
		"true_qi_cost": 1,
		"thought_cost": 1,
		"life_cost": 0,
		"is_permanent": false,
		"durability_mode": "",
		"trigger_qi_cost": 0,
		"trigger_block": 0,
		"maintain_qi_cost": 0,
		"duration_turns": 0,
		"effect": {"kind": "strike", "amount": 1},
		"consumed": false,
	}


func _preview_by_id(battle: Dictionary, state: RunState) -> Dictionary:
	var out := {}
	for card_value in ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog):
		var card: Dictionary = card_value
		out[str(card["id"])] = card
	return out


func _probe_slot_index(battle: Dictionary, instance_id: String) -> int:
	for i in (battle.get("gu_slots", []) as Array).size():
		if str(battle["gu_slots"][i].get("instance_id", "")) == instance_id:
			return i
	return -1


func _patched(source: Variant, overrides: Dictionary) -> Dictionary:
	var out: Dictionary = (source as Dictionary).duplicate(true)
	for key in overrides:
		out[str(key)] = overrides[key]
	return out


func _living_enemy_ids(battle: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", true)) and int(enemy.get("hp", 0)) > 0:
			ids.append(str(enemy.get("id", "")))
	return ids


func _enemy_hp(battle: Dictionary, enemy_id: String) -> int:
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if str(enemy.get("id", "")) == enemy_id:
			return int(enemy.get("hp", 0))
	return -1