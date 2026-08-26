extends "res://addons/gut/test.gd"


# B3 experience gaps from the review: intent speed on the UI, first-battle
# guidance, three-way run-end statistics, scavenged recipes reaching the
# global meta codex, data-driven enemy mapping, and shop material sell cards.


const BattleResolverScript := preload("res://scripts/domain/battle_resolver.gd")
const BattleViewScript := preload("res://scripts/presentation/battle_view.gd")
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
	assert_true(record.recipe_codex_ids.has("phantom_moon_locked"))


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


func test_battle_view_shows_intent_speed() -> void:
	var catalog: Dictionary = ContentCatalogScript.load_all()
	var battle := BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, make_state(), catalog)
	var texts := _battle_view_texts(battle, make_state(), catalog)
	var found := false
	for text in texts:
		if text.find("速 1") >= 0:
			found = true
	assert_true(found, "intent speed must be visible on the battle view")


func test_battle_view_shows_first_battle_tip_once() -> void:
	var catalog: Dictionary = ContentCatalogScript.load_all()
	var battle := BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, make_state(), catalog)
	var first_texts := _battle_view_texts(battle, make_state(), catalog)
	var found_first := false
	for text in first_texts:
		if text.begins_with("初战指引"):
			found_first = true
	assert_true(found_first, "first battle must show guidance")
	var state := make_state()
	state.event_log.append({"action": "battle_finished", "reason": "battle_victory"})
	var second_texts := _battle_view_texts(battle, state, catalog)
	var found_second := false
	for text in second_texts:
		if text.begins_with("初战指引"):
			found_second = true
	assert_false(found_second, "later battles must not repeat guidance")


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
	state.global_codex_ids.append("phantom_moon_locked")
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


func _battle_view_texts(battle: Dictionary, state: RunState, catalog: Dictionary) -> Array[String]:
	var view = BattleViewScript.new()
	add_child_autofree(view)
	view.render(battle, state, catalog, [])
	var texts: Array[String] = []
	for node in _collect(view):
		if node is Label:
			texts.append(str(node.text))
	return texts


func _collect(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child in node.get_children():
		found.append_array(_collect(child))
	return found