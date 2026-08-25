class_name RunController
extends Node


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const THEME := preload("res://assets/theme/gu_theme.tres")

const DeathReportBuilderScript = preload("res://scripts/domain/death_report_builder.gd")
const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const TemplateDialogueGatewayScript = preload("res://scripts/domain/template_dialogue_gateway.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")

const SCREEN_PATHS := {
	"Title": "res://ui/screens/hall_view.gd",
	"Map": "res://ui/screens/map_screen.gd",
	"Encounter": "res://ui/screens/encounter_screen.gd",
	"Battle": "res://ui/screens/battle_screen.gd",
	"Ending": "res://ui/screens/ending_screen.gd",
}


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
var _selected_school := "force"

var _rui_host: Control
var _rui_root
var _ending_state: Dictionary = {}


func _ready() -> void:
	ensure_ui()


func ensure_ui() -> void:
	if _rui_root != null:
		return
	_initialize_view_flow()


func _initialize_view_flow() -> void:
	_rui_host = Control.new()
	_rui_host.name = "RUIHost"
	_rui_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rui_host.theme = THEME
	add_child(_rui_host)
	_rui_root = RuiRoot.create(_rui_host, VLib.fc(VLib.comp(SCREEN_PATHS["Title"], "render"), {}))
	_show_title()


func start_new_run(seed: int, school: String = "") -> void:
	catalog = ContentCatalog.load_all()
	meta = SaveRepository.load_meta_file()
	if meta == null:
		meta = load("res://scripts/domain/meta_progress.gd").new_empty()
	state = RunState.new_run(seed, meta)
	state.cave_aperture["essence_max"] = EssenceCapacityScript.essence_max(state, catalog)
	_inject_school_starters(school)
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
	var enemy_kind := str(current_node.get("enemy_kind", "beast_swarm"))
	var first_mover := "player"
	var notorious := Resolver.notoriety(state)
	var stance := str(current_session.get("stance", "neutral"))
	var hostile_flag := stance in ["hostile", "extreme_hostile"] or bool(current_session.get("flags", {}).get("reputation_hostile", false))
	if notorious > 0 or hostile_flag:
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
	# N6: weaknesses procured through probe carry into the battle as bonus damage.
	if state.known_facts.has("procured_weakness"):
		current_battle["intel_bonus"] = 1
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
	_render()


func _inject_school_starters(school: String) -> void:
	if school.is_empty():
		return
	state.school = school
	var schools: Dictionary = catalog.get("schools", {})
	var starters: Array = schools.get(school, {}).get("starter_gu_ids", [])
	for starter_value in starters:
		var gu_id := str(starter_value)
		if state.refined_gu_ids.has(gu_id):
			continue
		var instance_id := _next_gu_instance_id(state)
		state.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": gu_id,
			"state": "refined",
		}
		state.cave_aperture["stored_gu_instance_ids"].append(instance_id)
		state.sync_legacy_gu_projections()


func _next_gu_instance_id(state: RunState) -> String:
	var highest := 0
	for key_value in state.gu_instances:
		var text := str(key_value)
		if text.begins_with("gu_"):
			highest = maxi(highest, int(text.trim_prefix("gu_")))
	return "gu_%03d" % (highest + 1)


func _start_run_from_title() -> void:
	if _view_name == "Title":
		start_new_run(roll_seed(), _selected_school)


static func roll_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 2147483647)


static func _run_end_outcome(outcome: String) -> String:
	match outcome:
		"success": return "won"
		"risky_success": return "risky"
	return "dead"


func _show_map() -> void:
	_view_name = "Map"
	_render()


func _show_encounter() -> void:
	_view_name = "Encounter"
	_render()


func _show_battle() -> void:
	_view_name = "Battle"
	_render()


func _continue_saved_run() -> void:
	if not FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH):
		return
	var data := SaveRepositoryScript.load_run()
	if data == null or data.is_empty():
		_show_title()
		return
	if not data.has("state") or not (data["state"] is RunState):
		_show_title()
		return
	state = data["state"]
	if data.has("route"):
		route = data["route"].duplicate(true)
	if FileAccess.file_exists(SaveRepositoryScript.META_PATH):
		meta = SaveRepositoryScript.load_meta_file()
	else:
		meta = load("res://scripts/domain/meta_progress.gd").new_empty()
	current_node = _node_by_id(state.current_node_id)
	current_battle = {}
	current_session = state.encounter_session.duplicate(true)
	dialogue_replies = data.get("replies", [])
	_show_map()


