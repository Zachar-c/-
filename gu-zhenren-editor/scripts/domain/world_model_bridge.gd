class_name WorldModelBridge
extends RefCounted

## world-model 只读接入层（2026-09-17）。
##
## world-model/ 是从上游 `data/` 派生的**规范视图**（生成器：
## world-model/tools/build_world_model.py，纯 Python 标准库，退出码即结论）。
## 本层只做三件事：把 world-model/data/*.json 读进 Godot、暴露只读访问器、
## 供一致性门禁（tests/unit/test_world_model_bridge.gd）比对两边。
##
## 边界（重要）：
## - **不是运行时数据源**。游戏仍从 `data/` 读定义（走 ContentCatalog），
##   本层不得被战斗/经济/地图/存档任一领域路径调用；两表不一致时由门禁报警，
##   而不是由本层在运行时替选数据。
## - 只读：不写回、不产生状态、不参与随机与结算。
## - 未纳入导出（export_presets.cfg 的 include_filter 不含本目录）：world-model
##   是开发/校验侧产物，Release 包不携带（AGENTS.md「Release 不包含语料/测试/
##   受排除资源」）。因此导出包里 is_available() 会是 false，调用方必须先问
##   is_available()，不得假定文件存在。
##
## 数据形状（均为世界模型统一 envelope：{entity_type, count, entities[]}）：
##   蛊/流派/事件/…：data/<doc>.json → entities[]
##   敌人：regions.json 的 macro_region.entities[*].enemy_roster
##   配方边：gu.json 每条蛊的 refine_as_output[]（含 recipe_id/输入/材料/代价）
##   价值锚：balance.json entities[0].economy.gu_value_by_rank(+_exceptions)

const DATA_DIR := "res://world-model/data/"
## 世界模型的全部实体文档；缺任何一个都视为"未接线"。
const DOC_NAMES: Array[String] = [
	"realms", "paths", "gu", "economy", "factions", "regions", "events", "loot", "balance", "manifest",
]


## 全部实体文档是否就位（只看文件存在性，不解析）。
static func is_available() -> bool:
	return missing_docs().is_empty()


## 缺失的实体文档名（用于把"没接线"和"接线了但内容不一致"区分开）。
static func missing_docs() -> Array[String]:
	var missing: Array[String] = []
	for doc_name in DOC_NAMES:
		if not FileAccess.file_exists(DATA_DIR + doc_name + ".json"):
			missing.append(doc_name)
	return missing


## 读取单个实体文档；文件缺失或 JSON 不合法时返回 {}（调用方用 is_available() 判前置）。
static func load_doc(doc_name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR + doc_name + ".json"))
	if parsed is Dictionary:
		return parsed
	return {}


## 文档的 entities 数组；缺失时返回空数组。
static func entities_of(doc_name: String) -> Array:
	var entities: Variant = load_doc(doc_name).get("entities")
	if entities is Array:
		return entities
	return []


static func world_model_version() -> String:
	return str(load_doc("manifest").get("world_model_version", ""))


static func generated_at() -> String:
	return str(load_doc("manifest").get("generated_at", ""))


# --- 蛊 -------------------------------------------------------------------

static func gu_entities() -> Array:
	return entities_of("gu")


static func gu_by_id() -> Dictionary:
	return _index_by_id(gu_entities())


# --- 敌人（世界模型把敌人挂在南疆 macro_region 的 enemy_roster 上）---------

static func enemy_entities() -> Array:
	var roster: Array = []
	for region in entities_of("regions"):
		if str((region as Dictionary).get("entity_kind", "")) != "macro_region":
			continue
		var entries: Variant = (region as Dictionary).get("enemy_roster")
		if entries is Array:
			roster.append_array(entries)
	return roster


static func enemy_by_id() -> Dictionary:
	return _index_by_id(enemy_entities())


# --- 配方边（从蛊表反向展开，扁平化为"一条边一个配方"）-------------------

static func recipe_edges() -> Array[Dictionary]:
	var by_recipe := {}
	for gu in gu_entities():
		for edge in (gu as Dictionary).get("refine_as_output", []):
			var recipe_id := str((edge as Dictionary).get("recipe_id", ""))
			if not recipe_id.is_empty():
				by_recipe[recipe_id] = edge
	var ids: Array = by_recipe.keys()
	ids.sort()
	var edges: Array[Dictionary] = []
	for recipe_id in ids:
		edges.append(by_recipe[recipe_id])
	return edges


static func recipe_edge_by_id() -> Dictionary:
	var indexed := {}
	for edge in recipe_edges():
		indexed[str(edge.get("recipe_id", ""))] = edge
	return indexed


# --- 商店报价 -------------------------------------------------------------

static func shop_offers() -> Array:
	for economy in entities_of("economy"):
		var offers: Variant = (economy as Dictionary).get("shop_offers")
		if offers is Array:
			return offers
	return []


static func shop_offer_by_id() -> Dictionary:
	return _index_by_id(shop_offers())


# --- 价值锚 ---------------------------------------------------------------

static func _balance_economy() -> Dictionary:
	var entities := entities_of("balance")
	if entities.is_empty():
		return {}
	var economy: Variant = (entities[0] as Dictionary).get("economy")
	if economy is Dictionary:
		return economy
	return {}


## 普通蛊的同转基准价值锚（rank 字符串键 → 价值）。
static func gu_value_by_rank() -> Dictionary:
	return _balance_economy().get("gu_value_by_rank", {})


## 允许高于同转锚值的策展蛊登记表（id → 策展说明）。
static func gu_value_anchor_exceptions() -> Dictionary:
	return _balance_economy().get("gu_value_anchor_exceptions", {})


# --- 内部 -----------------------------------------------------------------

static func _index_by_id(entries: Array) -> Dictionary:
	var indexed := {}
	for entry in entries:
		if entry is Dictionary and (entry as Dictionary).has("id"):
			indexed[str((entry as Dictionary)["id"])] = entry
	return indexed
