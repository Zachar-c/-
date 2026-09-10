extends GutTest


# E6 敌人按层抽取（2026-09-10）。
#
# 不变量（每条都对应一个"错了会静默毁掉节奏"的点）：
#   · 确定性：同种子同节点 → 同一结果，可复现（回放/存档一致）。
#   · 主题与层区间：抽出的敌人必须属于该点位的主题，且 rank 落在本层区间内。
#   · **Boss 绝不随机出现**：关底台是刻意摆放的锚点，随机抽到 Boss 会让层节奏失效。
#   · 同节点不重复：节点上出现两个同名敌人会被 content_catalog 当错误拒绝。
#   · 池空回退、且**绝不返回空数组**；区间为空时先放宽下界，不整层抽空某个主题。
#   · **不扰动地图布局**：抽取走独立派生流，去掉敌人目录后地图结构必须逐字段一致。

const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const EnemyCatalogScript := preload("res://scripts/domain/enemy_catalog.gd")
const MapGeneratorScript := preload("res://scripts/domain/map_generator.gd")
const FacadeScript := preload("res://scripts/domain/battle_command_facade.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")

const SEEDS: Array[int] = [2026, 4242, 777, 31337, 9]
const LAYOUT_KEYS: Array[String] = ["id", "template_id", "layer", "row", "anchor", "revealed", "next_ids"]


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func _layer_band(pacing: Dictionary, layer: int) -> Array:
	var cfg: Dictionary = pacing["layers"][str(layer)]
	return [int(cfg["enemy_rank_min"]), int(cfg["enemy_rank_max"])]


# ---------------------------------------------------------------------------
# 抽取函数本身
# ---------------------------------------------------------------------------

func test_roll_is_deterministic_for_the_same_seed_and_salt() -> void:
	var cat: Dictionary = catalog()
	var weights: Dictionary = cat["pacing"]["enemy_weights"]
	var first: Array = EnemyCatalogScript.roll_enemy_ids(cat, "beast", 0, 3, weights, 2, 2026, "L1R2N3", [])
	var second: Array = EnemyCatalogScript.roll_enemy_ids(cat, "beast", 0, 3, weights, 2, 2026, "L1R2N3", [])
	assert_eq(first, second, "同种子同 salt 必须逐字节复现")


func test_roll_respects_theme_and_layer_rank_band() -> void:
	var cat: Dictionary = catalog()
	var weights: Dictionary = cat["pacing"]["enemy_weights"]
	var by_id: Dictionary = cat["enemy_by_id"]
	for layer in range(1, 6):
		var band: Array = _layer_band(cat["pacing"], layer)
		for theme in ["beast", "faction"]:
			for salt_index in range(20):
				var rolled: Array = EnemyCatalogScript.roll_enemy_ids(cat, theme, int(band[0]),
						int(band[1]), weights, 1, 2026, "probe_%d_%s_%d" % [layer, theme, salt_index], [])
				assert_eq(rolled.size(), 1)
				var enemy_id := str(rolled[0])
				var definition: Dictionary = by_id[enemy_id]
				assert_eq(str(definition["theme"]), theme,
						"层 %d 抽出的 %s 主题应为 %s" % [layer, enemy_id, theme])
				var rank := int(definition["rank"])
				assert_true(rank >= int(band[0]) and rank <= int(band[1]),
						"层 %d 抽出的 %s rank=%d 应落在 %s" % [layer, enemy_id, rank, str(band)])


func test_roll_never_returns_a_boss_across_every_theme_and_layer() -> void:
	var cat: Dictionary = catalog()
	var weights: Dictionary = cat["pacing"]["enemy_weights"]
	var by_id: Dictionary = cat["enemy_by_id"]
	var bosses: Array[String] = []
	for theme_value in EnemyCatalogScript.THEMES:
		var theme := str(theme_value)
		for layer in range(1, 6):
			var band: Array = _layer_band(cat["pacing"], layer)
			for salt_index in range(40):
				var rolled: Array = EnemyCatalogScript.roll_enemy_ids(cat, theme, int(band[0]),
						int(band[1]), weights, 2, 4242, "boss_probe_%s_%d_%d" % [theme, layer, salt_index], [])
				for enemy_id_value in rolled:
					if str((by_id[str(enemy_id_value)] as Dictionary).get("tier", "")) == "boss":
						bosses.append("%s@L%d" % [str(enemy_id_value), layer])
	assert_eq(bosses, [] as Array[String], "随机抽取绝不能产生 Boss")