func _show_ending(outcome: Dictionary) -> void:
	_record_run_end(_run_end_outcome(str(outcome.get("outcome", ""))))
	_ending_state = _build_ending_state(outcome, JournalBuilder.build(state, outcome), state.to_save_data())
	_view_name = "Ending"
	_render()


func _show_death(report: Dictionary) -> void:
	_record_run_end("dead")
	_ending_state = {
		"title": "身死道消",
		"ending_type": "death",
		"key_decisions": ["最后一击：%s" % _blow_text(str(report.get("final_blow", "")))],
		"gains_losses": "最后一击：%s（%d 点伤害）" % [_blow_text(str(report.get("final_blow", ""))), int(report.get("damage", 0))],
		"resource_balance": {"yuanstone": int(state.stone), "shouyuan": int(state.cultivator.get("lifespan", 0))},
		"unlocks": [],
		"aftermath": "残魂归于大地，修行札记已留存。",
	}
	_view_name = "Ending"
	_render()


func _record_run_end(outcome: String) -> void:
	if meta == null:
		return
	meta = meta.record_run_end(state, outcome)
	SaveRepository.save_meta_file(meta)


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
	var battle_loot: Dictionary = current_battle.get("loot", {})
	current_battle = {}
	current_session = current_session.duplicate(true)
	current_session["phase"] = "post_battle"
	var feed := ResultFeedScript.entry("battle", "battle_%s" % outcome, {}, [])
	var results := state.encounter_results.duplicate(true)
	if outcome == "victory" and not battle_loot.is_empty():
		var loot_labels: Array[String] = []
		for material_value in battle_loot.get("material_ids", []):
			loot_labels.append(DisplayText.material(str(material_value)))
		var loot_gu := str(battle_loot.get("gu_id", ""))
		if not loot_gu.is_empty():
			loot_labels.append(DisplayText.gu(loot_gu))
		if not loot_labels.is_empty():
			results.append(ResultFeedScript.entry("battle", "battle_loot", {"loot_display": "、".join(loot_labels)}, []))
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


# ----------------------------------------------------------------------------
# RUI 渲染层：单根挂载，按 _view_name 渲染对应屏；仅经 commands 提交领域命令。
# ----------------------------------------------------------------------------

func _render() -> void:
	if _rui_root == null:
		return
	var comp := VLib.comp(SCREEN_PATHS.get(_view_name, SCREEN_PATHS["Title"]), "render")
	if not (comp is Callable):
		push_error("RUI 组件缺失: %s" % _view_name)
		return
	var snapshot: Dictionary
	if _view_name == "Ending":
		snapshot = _ending_state
	else:
		snapshot = _snapshot_for(_view_name)
	_rui_root.set_root(VLib.fc(comp, {"state": snapshot, "commands": _build_commands(_view_name)}))


func _snapshot_for(screen: String) -> Dictionary:
	match screen:
		"Title": return _snapshot_hall()
		"Map": return _snapshot_map()
		"Encounter": return _snapshot_encounter()
		"Battle": return _snapshot_battle()
	return {}


func _build_commands(screen: String) -> Dictionary:
	match screen:
		"Title":
			return {
				"continue_run": func(): submit_command({"type": "load_run"}),
				"new_run": func(): start_new_run(roll_seed(), _selected_school),
				"open_codex": func(): pass,
				"open_settings": func(): pass,
			}
		"Encounter":
			return {
				"choose_option": func(id): submit_command({"type": "action_card", "action_id": str(id)}),
				"confirm_danger": func(id): submit_command({"type": "action_card", "action_id": str(id)}),
				"leave": func(): submit_command({"type": "leave_encounter"}),
			}
		"Map":
			return {
				"travel": func(id): submit_command({"type": "travel", "node_id": str(id)}),
				"view_node": func(id): submit_command({"type": "view_node", "node_id": str(id)}),
			}
		"Battle":
			return {
				"play_card": func(cid, tid): submit_command({"type": "action_card", "card_id": str(cid), "target_id": str(tid)}),
				"end_turn": func(): submit_command({"type": "end_turn"}),
				"ultimate": func(): submit_command({"type": "ultimate"}),
				"refine": func(): submit_command({"type": "refine"}),
				"flee": func(): submit_command({"type": "retreat"}),
			}
		"Ending":
			return {
				"to_hall": func(): _show_title(),
				"to_codex": func(): pass,
			}
	return {}


