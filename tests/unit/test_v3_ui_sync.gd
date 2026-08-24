extends GutTest


# UI sync regression: every domain node type must render at least one
# executable-or-blocked action button through the real EncounterView scene.


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const EncounterViewScript = preload("res://scripts/presentation/encounter_view.gd")
const BattleViewScript = preload("res://scripts/presentation/battle_view.gd")


const NODE_CASES := [
	{"id": "neutral_wanderer", "type": "contact", "choices": ["negotiate", "deceive", "fight", "retreat"]},
	{"id": "ridge_caravan", "type": "caravan", "choices": []},
	{"id": "refinement_hollow", "type": "refinement", "choices": []},
	{"id": "cultivation_spring", "type": "cultivation", "choices": []},
	{"id": "stage_one_ledger", "type": "ledger", "choices": []},
	{"id": "ridge_black_market", "type": "shop", "choices": []},
	{"id": "echo_cave", "type": "event", "choices": []},
	{"id": "toxic_mountain_path", "type": "hazard", "choices": ["scout", "cross", "withdraw"]},
	{"id": "blood_moss_grove", "type": "wild_gu", "choices": ["harvest", "trade", "leave"]},
	{"id": "village_short_work", "type": "market", "choices": ["work", "trade", "leave"]},
	{"id": "moonlit_trail", "type": "inheritance", "choices": ["inspect", "claim", "leave"]},
	{"id": "beast_swarm_pass", "type": "combat", "choices": ["fight", "retreat", "lure"]},
	{"id": "greedy_wanderer", "type": "pursuit", "choices": ["fight", "trade", "retreat"]},
	{"id": "earth_vein_contest", "type": "earth_vein", "choices": ["ally", "scheme", "fight", "retreat"]},
	{"id": "body_imprint_ritual", "type": "seclusion", "choices": ["meditate", "take_imprint", "leave"]},
	{"id": "herbalist_commission", "type": "commission", "choices": ["accept", "trade", "leave"]},
	{"id": "ascension_window", "type": "ascension", "choices": ["attempt_ascension", "prepare", "retreat"]},
]


func test_every_node_type_renders_action_buttons() -> void:
	var catalog := ContentCatalog.load_all()
	var empty_results: Array[Dictionary] = []
	for node_value in NODE_CASES:
		var node: Dictionary = node_value
		var state := RunState.new_run(101)
		state.stone = 20
		var cards := ActionPreviewServiceScript.preview_actions(state, node, catalog)
		var view: Control = autofree(EncounterViewScript.new())
		add_child(view)
		view.render_session(node, state, {"completed": false, "phase": "active"}, empty_results, {}, cards)
		assert_gt(_count_buttons(view), 0, "node %s (%s) rendered no buttons" % [str(node["id"]), str(node["type"])])


func test_battle_view_renders_hand_and_turn_buttons() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var view: Control = autofree(BattleViewScript.new())
	add_child(view)
	view.render(battle, state, catalog, ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog))
	assert_gt(_count_buttons(view), 1)


func test_battle_view_renders_hud_bars_intent_and_actions() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var view: Control = autofree(BattleViewScript.new())
	add_child(view)
	view.render(battle, state, catalog, ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog))
	var hud := _find_label_with_text(view, "真元")
	assert_not_null(hud, "battle view must expose essence hud")
	for item in ["元石", "寿元", "魂魄"]:
		assert_not_null(_find_label_with_text(view, item), "hud missing %s" % item)
	assert_eq(_count_typed(view, ProgressBar), 2, "hero and enemy health bars expected in battle view")
	assert_not_null(_find_label_with_text(view, "意图"), "battle view must expose enemy intent")


func test_battle_view_hud_uses_programmatic_icons() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var view: Control = autofree(BattleViewScript.new())
	add_child(view)
	view.render(battle, state, catalog, ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog))
	var icons := _collect_typed(view, "ResourceIcon")
	assert_eq(icons.size(), 4, "battle hud must render four resource icons")


func test_battle_hud_shows_formula_essence_max() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	state.cave_aperture["essence_max"] = 6
	var battle := BattleResolver.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var view: Control = autofree(BattleViewScript.new())
	add_child(view)
	view.render(battle, state, catalog, ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog))
	var hud := _find_label_with_text(view, "真元")
	assert_not_null(hud, "essence hud must stay")
	var cap_label := _find_label_with_text(view, "3/6")
	assert_not_null(cap_label, "hud must use formula essence_max")


func test_battle_hud_shows_multitasking_capacity() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var view: Control = autofree(BattleViewScript.new())
	add_child(view)
	view.render(battle, state, catalog, ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog))
	var ops := _find_label_with_text(view, "出手 0/4")
	assert_not_null(ops, "multitasking capacity must be visible")


