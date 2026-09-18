extends GutTest


## 第三阶段 Task 6：战斗核心的端到端生命周期。
## 全程只经 controller 的命令缝（Battle 屏快照卡自带的结构化命令），
## 不直接调用 V1BattleResolver / Battle2TurnEngine 内部接口。

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const CommandSpecRegistryScript = preload("res://scripts/domain/command_spec_registry.gd")
const AcceptanceDriverScript = preload("res://scripts/acceptance_driver.gd")
const RunCommandBuilderScript = preload("res://scripts/presentation/run_command_builder.gd")
const RejectionTextScript = preload("res://scripts/presentation/rejection_text.gd")


var catalog: Dictionary
var _hosts: Array = []


func before_all() -> void:
	catalog = ContentCatalogScript.load_all()


func before_each() -> void:
	_cleanup_save_files()


func after_each() -> void:
	_cleanup_save_files()
	for host in _hosts:
		if is_instance_valid(host):
			host.free()
	_hosts.clear()


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
		"expected_phase": str(controller.current_battle.get("phase", "player_action")),
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
	var log_before := controller.state.event_log.size()
	var blocked: Dictionary = controller.submit_command({
		"type": "retreat",
		"state_version": controller.state.event_log.size(),
		"expected_phase": str(controller.current_battle.get("phase", "player_action")),
	})
	assert_false(bool(blocked.get("accepted", false)))
	assert_true((blocked.get("feeds", []) as Array).has("retreat_forbidden"),
			"a boss battle must answer retreat_forbidden: %s" % str(blocked.get("feeds", [])))
	assert_eq(controller.current_battle, before, "a forbidden retreat must not touch the battle")
	assert_eq(controller.current_view_name(), "Battle", "a refused retreat must keep the battle open")
	assert_eq(controller.state.event_log.size(), log_before,
			"a refused retreat must not append events")
	assert_eq(_count(controller.state.event_log, "battle_finished"), 0,
			"a refused retreat must not close the session")


# ---------- F-02：战斗命令新鲜度（RunController 路径） ----------

func test_valid_battle_command_with_fresh_context_is_accepted() -> void:
	var controller: RunController = _controller(_combat_node())
	_enter_battle(controller)
	var version := controller.state.event_log.size()
	var phase := str(controller.current_battle.get("phase", "player_action"))

	var out: Dictionary = controller.submit_command({
		"type": "basic_attack",
		"state_version": version,
		"expected_phase": phase,
	})

	assert_true(bool(out.get("accepted", false)),
			"a fresh battle command must be accepted: %s" % str(out.get("feeds", [])))
	assert_gt(controller.state.event_log.size(), version, "an accepted turn must append events")


func test_stale_state_version_is_rejected_without_mutation() -> void:
	var controller: RunController = _controller(_combat_node())
	_enter_battle(controller)
	var battle_before := controller.current_battle.duplicate(true)
	var log_before := controller.state.event_log.size()
	var phase := str(controller.current_battle.get("phase", "player_action"))

	var out: Dictionary = controller.submit_command({
		"type": "basic_attack",
		"state_version": log_before - 1,
		"expected_phase": phase,
	})

	assert_false(bool(out.get("accepted", false)), "stale state_version must be rejected")
	assert_true((out.get("feeds", []) as Array).has("battle_action_stale")
			or str(out.get("reason", "")) == "battle_action_stale",
			"stale version must answer battle_action_stale: %s" % str(out))
	assert_eq(controller.current_battle, battle_before, "stale reject must not touch battle")
	assert_eq(controller.state.event_log.size(), log_before, "stale reject must not append events")
	assert_eq(_count(controller.state.event_log, "battle_finished"), 0,
			"stale reject must not write battle_finished")
	assert_eq(controller.current_view_name(), "Battle", "stale reject must keep the battle open")


func test_stale_expected_phase_is_rejected_without_mutation() -> void:
	var controller: RunController = _controller(_combat_node())
	_enter_battle(controller)
	var battle_before := controller.current_battle.duplicate(true)
	var log_before := controller.state.event_log.size()

	var out: Dictionary = controller.submit_command({
		"type": "basic_attack",
		"state_version": log_before,
		"expected_phase": "not_the_current_phase",
	})

	assert_false(bool(out.get("accepted", false)), "stale expected_phase must be rejected")
	assert_true((out.get("feeds", []) as Array).has("battle_phase_stale")
			or str(out.get("reason", "")) == "battle_phase_stale",
			"stale phase must answer battle_phase_stale: %s" % str(out))
	assert_eq(controller.current_battle, battle_before, "stale phase reject must not touch battle")
	assert_eq(controller.state.event_log.size(), log_before,
			"stale phase reject must not append events")
	assert_eq(_count(controller.state.event_log, "battle_finished"), 0,
			"stale phase reject must not write battle_finished")
	assert_eq(controller.current_view_name(), "Battle", "stale phase reject must keep battle open")


