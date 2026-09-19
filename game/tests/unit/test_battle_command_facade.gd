extends GutTest


## V1 战斗门面测试（2026-08-30 全量替换卡牌战斗）：路由经
## BattleCommandFacade → V1BattleResolver（蛊行动制）。


const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const V1Script = preload("res://scripts/domain/v1_battle_resolver.gd")
const CommandSpecRegistryScript = preload("res://scripts/domain/command_spec_registry.gd")
const RunCommandBuilderScript = preload("res://scripts/presentation/run_command_builder.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")


var catalog: Dictionary
var _hosts: Array = []
var _rejected_payloads: Array = []


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func after_each() -> void:
	for host in _hosts:
		if is_instance_valid(host):
			host.free()
	_hosts.clear()


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
	# 敌人 2 伤，玩家气血 100→98；真元按回复 +5（20 满则不变）。
	assert_eq(int(result["battle"]["player"]["hp"]), 98)
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
	var battle: Dictionary = FacadeScript.start(
			{"enemy_kind": "beast_swarm", "terrain": "path"}, state, catalog)

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
	# 普通战斗不落 Boss 旗标、可撤（同预览：还需开放地形与元石）。
	var common: Dictionary = FacadeScript.start(
			{"enemy_kind": "ridge_hound", "terrain": "path"}, state, catalog)
	assert_false(bool(common["flags"].get("boss_battle", false)), "trivial fight must not be a boss")
	var out: Dictionary = FacadeScript.apply_turn(common, state, {"type": "retreat"}, catalog)
	assert_eq(out["result"], "retreat")


func test_enemy_first_mover_resolves_before_player() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm", "first_mover": "enemy"}, state, catalog)

	var pre: Dictionary = FacadeScript.apply_enemy_pre_turn(battle, state, catalog)

	assert_eq(int(pre["battle"]["player"]["hp"]), 98)
	# 敌人先手一次完整回合后，战斗进入第 2 回合（玩家行动阶段）。
	assert_eq(int(pre["battle"]["turn"]), 2)
	assert_eq(pre["finished"], false)


func test_facade_is_deterministic_for_same_seed_and_command_sequence() -> void:
	assert_eq(_run_sequence(4242), _run_sequence(4242))


# ==== Agent B: battle mouse command contract ====

## gu.<instance_id> 点击 → use_gu 命令，state_version 取自当前事件日志长度。
func test_gu_click_builds_use_gu_command_with_current_log_version() -> void:
	var state := RunState.new_run(101)
	var command: Dictionary = RunCommandBuilderScript._battle_card_command(
			_stub_controller(state), "gu.inst_1", "")

	assert_eq(str(command["type"]), "use_gu")
	assert_eq(str(command["instance_id"]), "inst_1")
	assert_eq(int(command["state_version"]), state.event_log.size())


## 单目标卡在构造命令前保留 target_id，命令信封内透传。
func test_single_target_card_retains_target_until_command_construction() -> void:
	var controller := _stub_controller(RunState.new_run(101), {"battle_id": "v1", "phase": "player"})
	var command: Dictionary = RunCommandBuilderScript._battle_card_command(
			controller, "battle.v1.some_card", "e0")

	assert_eq(str(command["target_id"]), "e0")
	assert_eq(str(command["card_id"]), "some_card")


## 同一 card/target 键在呈现边界只允许一次下发，不产生第二个领域命令。
func test_repeated_card_target_click_submits_exactly_once() -> void:
	var played: Array = []
	var host := _mount_battle_screen(func(card_id, target_id): played.append([card_id, target_id]), [
		{"id": "gu.inst_1", "name": "月光蛊", "executable": true,
			"target_type": "single_enemy", "valid_target_ids": ["e0"]},
	])
	var screen := _screen_of(host)
	var card: Dictionary = screen._snapshot.get("hand", [])[0]

	screen._submit_card(card, "e0")
	screen._submit_card(card, "e0")

	assert_eq(played, [["gu.inst_1", "e0"]],
			"a repeated UI signal must not replay play_card against the same snapshot")