func test_roll_does_not_repeat_within_one_node() -> void:
	var cat: Dictionary = catalog()
	var weights: Dictionary = cat["pacing"]["enemy_weights"]
	for salt_index in range(60):
		var rolled: Array = EnemyCatalogScript.roll_enemy_ids(cat, "beast", 0, 5, weights, 3, 31337,
				"unique_%d" % salt_index, [])
		var unique := {}
		for enemy_id_value in rolled:
			unique[str(enemy_id_value)] = true
		assert_eq(unique.size(), rolled.size(), "同节点内不得出现重复敌人：%s" % str(rolled))


func test_roll_falls_back_when_the_pool_is_empty() -> void:
	var cat: Dictionary = catalog()
	var weights: Dictionary = cat["pacing"]["enemy_weights"]
	var rolled: Array = EnemyCatalogScript.roll_enemy_ids(cat, "no_such_theme", 0, 5, weights, 2, 2026,
			"fallback", ["ridge_hound"])
	assert_eq(rolled, ["ridge_hound"], "未知主题必须回退，绝不返回空数组")


## 区间为空时必须先放宽下界——否则某个主题会在深层层被整层抽空。
## neutral 主题在层 5 的区间（rank 3..5）里没有成员，应放宽到 0..5 后仍抽得出。
func test_roll_relaxes_the_floor_instead_of_emptying_a_theme() -> void:
	var cat: Dictionary = catalog()
	var weights: Dictionary = cat["pacing"]["enemy_weights"]
	var band: Array = _layer_band(cat["pacing"], 5)
	var rolled: Array = EnemyCatalogScript.roll_enemy_ids(cat, "neutral", int(band[0]), int(band[1]),
			weights, 1, 2026, "relax", ["should_not_be_used"])
	assert_eq(rolled.size(), 1)
	assert_ne(str(rolled[0]), "should_not_be_used", "区间为空应放宽下界，而不是直接回退")


## tier 权重必须真的生效：common 权重远高于 elite 时，elite 占比应显著低于一半。
func test_tier_weights_favour_common_over_elite() -> void:
	var cat: Dictionary = catalog()
	var weights: Dictionary = cat["pacing"]["enemy_weights"]
	var by_id: Dictionary = cat["enemy_by_id"]
	var elite := 0
	var total := 0
	for salt_index in range(400):
		var rolled: Array = EnemyCatalogScript.roll_enemy_ids(cat, "beast", 0, 5, weights, 1, 2026,
				"weight_%d" % salt_index, [])
		for enemy_id_value in rolled:
			total += 1
			if str((by_id[str(enemy_id_value)] as Dictionary).get("tier", "")) == "elite":
				elite += 1
	assert_true(total > 300, "样本量不足：%d" % total)
	var share := float(elite) / float(total)
	assert_true(share > 0.05 and share < 0.45,
			"elite 占比 %.3f 偏离配置权重 25%% 太远（权重表可能没生效）" % share)


# ---------------------------------------------------------------------------
# 地图接线
# ---------------------------------------------------------------------------

func test_generated_combat_nodes_carry_a_roll_and_anchors_do_not() -> void:
	var cat: Dictionary = catalog()
	for seed_value in SEEDS:
		var route: Array = MapGeneratorScript.build(seed_value, false, cat)
		var rolled := 0
		var missing: Array[String] = []
		for node_value in route:
			var node: Dictionary = node_value
			if str(node.get("type", "")) != "combat":
				continue
			if bool(node.get("anchor", false)):
				assert_false(node.has("enemy_roll"),
						"锚点/关底台不得带随机敌人：%s" % str(node["id"]))
				continue
			rolled += 1
			if not node.has("enemy_roll") or (node["enemy_roll"] as Array).is_empty():
				missing.append(str(node["id"]))
		assert_true(rolled > 0, "seed %d 的图里应当有非锚点战斗节点" % seed_value)
		assert_eq(missing, [] as Array[String], "非锚点战斗节点必须带 enemy_roll")


