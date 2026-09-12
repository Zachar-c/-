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


static func _rest_mode_action_command(controller, id: String) -> Dictionary:
	# E4b 修炼族（规格 §4）：meditate 走 encounter 标准 action_card 信封
	# （带 state_version/node 防串档）；cultivate 冲二转是专属领域命令。
	if str(id) == "meditate":
		return _encounter_action_command(controller, "meditate")
	if str(id) == "cultivate":
		return {"type": "cultivate_rank_two"}
	return {}


static func _rest_choose_command(controller, id: String, target_id: String = "") -> Dictionary:
	match str(id):
		"heal": return {"type": "rest", "mode": "heal"}
		"upgrade_card": return {"type": "rest", "mode": "upgrade_card", "card_key": str(target_id)}
		"remove": return {"type": "rest", "mode": "remove_card", "instance_id": target_id}
		"remove_card": return {"type": "rest", "mode": "remove_card", "instance_id": str(target_id)}
		"remove_imprint": return {"type": "rest", "mode": "remove_imprint", "relic_id": str(target_id)}
		"remove_curse": return {"type": "rest", "mode": "remove_curse", "curse_id": str(target_id)}
		"skip": return {"type": "rest", "mode": "skip"}
		"wash": return {"type": "raise_aptitude", "node_id": str(controller.current_node.get("id", ""))}
	return {"type": "leave_encounter"}


static func _npc_talk_command(controller, id: String) -> Dictionary:
	return {
		"type": "action_card",
		"action_id": str(id),
		"state_version": controller.state.event_log.size() if controller.state != null else -1,
		"node_id": str(controller.current_node.get("id", "")),
		"session_node_id": str(controller.state.encounter_session.get("node_id", controller.current_node.get("id", ""))) if controller.state != null else str(controller.current_node.get("id", "")),
	}


static func _battle_card_command(controller, action_id: String, target_id: String) -> Dictionary:
	# V1 蛊行动制：手牌行 id 即 gu.<instance_id>，直接走 use_gu 命令。
	if action_id.begins_with("gu."):
		return {
			"type": "use_gu",
			"instance_id": str(action_id.trim_prefix("gu.")),
			"target_id": target_id,
			"state_version": int(controller.state.event_log.size()) if controller.state != null else -1,
		}
	# V1 拳脚（肉体搏斗）。
	if action_id == "basic_attack":
		return {
			"type": "basic_attack",
			"state_version": int(controller.state.event_log.size()) if controller.state != null else -1,
		}
	# V1 预制杀招。
	if action_id.begins_with("kill_move."):
		return {
			"type": "play_kill_move",
			"kill_move_id": str(action_id.trim_prefix("kill_move.")),
			"state_version": int(controller.state.event_log.size()) if controller.state != null else -1,
		}
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
	if controller.state != null and not controller.state.encounter_session.is_empty():
		session_node_id = str(controller.state.encounter_session.get("node_id", node_id))
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
				# W10 方案甲（2026-09-10 视觉会话裁定）：「续入此世」= 读档继续，
				# 经统一命令入口直接恢复进行中的 Run；无存档时 primary_action
				# 本就是 open_schools，此分支只在 has_save 时可点。
				"continue_run": func(): controller.submit_command({"type": "load_run"}),
				"load_run": func(): controller.submit_command({"type": "load_run"}),
				"select_school": func(school: String): controller.select_school(str(school)),
				"toggle_buff": func(id): controller._toggle_buff(str(id)),
				"toggle_contract": func(id: String):
					var cid := str(id)
					if controller._selected_contracts.has(cid):
						controller._selected_contracts.erase(cid)
					else:
						controller._selected_contracts.append(cid),
				"new_run": func(): controller.start_new_run(controller.roll_seed(), controller._selected_school, Array(controller._selected_contracts), Array(controller._selected_buffs)),
				"open_schools": func(): controller._show_hall_subview("schools"),
				"open_contracts": func(): controller._show_hall_subview("contracts"),
				"open_codex": func(): controller._show_hall_subview("codex"),
				"open_settings": func(): controller._show_settings(),
				"open_kill": func(): controller._show_kill(),
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
				"open_settings": func(): controller._show_settings(),
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
				# E4b 三选一：修炼/炼蛊族动作卡（mode_groups）。refine/free_pair
				# 是会话内子屏导航，不发领域命令。
				"mode_action": func(id = ""):
					var mid := str(id)
					if mid == "refine":
						controller.open_refine_subview()
					elif mid == "free_pair":
						controller.open_refine_subview("free_pair")
					else:
						controller.submit_command(_rest_mode_action_command(controller, mid)),
				"confirm_wash": func(): controller.submit_command({"type": "raise_aptitude", "node_id": str(controller.current_node.get("id", ""))}),
				"cancel_confirm": func(): pass,
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Refine":
			return {
				"refine": func(id = ""): controller.submit_command({"type": "refine_gu", "recipe_id": str(id)}),
				"dismantle": func(id = ""): controller.submit_command({"type": "destroy_gu", "instance_id": str(id)}),
				"select_pair_main": func(id = ""): controller.select_pair_main(str(id)),
				"select_pair_partner": func(id = ""): controller.select_pair_partner(str(id)),
				"refine_free_pair": func(): controller.submit_command({"type": "refine_free_pair", "main_instance_id": controller._selected_pair_main, "partner_instance_id": controller._selected_pair_partner}),
				# E4a 炼蛊子屏：经休息屏打开时「离开」退回休息屏继续三选一，
				# 不提交 leave_encounter（探访是否结束由休息屏的离开/放弃决定）。
				"leave": func():
					if controller._refine_from_rest:
						controller.close_refine_subview()
					else:
						controller.submit_command({"type": "leave_encounter"}),
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
		"Kill":
			return {
				"back": func(): controller.back_from_overlay(),
			}
		"Settings":
			return {
				"back": func(): controller.back_from_overlay(),
				"set_resolution": func(index): controller.set_resolution_index(int(index)),
				"toggle_mute": func(): controller.toggle_mute(),
				"save": func():
					if controller.state != null:
						controller.submit_command({"type": "save_run"}),
				"load": func(): controller.submit_command({"type": "load_run"}),
			}
		"ContentError":
			return {"quit": func(): controller.quit_game()}
	return {}
