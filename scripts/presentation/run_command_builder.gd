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
				"open_codex": func(): pass,
				"open_settings": func(): pass,
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
				"refine": func(): controller.submit_command({"type": "refine"}),
				"flee": func(): controller.submit_command({"type": "retreat"}),
			}
		"Ending":
			return {
				"to_hall": func(): controller._show_title(),
				"to_codex": func(): pass,
			}
	return {}