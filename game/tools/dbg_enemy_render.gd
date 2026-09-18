extends SceneTree
const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")
func _initialize() -> void:
	var controller: Node = preload("res://scripts/presentation/run_controller.gd").new()
	root.add_child(controller)
	controller.start_new_run(2026)
	controller.current_node = {"id": "beast_swarm_pass", "type": "combat", "enemy_kind": "neutral_stone_wanderer"}
	controller._start_battle()
	var snapshot: Dictionary = controller._snapshot_for("Battle")
	var host := Control.new()
	root.add_child(host)
	host.add_child(TscnMountHelper.instantiate("res://scenes/ui/screens/battle_screen.tscn", snapshot, {}))
	await process_frame
	var labels: Array = []
	_find(host, func(n): if n is Label: labels.append([n.name, n.text]))
	print("LABELS=", labels)
	quit(0)

func _find(node: Node, cb: Callable) -> void:
	cb.call(node)
	for c in node.get_children():
		_find(c, cb)
