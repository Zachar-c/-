extends GutTest
## D7 精英节点显性化（2026-09-16）。
##
## 背景：`map_screen_view._build_node_button` 早就写了 `ELITE_STYLE` 分支，判据是
## `str(node.get("enemy_kind","")).contains("elite")`，但：
##   ① 地图快照的节点字典是 12 键白名单，**从来不写 `enemy_kind`** ⇒ 该分支是死代码；
##   ② 12 个 tier=="elite" 的敌人里只有 `ridge_elite_scout` 的 id 含 "elite"
##      ⇒ 即使键到位，也会漏判 11/12。
## 本文件把「节点是否精英遭遇」固化为**数据驱动**的只读投影：
##   `MapGenerator.node_threat(node, catalog)` ⇒ "" | "elite"
## 判据读 `catalog.enemy_by_id` 的 `tier`，不猜 id 子串；迷雾节点不泄露。
##
## 规格：docs/superpowers/reports/2026-09-16-roguelike-audit-and-directions.md §3.6（D7）


const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")

## 数据里 tier=="elite" 但 id **不含** "elite" 的敌人——旧子串判据漏判的那一类。
const ELITE_ID_WITHOUT_MARK: String = "thunder_crown_wolf"
const ELITE_ID_WITH_MARK: String = "ridge_elite_scout"
const COMMON_ID: String = "ridge_hound"
const BOSS_ID: String = "miasma_vein_lord"

var _catalog: Dictionary = {}


func before_all() -> void:
	_catalog = ContentCatalogScript.load_all()


func _controller(seed_value: int = 101) -> RunController:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(seed_value)
	return controller


# ------------------------------------------------------------------ 数据前提

func test_fixture_ids_sit_on_the_tiers_this_suite_assumes() -> void:
	var enemy_by_id: Dictionary = _catalog.get("enemy_by_id", {})
	assert_eq(str(enemy_by_id.get(ELITE_ID_WITHOUT_MARK, {}).get("tier", "")), "elite")
	assert_eq(str(enemy_by_id.get(ELITE_ID_WITH_MARK, {}).get("tier", "")), "elite")
	assert_eq(str(enemy_by_id.get(COMMON_ID, {}).get("tier", "")), "common")
	assert_eq(str(enemy_by_id.get(BOSS_ID, {}).get("tier", "")), "boss")
	# 这条前提一旦被下游数据改动打破，本套件的其余断言就失去意义。
	assert_false(ELITE_ID_WITHOUT_MARK.contains("elite"),
			"fixture must stay an elite whose id has no 'elite' substring")


# ------------------------------------------------------------------ 判据

func test_threat_reads_the_data_tier_not_the_id_substring() -> void:
	var node := {"type": "combat", "enemy_kind": ELITE_ID_WITHOUT_MARK, "revealed": true}
	assert_eq(MapGeneratorScript.node_threat(node, _catalog), "elite",
			"elite tier must come from the catalog; guessing from the id misses 11 of 12 elites")


func test_threat_stays_empty_for_common_boss_and_non_combat_nodes() -> void:
	var cases := [
		{"name": "common enemy", "node": {"type": "combat", "enemy_kind": COMMON_ID, "revealed": true}},
		{"name": "boss stand", "node": {"type": "combat", "enemy_kind": BOSS_ID, "revealed": true}},
		{"name": "rest node", "node": {"type": "rest", "enemy_kind": ELITE_ID_WITHOUT_MARK, "revealed": true}},
		{"name": "fogged node", "node": {"type": "combat", "enemy_kind": ELITE_ID_WITHOUT_MARK, "revealed": false}},
		{"name": "no enemy at all", "node": {"type": "combat", "revealed": true}},
	]
	for case_value in cases:
		var case: Dictionary = case_value
		assert_eq(MapGeneratorScript.node_threat(case["node"], _catalog), "",
				"threat must stay empty for: %s" % str(case["name"]))


func test_threat_honours_the_encounter_key_precedence() -> void:
	# `enemy_roll`（E6 抽取）优先于模板自带 `enemy_kinds` / `enemy_kind`
	# —— 与 run_battle_flow / battle_command_facade 的读键顺序一致。
	var rolled := {
		"type": "combat", "revealed": true,
		"enemy_kind": COMMON_ID,
		"enemy_kinds": [COMMON_ID],
		"enemy_roll": [ELITE_ID_WITHOUT_MARK],
	}
	assert_eq(MapGeneratorScript.node_threat(rolled, _catalog), "elite",
			"enemy_roll must win over the template enemy")
	var template_only := {
		"type": "combat", "revealed": true,
		"enemy_kind": COMMON_ID,
		"enemy_kinds": [ELITE_ID_WITHOUT_MARK],
	}
	assert_eq(MapGeneratorScript.node_threat(template_only, _catalog), "elite",
			"enemy_kinds must be used when there is no roll (anchors / old saves)")