## 相同 hand_version 重新挂载（刷新/重渲染）不得解除已建立的防重复提交保护。
func test_remount_same_hand_version_keeps_dedup_guard() -> void:
	var played: Array = []
	var host := _mount_battle_screen(func(card_id, target_id): played.append([card_id, target_id]), [
		{"id": "gu.inst_1", "name": "月光蛊", "executable": true,
			"target_type": "single_enemy", "valid_target_ids": ["e0"]},
	])
	var screen := _screen_of(host)
	var card: Dictionary = screen._snapshot.get("hand", [])[0]

	screen._submit_card(card, "e0")
	screen.mount_snapshot(screen._snapshot, {"play_card": func(c, t): played.append([c, t])})
	screen._submit_card(card, "e0")

	assert_eq(played, [["gu.inst_1", "e0"]],
			"remounting the same hand_version must not replay play_card against the same snapshot")


## 新 hand_version（领域状态推进）重新挂载应允许重新提交同一卡/目标。
func test_remount_new_hand_version_allows_resubmit() -> void:
	var played: Array = []
	var host := _mount_battle_screen(func(card_id, target_id): played.append([card_id, target_id]), [
		{"id": "gu.inst_1", "name": "月光蛊", "executable": true,
			"target_type": "single_enemy", "valid_target_ids": ["e0"]},
	])
	var screen := _screen_of(host)
	var card: Dictionary = screen._snapshot.get("hand", [])[0]

	screen._submit_card(card, "e0")
	var next_snapshot: Dictionary = screen._snapshot.duplicate(true)
	next_snapshot["hand_version"] = 5
	screen.mount_snapshot(next_snapshot, {"play_card": func(c, t): played.append([c, t])})
	screen._submit_card(card, "e0")

	assert_eq(played, [["gu.inst_1", "e0"], ["gu.inst_1", "e0"]],
			"a new hand_version must allow the same card/target to be submitted again")


# ==== F-02 复验：旧 play_card 兼容包装与拒绝分支不得产生成功动效 ====

## 旧 `play_card` 按现行手牌 id（`battle.end_turn`，不含 battle_id 段）组装命令后，
## 执行侧必须仍命中同一条路由——否则兼容包装只剩"提交被拒"。
func test_legacy_play_card_end_turn_still_routes_to_the_shared_turn_path() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start(
			{"enemy_kind": "beast_swarm", "terrain": "path"}, state, catalog)
	var legacy: Dictionary = RunCommandBuilderScript._battle_card_command(
			_stub_controller(state, battle), "battle.end_turn", "")

	assert_eq(str(legacy.get("type", "")), "action_card",
			"the legacy wrapper must still send an action_card envelope")
	var out: Dictionary = FacadeScript.apply_turn(battle, state, legacy, catalog)
	assert_true(bool(out.get("accepted", false)),
			"legacy battle.end_turn must still route: %s" % str(out.get("feeds", [])))
	assert_eq(str(out.get("result", "")), "ongoing")


## 旧 `play_card("battle.retreat")` 同样必须落到 F-01 同一套撤离门禁上。
func test_legacy_play_card_retreat_still_routes_to_the_gated_retreat() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start(
			{"enemy_kind": "beast_swarm", "terrain": "path"}, state, catalog)
	var legacy: Dictionary = RunCommandBuilderScript._battle_card_command(
			_stub_controller(state, battle), "battle.retreat", "")

	var out: Dictionary = FacadeScript.apply_turn(battle, state, legacy, catalog)
	assert_true(bool(out.get("accepted", false)),
			"legacy battle.retreat must still route: %s" % str(out.get("feeds", [])))
	assert_eq(str(out.get("result", "")), "retreat")