func test_rolled_enemies_match_the_theme_and_count_of_their_node() -> void:
	var cat: Dictionary = catalog()
	var by_id: Dictionary = cat["enemy_by_id"]
	var problems: Array[String] = []
	for seed_value in SEEDS:
		for node_value in MapGeneratorScript.build(seed_value, false, cat):
			var node: Dictionary = node_value
			if not node.has("enemy_roll"):
				continue
			var rolls: Array = node["enemy_roll"]
			var declared := 1
			if node.has("enemy_kinds"):
				declared = (node["enemy_kinds"] as Array).size()
			if rolls.size() != declared:
				problems.append("%s 数量 %d != %d" % [str(node["id"]), rolls.size(), declared])
			for enemy_id_value in rolls:
				var definition: Dictionary = by_id.get(str(enemy_id_value), {})
				if str(definition.get("theme", "")) != str(node.get("enemy_theme", "")):
					problems.append("%s 主题不符 %s" % [str(node["id"]), str(enemy_id_value)])
	assert_eq(problems, [] as Array[String], str(problems))


## 抽取走独立派生流：**去掉敌人目录后，地图结构必须逐字段一致**。
## 这条守住"加入 E6 不改动既有地图布局与既有种子产出"。
func test_enemy_roll_does_not_perturb_the_map_layout() -> void:
	var cat: Dictionary = catalog()
	var stripped: Dictionary = cat.duplicate(true)
	stripped.erase("enemy_by_id")
	stripped.erase("enemy_ids_by_theme")
	for seed_value in SEEDS:
		var with_roll: Array = MapGeneratorScript.build(seed_value, false, cat)
		var without_roll: Array = MapGeneratorScript.build(seed_value, false, stripped)
		assert_eq(with_roll.size(), without_roll.size(), "seed %d 路线长度被改变" % seed_value)
		for index in range(with_roll.size()):
			var a: Dictionary = with_roll[index]
			var b: Dictionary = without_roll[index]
			for key in LAYOUT_KEYS:
				assert_eq(a.get(key), b.get(key),
						"seed %d 第 %d 个节点的 %s 被 enemy_roll 扰动" % [seed_value, index, key])


# ---------------------------------------------------------------------------
# 战斗侧接线
# ---------------------------------------------------------------------------

func test_facade_prefers_enemy_roll_over_the_template_enemy_kind() -> void:
	var cat: Dictionary = catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var battle: Dictionary = FacadeScript.start({
		"enemy_kind": "ridge_hound",              # 模板自带的敌人应被 enemy_roll 覆盖
		"enemy_roll": ["blood_forest_wolf"],
	}, state, cat)
	assert_eq((battle["enemies"] as Array).size(), 1)
	assert_eq(str((battle["enemies"][0] as Dictionary)["id"]), "blood_forest_wolf")
	assert_eq(str(battle["enemy_kind"]), "blood_forest_wolf",
			"单敌遭遇应同时落顶层 enemy_kind（死亡报告按它取文案）")


func test_facade_falls_back_to_the_template_enemy_without_a_roll() -> void:
	var cat: Dictionary = catalog()
	var state: RunState = RunStateScript.new_run(2026, null)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "ridge_hound"}, state, cat)
	assert_eq(str((battle["enemies"][0] as Dictionary)["id"]), "ridge_hound",
			"没有 enemy_roll（锚点/旧存档）时必须回退到模板敌人")
	# 多敌节点也走回退分支。
	var multi: Dictionary = FacadeScript.start({
		"enemy_kinds": ["ridge_hound", "neutral_stone_wanderer"],
	}, state, cat)
	assert_eq((multi["enemies"] as Array).size(), 2, "回退分支必须保留多敌遭遇")


# ---------------------------------------------------------------------------
# 配置校验
# ---------------------------------------------------------------------------

func test_validation_rejects_a_floor_above_the_ceiling() -> void:
	var cat: Dictionary = catalog()
	(cat["pacing"]["layers"]["3"] as Dictionary)["enemy_rank_min"] = 5
	(cat["pacing"]["layers"]["3"] as Dictionary)["enemy_rank_max"] = 2
	assert_true(_has_hint(ContentCatalogScript.validate(cat), "exceeds enemy_rank_max"))


func test_validation_rejects_a_non_zero_boss_weight() -> void:
	var cat: Dictionary = catalog()
	(cat["pacing"]["enemy_weights"] as Dictionary)["boss"] = 5
	assert_true(_has_hint(ContentCatalogScript.validate(cat), "enemy_weights.boss must be 0"))


func test_validation_rejects_a_missing_enemy_weight_tier() -> void:
	var cat: Dictionary = catalog()
	(cat["pacing"]["enemy_weights"] as Dictionary).erase("elite")
	assert_true(_has_hint(ContentCatalogScript.validate(cat), "enemy_weights missing tier elite"))


func _has_hint(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if str(error).contains(needle):
			return true
	return false
