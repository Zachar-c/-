class_name RunController
extends Node


const MAP_SCENE := preload("res://scenes/map.tscn")
const ENCOUNTER_SCENE := preload("res://scenes/encounter.tscn")
const BATTLE_SCENE := preload("res://scenes/battle.tscn")
const ENDING_SCENE := preload("res://scenes/ending.tscn")
const TITLE_VIEW_SCRIPT := preload("res://scripts/presentation/title_view.gd")
const DeathReportBuilderScript = preload("res://scripts/domain/death_report_builder.gd")
const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const TemplateDialogueGatewayScript = preload("res://scripts/domain/template_dialogue_gateway.gd")


var catalog: Dictionary
var state: RunState
var meta  # MetaProgress instance loaded from save, untyped for property access
var route: Array[Dictionary] = []
var current_node: Dictionary = {}
var current_battle: Dictionary = {}
var current_session: Dictionary = {}
var last_result: Dictionary = {}
var dialogue_replies: Array[Dictionary] = []
var last_feedback := ""
var _dialogue_gateway: DialogueGateway
var _view_name := "Map"
var _views: Dictionary = {}


func _ready() -> void:
	call_deferred("_initialize_view_flow")


func _initialize_view_flow() -> void:
	_ensure_views()
	_show_title()


func start_new_run(seed: int) -> void:
	catalog = ContentCatalog.load_all()
	meta = SaveRepository.load_meta_file()
	if meta == null:
		meta = load("res://scripts/domain/meta_progress.gd").new_empty()
	state = RunState.new_run(seed, meta)
	state.cave_aperture["essence_max"] = EssenceCapacityScript.essence_max(state, catalog)
	route = MapGenerator.build(seed, seed == 101)
	current_node = {}
	current_battle = {}
	current_session = {}
	last_result = {}
	dialogue_replies = []
	_dialogue_gateway = TemplateDialogueGatewayScript.new()
	_show_map()


func submit_command(command: Dictionary) -> Dictionary:
	if command.get("type", "") == "save_run":
		var save_error := save_current_run()
		last_feedback = "已存档。" if save_error == OK else "存档失败（错误码 %d）。" % save_error
		_show_map()
		return {"ok": save_error == OK, "feedback": last_feedback}
	if command.get("type", "") == "load_run":
		var loaded := load_saved_run()
		last_feedback = "已读档：回到最近保存的行程。" if loaded else "没有可读的存档，先「存档」一次。"
		_show_map()
		return {"ok": loaded, "feedback": last_feedback}
	if command.get("type", "") == "travel":
		return _travel_to(str(command.get("node_id", "")))
	if command.get("type", "") == "leave_encounter":
		command = {"type": "leave_node"}
	if command.get("type", "") == "action_card" and not current_battle.is_empty():
		var turn := BattleResolver.apply_action_card(current_battle, state, command, catalog)
		state = turn["state"]
		current_battle = turn["battle"]
		last_result = {"battle_result": turn["result"], "feeds": turn["feeds"]}
		if turn["finished"]:
			if str(turn["result"]) == "death":
				_show_death(DeathReportBuilderScript.build(current_battle, state))
			else:
				_finish_battle_in_session(str(turn["result"]))
		else:
			_show_battle()
		return turn
	if command.get("type", "") in ["use_gu", "use_inheritance", "end_turn", "retreat", "basic_attack", "basic_dodge"] and not current_battle.is_empty():
		var turn := BattleResolver.take_turn(
			current_battle,
			command,
			state,
			catalog,
			int(command.get("state_version", -1)),
			str(command.get("expected_phase", ""))
		)
		state = turn["state"]
		current_battle = turn["battle"]
		last_result = {"battle_result": turn["result"]}
		if turn["finished"]:
			if str(turn["result"]) == "death":
				_show_death(DeathReportBuilderScript.build(current_battle, state))
			else:
				_finish_battle_in_session(str(turn["result"]))
		else:
			_show_battle()
		return turn
	if not current_node.is_empty():
		var session_result := EncounterSessionResolverScript.apply(state, current_session, command, catalog, current_node)
		state = session_result["state"]
		current_session = session_result["session"]
		last_result = session_result["result"]
		_attach_social_dialogue(last_result)
		_record_dialogue_reply(last_result)
		if bool(last_result.get("start_battle", false)) or str(last_result.get("action_id", "")) == "fight":
			_start_battle()
			return last_result
		if bool(current_session.get("completed", false)):
			_return_to_map()
		else:
			_show_encounter()
		return session_result
	var resolved := Resolver.apply(state, command, catalog)
	state = resolved["state"]
	last_result = resolved["result"]
	_attach_social_dialogue(last_result)
	_record_dialogue_reply(last_result)
	if bool(last_result.get("start_battle", false)):
		_start_battle()
		return last_result
	if command.get("type", "") == "choose_action" and command.get("action_id", "") == "fight":
		_start_battle()
		return {"ok": true}
	if command.get("type", "") == "attempt_ascension":
		_show_ending(resolved["result"])
	elif not current_node.is_empty():
		_show_encounter()
	return resolved