## 被拒的卡命令（新鲜度过期 / 门禁不通过）不得播放成功音效与墨迹，不得进入
## 成功态；去重键必须释放，让拒绝文案里的"请重试"真的可重试。
func test_rejected_card_command_skips_success_effects_and_allows_retry() -> void:
	_rejected_payloads = []
	var commands := {"submit_command": Callable(self, "_rejecting_submit")}
	var hand := [{"id": "gu.inst_1", "name": "月光蛊", "executable": true, "command": {
		"type": "use_gu", "instance_id": "inst_1",
		"state_version": 1, "expected_phase": "player_action"}}]
	var host := _mount_battle_screen_with(commands, hand)
	var screen := _screen_of(host)
	var card: Dictionary = screen._snapshot.get("hand", [])[0]

	screen._submit_card(card, "")
	assert_eq(_rejected_payloads.size(), 1, "the card must be forwarded once")
	assert_ne(str(screen._mode), "play_success",
			"a rejected card must not enter the success state")
	assert_false(bool(screen._ink_overlay.visible),
			"a rejected card must not play the success ink animation")

	screen._submit_card(card, "")
	assert_eq(_rejected_payloads.size(), 2,
			"a rejected card must stay retryable once its dedup key is released")


# ==== Agent B 返工 P2-4：效果事件日志事实字段 ====

## status 蛊的 use_gu 事件日志必须携带状态名与目标敌人 ID，amount 与 resolver 一致。
func test_v1_status_effect_log_carries_name_amount_and_target() -> void:
	var run := RunState.new_run(101)
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_instances = {}
	var status_id := "st_00"
	run.cave_aperture["stored_gu_instance_ids"].append(status_id)
	# venom_thread_gu 于 802 重建删去；以现存侦察蛊 light_rec_1_10_gu 的 role 兜底
	# 状态效果（recon → status marked）锚定同一日志契约。
	run.gu_instances[status_id] = GuInstanceScript.new_instance("light_rec_1_10_gu", status_id, catalog)
	var battle := FacadeScript.start(
			{"enemy_kinds": ["beast_swarm", "iron_hide_boar"]}, run, catalog)
	var out := FacadeScript.apply_turn(
			battle, run,
			{"type": "use_gu", "instance_id": status_id, "target_id": "iron_hide_boar"}, catalog)

	assert_true(bool(out["accepted"]))
	var event: Dictionary = out["state"].event_log.back()
	var effect: Dictionary = event["info"]["effect"]
	assert_eq(str(effect["kind"]), "status")
	assert_eq(str(effect["name"]), "marked", "status effect log must record the status name")
	assert_eq(int(effect["amount"]), 1, "status amount must match the resolver-applied amount")
	assert_eq(str(effect["target_id"]), "iron_hide_boar", "status log must record the targeted enemy id")


## heal_and_strike 蛊的 use_gu 事件日志必须记录治疗量与目标敌人 ID。
func test_v1_heal_and_strike_effect_log_carries_heal_and_target() -> void:
	var run := RunState.new_run(101)
	run.health = 1
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_instances = {}
	var heal_id := "he_00"
	run.cave_aperture["stored_gu_instance_ids"].append(heal_id)
	# blood_moss_gu 于 802 重建删去；现存血蝠蛊 blood_bat_gu 是同款 heal_and_strike 锚。
	run.gu_instances[heal_id] = GuInstanceScript.new_instance("blood_bat_gu", heal_id, catalog)
	var battle := FacadeScript.start(
			{"enemy_kinds": ["beast_swarm", "iron_hide_boar"]}, run, catalog)
	var out := FacadeScript.apply_turn(
			battle, run,
			{"type": "use_gu", "instance_id": heal_id, "target_id": "iron_hide_boar"}, catalog)

	assert_true(bool(out["accepted"]))
	var event: Dictionary = out["state"].event_log.back()
	var effect: Dictionary = event["info"]["effect"]
	assert_eq(str(effect["kind"]), "heal_and_strike")
	assert_eq(int(effect["heal"]), 1, "heal_and_strike log must record the heal amount")
	assert_eq(str(effect["target_id"]), "iron_hide_boar", "heal_and_strike log must record the targeted enemy id")
	assert_eq(int(effect["amount"]), 1)


