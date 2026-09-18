extends SceneTree

## Reachability-8 / B1 只读地图产物审计（measurement-only）。
##
## 目的：回答「短局为何起手在 L3/L4」。
##   - 转储每个种子的 trailhead 可达起点集（`start==true` 的节点）；
##   - 对照 `_generate_instance_route` 的 start 赋值契约（只应给 layer 1 / row 0）；
##   - 给出每层节点构成，以及 S1 surrogate 的若干候选口径；
##   - 与 32 局语料实测的「首个访问节点 / 战斗数」逐条对照。
##
## 本工具**只读**：仅调用 MapGenerator.build()，不写任何文件、不改任何规则。
## 用法：godot --headless --path . -s tools/q8g_reachability8_b1_map_audit.gd

const SEEDS: Array[int] = [
	20260927, 11, 33, 55, 101, 202, 303, 404,
	505, 606, 707, 808, 909, 1111, 1212, 1313,
]

const COMBAT_TYPES: Array[String] = ["combat", "pursuit"]

## 32 局语料实测（来自 <TEMP>/gu-zhenrens-r5-logs，两条流派合并）。
## node = 该 seed 图里驱动实际选中的首个访问节点；battles = 观测到的战斗数（force/sword）。
const OBSERVED: Dictionary = {
	20260927: {"node": "L1R3N3", "battles": [19, 13]},
	11: {"node": "L4R3N1", "battles": [12, 9]},
	33: {"node": "L4R3N1", "battles": [8, 8]},
	55: {"node": "L1R2N1", "battles": [22, 23]},
	101: {"node": "L1R0N0", "battles": [20, 24]},
	202: {"node": "L1R0N0", "battles": [21, 21]},
	303: {"node": "L1R2N4", "battles": [16, 18]},
	404: {"node": "L2R3N3", "battles": [15, 18]},
	505: {"node": "L1R0N0", "battles": [19, 20]},
	606: {"node": "L4R2N3", "battles": [3, 7]},
	707: {"node": "L1R3N1", "battles": [22, 21]},
	808: {"node": "L4R4N0", "battles": [12, 12]},
	909: {"node": "L4R2N2", "battles": [9, 8]},
	1111: {"node": "L1R2N4", "battles": [18, 16]},
	1212: {"node": "L3R3N1", "battles": [9, 9]},
	1313: {"node": "L1R0N0", "battles": [20, 21]},
}


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	print("===== R8 / B1 只读地图审计：%d 个种子 =====" % SEEDS.size())
	var catalog: Dictionary = {
		"nodes_data": _load_json("res://data/nodes.json"),
		"pacing": _load_json("res://data/pacing.json"),
	}

	var non_l1_seeds: Array[int] = []
	var start_layer_hist: Dictionary = {}
	var start_contract_violations: Array[String] = []
	var whole_combat: Array[int] = []
	var layer_total: Dictionary = {}
	var layer_combat: Dictionary = {}
	var matched_first := 0
	var rows: Array[Dictionary] = []

	for seed_value in SEEDS:
		var route: Array = MapGenerator.build(seed_value, false, catalog)
		var span: Dictionary = _path_combat_span(route)
		var by_node: Dictionary = span["by_node"]

		var starts: Array = []
		var by_layer: Dictionary = {}
		var combat_by_layer: Dictionary = {}
		for node_value in route:
			var node: Dictionary = node_value
			var layer := int(node.get("layer", 0))
			if not by_layer.has(layer):
				by_layer[layer] = 0
				combat_by_layer[layer] = 0
			by_layer[layer] = int(by_layer[layer]) + 1
			if COMBAT_TYPES.has(str(node.get("type", ""))):
				combat_by_layer[layer] = int(combat_by_layer[layer]) + 1
			if bool(node.get("start", false)):
				var start_row := int(node.get("row", -1))
				starts.append({
					"id": str(node.get("id", "")),
					"layer": layer,
					"row": start_row,
					"template_id": str(node.get("template_id", "")),
					"type": str(node.get("type", "")),
				})
				# 绝对契约（_generate_instance_route:111）：只有 layer==1 && row==0 可带 start。
				if layer != 1 or start_row != 0:
					start_contract_violations.append(
							"seed=%d %s layer=%d row=%d tpl=%s"
							% [seed_value, str(node.get("id", "")), layer, start_row,
								str(node.get("template_id", ""))])
		for layer_key in by_layer.keys():
			layer_total[layer_key] = int(layer_total.get(layer_key, 0)) + int(by_layer[layer_key])
			layer_combat[layer_key] = int(layer_combat.get(layer_key, 0)) + int(combat_by_layer[layer_key])

		var combat_total := 0
		for layer_key in combat_by_layer.keys():
			combat_total += int(combat_by_layer[layer_key])
		whole_combat.append(combat_total)

		var non_l1 := 0
		var start_ids: Array[String] = []
		var start_detail: Array[String] = []
		for start_value in starts:
			var start: Dictionary = start_value
			var layer := int(start["layer"])
			start_layer_hist[layer] = int(start_layer_hist.get(layer, 0)) + 1
			if layer != 1:
				non_l1 += 1
			start_ids.append(str(start["id"]))
			start_detail.append("%s(L%dR%d)"
					% [str(start["id"]), layer, int(start["row"])])
		if non_l1 > 0:
			non_l1_seeds.append(seed_value)

		var observed: Dictionary = OBSERVED.get(seed_value, {})
		var first_node := str(observed.get("node", ""))
		var in_start_set: bool = start_ids.has(first_node)
		if in_start_set:
			matched_first += 1
		var first_span: Dictionary = by_node.get(first_node, {"min": -1, "max": -1})
		var battles: Array = observed.get("battles", [])

		rows.append({
			"seed": seed_value,
			"combat": combat_total,
			"starts": starts.size(),
			"non_l1": non_l1,
			"start_detail": start_detail,
			"span_min": int(span["min"]),
			"span_max": int(span["max"]),
			"first": first_node,
			"first_in_starts": in_start_set,
			"first_lo": int(first_span["min"]),
			"first_hi": int(first_span["max"]),
			"battles": battles,
		})

	print("")
	print("seed       combat starts nonL1  span(全图入口)  实测首节点   在起点集? 该节点前向combat  实测battles")
	print("----------------------------------------------------------------------------------------------------")
	for row in rows:
		print("%-10d %-6d %-6d %-6d %-15s %-12s %-10s %-16s %s" % [
			int(row["seed"]), int(row["combat"]), int(row["starts"]), int(row["non_l1"]),
			"%d..%d" % [int(row["span_min"]), int(row["span_max"])],
			str(row["first"]),
			"YES" if bool(row["first_in_starts"]) else "NO",
			"%d..%d" % [int(row["first_lo"]), int(row["first_hi"])],
			str(row["battles"]),
		])

	print("")
	print("===== 每 seed 起点明细 =====")
	for row in rows:
		print("  seed=%-9d starts=%d %s"
				% [int(row["seed"]), int(row["starts"]), str(row["start_detail"])])

	print("")
	print("===== B1 汇总 =====")
	print("非 L1 起手的种子数: %d / %d" % [non_l1_seeds.size(), SEEDS.size()])
	print("起手层直方图 (layer -> start 节点数): %s" % str(start_layer_hist))
	var total_starts := 0
	var non_l1_starts := 0
	for layer_key in start_layer_hist.keys():
		total_starts += int(start_layer_hist[layer_key])
		if int(layer_key) != 1:
			non_l1_starts += int(start_layer_hist[layer_key])
	print("起点总数 %d，其中 L1 以外 %d (%.0f%%)"
			% [total_starts, non_l1_starts, 100.0 * float(non_l1_starts) / float(total_starts)])
	print("实测首节点落在该图起点集内的种子数: %d / %d" % [matched_first, SEEDS.size()])
	print("")
	print("===== 起点绝对断言（layer==1 && row==0）=====")
	print("契约违规起点数: %d" % start_contract_violations.size())
	for violation in start_contract_violations:
		print("  VIOLATION %s" % violation)
	print("  => start_contract=%s"
			% ("OK" if start_contract_violations.is_empty() else "FAIL"))

	print("")
	print("===== S1 surrogate 候选口径（均为生成期可观察）=====")
	print("A) 全图 combat/pursuit 节点数            : min=%d max=%d" % [_min_int(whole_combat), _max_int(whole_combat)])
	print("B) DAG 完整路线的 combat 数 min-path    : min=%d max=%d"
			% [_min_int(_pluck(rows, "span_min")), _max_int(_pluck(rows, "span_min"))])
	print("C) DAG 完整路线的 combat 数 max-path    : min=%d max=%d"
			% [_min_int(_pluck(rows, "span_max")), _max_int(_pluck(rows, "span_max"))])
	print("D) 实测入口节点的前向 combat 数         : min=%d max=%d"
			% [_min_int(_pluck(rows, "first_lo")), _max_int(_pluck(rows, "first_hi"))])
	print("")
	print("各层平均节点数 (共 %d 种子):" % SEEDS.size())
	for layer_key in [1, 2, 3, 4, 5]:
		print("  L%d: nodes=%.1f combat=%.1f"
				% [layer_key,
					float(layer_total.get(layer_key, 0)) / float(SEEDS.size()),
					float(layer_combat.get(layer_key, 0)) / float(SEEDS.size())])

	print("")
	print("===== 确定性自检（同 seed 两次构建逐字节比对）=====")
	var determinism_ok := true
	for seed_value in [606, 11, 33]:
		var a := _fingerprint(MapGenerator.build(seed_value, false, catalog))
		var b := _fingerprint(MapGenerator.build(seed_value, false, catalog))
		var same := a == b
		if not same:
			determinism_ok = false
		print("  seed=%-9d fingerprint=%s identical=%s" % [seed_value, a.substr(0, 16), str(same)])
	print("  => determinism=%s" % ("OK" if determinism_ok else "FAIL"))

	print("")
	print("elapsed=%d ms" % (Time.get_ticks_msec() - started))
	quit(0)