func test_encounter_view_shows_notoriety_when_present() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	state.cultivator["notorious"] = 2
	var node := {"id": "neutral_wanderer", "type": "contact"}
	var empty_results: Array[Dictionary] = []
	var empty_cards: Array[Dictionary] = []
	var view: Control = autofree(preload("res://scripts/presentation/encounter_view.gd").new())
	add_child(view)
	view.render_session(node, state, EncounterSessionResolverScript.start(node), empty_results, {}, empty_cards, catalog)
	var label := _find_label_with_text(view, "恶名")
	assert_not_null(label, "notoriety must be visible")
	assert_true(str(label.text).contains("2"))

	var clean_view: Control = autofree(preload("res://scripts/presentation/encounter_view.gd").new())
	add_child(clean_view)
	clean_view.render_session(node, RunState.new_run(101), EncounterSessionResolverScript.start(node), empty_results, {}, empty_cards, catalog)
	assert_null(_find_label_with_text(clean_view, "恶名"), "zero notoriety stays hidden")


func test_map_view_shows_cross_run_codex_unlock_count() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller.start_new_run(101)
	controller.state.global_codex_ids.assign(["phantom_moon_locked"])
	var view: Control = autofree(load("res://scripts/presentation/map_view.gd").new())
	add_child(view)
	view.render(controller.route, controller.state, controller.catalog, controller.meta)
	var codex := _find_label_with_text(view, "跨局解锁")
	assert_not_null(codex, "codex unlock count must be visible")
	assert_true(str(codex.text).contains("1 种"))


func test_gu_orb_renders_for_every_known_gu() -> void:
	for gu_id in ["small_light_gu", "moonlight_gu", "moon_glow_gu", "phantom_moon_gu", "moon_shadow_gu", "stone_shell_gu", "trail_eye_gu", "thorn_whip_gu", "blood_moss_gu", "mist_step_gu", "venom_thread_gu", "shadow_veil_gu", "pulse_drum_gu"]:
		var orb: Control = autofree(load("res://scripts/presentation/gu_orb.gd").new())
		add_child(orb)
		orb.gu_id = gu_id
		assert_eq(str(orb.gu_id), gu_id)


func test_enemy_catalog_labels_cover_real_enemy_kinds() -> void:
	assert_eq(DisplayText.enemy("neutral_stone_wanderer"), "石甲散修")
	assert_eq(DisplayText.enemy("ridge_hound"), "山脊猎犬")


func test_map_view_uses_reference_layout_regions() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller.start_new_run(101)
	var view: Control = autofree(load("res://scripts/presentation/map_view.gd").new())
	add_child(view)
	view.render(controller.route, controller.state, controller.catalog, controller.meta)
	assert_not_null(_find_label_with_text(view, "南疆行程"), "map must keep the journey title")
	assert_not_null(_find_label_with_text(view, "蛊囊"), "map must keep the gu satchel panel")
	assert_not_null(_find_label_with_text(view, "图鉴"), "map must expose codex regions")
	var bottom_save := _find_button_with_text(view, "存档")
	assert_not_null(bottom_save, "save button must exist in bottom command group")


func test_map_view_exposes_gu_management_and_save_commands() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller.start_new_run(101)
	var gu_by_id: Dictionary = controller.catalog.get("gu_by_id", {})
	controller.state.gu_instances["gu_002"] = {
		"instance_id": "gu_002",
		"definition_id": "stone_shell_gu",
		"state": "refined",
	}
	controller.state.cave_aperture["stored_gu_instance_ids"].append("gu_002")
	controller.state.sync_legacy_gu_projections()
	var view: Control = autofree(load("res://scripts/presentation/map_view.gd").new())
	add_child(view)
	view.render(controller.route, controller.state, controller.catalog, controller.meta)
	var submitted: Array[Dictionary] = []
	view.action_submitted.connect(func(command: Dictionary): submitted.append(command))
	_press_buttons(view)
	assert_true(submitted.any(func(command: Dictionary): return str(command.get("type", "")) == "destroy_gu"))
	assert_true(submitted.any(func(command: Dictionary): return str(command.get("type", "")) == "save_run"))


func test_encounter_view_shows_feeding_footer_when_shortfall() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	state.materials = {"feed_points": 0}
	var node := {"id": "village_short_work", "type": "market", "choices": []}
	var view: Control = autofree(EncounterViewScript.new())
	add_child(view)
	var empty_results: Array[Dictionary] = []
	var empty_cards: Array[Dictionary] = []
	view.render_session(node, state, {"completed": false, "phase": "active"}, empty_results, {}, empty_cards, catalog)
	var submitted: Array[Dictionary] = []
	view.command_submitted.connect(func(command: Dictionary): submitted.append(command))
	_press_buttons(view)
	assert_true(submitted.any(func(command: Dictionary): return str(command.get("type", "")) == "settle_node_feeding"))


func test_controller_records_and_persists_meta_on_death() -> void:
	if FileAccess.file_exists("user://nanjiang_smoke_meta.json"):
		DirAccess.remove_absolute("user://nanjiang_smoke_meta.json")
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller.start_new_run(101)
	controller.force_death_for_test("test_blow")
	var saved = SaveRepository.load_meta_file()
	assert_not_null(saved)
	assert_eq(int(saved.statistics.get("deaths", 0)), 1)


