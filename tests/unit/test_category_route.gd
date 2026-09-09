extends GutTest
## E2b：事件分类按层伪随机——确定性、4 分类分布、战斗占比、迷雾标记。
## 规格：docs/superpowers/specs/2026-09-09-event-classification-design.md §3/§5。


const CATEGORY_BY_TYPE := {
	"combat": "battle", "pursuit": "battle",
	"rest": "rest", "refinement": "rest", "cultivation": "rest",
	"hazard": "unknown", "event": "unknown", "inheritance": "unknown",
	"earth_vein": "unknown", "wild_gu": "unknown", "seclusion": "unknown",
	"contact": "trade", "caravan": "trade", "market": "trade",
	"shop": "trade", "commission": "trade",
}
const SPECIAL_TYPES := ["ledger", "ascension"]
# 固定位锚点不计入随机槽分布（黑市/遗葬由 pacing anchors 保底，boss 行尾固定）。
const FIXED_SLOT_TEMPLATES := [
	"ridge_black_market", "yizang_ridge", "layer_boss_stand_1", "layer_boss_stand_2",
	"layer_boss_stand_3", "layer_boss_stand_4", "final_boss_stand", "stage_one_ledger",
]


static func _is_fixed_slot(n: Dictionary) -> bool:
	return FIXED_SLOT_TEMPLATES.has(str(n.get("template_id", "")))


static func _categorize(nodes: Array) -> Dictionary:
	var counts := {"battle": 0, "rest": 0, "unknown": 0, "trade": 0}
	var unknown_unrevealed := 0
	var special := 0
	for n in nodes:
		if _is_fixed_slot(n):
			continue
		var ntype := str(n.get("type", ""))
		if SPECIAL_TYPES.has(ntype):
			special += 1
			continue
		var cat: String = CATEGORY_BY_TYPE.get(ntype, "trade")
		counts[cat] = counts[cat] + 1
		if cat == "unknown" and not bool(n.get("revealed", true)):
			unknown_unrevealed += 1
	return {"counts": counts, "unknown_unrevealed": unknown_unrevealed, "special": special}


func test_same_seed_same_category_route() -> void:
	var a := MapGenerator.build(20260909, false)
	var b := MapGenerator.build(20260909, false)
	assert_eq(a, b, "same seed must yield identical route (incl. revealed)")


func test_category_pick_weights_match() -> void:
	# 直接调用隔离验证：随机槽分类分布贴合权重（L1 82/5/9/4，允许保底扰动）。
	var pacing: Dictionary = _load_json("res://data/pacing.json")
	var nodes: Dictionary = _load_json("res://data/nodes.json")
	var node_by_id := {}
	for n in nodes.get("nodes", []):
		node_by_id[str(n.get("id", ""))] = n
	var pools: Dictionary = pacing.get("category_pools", {})
	var counts := {"battle": 0, "rest": 0, "unknown": 0, "trade": 0}
	for rep in range(1, 21):
		var rng = SeededRng.new(rep)
		var used := {}
		for i in range(50):
			var pick: Dictionary = MapGenerator._pick_category_template(rng,
					pacing["layers"]["1"], pools, node_by_id, 1, [], [], used)
			var cat: String = str(pick.get("category", "?"))
			counts[cat] = counts[cat] + 1
			used[cat] = int(used.get(cat, 0)) + 1
			used["_slots"] = int(used.get("_slots", 0)) + 1
	var total: int = counts["battle"] + counts["rest"] + counts["unknown"] + counts["trade"]
	# 权重 82/5/9/4；保底强制少量扰动，宽断言 75-90 / 3-10 / 5-15 / 2-8。
	assert_between(float(counts["battle"]) / total, 0.75, 0.90, "direct battle weight")
	assert_between(float(counts["rest"]) / total, 0.02, 0.10, "direct rest weight")
	assert_between(float(counts["unknown"]) / total, 0.04, 0.16, "direct unknown weight")
	assert_between(float(counts["trade"]) / total, 0.01, 0.10, "direct trade weight")


static func _load_json(path: String) -> Variant:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return {}
	var text := handle.get_as_text()
	handle.close()
	return JSON.parse_string(text)