# ---------- F-02 复验：过期命令的拒绝反馈必须可见 ----------

## 预检拒绝（新鲜度过期）必须留下玩家可见文案，并随战斗快照的 feedback 键
## 送到战斗屏 toast；同时证得零副作用。
func test_stale_command_writes_rejection_feedback_visible_on_the_battle_screen() -> void:
	var controller: RunController = _controller(_combat_node())
	_enter_battle(controller)
	controller.last_feedback = ""
	var battle_before := controller.current_battle.duplicate(true)
	var log_before := controller.state.event_log.size()

	var out: Dictionary = controller.submit_command({
		"type": "basic_attack",
		"state_version": log_before - 1,
		"expected_phase": str(controller.current_battle.get("phase", "player_action")),
	})

	assert_false(bool(out.get("accepted", false)), "a stale command must be rejected")
	assert_false(str(controller.last_feedback).is_empty(),
			"a rejected battle command must leave player-facing feedback")
	assert_true(str(controller.last_feedback).contains("请重试"),
			"the feedback must be Chinese rejection text, not a raw reason key: %s"
					% controller.last_feedback)
	assert_eq(str(controller._snapshot_for("Battle").get("feedback", "")),
			str(controller.last_feedback),
			"the Battle snapshot must carry the rejection text so the toast can show it")
	assert_eq(controller.current_battle, battle_before, "the rejection must not touch the battle")
	assert_eq(controller.state.event_log.size(), log_before, "the rejection must not append events")
	assert_eq(_count(controller.state.event_log, "battle_finished"), 0,
			"the rejection must not close the session")


## 领域拒绝（F-01 的撤离门禁）走的是另一条分支（facade `_rejected`），
## 同样必须写反馈——否则门禁拒绝是"静默"的。
func test_domain_level_rejection_also_writes_visible_feedback() -> void:
	var controller: RunController = _controller(_combat_node(["ridge_hound"], {"layer_boss": 2}))
	_enter_battle(controller)
	controller.last_feedback = ""
	var log_before := controller.state.event_log.size()

	var out: Dictionary = controller.submit_command({
		"type": "retreat",
		"state_version": controller.state.event_log.size(),
		"expected_phase": str(controller.current_battle.get("phase", "player_action")),
	})

	assert_false(bool(out.get("accepted", false)))
	assert_true((out.get("feeds", []) as Array).has("retreat_forbidden"))
	assert_eq(str(controller.last_feedback), "此战不可撤退。",
			"a domain-level rejection must surface its Chinese text, never sit silent")
	assert_eq(str(controller._snapshot_for("Battle").get("feedback", "")), "此战不可撤退。")
	assert_eq(controller.state.event_log.size(), log_before,
			"a domain-level rejection must not append events")


# ---------- 验收驱动：战斗命令必须带新鲜度上下文 ----------

## 真实 smoke/play 路径经 acceptance_driver 提交战斗命令；缺 state_version /
## expected_phase 会让整条验收路径落到预检拒绝分支（命令永远不生效）。
func test_acceptance_driver_battle_commands_carry_freshness_context() -> void:
	var controller: RunController = _controller(_combat_node())
	_enter_battle(controller)
	var battle: Dictionary = controller.current_battle
	var version := controller.state.event_log.size()
	var phase := str(battle.get("phase", "player_action"))

	var gu: Dictionary = AcceptanceDriverScript._play_gu_command(
			controller, battle, "inst_probe")
	assert_eq(str(gu.get("type", "")), "use_gu")
	assert_eq(int(gu.get("state_version", -1)), version,
			"the acceptance driver must stamp the current event-log version")
	assert_eq(str(gu.get("expected_phase", "")), phase,
			"the acceptance driver must stamp the current battle phase")

	var turn: Dictionary = AcceptanceDriverScript._battle_turn_command(controller, "end_turn")
	assert_eq(str(turn.get("type", "")), "end_turn")
	assert_eq(int(turn.get("state_version", -1)), version)
	assert_eq(str(turn.get("expected_phase", "")), phase)

	# 直接过 freshness 预检：驱动命令必须通过真实门禁，而不是被拒后原地空转。
	var preflight: Dictionary = CommandSpecRegistryScript.preflight(
			"battle.turn", controller.state, battle, {}, turn, controller.catalog)
	assert_true(bool(preflight.get("ok", false)),
			"a driver-built command must pass the battle.turn freshness preflight: %s"
					% str(preflight.get("reason", "")))
	var out: Dictionary = controller.submit_command(turn)
	assert_true(bool(out.get("accepted", false)),
			"a driver-built command must be accepted on the real submit path: %s"
					% str(out.get("feeds", [])))