## 复审 P3：目标为空/无效时 resolver 回退首个存活敌人，事件日志必须记录
## 实际命中的敌人 ID，而不是请求中的空目标。
func test_v1_status_log_records_fallback_target_when_request_empty() -> void:
	var run := RunState.new_run(101)
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_instances = {}
	var status_id := "st_fb"
	run.cave_aperture["stored_gu_instance_ids"].append(status_id)
	# 同上：venom_thread_gu 已删，改以 light_rec_1_10_gu（recon → status marked）为锚。
	run.gu_instances[status_id] = GuInstanceScript.new_instance("light_rec_1_10_gu", status_id, catalog)
	var battle := FacadeScript.start(
			{"enemy_kinds": ["beast_swarm", "iron_hide_boar"]}, run, catalog)
	var out := FacadeScript.apply_turn(
			battle, run,
			{"type": "use_gu", "instance_id": status_id}, catalog)

	assert_true(bool(out["accepted"]))
	var event: Dictionary = out["state"].event_log.back()
	var effect: Dictionary = event["info"]["effect"]
	assert_eq(str(effect["kind"]), "status")
	assert_eq(str(effect["target_id"]), "beast_swarm",
			"empty requested target must resolve to the actual (first alive) enemy in the log")


## 禁用卡保持可见（卡体仍可悬停），但点按绝不触发 play_card。
func test_disabled_card_stays_visible_and_never_submits() -> void:
	var played: Array = []
	var host := _mount_battle_screen(func(card_id, target_id): played.append([card_id, target_id]), [
		{"id": "gu.blocked", "name": "封印蛊", "executable": false,
			"block_reason": "本回合已催动。", "target_type": "none"},
	])
	var screen := _screen_of(host)
	var body := _find_card_body(screen, "gu.blocked")
	assert_not_null(body, "disabled cards stay visible as a clickable card body")
	if body == null:
		return
	(body as Button).pressed.emit()

	assert_true(played.is_empty())
	assert_eq(str(screen._snapshot.get("hand", [])[0].get("block_reason", "")), "本回合已催动。")


## 过期事件日志版本的战斗回合命令被 preflight 拒绝，且不改动 RunState。
func test_stale_battle_command_is_rejected_by_preflight_without_mutation() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var expected := state.event_log.size()
	var stale: Dictionary = CommandSpecRegistryScript.preflight(
			"battle.turn", state, battle, {},
			{"type": "end_turn", "state_version": expected - 1, "expected_phase": "player"},
			catalog)

	assert_false(stale["ok"])
	assert_eq(stale["reason"], "battle_action_stale")
	assert_eq(state.event_log.size(), expected,
			"preflight rejection must not mutate RunState")


## 两代卡 id 形状归一到同一组现行 id（唯一映射点在门面）：preflight 与执行侧
## 因此不可能各自持一份形状表，旧形状也不会"查不到卡"。
func test_card_id_shapes_canonicalise_to_the_current_hand_ids() -> void:
	var pairs := {
		"battle.end_turn": "battle.end_turn",
		"battle.v1.end_turn": "battle.end_turn",
		"battle.retreat": "battle.retreat",
		"battle.v1.retreat": "battle.retreat",
		"battle.v1.basic.punch": "basic_attack",
		"gu.inst_1": "gu.inst_1",
	}
	for raw in pairs:
		assert_eq(FacadeScript.canonical_action_card_id(str(raw)), str(pairs[raw]),
				"%s must canonicalise to %s" % [raw, pairs[raw]])

	# 路由侧同源：两代形状必须落到同一个 passthrough 结果。
	var battle := {"battle_id": "v1"}
	assert_eq(FacadeScript._action_card_passthrough(battle, {"action_id": "battle.end_turn"}), "end_turn")
	assert_eq(FacadeScript._action_card_passthrough(battle, {"action_id": "battle.v1.end_turn"}), "end_turn")
	assert_eq(FacadeScript._action_card_passthrough(battle, {"action_id": "battle.retreat"}), "retreat")
	assert_eq(FacadeScript._action_card_passthrough(battle, {"action_id": "battle.v1.retreat"}), "retreat")
	assert_eq(FacadeScript._action_card_passthrough(battle, {"action_id": "battle.v1.basic.punch"}), "basic_attack")
	# 归一不依赖 battle 上的 battle_id 键（生产战斗从不设置它）。
	assert_eq(FacadeScript.canonical_action_card_id("battle.v1.end_turn"), "battle.end_turn")
	assert_eq(FacadeScript._action_card_passthrough({}, {"action_id": "battle.v1.retreat"}), "retreat")


