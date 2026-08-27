class_name RunCommandBuilder
extends RefCounted


# Builds the RUI command surface for each screen. Callbacks close over the
# RunController so the controller keeps owning flow and submit_command.
# 约束：lambda 一律单行，避免 Godot 多行 lambda 的缩进解析问题；多分支
# 命令逻辑抽成 static helper。


static func _shop_buy_command(controller, id: String) -> Dictionary:
	# 按货架 offer 的 kind 映射到真实领域命令。
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


static func _rest_choose_command(controller, id: String) -> Dictionary:
	match str(id):
		"heal":
			return {"type": "rest", "mode": "heal"}
		"remove":
			return {"type": "rest", "mode": "remove_card"}
		"wash":
			return {"type": "raise_aptitude", "node_id": str(controller.current_node.get("id", ""))}
	return {"type": "leave_encounter"}


static func _npc_talk_command(controller, id: String) -> Dictionary:
	return {
		"type": "resolve_contact",
		"node_id": str(controller.current_node.get("id", "")),
		"approach": str(id),
	}


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
			"toggle_dda": func(): controller.toggle_dda(),
			"quit": func(): controller.quit_game(),
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
				"save_run": func(): controller.submit_command({"type": "save_run"}),
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
				"buy": func(id = ""): controller.submit_command(_shop_buy_command(controller, str(id))),
				"block": func(id = ""): controller.submit_command({"type": "shop_block_pool", "offer_id": str(id)}),
				"use_service": func(id = ""): controller.submit_command({"type": "shop_service", "service_id": str(id)}),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Rest":
			return {
				"choose": func(id = ""): controller.submit_command(_rest_choose_command(controller, str(id))),
				"confirm_wash": func(): controller.submit_command({"type": "raise_aptitude", "node_id": str(controller.current_node.get("id", ""))}),
				"cancel_confirm": func(): pass,
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
		"Refine":
			return {
				"set_channel": func(id = ""): controller.submit_command({"type": "refine_channel", "channel_id": str(id)}),
				"refine": func(id = ""): controller.submit_command({"type": "refine_gu", "recipe_id": str(id)}),
				"toggle_input": func(id = ""): controller.submit_command({"type": "refine_toggle_input", "gu_id": str(id)}),
				"dismantle": func(id = ""): controller.submit_command({"type": "destroy_gu", "instance_id": str(id)}),
				"confirm": func(): controller.submit_command({"type": "refine_confirm"}),
				"cancel_confirm": func(): pass,
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
				"talk": func(id = ""): controller.submit_command(_npc_talk_command(controller, str(id))),
				"buy": func(id = ""): controller.submit_command({"type": "npc_trade", "npc_id": str(controller.current_node.get("npc_id", "")), "offer_id": str(id)}),
				"barter": func(id = ""): controller.submit_command({"type": "npc_trade", "npc_id": str(controller.current_node.get("npc_id", "")), "offer_id": str(id), "input_instance_ids": []}),
				"flee": func(): controller.submit_command({"type": "retreat"}),
				"leave": func(): controller.submit_command({"type": "leave_encounter"}),
			}
	return {}