# ---------- F-02 复验（第三轮）：命令面不得吞信封 / 旧卡 id 形状统一 ----------

## 命令面通道必须把领域信封原样交回调用方。GDScript 的单行 lambda **不隐式返回**
## 末表达式，漏了显式 `return` 时领域拒绝信封被吞成 `null`，战斗屏会把它当作
## "未转呈"而照常播成功动效——这两条通道都要钉住。
func test_battle_command_channels_return_the_domain_envelope() -> void:
	var controller: RunController = _controller(_combat_node(["ridge_hound"], {"layer_boss": 2}))
	_enter_battle(controller)
	var face: Dictionary = controller._build_commands("Battle")

	var via_play_card: Variant = face["play_card"].call("battle.retreat", "")
	assert_true(via_play_card is Dictionary,
			"the play_card channel must hand the envelope back, not null: %s" % str(via_play_card))
	assert_false(bool((via_play_card as Dictionary).get("accepted", true)),
			"a boss retreat must come back rejected: %s" % str(via_play_card))

	var structured: Variant = face["submit_command"].call({
		"type": "end_turn",
		"state_version": controller.state.event_log.size(),
		"expected_phase": str(controller.current_battle.get("phase", "player_action")),
	})
	assert_true(structured is Dictionary,
			"the submit_command channel must hand the envelope back, not null: %s" % str(structured))
	assert_true(bool((structured as Dictionary).get("accepted", false)),
			"a fresh structured command must be accepted: %s" % str(structured))


## 两代卡 id 形状（现行 `battle.end_turn` 与旧信封 `battle.<battle_id>.end_turn`）
## 都必须真的通过 controller 的 preflight 并推进同一条结算路径——否则"声明兼容"
## 只剩"提交被拒"。这里走的是真实提交缝，不是 facade 直调。
func test_both_card_id_shapes_pass_the_controller_preflight() -> void:
	for action_id in ["battle.end_turn", "battle.v1.end_turn"]:
		var controller: RunController = _controller(_combat_node())
		_enter_battle(controller)
		var version := controller.state.event_log.size()

		var out: Dictionary = controller.submit_command(
				RunCommandBuilderScript._battle_card_command(controller, str(action_id), ""))

		assert_true(bool(out.get("accepted", false)),
				"%s must pass the controller preflight: %s" % [action_id, str(out.get("feeds", []))])
		assert_eq(str(out.get("result", "")), "ongoing", "%s must resolve as a normal turn" % action_id)
		assert_gt(controller.state.event_log.size(), version,
				"%s must actually advance the turn, not sit rejected" % action_id)


## 撤离卡的两代形状必须落到同一套 F-01 门禁：普通战斗都放行、Boss 战都以
## **同一个理由**拒绝且零副作用。
func test_both_retreat_card_id_shapes_hit_the_same_retreat_gate() -> void:
	for action_id in ["battle.retreat", "battle.v1.retreat"]:
		var controller: RunController = _controller(_combat_node())
		_enter_battle(controller)
		var out: Dictionary = controller.submit_command(
				RunCommandBuilderScript._battle_card_command(controller, str(action_id), ""))
		assert_true(bool(out.get("accepted", false)),
				"%s must retreat through the shared gate: %s" % [action_id, str(out.get("feeds", []))])
		assert_eq(str(out.get("result", "")), "retreat")
		assert_eq(_count(controller.state.event_log, "battle_finished"), 1,
				"%s must be closed by exactly one battle_finished event" % action_id)

	var reasons: Array = []
	for action_id in ["battle.retreat", "battle.v1.retreat"]:
		var controller: RunController = _controller(_combat_node(["ridge_hound"], {"layer_boss": 2}))
		_enter_battle(controller)
		var battle_before := controller.current_battle.duplicate(true)
		var log_before := controller.state.event_log.size()
		var out: Dictionary = controller.submit_command(
				RunCommandBuilderScript._battle_card_command(controller, str(action_id), ""))
		assert_false(bool(out.get("accepted", false)), "%s must be refused against a boss" % action_id)
		assert_eq(controller.current_battle, battle_before,
				"a refused retreat must not touch the battle")
		assert_eq(controller.state.event_log.size(), log_before,
				"a refused retreat must not append events")
		reasons.append(str(out.get("reason", "")))
	assert_eq(reasons[0], reasons[1],
			"both declared id shapes must answer through the same gate")
	assert_false(str(reasons[0]).is_empty(), "the refusal must name a reason")