## 过期战斗手牌版本（battle_hand）被 preflight 拒绝。
func test_stale_battle_hand_is_rejected_by_preflight() -> void:
	var state := RunState.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	battle["hand_version"] = 2
	var stale: Dictionary = CommandSpecRegistryScript.preflight(
			"battle.action_card", state, battle, {},
			{"type": "action_card", "action_id": "battle.v1.basic.punch",
				"state_version": 1, "expected_phase": "player"},
			catalog)

	assert_false(stale["ok"])
	assert_eq(stale["reason"], "battle_hand_stale")


# ==== Agent B 返工 P1-3：use_gu 目标贯穿 ====

## gu.<instance_id> 点击携带 target_id 时，命令信封必须保留该字段。
func test_gu_click_command_preserves_selected_target_id() -> void:
	var state := RunState.new_run(101)
	var command: Dictionary = RunCommandBuilderScript._battle_card_command(
			_stub_controller(state), "gu.inst_1", "e1")

	assert_eq(str(command["type"]), "use_gu")
	assert_eq(str(command["instance_id"]), "inst_1")
	assert_eq(str(command["target_id"]), "e1")


## 多敌战斗中，use_gu 命令指定 target_id 必须命中该敌人，而非首个存活敌人。
func test_use_gu_hits_the_selected_enemy_not_the_first() -> void:
	var run := RunState.new_run(101)
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_instances = {}
	var instance_id := "tgt_00"
	run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.gu_instances[instance_id] = GuInstanceScript.new_instance("small_light_gu", instance_id, catalog)
	# 敌人 id 即 kind；beast_swarm hp4 / iron_hide_boar hp5 / thunder_crown_wolf hp7。
	var battle := FacadeScript.start(
			{"enemy_kinds": ["beast_swarm", "iron_hide_boar", "thunder_crown_wolf"]},
			run, catalog)
	var out := FacadeScript.apply_turn(
			battle, run,
			{"type": "use_gu", "instance_id": instance_id, "target_id": "thunder_crown_wolf"},
			catalog)

	assert_true(bool(out["accepted"]))
	var enemies: Array = out["battle"]["enemies"]
	assert_eq(int(enemies[0]["hp"]), 4, "first enemy must be untouched when a later target is chosen")
	assert_eq(int(enemies[1]["hp"]), 5, "second enemy must be untouched")
	assert_eq(int(enemies[2]["hp"]), 6, "selected third enemy must take the strike")


func test_ordinary_encounter_does_not_apply_boss_layer_scaling() -> void:
	var state := RunState.new_run(101)
	var test_catalog := _catalog_with_scale_probe()
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "boss_scale_probe"}, state, test_catalog)
	assert_eq(int(battle["enemies"][0]["hp"]), 20)
	assert_eq(int(battle["enemies"][0]["intent"]["damage"]), 20)
	assert_true(bool(battle["flags"].get("boss_battle", false)))


func test_layer_boss_applies_central_l1_to_l5_hp_and_damage_multipliers() -> void:
	var state := RunState.new_run(101)
	var test_catalog := _catalog_with_scale_probe()
	var cases := [{"layer": 1, "hp": 20, "damage": 20}, {"layer": 2, "hp": 22, "damage": 21}, {"layer": 3, "hp": 24, "damage": 22}, {"layer": 4, "hp": 27, "damage": 23}, {"layer": 5, "hp": 30, "damage": 25}]
	for case in cases:
		var battle: Dictionary = FacadeScript.start({"enemy_kind": "boss_scale_probe", "layer_boss": int(case["layer"])}, state, test_catalog)
		assert_eq(int(battle["enemies"][0]["hp"]), int(case["hp"]))
		assert_eq(int(battle["enemies"][0]["intent"]["damage"]), int(case["damage"]))


