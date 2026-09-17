extends GutTest


## 第三阶段 Task 6：战斗核心的端到端生命周期。
## 全程只经 controller 的命令缝（Battle 屏快照卡自带的结构化命令），
## 不直接调用 V1BattleResolver / Battle2TurnEngine 内部接口。

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")


var catalog: Dictionary


func before_all() -> void:
	catalog = ContentCatalogScript.load_all()


func before_each() -> void:
	_cleanup_save_files()


func after_each() -> void:
	_cleanup_save_files()


func _cleanup_save_files() -> void:
	for path in [SaveRepositoryScript.SAVE_PATH, SaveRepositoryScript.TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


# ---------- 真实战斗胜利 ----------

func test_real_battle_victory_closes_the_session_once_and_leaves_the_battle() -> void:
	var controller: RunController = _controller(_combat_node())
	_enter_battle(controller)

	var steps := 0
	while controller.current_view_name() == "Battle" and steps < 60:
		steps += 1
		_submit_first_executable_card(controller)

	assert_ne(controller.current_view_name(), "Battle", "winning must leave the Battle screen")
	assert_true(controller.current_battle.is_empty(), "the battle scene must be cleared on exit")
	assert_eq(_count(controller.state.event_log, "battle_finished"), 1,
			"the lifecycle layer must close the battle with exactly one battle_finished event")
	assert_true(_has(controller.state.event_log, "battle_finished", "battle_victory"),
			"the close-out event must carry the victory reason")
	assert_true(controller.state.current_battle2_ledger.is_empty(),
			"the runtime battle ledger must be cleared once the session is finalised")

	var finished: Dictionary = _last_event(controller.state.event_log, "battle_finished")
	var ledger: Dictionary = (finished.get("info", {}) as Dictionary).get("_battle2_ledger", {})
	assert_false(ledger.is_empty(),
			"the close-out event must carry the final round ledger snapshot")
	assert_eq(_accepted_actions(controller.state.event_log), _count(controller.state.event_log, "battle_v1"),
			"every battle_v1 event must come from one accepted action")


# ---------- 敌人先手 ----------

func test_enemy_first_mover_lands_through_the_shared_turn_path() -> void:
	var controller: RunController = _controller(_combat_node())
	controller.state.health = 60
	controller.state.max_health = 60
	controller.state.encounter_session["stance"] = "hostile"
	_enter_battle(controller)

	assert_eq(str(controller.current_battle.get("first_mover", "")), "enemy",
			"a hostile session must open with the enemy move")
	# 敌先手不另起旁路：它落的是同一条 end_turn 结算与同一条 battle_v1 事件。
	assert_eq(_count(controller.state.event_log, "battle_v1"), 1,
			"the opening move must be logged exactly once")
	assert_true(_has(controller.state.event_log, "battle_v1", "battle_v1_end_turn"),
			"the opening move must ride the shared end_turn settlement path")
	assert_eq(int(controller.current_battle["player"]["hp"]), 60 - _opening_damage(controller.current_battle),
			"the public intent must actually land before the player acts")
	assert_eq(controller.current_view_name(), "Battle", "the player must still get their turn")


# ---------- 多敌战斗与显式撤离 ----------

func test_multi_enemy_target_selection_then_explicit_retreat() -> void:
	var node := _combat_node(["ridge_hound", "neutral_stone_wanderer"])
	var controller: RunController = _controller(node)
	_enter_battle(controller)

	var living := _living_enemy_ids(controller.current_battle)
	assert_eq(living.size(), 2, "the fixture must be a two-enemy battle")
	assert_eq(str(controller._snapshot_for("Battle").get("default_target_id", "")), living[0])

	var strike := _first_executable_card(controller, "single_enemy")
	assert_false(strike.is_empty(), "the fixture must offer a target-choosing card")
	assert_eq(strike["valid_target_ids"], living, "the target face must list every living enemy")
	# Task 3 契约：UI 只转呈卡上的命令，并按本屏交互态补入目标。
	var target_before := _enemy_hp(controller.current_battle, living[1])
	var bystander_before := _enemy_hp(controller.current_battle, living[0])
	var payload: Dictionary = (strike["command"] as Dictionary).duplicate(true)
	payload["target_id"] = living[1]
	var hit := controller.submit_command(payload)
	assert_true(bool(hit.get("accepted", false)),
			"the previewed command with a chosen target must be accepted: %s" % str(hit.get("feeds", [])))
	assert_lt(_enemy_hp(controller.current_battle, living[1]), target_before,
			"the named target must take the effect")
	assert_eq(_enemy_hp(controller.current_battle, living[0]), bystander_before,
			"the other enemy must stay untouched")
	assert_eq(str(controller.current_battle.get("last_effect_target", "")), living[1],
			"the resolved target must be the one the card carried")

	var retreated: Dictionary = controller.submit_command({
		"type": "retreat",
		"state_version": controller.state.event_log.size(),
		"expected_phase": str(controller.current_battle.get("phase", "")),
	})
	assert_true(bool(retreated.get("accepted", false)), "ordinary combat must keep an explicit retreat")
	assert_eq(str(retreated.get("result", "")), "retreat")
	assert_ne(controller.current_view_name(), "Battle", "retreat must leave the Battle screen")
	assert_eq(controller.state.terminal_state, "active", "a retreat must leave the run active")
	assert_eq(_count(controller.state.event_log, "battle_finished"), 1,
			"retreat must also be closed by exactly one battle_finished event")
	assert_true(_has(controller.state.event_log, "battle_finished", "battle_retreat"))
	assert_true(controller.state.current_battle2_ledger.is_empty(),
			"retreat must hand the runtime battle ledger back through the lifecycle layer")


# ---------- Boss 禁止撤离 ----------

func test_boss_battle_refuses_retreat_and_locks_the_ui_flee_entry() -> void:
	var controller: RunController = _controller(_combat_node(["ridge_hound"], {"layer_boss": 2}))
	_enter_battle(controller)

	assert_false(bool(controller._snapshot_for("Battle").get("flee_available", true)),
			"the UI battle path must not offer surrender against a boss")
	var before := controller.current_battle.duplicate(true)
	var blocked: Dictionary = controller.submit_command({
		"type": "retreat",
		"state_version": controller.state.event_log.size(),
	})
	assert_false(bool(blocked.get("accepted", false)))
	assert_true((blocked.get("feeds", []) as Array).has("retreat_forbidden"),
			"a boss battle must answer retreat_forbidden: %s" % str(blocked.get("feeds", [])))
	assert_eq(controller.current_battle, before, "a forbidden retreat must not touch the battle")
	assert_eq(controller.current_view_name(), "Battle", "a refused retreat must keep the battle open")
	assert_eq(_count(controller.state.event_log, "battle_finished"), 0,
			"a refused retreat must not close the session")


# ---------- 战死与重新开始 ----------

func test_battle_death_ends_the_run_with_the_precise_cause_then_a_fresh_run_resets() -> void:
	var controller: RunController = _controller(_combat_node())
	controller.state.health = 2
	controller.state.max_health = 2
	_enter_battle(controller)
	# 先落一份进行中存档，才能证明"结局即此世终点"确实清掉了它。
	assert_eq(SaveRepositoryScript.save_run(controller.state, controller.route, []), OK)
	assert_true(FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH))

	var lethal: Dictionary = controller.submit_command({"type": "end_turn"})
	assert_eq(str(lethal.get("result", "")), "death", "the public intent must be able to kill the player")
	assert_true(bool(lethal.get("finished", false)))
	assert_eq(controller.current_view_name(), "Ending", "battle death must route into the ending")
	assert_eq(_count(controller.state.event_log, "battle_finished"), 1,
			"death must be closed by exactly one battle_finished event")
	assert_true(_has(controller.state.event_log, "battle_finished", "battle_death"))

	var view: Dictionary = controller._ending_state
	assert_eq(str(view.get("ending_type", "")), "death")
	assert_eq(str(view.get("death_cause_id", "")), "death_cause_battle",
			"the death review must name the battle as the precise cause")
	assert_ne(str(view.get("death_cause", "")), "")
	# 战死保留战斗现场供归因（既有死亡复盘通路读它）；run 已终结，不会再续战。
	assert_false(controller.current_battle.is_empty(),
			"battle death must keep the scene for the death review")
	assert_true(controller.state.current_battle2_ledger.is_empty(),
			"the runtime battle ledger must still be handed back on death")
	# 结局即此世终点：进行中 Run 存档必须被删除（run_ending_flow.record_run_end）。
	assert_false(FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH),
			"battle death must delete the in-progress run save")

	controller.start_new_run(202)
	assert_eq(controller.state.terminal_state, "active", "a fresh run must start active")
	assert_true(controller.current_battle.is_empty(), "a fresh run must start without a battle")
	assert_eq(_count(controller.state.event_log, "battle_finished"), 0,
			"a fresh run must start with a clean battle log")