## 沿 next_ids 的 DAG（route 逆序即拓扑序）求「一条完整路线上的 combat 节点数」上下界。
## 返回 {"min", "max", "by_node": {id: {"min", "max"}}}。
func _path_combat_span(route: Array) -> Dictionary:
	var index_by_id: Dictionary = {}
	for i in route.size():
		index_by_id[str((route[i] as Dictionary).get("id", ""))] = i
	var best_min: Array = []
	var best_max: Array = []
	best_min.resize(route.size())
	best_max.resize(route.size())
	for i in range(route.size() - 1, -1, -1):
		var node: Dictionary = route[i]
		var self_cost := 1 if COMBAT_TYPES.has(str(node.get("type", ""))) else 0
		var children: Array = []
		for next_id_value in node.get("next_ids", []):
			var next_id := str(next_id_value)
			if index_by_id.has(next_id):
				children.append(int(index_by_id[next_id]))
		if children.is_empty():
			best_min[i] = self_cost
			best_max[i] = self_cost
		else:
			var lo: int = int(best_min[children[0]])
			var hi: int = int(best_max[children[0]])
			for child in children:
				lo = mini(lo, int(best_min[child]))
				hi = maxi(hi, int(best_max[child]))
			best_min[i] = self_cost + lo
			best_max[i] = self_cost + hi
	var by_node: Dictionary = {}
	for i in route.size():
		by_node[str((route[i] as Dictionary).get("id", ""))] = {
			"min": int(best_min[i]),
			"max": int(best_max[i]),
		}
	var start_min: int = 1 << 30
	var start_max: int = 0
	for i in route.size():
		if not bool((route[i] as Dictionary).get("start", false)):
			continue
		start_min = mini(start_min, int(best_min[i]))
		start_max = maxi(start_max, int(best_max[i]))
	if start_min == 1 << 30:
		return {"min": -1, "max": -1, "by_node": by_node}
	return {"min": start_min, "max": start_max, "by_node": by_node}


func _fingerprint(route: Array) -> String:
	var parts: Array[String] = []
	for node_value in route:
		var node: Dictionary = node_value
		parts.append("%s|%s|%s|%s|%s" % [
			str(node.get("id", "")), str(node.get("template_id", "")),
			str(node.get("layer", "")), str(node.get("start", false)),
			str(node.get("next_ids", [])),
		])
	return str(hash("\n".join(parts)))


func _pluck(rows: Array[Dictionary], key: String) -> Array[int]:
	var out: Array[int] = []
	for row in rows:
		out.append(int(row[key]))
	return out


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _min_int(values: Array[int]) -> int:
	var out: int = values[0]
	for value in values:
		out = mini(out, value)
	return out


func _max_int(values: Array[int]) -> int:
	var out: int = values[0]
	for value in values:
		out = maxi(out, value)
	return out
