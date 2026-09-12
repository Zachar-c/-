extends SceneTree
## A1 real-window acceptance walkthrough (AGENTS.md AI contract: UI drag changes
## must be verified in a real window with synthesised mouse/keyboard input).
##
## Launch WITHOUT --headless (real window). Drives a real run through
## RunController until the first ordinary battle opens on the wenzhen battle
## master, then drags an executable single-target hand card onto the LAST living
## enemy actor and releases. Asserts the domain received the TARGETED play (that
## enemy's hp/shield dropped; a non-target enemy stays untouched when present),
## then retreats, returns to map and travels onward. Force-draws the window and
## samples the framebuffer for real rendered content (>100 colours).
##
## Exit code 0 = pass; 1 = any gate failed.

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ACTION_PREVIEW_SERVICE = preload("res://scripts/domain/action_preview_service.gd")
const BATTLE_COMMAND_FACADE = preload("res://scripts/domain/battle_command_facade.gd")

const BATTLE_MASTER := "res://scenes/ui_masters/wenzhen_battle_master.tscn"
const SEEDS := [1, 3, 7, 13, 101]
const MAX_DRIVE_STEPS := 60

var _log := ""


func _log_line(line: String) -> void:
	_log += line + "\n"
	print("[A1-ACCEPT] ", line)


func _initialize() -> void:
	_run()


func _run() -> void:
	var failed := false
	var controller: RunController = RunControllerScript.new()
	root.add_child(controller)
	# Let the controller's _ready (catalog + hall) run before starting a run, or
	# the deferred initialisation would reset the view back to the Title hall.
	await _settle(3)

	var opened := false
	for seed in SEEDS:
		controller.start_new_run(seed)
		await _settle(5)
		var outcome := await _drive_to_battle(controller)
		if outcome:
			opened = true
			_log_line("battle open on seed=%d via %s" % [seed, outcome])
			break
		_log_line("seed %d could not reach an ordinary battle, retrying" % seed)
	if not opened:
		_log_line("FAIL no seed reached an ordinary battle")
		_quit(1)
		return

	var master = controller._master_instance
	if master == null or str(master.scene_file_path) != BATTLE_MASTER:
		_log_line("FAIL battle view did not mount the wenzhen battle master")
		_quit(1)
		return
	_log_line("wenzhen battle master mounted")

	var pre := controller._snapshot_for("Battle")
	var enemies: Array = pre.get("enemies", [])
	var enemy_ids: Array = []
	for e in enemies:
		enemy_ids.append(str(e.get("id", "")))
	_log_line("enemies=%s hand=%d" % [str(enemy_ids), (pre.get("hand", []) as Array).size()])

	var card := _drag_card(pre)
	if card.is_empty():
		_log_line("FAIL no executable single-enemy card in hand to drag")
		_quit(1)
		return
	var card_id := str(card.get("id", ""))
	# Prefer a non-first living enemy so an auto-filled default target cannot fake
	# a pass: a drop with a real target must damage THIS enemy and only this one.
	var target_enemy_id := str(enemy_ids[enemy_ids.size() - 1]) if enemy_ids.size() >= 2 else str(enemy_ids[0])

	var card_node := _find(master, "card_body_" + card_id.replace(".", "_"))
	var enemy_node := _find(master, "enemy_actor_" + target_enemy_id)
	if not (card_node is Control) or not (enemy_node is Control):
		_log_line("FAIL nodes not found card=%s enemy=%s" % [card_id, target_enemy_id])
		_quit(1)
		return

	var hp_before := _enemy_hp(pre, target_enemy_id)
	var shield_before := _enemy_shield(pre, target_enemy_id)
	var first_before := _enemy_hp(pre, str(enemies[0].get("id", ""))) if enemy_ids.size() >= 2 else -1

	var from: Vector2 = (card_node as Control).get_global_rect().get_center()
	var to: Vector2 = (enemy_node as Control).get_global_rect().get_center()
	_log_line("drag %s (%s) -> %s" % [card_id, str(from.round()), target_enemy_id])

	# Real-window contract: warp the OS cursor, then parse real mouse events.
	Input.warp_mouse(from)
	await _settle(1)
	_motion(from)
	_button(from, true)
	await _settle(1)
	_motion(to)
	await _settle(1)
	_button(to, false)
	await _settle(6)

	var post := controller._snapshot_for("Battle")
	var hp_after := _enemy_hp(post, target_enemy_id)
	var shield_after := _enemy_shield(post, target_enemy_id)
	var first_after := _enemy_hp(post, str(enemies[0].get("id", ""))) if enemy_ids.size() >= 2 else -1
	var hp_delta := hp_before - hp_after
	var shield_delta := shield_before - shield_after
	_log_line("target %s hp %d->%d shield %d->%d (dmg %d)" % [
		target_enemy_id, hp_before, hp_after, shield_before, shield_after, hp_delta + shield_delta])

	if hp_delta + shield_delta <= 0:
		_log_line("FAIL drag did not land a targeted play on %s" % target_enemy_id)
		failed = true
	if enemy_ids.size() >= 2 and first_after >= 0 and first_after < first_before:
		_log_line("FAIL drag also damaged the non-target enemy (target not honoured)")
		failed = true

	var colours := await _pixel_count()
	_log_line("framebuffer unique colours=%d" % colours)
	if colours <= 100:
		_log_line("FAIL framebuffer looks blank")
		failed = true

	# Settle: formal retreat (ordinary combat), return to map, travel onward.
	var retreat: Dictionary = controller.submit_command({
		"type": "retreat",
		"state_version": controller.state.event_log.size() if controller.state != null else -1,
		"expected_phase": str(controller.current_battle.get("phase", "")),
	})
	if not bool(retreat.get("accepted", false)):
		_log_line("FAIL ordinary combat retreat rejected")
		failed = true
	await _settle(6)
	controller.submit_command({"type": "leave_node"})
	await _settle(6)
	if str(controller.current_view_name()) != "Map":
		_log_line("FAIL did not return to map after battle (view=%s)" % controller.current_view_name())
		failed = true
	else:
		_log_line("returned to map after battle")
	var next_node := _next_reachable(controller)
	if next_node != "":
		var r: Dictionary = controller.submit_command({"type": "travel", "node_id": next_node})
		await _settle(6)
		_log_line("travelled to %s -> view=%s" % [next_node, controller.current_view_name()])
		if str(controller.current_view_name()) == "Map":
			_log_line("FAIL travel did not switch layers/nodes")
			failed = true
	else:
		_log_line("FAIL no further reachable node to switch to")
		failed = true

	_log_line("VERDICT=%s" % ("FAIL" if failed else "PASS"))
	_quit(1 if failed else 0)