func current_view_name() -> String:
	return _view_name


func force_complete_for_test() -> void:
	_show_ending({"outcome": "survived_failure", "conditions": {}})


func visible_route_nodes(forward_layers: int = 2) -> Array[Dictionary]:
	return MapGenerator.visible_nodes(route, state, forward_layers)


func force_death_for_test(final_blow_id: String) -> void:
	state = state.finalize_death()
	var report := DeathReportBuilderScript.build({}, state)
	report["final_blow"] = final_blow_id
	_show_death(report)


func save_current_run() -> Error:
	return SaveRepository.save_run(state, route, dialogue_replies)


func load_saved_run() -> bool:
	var loaded := SaveRepository.load_run()
	if loaded.is_empty():
		return false
	state = loaded["state"]
	route = loaded["route"]
	dialogue_replies = loaded["replies"]
	current_node = _node_by_id(state.current_node_id)
	current_battle = {}
	current_session = state.encounter_session.duplicate(true)
	_show_map()
	return true


func _travel_to(node_id: String) -> Dictionary:
	var node := _node_by_id(node_id)
	if node.is_empty():
		return {"ok": false, "reason": "unknown_route_node"}
	var reachable_ids: Array[String] = []
	for reachable in MapGenerator.reachable_nodes(route, state):
		reachable_ids.append(str(reachable["id"]))
	if not reachable_ids.has(node_id):
		return {"ok": false, "reason": "unreachable_route_node"}
	var resolved := Resolver.apply(state, {"type": "travel", "node_id": node_id}, catalog)
	state = resolved["state"]
	current_node = node
	var session_started := EncounterSessionResolverScript.begin(state, node)
	state = session_started["state"]
	current_session = session_started["session"]
	last_result = resolved["result"]
	if node["type"] in ["combat", "pursuit"]:
		_start_battle()
	else:
		_show_encounter()
	return resolved["result"]


func _start_battle() -> void:
	var enemy_kind := "beast_swarm"
	if current_node.get("id", "") == "neutral_wanderer" or current_node.get("id", "") == "greedy_wanderer":
		enemy_kind = "greedy_wanderer"
	elif current_node.get("id", "") == "faction_guard_checkpoint" or current_node.get("id", "") == "caravan_missing_goods":
		enemy_kind = "faction_guard"
	if current_node.get("id", "") == "neutral_wanderer":
		enemy_kind = "neutral_stone_wanderer"
	elif current_node.get("id", "") == "beast_swarm_pass":
		enemy_kind = "ridge_hound"
	elif current_node.get("id", "") == "final_boss_stand":
		enemy_kind = "miasma_vein_lord"
	var first_mover := "player"
	var notorious := Resolver.notoriety(state)
	if notorious > 0:
		var hostile_flag := bool(current_session.get("flags", {}).get("reputation_hostile", false))
		if hostile_flag:
			first_mover = "enemy"
		else:
			var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
			var pct := notorious * int(effects.get("first_move_chance_pct_per_point", 10))
			if Resolver.roll_chance(state, pct, "reputation_first_move"):
				first_mover = "enemy"
	var kill_source := ""
	if str(current_session.get("kind", "")) in ["contact", "caravan", "market", "shop", "wild_gu"]:
		kill_source = "neutral_npc"
	current_battle = BattleResolver.start({
		"enemy_kind": enemy_kind,
		"terrain": _battle_terrain(),
		"first_mover": first_mover,
		"kill_source": kill_source,
	}, state, catalog)
	if first_mover == "enemy":
		var pre := BattleResolver.apply_enemy_pre_turn(current_battle, state, catalog)
		state = pre["state"]
		current_battle = pre["battle"]
		if bool(pre["finished"]):
			if str(pre["result"]) == "death":
				_show_death(DeathReportBuilderScript.build(current_battle, state))
			else:
				_finish_battle_in_session(str(pre["result"]))
			return
	_show_battle()


func _battle_terrain() -> String:
	if current_node.get("id", "") == "greedy_wanderer":
		return "ridge"
	return "path"


func _show_title() -> void:
	_view_name = "Title"
	if _views.has("Title"):
		_show_only("Title")


func _start_run_from_title() -> void:
	if _view_name == "Title":
		start_new_run(101)


func _show_map() -> void:
	_view_name = "Map"
	if _views.has("Map"):
		_show_only("Map")
		_views["Map"].render(route, state, catalog, meta, last_feedback)


func _show_encounter() -> void:
	_view_name = "Encounter"
	if _views.has("Encounter"):
		_show_only("Encounter")
		var knowledge: Dictionary = meta.unlocked_random_outcomes if meta != null else {}
		_views["Encounter"].render_session(
			current_node,
			state,
			current_session,
			state.encounter_results,
			last_result,
			ActionPreviewServiceScript.preview_actions(state, current_node, catalog, knowledge)
		)