## 真实 controller + 真实命令面 + 真实战斗屏：被拒的旧 `play_card` 不得进入成功态、
## 不得播墨迹，且必须可重试（拒绝文案让玩家"重试"，去重键不释放就永远重试不了）。
func test_rejected_legacy_play_card_keeps_the_battle_screen_retryable() -> void:
	var controller: RunController = _controller(_combat_node(["ridge_hound"], {"layer_boss": 2}))
	_enter_battle(controller)
	var forwarded: Array = []
	var envelopes: Array = []
	var host := _mount_real_battle_screen(controller, forwarded, envelopes)
	var screen := _screen_of(host)
	assert_not_null(screen, "the real battle screen must mount")
	if screen == null:
		return
	var card := {
		"id": "battle.retreat", "type": "retreat", "title": "撤离",
		"executable": true, "target_type": "none", "known_risk": [],
	}

	screen._play_card(card)
	assert_eq(forwarded, ["battle.retreat"],
			"a card without a structured command must reach the play_card channel")
	assert_eq(envelopes.size(), 1)
	var envelope: Variant = envelopes[0]
	assert_true(envelope is Dictionary,
			"the play_card channel must hand the domain envelope back to the screen")
	assert_false(bool((envelope as Dictionary).get("accepted", true)),
			"a boss battle must refuse the legacy retreat card: %s" % str(envelope))
	assert_ne(str(screen._mode), "play_success",
			"a rejected card must not enter the success state")
	assert_false(bool(screen._ink_overlay.visible),
			"a rejected card must not play the success ink animation")
	assert_false(str(controller.last_feedback).is_empty(),
			"a rejected card must leave player-facing feedback")
	assert_eq(str(controller.last_feedback),
			RejectionTextScript.text(str((envelope as Dictionary).get("reason", ""))),
			"the visible text must come from the reason the domain actually answered")
	assert_eq(str(controller._snapshot_for("Battle").get("feedback", "")),
			str(controller.last_feedback),
			"the Battle snapshot must carry the rejection text for the toast")

	screen._play_card(card)
	assert_eq(forwarded.size(), 2,
			"the rejection text asks the player to retry; the dedup key must be released")


# ---------- 战死与重新开始 ----------

func test_battle_death_ends_the_run_with_the_precise_cause_then_a_fresh_run_resets() -> void:
	var controller: RunController = _controller(_combat_node())
	controller.state.health = 2
	controller.state.max_health = 2
	_enter_battle(controller)
	# 先落一份进行中存档，才能证明"结局即此世终点"确实清掉了它。
	assert_eq(SaveRepositoryScript.save_run(controller.state, controller.route, []), OK)
	assert_true(FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH))

	var lethal: Dictionary = controller.submit_command({
		"type": "end_turn",
		"state_version": controller.state.event_log.size(),
		"expected_phase": str(controller.current_battle.get("phase", "player_action")),
	})
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
		return controller.submit_command({
			"type": "end_turn",
			"state_version": controller.state.event_log.size(),
			"expected_phase": str(controller.current_battle.get("phase", "player_action")),
		})
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


## 用**真实** controller 与真实命令面挂载战斗屏：命令面取
## `controller._build_commands("Battle")`（生产实现），只把 `play_card` 包一层
## 转发计数，转呈逻辑仍是生产代码本身。
func _mount_real_battle_screen(controller: RunController, forwarded: Array, envelopes: Array) -> Node:
	var face: Dictionary = controller._build_commands("Battle")
	var commands := {
		"submit_command": face["submit_command"],
		"play_card": func(action_id, target_id, confirmed = false):
			forwarded.append(str(action_id))
			var out: Variant = face["play_card"].call(action_id, target_id, confirmed)
			envelopes.append(out)
			return out,
		"end_turn": face["end_turn"],
		"flee": face["flee"],
	}
	var host := Control.new()
	add_child(host)
	_hosts.append(host)
	var inst := TscnMountHelper.instantiate(
			"res://scenes/ui/screens/battle_screen.tscn",
			controller._snapshot_for("Battle"), commands)
	host.add_child(inst)
	return host


func _screen_of(host: Node) -> Node:
	for child in host.get_children():
		if child is BattleScreenView:
			return child
	return null


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