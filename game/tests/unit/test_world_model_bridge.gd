extends GutTest


# 世界模型一致性门禁（2026-09-17）。
#
# 目的：`world-model/data/` 是从生产 `data/` 派生的规范视图（生成器
# world-model/tools/build_world_model.py）。上游被并行改动后两边会静默漂移
# （RISK-13），Python 侧有 tools/check_upstream_drift.py 兜底；本门禁是 **Godot 侧
# 的同一条底线**：让项目自己证明"我读得到 world-model，且它和生产数据一致"。
#
# 本门禁只读两侧、不改任何状态，也不参与运行时（WorldModelBridge 不是数据源；
# 游戏仍从 data/ 读定义）。
#
# 负控（证明门禁不是空转）：把下面的 SABOTAGE 临时置为 true，_wm_gu() 会把一只蛊的
# value 改坏、_wm_offer_by_id() 会删掉一条报价，门禁必须因此失败。实测两种状态的
# 输出写在 docs/superpowers/reports/2026-09-17-world-model-bridge-gate.md。
const SABOTAGE := false

const BRIDGE_SABOTAGE_GU_ID := "bear_strength_gu"
const BRIDGE_SABOTAGE_OFFER_ID := "purchase_blood_droplet"

var catalog: Dictionary


# 本门禁只读、每个用例都不改状态，所以生产数据只装一次（全量 unit 套件里有 9 个
# 用例要读 gu/enemies/recipes/shops/balance，逐个 before_each 装会白白拖慢回归）。
func before_all() -> void:
	catalog = ContentCatalog.load_all()


# --- 接入层本身 -----------------------------------------------------------

func test_bridge_is_wired_to_world_model_data() -> void:
	assert_true(WorldModelBridge.is_available(),
			"world-model/data/*.json 未就位，缺失：%s" % str(WorldModelBridge.missing_docs()))
	assert_eq(WorldModelBridge.missing_docs(), [] as Array[String])
	assert_ne(WorldModelBridge.world_model_version(), "", "world-model 版本号不得为空")
	assert_ne(WorldModelBridge.generated_at(), "", "world-model 生成时间不得为空")


func test_gate_is_not_left_sabotaged() -> void:
	# SABOTAGE 只用于"门禁必须会失败"的负控验证，不得随提交开启。
	assert_false(SABOTAGE, "SABOTAGE 负控开关被打开：门禁当前处于人为损坏状态")


# --- 蛊 -------------------------------------------------------------------

func test_gu_table_matches_production_gu() -> void:
	var upstream: Array = catalog["gu"]
	var mirror := _wm_gu()
	assert_gt(upstream.size(), 0, "生产蛊表读到空数组：本用例会退化成恒真")
	assert_eq(mirror.size(), upstream.size(), "蛊条数：世界模型 vs 生产 data/gu.json")

	var mismatches: Array[String] = []
	for gu in upstream:
		var gu_id := str(gu["id"])
		if not mirror.has(gu_id):
			mismatches.append("世界模型缺少蛊 %s" % gu_id)
			continue
		var entry: Dictionary = mirror[gu_id]
		for field in ["rank", "value"]:
			if int(entry.get(field, -1)) != int(gu.get(field, -2)):
				mismatches.append("gu %s.%s: 生产=%s 世界模型=%s"
						% [gu_id, field, str(gu.get(field)), str(entry.get(field))])
		for field in ["school", "role"]:
			if str(entry.get(field, "")) != str(gu.get(field, "")):
				mismatches.append("gu %s.%s: 生产=%s 世界模型=%s"
						% [gu_id, field, str(gu.get(field)), str(entry.get(field))])
	assert_eq(mismatches, [] as Array[String], "蛊逐只 rank/value/school/role 应与生产一致")


# --- 敌人 -----------------------------------------------------------------

func test_enemy_roster_matches_production_enemies() -> void:
	var upstream: Array = catalog["enemies"]
	var mirror := WorldModelBridge.enemy_by_id()
	assert_gt(upstream.size(), 0, "生产敌人表读到空数组：本用例会退化成恒真")
	assert_eq(mirror.size(), upstream.size(), "敌人条数：世界模型 vs 生产 data/enemies.json")

	var mismatches: Array[String] = []
	for enemy in upstream:
		var enemy_id := str(enemy["id"])
		if not mirror.has(enemy_id):
			mismatches.append("世界模型缺少敌人 %s" % enemy_id)
			continue
		var entry: Dictionary = mirror[enemy_id]
		for field in ["hp", "rank", "tier"]:
			var want: Variant = enemy.get(field)
			var got: Variant = entry.get(field)
			if field != "tier":
				want = int(want)
				got = int(got)
			if got != want:
				mismatches.append("enemy %s.%s: 生产=%s 世界模型=%s"
						% [enemy_id, field, str(enemy.get(field)), str(entry.get(field))])
	assert_eq(mismatches, [] as Array[String], "敌人逐条 hp/rank/tier 应与生产一致")


# --- 配方边 ---------------------------------------------------------------