func test_layer_boss_scaling_falls_back_for_missing_invalid_and_nonpositive_values() -> void:
	var state := RunState.new_run(101)
	var missing := _catalog_with_scale_probe()
	missing["v1_battle"] = {}
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "boss_scale_probe", "layer_boss": 3}, state, missing)
	assert_eq(int(battle["enemies"][0]["hp"]), 20)
	assert_eq(int(battle["enemies"][0]["intent"]["damage"]), 20)
	var invalid_layer := _catalog_with_scale_probe()
	battle = FacadeScript.start({"enemy_kind": "boss_scale_probe", "layer_boss": 6}, state, invalid_layer)
	assert_eq(int(battle["enemies"][0]["hp"]), 20)
	assert_eq(int(battle["enemies"][0]["intent"]["damage"]), 20)
	var invalid := _catalog_with_scale_probe()
	invalid["v1_battle"]["boss_layer_mult"]["three"] = {"hp": "bad", "damage": 0.0}
	battle = FacadeScript.start({"enemy_kind": "boss_scale_probe", "layer_boss": 3}, state, invalid)
	assert_eq(int(battle["enemies"][0]["hp"]), 20)
	assert_eq(int(battle["enemies"][0]["intent"]["damage"]), 20)


func test_layer_boss_scaling_rounds_floors_and_preserves_nonattack_intents() -> void:
	var state := RunState.new_run(101)
	var rounded := _catalog_with_scale_probe(3, 3)
	rounded["v1_battle"]["boss_layer_mult"]["one"] = {"hp": 1.5, "damage": 1.5}
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "boss_scale_probe", "layer_boss": 1}, state, rounded)
	assert_eq(int(battle["enemies"][0]["hp"]), 5)
	assert_eq(int(battle["enemies"][0]["intent"]["damage"]), 5)
	var zero := _catalog_with_scale_probe(1, 0)
	zero["v1_battle"]["boss_layer_mult"]["one"] = {"hp": 2.0, "damage": 2.0}
	battle = FacadeScript.start({"enemy_kind": "boss_scale_probe", "layer_boss": 1}, state, zero)
	assert_eq(int(battle["enemies"][0]["hp"]), 2)
	assert_eq(int(battle["enemies"][0]["intent"]["damage"]), 0)
	var floored := _catalog_with_scale_probe(1, 1)
	floored["v1_battle"]["boss_layer_mult"]["one"] = {"hp": 0.1, "damage": 0.1}
	battle = FacadeScript.start({"enemy_kind": "boss_scale_probe", "layer_boss": 1}, state, floored)
	assert_eq(int(battle["enemies"][0]["hp"]), 1)
	assert_eq(int(battle["enemies"][0]["intent"]["damage"]), 1)
	var nonattack := _catalog_with_scale_probe(4, 7, "seal")
	nonattack["v1_battle"]["boss_layer_mult"]["one"] = {"hp": 2.0, "damage": 2.0}
	battle = FacadeScript.start({"enemy_kind": "boss_scale_probe", "layer_boss": 1}, state, nonattack)
	assert_eq(int(battle["enemies"][0]["hp"]), 8)
	var mapped_intent: Dictionary = battle["enemies"][0]["intent"]
	assert_eq(mapped_intent, {
		"kind": "seal",
		# H3（Q8 Step 4）：意图带 damage_intent 语义属性——seal 类非伤害意图为 false。
		"damage_intent": false,
		"damage": 7,
		"label": "倍率探针",
		"speed": 3,
		"seal_turns": 2,
		"soul_drain": 4,
		"life_cost": 5,
		"counter_tag": "probe_counter",
	})