func _snapshot_hall() -> Dictionary:
	var schools: Dictionary = catalog.get("schools", {}) if catalog != null else {}
	var runs := 0
	var endings := 0
	if meta != null:
		runs = int(meta.statistics.get("runs_started", 0))
		endings = meta.gu_codex_ids.size() + meta.recipe_codex_ids.size() + meta.inheritance_codex_ids.size()
	return {
		"has_save": FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH),
		"available_schools": schools.keys(),
		"contracts": [],
		"meta_stats": {"runs": runs, "endings": endings},
	}


func _snapshot_map() -> Dictionary:
	var nodes: Array[Dictionary] = []
	for n in MapGenerator.visible_nodes(route, state, 2):
		nodes.append({
			"id": str(n.get("id", "")),
			"type": str(n.get("type", "")),
			"label": _node_label(n),
			"layer": int(n.get("layer", 0)),
		})
	var reach: Array[String] = []
	for n in MapGenerator.reachable_nodes(route, state):
		reach.append(str(n["id"]))
	return {
		"nodes": nodes,
		"current_node_id": str(state.current_node_id),
		"reachable_ids": reach,
		"resources": _resources(),
		"contracts": _contracts(),
		"anomalies": [],
		"death_lines": _death_lines(),
	}


func _snapshot_encounter() -> Dictionary:
	var knowledge: Dictionary = {}
	if meta != null:
		knowledge = meta.unlocked_random_outcomes
	var actions: Array[Dictionary] = []
	for c in ActionPreviewServiceScript.preview_actions(state, current_node, catalog, knowledge):
		actions.append(_enc_action(c))
	var intel: Dictionary = {}
	if state.known_facts.has("procured_weakness"):
		intel = {"weakness": "已探明弱点，战斗增伤", "cost": "情报"}
	return {
		"node": {
			"title": _node_label(current_node),
			"desc": str(current_node.get("summary", current_node.get("desc", ""))),
			"type": str(current_node.get("type", "")),
		},
		"actions": actions,
		"intel": intel,
		"resources": _resources(),
		"contracts": _contracts(),
		"anomalies": [],
		"death_lines": _death_lines(),
	}


func _snapshot_battle() -> Dictionary:
	var enemy_kind := str(current_battle.get("enemy_kind", ""))
	var flags: Array = current_battle.get("flags", [])
	var guarded: bool = flags.has("guarded")
	var enemies: Array[Dictionary] = [{
		"id": str(current_battle.get("battle_id", "")),
		"name": DisplayText.enemy(enemy_kind),
		"hp": int(current_battle.get("enemy_hp", 0)),
		"max_hp": maxi(1, int(current_battle.get("enemy_max_hp", 1))),
		"shield": 2 if guarded else 0,
		"intent": _intent_to_screen(current_battle.get("visible_intent", {})),
	}]
	var cult: Dictionary = state.cultivator
	var player := {
		"hp": int(cult.get("health", state.health)),
		"max_hp": maxi(1, int(cult.get("max_health", state.max_health))),
		"shield": 2 if guarded else 0,
		"primordial": int(state.essence),
		"soul": int(cult.get("soul", 0)),
		"statuses": _statuses_to_list(cult.get("statuses", {})),
	}
	var hand: Array[Dictionary] = []
	for c in ActionPreviewServiceScript.preview_battle_actions(current_battle, state, catalog):
		hand.append(_battle_card(c))
	return {
		"enemies": enemies,
		"player": player,
		"hand": hand,
		"can_ultimate": false,
		"resources": _resources(),
		"contracts": _contracts(),
		"anomalies": [],
		"death_lines": _death_lines(),
	}


func _enc_action(c: Dictionary) -> Dictionary:
	return {
		"id": str(c.get("id", "")),
		"label": str(c.get("title", "")),
		"detail": str(c.get("summary", "")),
		"dangerous": _is_dangerous(c),
		"quality": "",
		"effect": str(c.get("summary", "")),
		"cost": c.get("cost", {}),
		"curse_warning": ("反噬" in str(c.get("known_risk", ""))) or ("反噬" in str(c.get("summary", ""))),
	}


func _battle_card(c: Dictionary) -> Dictionary:
	var cost_dict: Dictionary = c.get("cost", {})
	var cost_num := 0
	for key in cost_dict:
		cost_num += int(cost_dict[key])
	return {
		"id": str(c.get("id", "")),
		"name": str(c.get("title", "")),
		"cost": cost_num,
		"cost_ex": "",
		"effect": str(c.get("summary", "")),
		"quality": "普通",
		"curse_warning": ("反噬" in str(c.get("known_risk", ""))) or ("反噬" in str(c.get("summary", ""))),
	}