func _show_battle() -> void:
	_view_name = "Battle"
	if _views.has("Battle"):
		_show_only("Battle")
		_views["Battle"].render(current_battle, state, catalog, ActionPreviewServiceScript.preview_battle_actions(current_battle, state, catalog))


func _show_ending(outcome: Dictionary) -> void:
	_record_run_end("won" if str(outcome.get("outcome", "")) == "success" else "dead")
	_view_name = "Ending"
	if _views.has("Ending"):
		_show_only("Ending")
		_views["Ending"].show_ending(outcome, JournalBuilder.build(state, outcome))


func _show_death(report: Dictionary) -> void:
	_record_run_end("dead")
	_view_name = "Ending"
	if _views.has("Ending"):
		_show_only("Ending")
		_views["Ending"].show_death(report)


func _record_run_end(outcome: String) -> void:
	if meta == null:
		return
	meta = meta.record_run_end(state, outcome)
	SaveRepository.save_meta_file(meta)


func _ensure_views() -> void:
	if not _views.is_empty() or not is_inside_tree():
		return
	var host := get_parent()
	if host == null:
		host = self
	var title := TITLE_VIEW_SCRIPT.new()
	_add_view(host, "Title", title)
	_add_view(host, "Map", MAP_SCENE.instantiate())
	_add_view(host, "Encounter", ENCOUNTER_SCENE.instantiate())
	_add_view(host, "Battle", BATTLE_SCENE.instantiate())
	_add_view(host, "Ending", ENDING_SCENE.instantiate())
	title.start_requested.connect(_start_run_from_title)
	_views["Map"].node_selected.connect(func(node_id: String): submit_command({"type": "travel", "node_id": node_id}))
	_views["Map"].action_submitted.connect(submit_command)
	_views["Encounter"].command_submitted.connect(submit_command)
	_views["Battle"].command_submitted.connect(submit_command)
	_views["Ending"].restart_requested.connect(func(): start_new_run(101))


func _add_view(host: Node, name: String, view: Control) -> void:
	host.add_child(view)
	view.hide()
	_views[name] = view


func _show_only(name: String) -> void:
	for view_name in _views:
		_views[view_name].visible = view_name == name


func _node_by_id(node_id: String) -> Dictionary:
	for node in route:
		if node["id"] == node_id:
			return node.duplicate(true)
	return {}


func _complete_current_node(outcome: String) -> void:
	if current_node.is_empty():
		return
	var completed := Resolver.apply(state, {
		"type": "complete_node",
		"node_id": current_node["id"],
		"outcome": outcome,
	}, catalog)
	state = completed["state"]


func _return_to_map() -> void:
	current_battle = {}
	current_node = {}
	current_session = {}
	_show_map()


func _finish_battle_in_session(outcome: String) -> void:
	var kill_source := str(current_battle.get("kill_source", ""))
	var enemy_kind := str(current_battle.get("enemy_kind", ""))
	current_battle = {}
	current_session = current_session.duplicate(true)
	current_session["phase"] = "post_battle"
	var feed := ResultFeedScript.entry("battle", "battle_%s" % outcome, {}, [])
	var results := state.encounter_results.duplicate(true)
	if outcome == "victory" and enemy_kind == "miasma_vein_lord":
		results.append(ResultFeedScript.entry("battle", "lifespan_milestone_gained", {}, []))
	results.append(feed)
	state = state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "battle_finished",
		"before": {"encounter_session": state.encounter_session, "encounter_results": state.encounter_results},
		"after": {"encounter_session": current_session, "encounter_results": results},
		"reason": "battle_%s" % outcome,
		"source": "run_controller",
		"targets": [],
	})
	if outcome == "victory" and kill_source == "neutral_npc":
		state = Resolver.apply(state, {"type": "record_neutral_npc_kill"}, catalog)["state"]
	if outcome == "victory" and enemy_kind == "miasma_vein_lord":
		state = Resolver.apply(state, {"type": "record_boss_defeated"}, catalog)["state"]
	_show_encounter()


func _record_dialogue_reply(result: Dictionary) -> void:
	var reply: Variant = result.get("dialogue", {})
	if not reply is Dictionary or reply.is_empty():
		return
	var payload: Dictionary = reply.duplicate(true)
	payload.erase("source")
	if DialogueGateway.is_valid_response(payload):
		dialogue_replies.append(payload)


func _attach_social_dialogue(result: Dictionary) -> void:
	var action_id := str(result.get("action_id", ""))
	if action_id not in ["probe", "trade"] or _dialogue_gateway == null:
		return
	var social: Dictionary = state.relations.get("caravan_steward", {})
	result["dialogue"] = _dialogue_gateway.respond({
		"intent": action_id,
		"disposition": str(social.get("npc_disposition", "neutral")),
	})