func test_rank_one_player_can_act_in_layer_five_boss_but_not_use_rank_two_gu() -> void:
	var state := RunState.new_run(101)
	state.cultivation = 1
	state.cave_aperture["stored_gu_instance_ids"] = []
	state.gu_instances = {}
	var test_catalog := catalog.duplicate(true)
	test_catalog["gu_by_id"]["rank_two_probe_gu"] = {"id": "rank_two_probe_gu", "combat": "strike", "school": "qi", "role": "attack", "rarity": "rare", "rank": 2, "true_qi_cost": 1, "v1_effect": {"kind": "strike", "amount": 3}}
	var instance_id := "rank_two_probe_00"
	state.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	state.gu_instances[instance_id] = GuInstanceScript.new_instance("rank_two_probe_gu", instance_id, test_catalog)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "ridge_hound", "layer_boss": 5}, state, test_catalog)
	assert_eq(int(battle["player"]["cultivation"]), 1)
	assert_true(bool(battle["flags"].get("boss_battle", false)))
	var punched: Dictionary = FacadeScript.apply_turn(battle, state, {"type": "basic_attack"}, test_catalog)
	assert_true(bool(punched.get("accepted", false)))
	var blocked: Dictionary = FacadeScript.apply_turn(battle, state, {"type": "use_gu", "instance_id": instance_id}, test_catalog)
	assert_false(bool(blocked.get("accepted", true)))
	assert_eq(blocked.get("feeds", []), ["insufficient_qi_quality"])


## 注入用的假 submit_command：记录载荷并返回领域拒绝信封（新鲜度过期形状）。
func _rejecting_submit(payload) -> Dictionary:
	_rejected_payloads.append(payload)
	return {
		"accepted": false, "ok": false, "result": "rejected", "finished": false,
		"feeds": ["battle_action_stale"], "reason": "battle_action_stale",
	}


func _catalog_with_scale_probe(hp: int = 20, damage: int = 20, intent_kind: String = "attack") -> Dictionary:
	var test_catalog := catalog.duplicate(true)
	var enemy_by_id: Dictionary = test_catalog.get("enemy_by_id", {})
	enemy_by_id["boss_scale_probe"] = {"id": "boss_scale_probe", "tier": "boss", "hp": hp, "intent": {"kind": intent_kind, "damage": damage, "label": "倍率探针", "speed": 3, "seal_turns": 2, "soul_drain": 4, "life_cost": 5, "counter_tag": "probe_counter"}}
	test_catalog["enemy_by_id"] = enemy_by_id
	return test_catalog
func _stub_controller(state: RunState, battle: Dictionary = {}) -> Dictionary:
	# M3：current_session 字段已删；stub 走 state.encounter_session。
	state.encounter_session = {}
	return {"state": state, "current_battle": battle, "current_node": {}}


func _mount_battle_screen(on_play: Callable, hand: Array) -> Control:
	return _mount_battle_screen_with({"play_card": on_play}, hand)


## 允许注入任意命令面（旧 play_card 通道与新的 submit_command 通道都要能挂）。
func _mount_battle_screen_with(commands: Dictionary, hand: Array) -> Control:
	var host := Control.new()
	add_child(host)
	_hosts.append(host)
	var state := {
		"resources": {}, "contracts": [], "anomalies": [], "death_lines": {},
		"enemies": [{"id": "e0", "name": "敌人0", "hp": 20, "max_hp": 20, "shield": 0,
			"statuses": [], "intent": {"type": "attack", "value": 4, "detail": "冲撞"}, "alive": true}],
		"player": {"hp": 20, "max_hp": 20, "shield": 0, "primordial": 3, "soul": 4, "statuses": []},
		"hand": hand,
		"piles": {"draw": 0, "discard": 0, "exhausted": 0}, "soul_ops": {"cap": 1, "used": 0},
		"default_target_id": "e0",
	}
	var inst := TscnMountHelper.instantiate(
			"res://scenes/ui/screens/battle_screen.tscn",
			state, commands)
	host.add_child(inst)
	return host


func _screen_of(host: Node) -> Node:
	for child in host.get_children():
		if child is BattleScreenView:
			return child
	return null


func _find_card_body(node: Node, card_id: String) -> Node:
	# Godot 会把节点名里的 "." 规范化成 "_"（card_body_gu.inst_1 → card_body_gu_inst_1）。
	var sanitized := str(card_id).replace(".", "_")
	return node.find_child("card_body_" + sanitized, true, false)


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