# ---------- 辅助 ----------

func _controller(node: Dictionary) -> RunController:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.catalog = catalog
	controller.state = RunState.new_run(2031)
	controller.state.current_node_id = str(node.get("id", ""))
	controller.current_node = node
	controller.state.current_node_template_id = str(node.get("id", ""))
	controller.state.current_node_layer = int(node.get("layer", 1))
	controller.state.encounter_session = EncounterSessionResolverScript.start(node)
	return controller


func _combat_node(enemy_kinds: Array = ["ridge_hound"], extra: Dictionary = {}) -> Dictionary:
	var node := {
		"id": "beast_swarm_pass",
		"type": "combat",
		"enemy_kind": str(enemy_kinds[0]),
		"enemy_kinds": enemy_kinds.duplicate(),
		"layer": 1,
		"stage": "one",
		"layer_boss": 0,
		"choices": ["fight", "retreat"],
	}
	for key in extra:
		node[str(key)] = extra[key]
	return node


func _enter_battle(controller: RunController) -> void:
	controller._start_battle()
	assert_eq(controller.current_view_name(), "Battle", "the fixture must open the Battle screen")


## UI 默认路径：从 Battle 屏快照里取第一张可执行卡，只提交卡自带的结构化命令。
func _submit_first_executable_card(controller: RunController) -> Dictionary:
	var card := _first_executable_card(controller, "")
	if card.is_empty():
		return controller.submit_command({"type": "end_turn"})
	var payload: Dictionary = (card["command"] as Dictionary).duplicate(true)
	var targets: Array = card["valid_target_ids"]
	if str(card.get("target_type", "")) == "single_enemy" and not targets.is_empty():
		payload["target_id"] = str(targets[0])
	return controller.submit_command(payload)


