extends SceneTree

# E5a：统计各层四分类（battle/rest/unknown/trade）与整局战斗占比。
# 用法：godot --headless --path . -s tools/verify_pacing_density.gd
# 退出码：0 = 四类均现且战斗占比在 [50%, 60%]；1 = 任一门禁失败。

# 单种子方差大：门禁用种子 1..40 聚合（与 test_category_route 同口径，样本加厚）。
# 单测口径 1..20 实测约 53.7%（规格 §3.1 校准注）；本工具多采样以贴近期望。
const SEEDS: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
	21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
]
const CATEGORY_BY_TYPE := {
	"combat": "battle", "pursuit": "battle",
	"rest": "rest", "refinement": "rest", "cultivation": "rest",
	"hazard": "unknown", "event": "unknown", "inheritance": "unknown",
	"earth_vein": "unknown", "wild_gu": "unknown", "seclusion": "unknown",
	"contact": "trade", "caravan": "trade", "market": "trade",
	"shop": "trade", "commission": "trade",
}
const SPECIAL_TYPES := ["ledger", "ascension"]
const FIXED_SLOT_TEMPLATES := [
	"ridge_black_market", "yizang_ridge", "layer_boss_stand_1", "layer_boss_stand_2",
	"layer_boss_stand_3", "layer_boss_stand_4", "final_boss_stand", "stage_one_ledger",
]
const CAT_KEYS: Array[String] = ["battle", "rest", "unknown", "trade"]


func _initialize() -> void:
	var MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
	var failures: Array[String] = []
	var layer_agg := {}
	for layer in range(1, 6):
		layer_agg[layer] = {"battle": 0, "rest": 0, "unknown": 0, "trade": 0, "total": 0}
	var full_agg := {"battle": 0, "rest": 0, "unknown": 0, "trade": 0}
	var seed_layers_missing: Array[String] = []

	for seed_value in SEEDS:
		var route: Array = MapGeneratorScript.build(seed_value, false)
		var combat_templates: Array = []
		print("===== seed %d =====" % seed_value)
		for layer_key in ["1", "2", "3", "4", "5"]:
			var layer_nodes: Array = route.filter(
					func(n): return str(n.get("layer", "")) == layer_key)
			var cats := _categorize(layer_nodes)
			var counts: Dictionary = cats["counts"]
			var template_counts: Dictionary = {}
			for node_value in layer_nodes:
				var node: Dictionary = node_value
				var template_id := str(node.get("template_id", ""))
				template_counts[template_id] = int(template_counts.get(template_id, 0)) + 1
				if (str(node.get("type", "")) == "combat"
						and not FIXED_SLOT_TEMPLATES.has(template_id)
						and not combat_templates.has(template_id)
						and not template_id.is_empty()):
					combat_templates.append(template_id)
			var layer_total := 0
			for key in CAT_KEYS:
				layer_total += int(counts[key])
				layer_agg[int(layer_key)][key] = int(layer_agg[int(layer_key)][key]) + int(counts[key])
			layer_agg[int(layer_key)]["total"] = int(layer_agg[int(layer_key)]["total"]) + layer_total
			for key in CAT_KEYS:
				full_agg[key] = full_agg[key] + int(counts[key])
			var missing_cats: Array[String] = []
			for key in CAT_KEYS:
				if int(counts[key]) <= 0:
					missing_cats.append(key)
			# 单种子单层 unknown/trade 样本少时可能为 0（权重 9%/4%）——只打印；
			# 门禁在多种子聚合层（下方 aggregate）。
			var mark := "ok"
			if not missing_cats.is_empty():
				mark = "sparse"
			print("  L%s battle=%d rest=%d unknown=%d trade=%d total=%d [%s] | combat templates=%d %s"
					% [layer_key, counts["battle"], counts["rest"], counts["unknown"],
					counts["trade"], layer_total, mark, combat_templates.size(),
					str(combat_templates)])

		var full_stat := _categorize(route)
		var full_total := 0
		for key in CAT_KEYS:
			full_total += int(full_stat["counts"][key])
		var battle_share := 0.0
		if full_total > 0:
			battle_share = float(full_stat["counts"]["battle"]) / float(full_total)
		# 单局方差 ±13%（见 test_category_route）：单种子只打印，门禁在多种子聚合。
		print("  FULL battle share=%.3f | unknown_unrevealed=%d"
				% [battle_share, int(full_stat["unknown_unrevealed"])])

	print("===== aggregate over %d seeds =====" % SEEDS.size())
	for layer in range(1, 6):
		var row: Dictionary = layer_agg[layer]
		var total := int(row["total"])
		var missing: Array[String] = []
		for key in CAT_KEYS:
			if int(row[key]) <= 0:
				missing.append(key)
		if not missing.is_empty():
			failures.append("aggregate L%d missing %s" % [layer, str(missing)])
		print("  L%d battle=%d rest=%d unknown=%d trade=%d total=%d"
				% [layer, row["battle"], row["rest"], row["unknown"], row["trade"], total])
	var agg_total := 0
	for key in CAT_KEYS:
		agg_total += full_agg[key]
	var agg_share := 0.0
	if agg_total > 0:
		agg_share = float(full_agg["battle"]) / float(agg_total)
	var agg_share_ok := agg_share >= 0.50 and agg_share <= 0.60
	if not agg_share_ok:
		failures.append("aggregate battle share %.3f outside [0.50,0.60]" % agg_share)
	print("  AGG battle=%d rest=%d unknown=%d trade=%d battle_share=%.3f [%s]"
			% [full_agg["battle"], full_agg["rest"], full_agg["unknown"], full_agg["trade"],
			agg_share, "ok" if agg_share_ok else "FAIL"])

	if failures.is_empty():
		print("E5a PASS: every layer has all four categories; battle share within band")
		quit(0)
	else:
		print("E5a FAIL: %d issue(s)" % failures.size())
		for line in failures:
			print("  - " + line)
		quit(1)


func _categorize(nodes: Array) -> Dictionary:
	var counts := {"battle": 0, "rest": 0, "unknown": 0, "trade": 0}
	var unknown_unrevealed := 0
	for n in nodes:
		if FIXED_SLOT_TEMPLATES.has(str(n.get("template_id", ""))):
			continue
		var ntype := str(n.get("type", ""))
		if SPECIAL_TYPES.has(ntype):
			continue
		var cat: String = str(CATEGORY_BY_TYPE.get(ntype, "trade"))
		if not counts.has(cat):
			counts[cat] = 0
		counts[cat] = int(counts[cat]) + 1
		if cat == "unknown" and not bool(n.get("revealed", true)):
			unknown_unrevealed += 1
	return {"counts": counts, "unknown_unrevealed": unknown_unrevealed}