# Drives to the first ordinary (non-boss) battle. Returns how it opened or "".
func _drive_to_battle(controller: RunController) -> String:
	var steps := 0
	var last := ""
	while steps < MAX_DRIVE_STEPS:
		steps += 1
		if controller.state == null or controller.state.is_terminal():
			return ""
		var view := str(controller.current_view_name())
		if view == "Battle":
			if bool(BATTLE_COMMAND_FACADE.boss_blocks_retreat(controller.current_battle)):
				return ""
			return "combat_node"
		var chosen := ""
		for node_value in controller.visible_route_nodes(2):
			var node: Dictionary = node_value
			if not bool(node.get("reachable", false)):
				continue
			var ntype := str(node.get("type", ""))
			if ntype in ["combat", "pursuit"]:
				chosen = str(node.get("id", ""))
				break
			if chosen == "" and ntype in ["hazard", "event", "contact", "wild_gu"]:
				chosen = str(node.get("id", ""))
		if chosen == "":
			return ""
		controller.submit_command({"type": "travel", "node_id": chosen})
		await _settle(6)
		view = str(controller.current_view_name())
		if view == "Battle":
			if bool(BATTLE_COMMAND_FACADE.boss_blocks_retreat(controller.current_battle)):
				return ""
			return "traveled_to_" + chosen
		if view == "Map":
			continue
		if view == "Ending":
			return ""
		# Non-battle session screen: try to pick a fight via the real preview cards.
		if await _pick_fight(controller):
			return "fight_from_%s" % chosen
		if view != "Battle":
			controller.submit_command({"type": "leave_node"})
			await _settle(6)
	last = "steps_cap"
	return ""


func _pick_fight(controller: RunController) -> bool:
	if controller.current_node.is_empty():
		return false
	var cards: Array[Dictionary] = ACTION_PREVIEW_SERVICE.preview_actions(
			controller.state, controller.current_node, controller.catalog)
	for card in cards:
		if not bool(card.get("executable", false)):
			continue
		var command: Dictionary = card.get("command", {})
		var is_fight := str(command.get("action_id", "")) == "fight" \
				or (str(command.get("type", "")) == "resolve_contact" and str(command.get("approach", "")) == "fight")
		if not is_fight:
			continue
		controller.submit_command({
			"type": "action_card",
			"action_id": str(card.get("id", "")),
			"state_version": controller.state.event_log.size(),
			"node_id": str(controller.current_node.get("id", "")),
			"session_node_id": str(controller.state.encounter_session.get("node_id", "")),
		})
		await _settle(6)
		return str(controller.current_view_name()) == "Battle"
	return false


func _next_reachable(controller: RunController) -> String:
	for node_value in controller.visible_route_nodes(2):
		var node: Dictionary = node_value
		if bool(node.get("reachable", false)) and str(node.get("type", "")) != "rest":
			return str(node.get("id", ""))
	return ""


func _drag_card(snapshot: Dictionary) -> Dictionary:
	for card_value in snapshot.get("hand", []):
		var card: Dictionary = card_value
		if bool(card.get("executable", false)) and str(card.get("target_type", "none")) == "single_enemy":
			return card
	return {}


func _enemy_hp(snapshot: Dictionary, enemy_id: String) -> int:
	for enemy_value in snapshot.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if str(enemy.get("id", "")) == enemy_id:
			return int(enemy.get("hp", 0))
	return -1


func _enemy_shield(snapshot: Dictionary, enemy_id: String) -> int:
	for enemy_value in snapshot.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if str(enemy.get("id", "")) == enemy_id:
			return int(enemy.get("shield", 0))
	return -1


func _motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = Vector2.ZERO
	Input.parse_input_event(event)


func _button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null


func _pixel_count() -> int:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var window := root as Window
	if window == null or window.get_texture() == null:
		return 0
	var image := window.get_texture().get_image()
	var counts := {}
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var key := image.get_pixel(x, y).to_html(false).substr(0, 6)
			counts[key] = int(counts.get(key, 0)) + 1
	return counts.size()


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame


func _quit(code: int) -> void:
	quit(code)
