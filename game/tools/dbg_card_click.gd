extends SceneTree
const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")
func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	root.add_child(viewport)
	var host := Control.new()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var state := {
		"resources": {}, "contracts": [], "anomalies": [], "death_lines": {},
		"enemies": [{"id": "e0", "name": "敌人0", "hp": 20, "max_hp": 20, "shield": 0, "statuses": [], "intent": {"type": "attack", "value": 4, "detail": "冲撞"}, "alive": true}],
		"player": {"hp": 20, "max_hp": 20, "shield": 0, "primordial": 3, "soul": 4, "statuses": []},
		"hand": [{"id": "c1", "name": "月光蛊", "cost": 1, "effect": "造成伤害", "executable": true, "target_type": "single_enemy", "valid_target_ids": ["e0"]}],
		"piles": {"draw": 0, "discard": 0, "exhausted": 0}, "soul_ops": {"cap": 1, "used": 0}, "default_target_id": "e0",
	}
	var inst := TscnMountHelper.instantiate("res://scenes/ui/screens/battle_screen.tscn", state, {})
	host.add_child(inst)
	await process_frame
	await process_frame
	var btn := _find_button(inst, "card_body")
	var center := btn.get_global_rect().get_center()
	print("BTN rect=", btn.get_global_rect(), " center=", center)
	var ev := InputEventMouseMotion.new()
	ev.position = center; ev.global_position = center
	viewport.push_input(ev)
	await process_frame
	await process_frame
	print("after hover: btn.is_hovered=", btn.is_hovered(), " gui_hovered=", viewport.gui_get_hovered_control())
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = center; down.global_position = center
	viewport.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = center; up.global_position = center
	viewport.push_input(up)
	await process_frame
	await process_frame
	print("after click: target_select=", _named(inst, "battle_target_select") != null, " idle=", _named(inst, "battle_idle") != null)
	quit(0)

func _find_button(node: Node, prefix: String) -> Button:
	if node is Button and str(node.name).begins_with(prefix):
		return node
	for c in node.get_children():
		var f := _find_button(c, prefix)
		if f != null:
			return f
	return null

func _named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for c in node.get_children():
		var f := _named(c, wanted)
		if f != null:
			return f
	return null
