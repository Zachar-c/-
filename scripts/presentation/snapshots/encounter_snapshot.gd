class_name EncounterSnapshot
extends RefCounted


# W12 split: the Encounter (real node actions) screen snapshot, moved verbatim
# from run_snapshot_builder.gd. Read-only projection; multi-screen shared
# helpers stay on RunSnapshotBuilder.


const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")


static func build(controller) -> Dictionary:
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var meta = controller.meta
	var current_node: Dictionary = controller.current_node
	var knowledge: Dictionary = {}
	if meta != null:
		knowledge = meta.unlocked_random_outcomes
	var actions: Array[Dictionary] = RunSnapshotBuilder._node_actions(controller)
	var intel: Dictionary = {}
	if state.known_facts.has("procured_weakness"):
		intel = {"weakness": "已探明弱点，战斗增伤", "cost": "情报"}
	return {
		"node": {
			"title": RunSnapshotBuilder._node_label(current_node),
			"desc": str(current_node.get("summary", current_node.get("desc", ""))),
			"type": str(current_node.get("type", "")),
		},
		"actions": actions,
		"intel": intel,
		"player": _player_panel(state),
		"resources": RunSnapshotBuilder._resources(state),
		"contracts": RunSnapshotBuilder._contracts(state, catalog),
		"anomalies": DdaResolverScript.marker_meta(state, catalog),
		"death_lines": RunSnapshotBuilder._death_lines(state),
		"inventory": RunSnapshotBuilder._inventory(state, catalog),
	}


## C4 侧边自身状态面板（§16.5 事件侧边快捷查看气血/魂魄/元石/蛊虫）。
static func _player_panel(state) -> Dictionary:
	var cult: Dictionary = state.cultivator
	var gu_names: Array[String] = []
	for inst_key in state.gu_instances:
		var inst: Dictionary = state.gu_instances[inst_key]
		gu_names.append(DisplayText.gu(str(inst.get("definition_id", ""))))
	return {
		# RunState.health 是唯一真值（battle 回合结算后由 run_controller 同步
		# 写回 state.health + cultivator 镜像；旧路径 shop/rest 也写它）。
		"hp": int(state.health),
		"max_hp": maxi(1, int(state.max_health)),
		"primordial": int(state.essence),
		"soul": int(cult.get("soul", 0)),
		"stone": int(state.stone),
		"gu_names": gu_names,
	}
