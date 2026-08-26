class_name RunCommandBuilder
extends RefCounted


# Builds the RUI command surface for each screen. Callbacks close over the
# RunController so the controller keeps owning flow and submit_command.


static func for_screen(screen: String, controller) -> Dictionary:
	match screen:
		"Title":
			return {
				"continue_run": func(): controller.submit_command({"type": "load_run"}),
				"select_school": func(school: String): controller._selected_school = school,
				"new_run": func(): controller.start_new_run(controller.roll_seed(), controller._selected_school),
				"open_schools": func(): controller._show_hall_subview("schools"),
				"open_contracts": func(): controller._show_hall_subview("contracts"),
				"open_codex": func(): controller._show_hall_subview("codex"),
				"open_settings": func(): controller._show_hall_subview("settings"),
				"open_journal": func(): controller._show_hall_subview("journal"),
				"back_to_hall": func(): controller._show_hall_subview("main"),
			}
		"Encounter":
			return {
				"choose_option": func(id): controller.submit_command({"type": "action_card", "action_id": str(id)}),
				"confirm_danger": func(id): controller.submit_command({"type": "action_card", "action_id": str(id)}),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Map":
			return {
				"travel": func(id): controller.submit_command({"type": "travel", "node_id": str(id)}),
				"view_node": func(id): controller.submit_command({"type": "view_node", "node_id": str(id)}),
			}
		"Battle":
			return {
				"play_card": func(cid, tid): controller.submit_command({"type": "action_card", "card_id": str(cid), "target_id": str(tid)}),
				"end_turn": func(): controller.submit_command({"type": "end_turn"}),
				"ultimate": func(): controller.submit_command({"type": "ultimate"}),
				"refine": func(id = ""): controller.submit_command({"type": "refine", "recipe_id": str(id)}),
				"flee": func(): controller.submit_command({"type": "retreat"}),
			}
		"Ending":
			return {
				"to_hall": func(): controller._show_title(),
				"to_codex": func(): pass,
			}
		"Shop":
			return {
				"buy": func(id = ""): controller.submit_command({"type": "shop_buy", "offer_id": str(id)}),
				"block": func(id = ""): controller.submit_command({"type": "shop_block_pool", "offer_id": str(id)}),
				"use_service": func(id = ""): controller.submit_command({"type": "shop_service", "service_id": str(id)}),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Rest":
			return {
				"choose": func(id = ""): controller.submit_command({"type": "rest_choose", "choice_id": str(id)}),
				"confirm_wash": func(): controller.submit_command({"type": "rest_wash_confirm"}),
				"cancel_confirm": func(): controller.submit_command({"type": "rest_wash_cancel"}),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Refine":
			return {
				"set_channel": func(id = ""): controller.submit_command({"type": "refine_channel", "channel_id": str(id)}),
				"refine": func(id = ""): controller.submit_command({"type": "refine", "recipe_id": str(id)}),
				"toggle_input": func(id = ""): controller.submit_command({"type": "refine_toggle_input", "gu_id": str(id)}),
				"dismantle": func(id = ""): controller.submit_command({"type": "refine_dismantle", "gu_id": str(id)}),
				"confirm": func(): controller.submit_command({"type": "refine_confirm"}),
				"cancel_confirm": func(): controller.submit_command({"type": "refine_cancel"}),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Reward":
			return {
				"take": func(i): controller.submit_command({"type": "reward_take", "index": int(i)}),
				"replace_and_take": func(i): controller.submit_command({"type": "reward_replace", "index": int(i)}),
				"skip": func(): controller.submit_command({"type": "reward_skip"}),
				"close": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Npc":
			return {
				"talk": func(id = ""): controller.submit_command({"type": "npc_talk", "option_id": str(id)}),
				"buy": func(id = ""): controller.submit_command({"type": "npc_buy", "offer_id": str(id)}),
				"barter": func(id = ""): controller.submit_command({"type": "npc_barter", "barter_id": str(id)}),
				"flee": func(): controller.submit_command({"type": "npc_flee"}),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
	return {}