func _intent_to_screen(i: Dictionary) -> Dictionary:
	var dmg := int(i.get("damage", 0))
	var def := int(i.get("defense", 0))
	if dmg > 0:
		return {"type": "attack", "value": dmg, "detail": str(i.get("label", "造成物理伤害"))}
	if def > 0:
		return {"type": "defend", "value": def, "detail": str(i.get("label", "凝防御"))}
	return {"type": "charge", "value": 0, "detail": "蓄势待发"}


func _statuses_to_list(statuses: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for curse_id in statuses:
		var entry = statuses[curse_id]
		var layers := 0
		if entry is Dictionary:
			layers = int(entry.get("layers", 0))
		else:
			layers = int(entry)
		out.append({"name": DisplayText.fact(str(curse_id)), "stacks": layers})
	return out


func _is_dangerous(card: Dictionary) -> bool:
	var cost: Dictionary = card.get("cost", {})
	if int(cost.get("lifespan", 0)) > 0:
		return true
	if int(cost.get("soul", 0)) > 0:
		return true
	var risk := str(card.get("known_risk", ""))
	return "反噬" in risk or "魂魄" in risk or "寿元" in risk


func _resources() -> Dictionary:
	var cult: Dictionary = state.cultivator if state != null else {}
	var mat := 0
	if state != null and state.materials is Dictionary:
		for key in state.materials:
			mat += int(state.materials[key])
	return {
		"yuanstone": int(state.stone) if state != null else 0,
		"shouyuan": int(cult.get("lifespan", 0)),
		"hunpo": int(cult.get("soul", 0)),
		"material": mat,
	}


func _contracts() -> Array:
	var out: Array = []
	if state != null and state.body_imprints is Array:
		for x in state.body_imprints:
			out.append(DisplayText.fact(str(x)))
	return out


func _death_lines() -> Dictionary:
	var cult: Dictionary = state.cultivator if state != null else {}
	var life := int(cult.get("lifespan", 0))
	var soul := int(cult.get("soul", 0))
	var life_max := int(cult.get("lifespan_max", life))
	if life_max <= 0:
		life_max = maxi(life, 1)
	var soul_max := int(cult.get("soul_max", soul))
	if soul_max <= 0:
		soul_max = maxi(soul, 1)
	var backlash := 0
	var statuses: Dictionary = cult.get("statuses", {})
	for cid in statuses:
		var e = statuses[cid]
		backlash += int(e.get("layers", 0)) if e is Dictionary else int(e)
	return {
		"shouyuan": {"value": life, "threshold": life_max},
		"hunpo": {"value": soul, "threshold": soul_max},
		"backlash": {"value": backlash, "threshold": 3},
	}


func _node_label(n: Dictionary) -> String:
	return str(n.get("label", DisplayText.node(str(n.get("id", "")))))


func _build_ending_state(outcome: Dictionary, journal: Array[Dictionary], run_data: Dictionary) -> Dictionary:
	var otype := str(outcome.get("outcome", "survived_failure"))
	var etype := "retreat"
	match otype:
		"success": etype = "success"
		"risky_success": etype = "risky"
		"survived_failure": etype = "retreat"
		"death": etype = "death"
		"gu_fall": etype = "gu_fall"
		"true_ending": etype = "true_ending"
	var decisions: Array[String] = []
	for entry in journal:
		decisions.append(DisplayText.journal_heading(str(entry.get("heading", ""))))
	var gains := "最高修为/转数：%s/%s；流派：%s；资产结余：元石 %d" % [
		str(run_data.get("cultivation", "-")),
		str(run_data.get("stage", "-")),
		str(run_data.get("school", "未定")),
		int(run_data.get("stone", 0)),
	]
	var codex: Array = run_data.get("global_codex_ids", [])
	var unlocks: Array[String] = []
	for x in codex:
		unlocks.append("图鉴：%s" % str(x))
	var cult: Dictionary = state.cultivator if state != null else {}
	return {
		"title": DisplayText.outcome(otype),
		"ending_type": etype,
		"key_decisions": decisions,
		"gains_losses": gains,
		"resource_balance": {"yuanstone": int(state.stone) if state != null else 0, "shouyuan": int(cult.get("lifespan", 0))},
		"unlocks": unlocks,
		"aftermath": "修行札记已留存，可于大厅图鉴查阅本次所得。",
	}


func _blow_text(id: String) -> String:
	match id:
		"stone_palm": return "石掌"
		"pounce": return "伏身扑咬"
		_: return "敌手攻势"
