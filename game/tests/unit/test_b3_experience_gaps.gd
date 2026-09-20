extends "res://addons/gut/test.gd"


# B3 experience gaps from the review: intent speed on the UI, first-battle
# guidance, three-way run-end statistics, scavenged recipes reaching the
# global meta codex, data-driven enemy mapping, and shop material sell cards.


const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")
const BATTLE_SCREEN_TSCN := "res://scenes/ui/screens/battle_screen.tscn"
const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const MetaProgressScript := preload("res://scripts/domain/meta_progress.gd")
const ActionPreviewServiceScript := preload("res://scripts/domain/action_preview_service.gd")
const ResolverScript := preload("res://scripts/domain/resolver.gd")
const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")


func make_state() -> RunState:
	return RunStateScript.new_run(2026, null)


func test_run_end_outcome_maps_three_outcomes() -> void:
	assert_eq(RunControllerScript._run_end_outcome("success"), "won")
	assert_eq(RunControllerScript._run_end_outcome("risky_success"), "risky")
	assert_eq(RunControllerScript._run_end_outcome("survived_failure"), "dead")


func test_meta_counts_risky_run() -> void:
	var meta: RefCounted = MetaProgressScript.new_empty()
	var record: RefCounted = meta.record_run_end(make_state(), "risky")
	var stats: Dictionary = record.statistics
	assert_eq(int(stats.get("runs_risky", 0)), 1)
	assert_eq(int(stats.get("runs_won", 0)), 0)
	assert_eq(int(stats.get("deaths", 0)), 0)


func test_scavenged_recipe_reaches_global_meta_codex() -> void:
	var state := make_state()
	state.node_flags["boss_defeated"] = "true"
	var scavenged: Dictionary = ResolverScript.apply(state, {"type": "scavenge", "node_id": "final_boss_stand"}, ContentCatalogScript.load_all())
	var meta: RefCounted = MetaProgressScript.new_empty()
	var record: RefCounted = meta.record_run_end(scavenged["state"], "survived_failure")
	assert_true(record.recipe_codex_ids.has("moon_shadow_locked"))


func test_combat_nodes_carry_valid_enemy_kind() -> void:
	var catalog: Dictionary = ContentCatalogScript.load_all()
	assert_eq(ContentCatalogScript.validate(catalog), [])
	for node in catalog.get("nodes", []):
		if str(node.get("type", "")) in ["combat", "pursuit"]:
			var enemy_kind := str(node.get("enemy_kind", ""))
			assert_false(enemy_kind.is_empty(), "combat node %s needs enemy_kind" % str(node.get("id", "")))
			assert_true(
				catalog.get("enemy_by_id", {}).has(enemy_kind) or enemy_kind in ["beast_swarm", "greedy_wanderer", "faction_guard", "resolute_elite"],
				"combat node %s references unknown enemy %s" % [str(node.get("id", "")), enemy_kind]
			)


func test_battle_screen_shows_intent_speed() -> void:
	var catalog := ContentCatalogScript.load_all()
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	controller.start_new_run(2026)
	controller.current_node = {"id": "beast_swarm_pass", "type": "combat", "enemy_kind": "neutral_stone_wanderer"}
	controller._start_battle()
	var snapshot: Dictionary = controller._snapshot_for("Battle")
	var host := Control.new()
	add_child_autofree(host)
	# 战斗屏已迁到 Godot 官方 .tscn。
	host.add_child(TscnMountHelper.instantiate(
		BATTLE_SCREEN_TSCN, snapshot, {}))
	await get_tree().process_frame
	assert_true(_any_label_contains(host, "速 1"), "intent speed must be visible on the battle screen")


func test_battle_screen_shows_first_battle_tip_once() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	controller.start_new_run(2026)
	controller.current_node = {"id": "beast_swarm_pass", "type": "combat", "enemy_kind": "neutral_stone_wanderer"}
	controller._start_battle()
	var first_snapshot: Dictionary = controller._snapshot_for("Battle")
	var first_host := Control.new()
	add_child_autofree(first_host)
	# 战斗屏已迁到 Godot 官方 .tscn。
	first_host.add_child(TscnMountHelper.instantiate(
		BATTLE_SCREEN_TSCN, first_snapshot, {}))
	await get_tree().process_frame
	assert_true(_any_label_contains(first_host, "初战指引"), "first battle must show guidance")

	controller.state = controller.state.append_event({"action": "battle_finished", "reason": "battle_victory"})
	var second_snapshot: Dictionary = controller._snapshot_for("Battle")
	var second_host := Control.new()
	add_child_autofree(second_host)
	# 战斗屏已迁到 Godot 官方 .tscn。
	second_host.add_child(TscnMountHelper.instantiate(
		BATTLE_SCREEN_TSCN, second_snapshot, {}))
	await get_tree().process_frame
	assert_false(_any_label_contains(second_host, "初战指引"), "later battles must not repeat guidance")



func test_shop_preview_offers_material_sell_cards() -> void:
	var catalog: Dictionary = ContentCatalogScript.load_all()
	var state := make_state()
	state.materials["beast_blood"] = 2
	var node := _node_by_id(catalog, "ridge_black_market")
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(state, node, catalog)
	var found := false
	for card in cards:
		if str(card.get("id", "")) == "sell.beast_blood":
			found = true
			assert_true(bool(card.get("executable", false)))
			assert_eq(str(card["command"].get("type", "")), "sell_material")
	assert_true(found, "shop must offer a sell card for owned materials")


func test_preview_scavenge_card_after_boss_defeat() -> void:
	var catalog: Dictionary = ContentCatalogScript.load_all()
	var node := _node_by_id(catalog, "final_boss_stand")
	var state := make_state()
	var before: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(state, node, catalog)
	assert_eq(_card_ids(before).filter(func(card_id): return card_id == "scavenge"), [])
	state.node_flags["boss_defeated"] = "true"
	var after: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(state, node, catalog)
	assert_true(_card_ids(after).has("scavenge"))
	# 2026-08-30：Boss 搜刮可掉多张蛊方，须全部持有后卡片才消失。
	state.global_codex_ids.append("moon_shadow_locked")
	state.global_codex_ids.append("blood_moon_forged")
	var done: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(state, node, catalog)
	assert_false(_card_ids(done).has("scavenge"))


func _node_by_id(catalog: Dictionary, node_id: String) -> Dictionary:
	for node in catalog.get("nodes", []):
		if str(node.get("id", "")) == node_id:
			return node
	return {}


func _card_ids(cards: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for card in cards:
		ids.append(str(card.get("id", "")))
	return ids


func _any_label_contains(root: Node, text: String) -> bool:
	if root is Label and str(root.text).contains(text):
		return true
	for child in root.get_children():
		if _any_label_contains(child, text):
			return true
	return false