func _first_executable_card(controller: RunController, target_type: String) -> Dictionary:
	for card_value in controller._snapshot_for("Battle").get("hand", []):
		var card: Dictionary = card_value
		if not bool(card.get("executable", false)):
			continue
		if not target_type.is_empty() and str(card.get("target_type", "")) != target_type:
			continue
		return card
	return {}


func _opening_damage(battle: Dictionary) -> int:
	var total := 0
	for enemy_value in battle.get("enemies", []):
		total += maxi(0, int(((enemy_value as Dictionary).get("intent", {}) as Dictionary).get("damage", 0)))
	return total


func _living_enemy_ids(battle: Dictionary) -> Array:
	var out: Array = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if int(enemy.get("hp", 0)) > 0:
			out.append(str(enemy.get("id", "")))
	return out


func _enemy_hp(battle: Dictionary, enemy_id: String) -> int:
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if str(enemy.get("id", "")) == enemy_id:
			return int(enemy.get("hp", 0))
	return -1


## 每个被接受的战斗行动落一条 battle_v1（battle_finished 由生命周期层另记）。
func _accepted_actions(events: Array) -> int:
	return _count(events, "battle_v1")


func _count(events: Array, action: String) -> int:
	var total := 0
	for event_value in events:
		if str((event_value as Dictionary).get("action", "")) == action:
			total += 1
	return total


func _has(events: Array, action: String, reason: String) -> bool:
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("action", "")) == action and str(event.get("reason", "")) == reason:
			return true
	return false


func _last_event(events: Array, action: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("action", "")) == action:
			return event
	return {}