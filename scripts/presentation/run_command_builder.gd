class_name RunCommandBuilder
extends RefCounted


static func _shop_buy_command(controller, id: String) -> Dictionary:
	var kind := ""
	if controller.catalog != null:
		kind = str(controller.catalog.get("shop_offer_by_id", {}).get(str(id), {}).get("kind", ""))
	if kind == "lifespan_deal":
		return {"type": "shop_lifespan_deal", "offer_id": str(id)}
	if kind == "barter":
		return {"type": "shop_barter", "offer_id": str(id)}
	if kind == "wash_notoriety":
		return {"type": "wash_notoriety"}
	return {"type": "shop_purchase", "offer_id": str(id)}


static func _shop_service_command(controller, service_id: String, target_id: String) -> Dictionary:
	match service_id:
		"remove_card": return {"type": "remove_card", "instance_id": target_id}
		"remove_imprint": return {"type": "remove_imprint", "relic_id": target_id}
		"remove_curse": return {"type": "remove_curse", "curse_id": target_id}
		"wash_notoriety": return {"type": "wash_notoriety"}
	return {}


static func _rest_choose_command(controller, id: String, target_id: String = "") -> Dictionary:
	match str(id):
		"heal": return {"type": "rest", "mode": "heal"}
		"remove": return {"type": "rest", "mode": "remove_card", "instance_id": target_id}
		"wash": return {"type": "raise_aptitude", "node_id": str(controller.current_node.get("id", ""))}
	return {"type": "leave_encounter"}


static func _npc_talk_command(controller, id: String) -> Dictionary:
	return {
		"type": "action_card",
		"action_id": str(id),
		"state_version": controller.state.event_log.size() if controller.state != null else -1,
		"node_id": str(controller.current_node.get("id", "")),
		"session_node_id": str(controller.current_session.get("node_id", controller.current_node.get("id", ""))) if controller.current_session != null else str(controller.current_node.get("id", "")),
	}


static func _battle_card_command(controller, action_id: String, target_id: String) -> Dictionary:
	var card_id := action_id.trim_prefix("battle.%s." % str(controller.current_battle.get("battle_id", "")))
	return {
		"type": "action_card",
		"action_id": action_id,
		"card_id": card_id,
		"target_id": target_id,
		"state_version": int(controller.current_battle.get("hand_version", -1)),
		"expected_phase": str(controller.current_battle.get("phase", "")),
	}


static func _encounter_action_command(controller, action_id: String) -> Dictionary:
	var state_version: int = controller.state.event_log.size() if controller.state != null else -1
	var node_id := str(controller.current_node.get("id", ""))
	var session_node_id := node_id
	if controller.current_session != null and not controller.current_session.is_empty():
		session_node_id = str(controller.current_session.get("node_id", node_id))
	return {"type": "action_card", "action_id": action_id, "state_version": state_version, "node_id": node_id, "session_node_id": session_node_id}


static func _battle_turn_command(controller, command_type: String, extra: Dictionary = {}) -> Dictionary:
	var command := {"type": command_type, "state_version": controller.state.event_log.size() if controller.state != null else -1, "expected_phase": str(controller.current_battle.get("phase", ""))}
	for key in extra:
		command[str(key)] = extra[key]
	return command


static func for_screen(screen: String, controller) -> Dictionary:
	match screen:
		"Title":
			return {
				"continue_run": func(): controller.submit_command({"type": "load_run"}),
				"select_school": func(school: String): controller._selected_school = school,
				"toggle_contract": func(id: String):
					var cid := str(id)
					if controller._selected_contracts.has(cid):
						controller._selected_contracts.erase(cid)
					else:
						controller._selected_contracts.append(cid),
				"new_run": func(): controller.start_new_run(controller.roll_seed(), controller._selected_school, Array(controller._selected_contracts)),
				"open_schools": func(): controller._show_hall_subview("schools"),
				"open_contracts": func(): controller._show_hall_subview("contracts"),
				"open_codex": func(): controller._show_hall_subview("codex"),
				"open_settings": func(): controller._show_hall_subview("settings"),
				"open_journal": func(): controller._show_hall_subview("journal"),
				"back_to_hall": func(): controller._show_hall_subview("main"),
				"toggle_dda": func(): controller.toggle_dda(),
				"step_volume": func(delta): controller.step_master_volume(int(delta)),
				"cycle_resolution": func(): controller.cycle_resolution(),
				"quit": func(): controller.quit_game(),
			}
		"Encounter":
			return {
				"choose_option": func(id): controller.submit_command(_encounter_action_command(controller, str(id))),
				"confirm_danger": func(id): controller.submit_command(_encounter_action_command(controller, str(id))),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Map":
			return {
				"travel": func(id): controller.submit_command({"type": "travel", "node_id": str(id)}),
				"save_run": func(): controller.submit_command({"type": "save_run"}),
				"to_hall": func(): controller.request_map_leave(),
				"save_and_to_hall": func(): controller.save_and_leave_map(),
				"leave_without_save": func(): controller.leave_map_without_save(),
				"cancel_to_hall": func(): controller.cancel_map_leave(),
				"surrender": func(): controller.surrender_run(),
			}
		"Battle":
			return {
				"play_card": func(action_id, target_id): controller.submit_command(_battle_card_command(controller, str(action_id), str(target_id))),
				"end_turn": func(): controller.submit_command(_battle_turn_command(controller, "end_turn")),
				"refine": func(id = ""): controller.submit_command(_battle_turn_command(controller, "refine", {"recipe_id": str(id)})),
				"flee": func(): controller.submit_command(_battle_turn_command(controller, "retreat")),
			}
		"Ending":
			return {
				"to_hall": func(): controller._show_title(),
				"to_codex": func():
					controller._show_title()
					controller._show_hall_subview("codex"),
			}
		"Shop":
			return {
				"buy": func(id = ""): controller.submit_command(_shop_buy_command(controller, str(id))),
				"service": func(service_id = "", target_id = ""): controller.submit_command(_shop_service_command(controller, str(service_id), str(target_id))),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Rest":
			return {
				"choose": func(id = "", target_id = ""): controller.submit_command(_rest_choose_command(controller, str(id), str(target_id))),
				"confirm_wash": func(): controller.submit_command({"type": "raise_aptitude", "node_id": str(controller.current_node.get("id", ""))}),
				"cancel_confirm": func(): pass,
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Refine":
			return {
				"refine": func(id = ""): controller.submit_command({"type": "refine_gu", "recipe_id": str(id)}),
				"dismantle": func(id = ""): controller.submit_command({"type": "destroy_gu", "instance_id": str(id)}),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Reward":
			return {"close": func(): controller.submit_command({"type": "leave_encounter"})}
		"Npc":
			return {
				"talk": func(id = ""): controller.submit_command(_npc_talk_command(controller, str(id))),
				"buy": func(id = ""): controller.submit_command({"type": "npc_trade", "npc_id": str(controller.current_node.get("npc_id", "")), "offer_id": str(id)}),
				"barter": func(id = ""): controller.submit_command({"type": "npc_trade", "npc_id": str(controller.current_node.get("npc_id", "")), "offer_id": str(id), "input_instance_ids": []}),
				"flee": func(): controller.submit_command({"type": "retreat"}),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"ContentError":
			return {"quit": func(): controller.quit_game()}
	return {}