func test_any_elite_in_a_multi_enemy_encounter_marks_the_node() -> void:
	# 多敌遭遇（`beast_swarm_pass`）的形状由 E6 保留：场上只要有一个精英，
	# 玩家就该在地图上看到风险——这正是「显性化风险决策」要买的信息。
	var mixed := {"type": "combat", "revealed": true, "enemy_roll": [COMMON_ID, ELITE_ID_WITHOUT_MARK]}
	assert_eq(MapGeneratorScript.node_threat(mixed, _catalog), "elite")
	var all_common := {"type": "combat", "revealed": true, "enemy_roll": [COMMON_ID, COMMON_ID]}
	assert_eq(MapGeneratorScript.node_threat(all_common, _catalog), "")


func test_unknown_enemy_ids_are_not_treated_as_elite() -> void:
	# 目录里查不到的 id（旧存档 / 手写桩）不得被猜成精英。
	var node := {"type": "combat", "enemy_kind": "resolute_elite", "revealed": true}
	assert_false(_catalog.get("enemy_by_id", {}).has("resolute_elite"),
			"fixture id must really be outside the catalog")
	assert_eq(MapGeneratorScript.node_threat(node, _catalog), "",
			"a non-catalog id must never be upgraded to elite")


func test_boundary_fixed_enemy_pursuit_nodes_are_out_of_scope_for_now() -> void:
	# 特征化断言（锁定当前边界，不是"这是对的"）：本轮只覆盖 `type=="combat"`
	# 的**抽取型**战斗。`greedy_wanderer` 的 type 是 `pursuit`、敌人硬编码为
	# `thunder_crown_wolf`（tier=elite），因此它是一场**固定**精英战却不被标记
	# ——固定敌人属设计常量、非 roguelike 方差，故不在 D7 范围内。
	# 若要把固定精英也显性化，改 `node_threat` 的类型白名单并同步本断言。
	var pursuit := {"type": "pursuit", "enemy_kind": ELITE_ID_WITHOUT_MARK, "revealed": true}
	assert_eq(str(_catalog.get("enemy_by_id", {}).get(ELITE_ID_WITHOUT_MARK, {}).get("tier", "")), "elite")
	assert_eq(MapGeneratorScript.node_threat(pursuit, _catalog), "",
			"pursuit nodes stay unmarked this round; see the follow-up in the D7 report")


# ------------------------------------------------------------------ 真实快照

func test_real_map_snapshot_carries_a_threat_key_on_every_node() -> void:
	var snapshot: Dictionary = _controller()._snapshot_for("Map")
	var nodes: Array = snapshot.get("nodes", [])
	assert_false(nodes.is_empty(), "map snapshot must expose nodes")
	for node_value in nodes:
		var node: Dictionary = node_value
		assert_true(node.has("threat"),
				"every map node must carry threat (node %s)" % str(node.get("id", "")))


func test_real_snapshot_threat_matches_the_route_node() -> void:
	# 快照是只读投影：不得自己算一套，必须与 route 节点上的判据逐点一致。
	for seed_value in [1, 2, 3, 7, 42]:
		var controller := _controller(seed_value)
		var route_by_id := {}
		for node_value in controller.route:
			route_by_id[str((node_value as Dictionary).get("id", ""))] = node_value
		var snapshot: Dictionary = controller._snapshot_for("Map")
		for node_value in snapshot.get("nodes", []):
			var node: Dictionary = node_value
			var node_id := str(node.get("id", ""))
			var source: Dictionary = route_by_id.get(node_id, {})
			assert_eq(str(node.get("threat", "")),
					MapGeneratorScript.node_threat(source, _catalog),
					"seed %d node %s: snapshot threat must mirror the route node" % [seed_value, node_id])


# ------------------------------------------------------------------ 反空转 canary

func test_elite_encounters_actually_appear_in_real_runs() -> void:
	# 若 pacing 的 rank 区间或 tier 权重让精英永不出现，`threat` 就是死数据。
	# 40 种子：至少 20 种子含精英战斗节点，且精英节点总数 ≥ 40。
	var seeds_with_elite := 0
	var elite_nodes := 0
	for seed_value in range(1, 41):
		var found_in_seed := false
		for node_value in MapGeneratorScript.build(seed_value, false, _catalog):
			var node: Dictionary = node_value
			if MapGeneratorScript.node_threat(node, _catalog) == "elite":
				elite_nodes += 1
				found_in_seed = true
		if found_in_seed:
			seeds_with_elite += 1
	assert_gte(seeds_with_elite, 20, "elite fights must occur across seeds, not just in fixtures")
	assert_gte(elite_nodes, 40, "40 seeds must yield a meaningful number of elite nodes")