func test_recipe_edges_match_production_recipes() -> void:
	var upstream_ids: Array[String] = []
	for recipe in catalog["refinement_recipes"]:
		if not str(recipe.get("output_gu_id", "")).is_empty():
			upstream_ids.append(str(recipe["id"]))
	upstream_ids.sort()

	var mirror := WorldModelBridge.recipe_edge_by_id()
	var mirror_ids: Array[String] = []
	for recipe_id in mirror:
		mirror_ids.append(str(recipe_id))
	mirror_ids.sort()

	assert_eq(mirror_ids, upstream_ids, "带产物的配方边集合应与生产 data/refinement_recipes.json 一致")
	assert_gt(mirror.size(), 0, "配方边不应为空（空表会让本断言变成恒真）")


# --- 商店报价 -------------------------------------------------------------

func test_shop_offers_match_production_shops() -> void:
	var upstream := {}
	for offer in catalog["shop_offers"]:
		upstream[str(offer["id"])] = offer
	var mirror := _wm_offer_by_id()

	assert_gt(upstream.size(), 0, "生产报价表读到空数组：本用例会退化成恒真")
	assert_eq(mirror.size(), upstream.size(), "商店报价条数：世界模型 vs 生产 data/shops.json")
	assert_eq(_sorted_ids(mirror), _sorted_ids(upstream), "商店报价 id 集合应与生产一致")

	var mismatches: Array[String] = []
	for offer_id in upstream:
		if not mirror.has(offer_id):
			continue
		var want: Dictionary = upstream[offer_id]
		var got: Dictionary = mirror[offer_id]
		for field in ["kind", "tier", "stone_cost", "npc_only"]:
			if _norm_offer(got, field) != _norm_offer(want, field):
				mismatches.append("报价 %s.%s: 生产=%s 世界模型=%s"
						% [offer_id, field, str(want.get(field)), str(got.get(field))])
	assert_eq(mismatches, [] as Array[String],
			"报价逐条 kind/tier/stone_cost/npc_only 应与生产一致（npc_only 是货阶分层豁免判据）")


# --- 价值锚 ---------------------------------------------------------------

func test_value_anchors_match_production_balance() -> void:
	var upstream_anchors: Dictionary = catalog["balance"].get("gu_value_by_rank", {})
	var mirror_anchors := WorldModelBridge.gu_value_by_rank()
	assert_eq(_flat_map(mirror_anchors), _flat_map(upstream_anchors),
			"同转价值锚应与生产 data/balance.json 一致")


func test_value_anchor_exceptions_are_consistent_with_production_gu() -> void:
	var anchors := WorldModelBridge.gu_value_by_rank()
	var exceptions := WorldModelBridge.gu_value_anchor_exceptions()
	assert_gt(exceptions.size(), 0, "价值锚例外表为空会让校验器放行任意偏离，必须非空")

	var problems: Array[String] = []
	for gu in catalog["gu"]:
		var gu_id := str(gu["id"])
		var rank := int(gu["rank"])
		if gu_id.begins_with("test_") or rank > 9:
			continue  # 调试/越界实体不进正式内容池，与校验器同口径
		var rank_key := str(rank)
		if not anchors.has(rank_key):
			problems.append("蛊 %s 的 %d 转不在锚表内" % [gu_id, rank])
			continue
		var expected := int(anchors[rank_key])
		var actual := int(gu["value"])
		var listed := exceptions.has(gu_id)
		if actual != expected and not listed:
			problems.append("蛊 %s 的 value %d 偏离 %d 转锚值 %d，且未登记为例外"
					% [gu_id, actual, rank, expected])
		elif actual == expected and listed:
			problems.append("蛊 %s 已登记为价值锚例外，但其 value 等于锚值 %d（应撤登记）" % [gu_id, expected])
	assert_eq(problems, [] as Array[String], "价值锚例外表应与生产蛊表一一对上")


# --- 辅助 -----------------------------------------------------------------

## 世界模型侧的蛊表镜像。负控打开时故意改坏一只蛊的 value。
func _wm_gu() -> Dictionary:
	var mirror := WorldModelBridge.gu_by_id()
	if SABOTAGE and mirror.has(BRIDGE_SABOTAGE_GU_ID):
		(mirror[BRIDGE_SABOTAGE_GU_ID] as Dictionary)["value"] = -999
	return mirror


## 世界模型侧的报价镜像。负控打开时故意删掉一条报价。
func _wm_offer_by_id() -> Dictionary:
	var mirror := WorldModelBridge.shop_offer_by_id()
	if SABOTAGE:
		mirror.erase(BRIDGE_SABOTAGE_OFFER_ID)
	return mirror


func _sorted_ids(index: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for key in index:
		ids.append(str(key))
	ids.sort()
	return ids


## 报价字段归一：上游缺省字段与缺省值类型不同（缺 stone_cost = null，缺 npc_only = 无键），
## 统一到同一口径再比，避免把"缺省"误报成"不一致"。
func _norm_offer(offer: Dictionary, field: String) -> Variant:
	match field:
		"tier":
			return int(offer.get("tier", 0))
		"npc_only":
			return bool(offer.get("npc_only", false))
		_:
			return offer.get(field)


## 字典扁平化为可排序的字符串数组，便于 assert_eq 给出可读差异。
func _flat_map(source: Dictionary) -> Array[String]:
	var flat: Array[String] = []
	for key in source:
		flat.append("%s=%s" % [str(key), str(source[key])])
	flat.sort()
	return flat