func test_run_save_round_trips_through_disk_json() -> void:
	var state := RunState.new_run(101)
	state.health = 4
	state.encounter_session = {"node_id": "neutral_wanderer", "completed": false}
	var result: Error = SaveRepository.save_run(state, MapGenerator.build(101, true), [])
	assert_eq(result, OK)
	var loaded := SaveRepository.load_run()
	assert_false(loaded.is_empty())
	assert_eq(int(loaded["state"].health), 4)


func test_same_encounter_card_cannot_be_applied_twice() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	state.stone = 20
	var node := {"id": "neutral_wanderer", "type": "contact", "choices": ["negotiate", "deceive", "fight", "retreat"]}
	var began := EncounterSessionResolverScript.begin(state, node)
	state = began["state"]
	var card := ActionPreviewServiceScript.find_card(state, node, "node.deceive", catalog)
	assert_false(card.is_empty())
	assert_true(bool(card.get("executable", false)))
	var first := EncounterSessionResolverScript.apply(state, began["session"], {
		"type": "action_card",
		"action_id": "node.deceive",
		"state_version": int(card["state_version"]),
	}, catalog, node)
	assert_true(bool(first["result"].get("ok", false)), "first use of the action must succeed")
	state = first["state"]
	var consumed := ActionPreviewServiceScript.find_card(state, node, "node.deceive", catalog)
	assert_false(bool(consumed.get("executable", false)), "action card must be consumed after success")
	var second := EncounterSessionResolverScript.apply(state, state.encounter_session, {
		"type": "action_card",
		"action_id": "node.deceive",
		"state_version": int(state.event_log.size()),
	}, catalog, node)
	assert_false(bool(second["result"].get("ok", false)), "consumed action card must be rejected")
	assert_eq(int(state.stone), 22, "second use must not grant rewards again")


func test_controller_save_and_load_expose_feedback() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	controller.start_new_run(101)
	var save_result := controller.submit_command({"type": "save_run"})
	assert_true(bool(save_result.get("ok", false)))
	assert_false(str(save_result.get("feedback", "")).is_empty())
	var load_result := controller.submit_command({"type": "load_run"})
	assert_true(bool(load_result.get("ok", false)))
	assert_false(str(load_result.get("feedback", "")).is_empty())


func test_map_view_renders_feedback_line() -> void:
	var view: Control = autofree(load("res://scripts/presentation/map_view.gd").new())
	add_child(view)
	view.render(MapGenerator.build(101, true), RunState.new_run(101), ContentCatalog.load_all(), null, "已存档。")
	assert_not_null(_find_label_with_text(view, "已存档"))


func test_encounter_view_keeps_actions_reachable_when_history_grows() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	var node := {"id": "neutral_wanderer", "type": "contact", "choices": ["negotiate", "deceive", "fight", "retreat"]}
	var results: Array[Dictionary] = []
	for i in 30:
		results.append({"text_key": "node_entered"})
	var cards := ActionPreviewServiceScript.preview_actions(state, node, catalog)
	var view: Control = autofree(EncounterViewScript.new())
	add_child(view)
	view.render_session(node, state, {"completed": false}, results, {}, cards, catalog)
	assert_not_null(_find_child(view, ScrollContainer), "encounter view must scroll to keep buttons reachable")
	assert_not_null(_find_capped_history(view), "result history must be height-capped")


func _find_child(root: Node, node_type: Variant) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if is_instance_of(current, node_type):
			return current
		stack.append_array(current.get_children())
	return null


func _count_typed(root: Node, node_type: Variant) -> int:
	var total := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if is_instance_of(current, node_type):
			total += 1
		stack.append_array(current.get_children())
	return total


func _collect_typed(root: Node, script_name: String) -> Array[Node]:
	var found: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if str(current.get_class()) == script_name or (current.get_script() != null and str(current.get_script().get_global_name()) == script_name):
			found.append(current)
		stack.append_array(current.get_children())
	return found


func _find_capped_history(root: Node) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is RichTextLabel:
			var label := current as RichTextLabel
			if label.scroll_active and label.custom_maximum_size.y > 0:
				return label
		stack.append_array(current.get_children())
	return null


func _find_label_with_text(root: Node, substring: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Label and (current as Label).text.contains(substring):
			return current
		stack.append_array(current.get_children())
	return null


func _find_button_with_text(root: Node, substring: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Button and (current as Button).text.contains(substring):
			return current
		stack.append_array(current.get_children())
	return null


func _press_buttons(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Button and not (current as Button).disabled:
			(current as Button).pressed.emit()
		stack.append_array(current.get_children())


func _count_buttons(root: Node) -> int:
	var total := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Button:
			total += 1
		stack.append_array(current.get_children())
	return total
