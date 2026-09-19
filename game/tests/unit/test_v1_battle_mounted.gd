extends GutTest


## 真实挂载战斗验证（V1 契约，2026-09-01）：经 RunController 开一场真实战斗 →
## RunSnapshotBuilder 出快照 → 挂载 battle_screen.tscn → 通过屏的命令边界
## 实跑 use_gu / end_turn → 断言渲染文本与领域状态推进，最终打穿到 victory。
## 这是「resolver / facade / snapshot / UI 共用唯一 V1 战斗 Schema」的端到端钉。


const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")
const RunCommandBuilderScript = preload("res://scripts/presentation/run_command_builder.gd")
const BATTLE_SCREEN_TSCN := "res://scenes/ui/screens/battle_screen.tscn"


func test_mounted_v1_battle_renders_and_drives_real_commands() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller.start_new_run(101)
	controller.current_node = {"id": "beast_swarm_pass", "type": "combat", "enemy_kind": "ridge_hound"}
	controller._start_battle()

	var battle: Dictionary = controller.current_battle
	# V1 领域契约形态：player/gu_slots/thoughts/true_qi，flags 为 Dictionary。
	assert_true(battle.has("player"), "V1 battle must carry player state")
	assert_true(battle.has("gu_slots"), "V1 battle must carry gu slots")
	assert_true(battle["flags"] is Dictionary, "V1 battle flags must be a Dictionary")
	assert_false(battle.has("draw_pile"), "V1 battle must not carry card piles")
	assert_false(battle.has("actions_max"), "V1 battle must not carry legacy action pool")

	var snapshot: Dictionary = controller._snapshot_for("Battle")
	assert_eq(int(snapshot["player"]["primordial"]), 20, "true qi from V1 player state")
	assert_eq(int(snapshot["actions"]["max"]), 2, "soul-tier action budget")
	var slot_id := str(battle["gu_slots"][0]["instance_id"])
	var hand_ids: Array = []
	for card in snapshot["hand"]:
		hand_ids.append(str(card.get("id", "")))
	assert_true(hand_ids.has("gu." + slot_id), "hand must expose V1 gu slot card")
	assert_true(hand_ids.has("basic_attack"), "hand must expose basic attack card")

	# 挂载战斗屏，附带真实命令边界。
	var cmds := RunCommandBuilderScript.for_screen("Battle", controller)
	var host := Control.new()
	add_child_autofree(host)
	host.add_child(TscnMountHelper.instantiate(BATTLE_SCREEN_TSCN, snapshot, cmds))
	await get_tree().process_frame
	var texts := _collect_texts(host)
	assert_true(_any_contains(texts, "真元 20"), "mounted battle renders true qi")
	assert_true(_any_contains(texts, "意图："), "mounted battle renders enemy intent")
	assert_true(_any_contains(texts, "山脊猎犬"), "mounted battle renders enemy name")

	# 通过屏的命令边界施放小光蛊（use_gu）：念头 2→1、敌人 -1 血。
	var enemy_hp_before := int(battle["enemies"][0]["hp"])
	cmds["play_card"].call("gu." + slot_id, "")
	assert_eq(int(controller.current_battle["player"]["thoughts"]), 1, "one action spent")
	assert_eq(int(controller.current_battle["enemies"][0]["hp"]), enemy_hp_before - 1, "gu strike lands")

	# 收势：敌人意图结算（山脊猎犬 2 伤），念头回满。
	cmds["end_turn"].call()
	assert_eq(int(controller.current_battle["turn"]), 2)
	assert_eq(int(controller.current_battle["player"]["thoughts"]), 2)
	assert_eq(int(controller.current_battle["player"]["hp"]), 100 - 2, "enemy intent resolved")

	# 快照与推进后的领域状态保持同源。
	var after: Dictionary = controller._snapshot_for("Battle")
	assert_eq(int(after["actions"]["max"]), 2)
	assert_eq(int(after["actions"]["left"]), 2)

	# 打穿：共 3 发小光（山脊猎犬 3 血），第 3 发触发 victory，走统一结算。
	# 注意：victory 使 current_battle 清空（_finish_battle_in_session），
	# 结局判定必须读 last_result.battle_result，不能读已清空的 current_battle。
	var final_result := "ongoing"
	for _round in 2:
		cmds["play_card"].call("gu." + slot_id, "")
		final_result = str(controller.last_result.get("battle_result", ""))
		if final_result == "victory":
			break
		cmds["end_turn"].call()
	assert_eq(final_result, "victory", "v1 battle resolves to victory")
	assert_eq(controller.current_view_name(), "Reward", "victory enters the unified post-battle view")


func _collect_texts(node: Node, out: Array[String] = []) -> Array[String]:
	if node is Label:
		out.append(str(node.text))
	for c in node.get_children():
		_collect_texts(c, out)
	return out


func _any_contains(texts: Array[String], substring: String) -> bool:
	for text in texts:
		if str(text).contains(substring):
			return true
	return false