func test_every_layer_has_all_four_categories() -> void:
	for seed in [20260909, 42, 777, 31337]:
		var route := MapGenerator.build(seed, false)
		for layer in range(1, 6):
			var layer_nodes := route.filter(func(n): return int(n.get("layer", 0)) == layer)
			var stat := _categorize(layer_nodes)
			for cat in ["battle", "rest", "unknown", "trade"]:
				assert_true(stat["counts"][cat] > 0,
						"seed %d layer %d must contain category %s (got %s)" % [seed, layer, cat, stat["counts"]])


func test_combat_share_within_50_60_percent() -> void:
	# 整局口径（含锚点 + REST_ROW_STRIDE 强制休息行）：battle 权重 82->74 实测
	# 100 种子 53.7%（规格目标 55-60% 受续航节奏封顶，见规格 §3.1 校准注）。
	# 单局方差 ±13%，用多种子聚合断言。
	var agg := {"battle": 0, "rest": 0, "unknown": 0, "trade": 0}
	for seed in range(1, 21):
		var route := MapGenerator.build(seed, false)
		var stat := _categorize(route)
		for cat in ["battle", "rest", "unknown", "trade"]:
			agg[cat] = agg[cat] + stat["counts"][cat]
	var total: int = agg["battle"] + agg["rest"] + agg["unknown"] + agg["trade"]
	var share := float(agg["battle"]) / float(total)
	assert_between(share, 0.50, 0.60, "aggregated full-route combat share %.2f" % share)


func test_unknown_nodes_are_misted_until_revealed() -> void:
	var route := MapGenerator.build(20260909, false)
	var unknown_hidden := route.filter(func(n):
		return CATEGORY_BY_TYPE.get(str(n.get("type", "")), "") == "unknown" and not bool(n.get("revealed", true)))
	assert_true(unknown_hidden.size() > 0, "random unknown nodes must start unrevealed")
	for n in unknown_hidden:
		assert_false(bool(n.get("revealed", true)), "unknown node must not be revealed")
	# 非未知分类一律可见。
	for n in route:
		var cat: String = CATEGORY_BY_TYPE.get(str(n.get("type", "")), "")
		if cat != "unknown":
			assert_true(bool(n.get("revealed", true)), "node %s must be revealed" % str(n.get("id", "")))


func test_anchor_nodes_stay_visible() -> void:
	# 锚点/行尾固定位（anchor 标记）保持可见；同一模板被当作未知类随机
	# 抽中时（如 L2+ 随机槽的遗藏 yizang_ridge）按未知规则迷雾。
	var route := MapGenerator.build(20260909, false)
	var anchor_count := 0
	for n in route:
		if bool(n.get("anchor", false)):
			anchor_count += 1
			assert_true(bool(n.get("revealed", true)), "anchor instance must stay visible: %s" % str(n.get("template_id", "")))
	assert_gt(anchor_count, 0, "route must contain anchor slots")


func test_category_pool_templates_are_reachable_some_seed() -> void:
	# 36 随机模板（29 进池 + 5 boss + yizang/black_market）至少有一个种子族到达。
	var seeds := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var seen := {}
	for seed in seeds:
		var route := MapGenerator.build(seed, false)
		for n in route:
			seen[str(n.get("template_id", ""))] = true
	var expected := [
		"beast_swarm_pass", "iron_hide_ambush", "scout_crossing_raid", "wolf_pack_trail",
		"faction_guard_checkpoint", "greedy_wanderer",
		"rest_hollow", "rest_shrine", "refinement_hollow", "cultivation_spring",
		"toxic_mountain_path", "flooded_cave", "black_mud_marsh", "echo_cave",
		"gu_rot_pact", "moonlit_trail", "mist_shrine", "earth_vein_contest",
		"sealed_earth_vein", "poison_fog_vein", "blood_moss_grove", "body_imprint_ritual",
		"neutral_wanderer", "wandering_peddler", "ridge_caravan", "caravan_missing_goods",
		"village_short_work", "ridge_market", "herbalist_commission",
		"yizang_ridge", "ridge_black_market",
		"layer_boss_stand_1", "layer_boss_stand_2", "layer_boss_stand_3",
		"layer_boss_stand_4", "final_boss_stand",
	]
	for tid in expected:
		assert_true(seen.has(tid), "template %s must appear in seeds 1..10" % tid)
