extends GutTest
## R9：关底 Boss 随机化（2026-09-16）。
## 覆盖：池成员全部可达、确定性、相邻层不重复、终局固定、无 catalog 回退。
## 规格：docs/superpowers/reports/2026-09-16-roguelike-audit-and-directions.md §3.2
## 本文件是 boss 池的 GUT 覆盖；历史一次性探针已于 2026-09-20 删除。


const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")

const ALL_BOSSES: Array[String] = [
	"crag_serpent_matriarch",
	"marrow_gu_adept",
	"thunder_crown_sovereign",
	"clan_patriarch",
	"blood_vein_bishop",
	"blue_fur_jiangshi",
	"miasma_vein_lord",
]

var _catalog: Dictionary = {}


func before_all() -> void:
	_catalog = ContentCatalogScript.load_all()


static func _boss_by_layer(route: Array) -> Dictionary:
	var by_layer := {}
	for node_value in route:
		var node: Dictionary = node_value
		if int(node.get("layer_boss", 0)) > 0:
			by_layer[int(node.get("layer", 0))] = str(node.get("enemy_kind", ""))
	return by_layer


func test_every_boss_is_reachable() -> void:
	# 改动前 clan_patriarch / blue_fur_jiangshi 从未出现在任何关底台。
	var seen := {}
	for seed_value in range(1, 21):
		for node_value in MapGeneratorScript.build(seed_value, false, _catalog):
			var node: Dictionary = node_value
			if int(node.get("layer_boss", 0)) > 0:
				seen[str(node.get("enemy_kind", ""))] = true
	for boss_id in ALL_BOSSES:
		assert_true(seen.has(boss_id), "boss %s must appear on some layer-boss stand" % boss_id)


func test_same_seed_rolls_same_bosses() -> void:
	var a := MapGeneratorScript.build(20260909, false, _catalog)
	var b := MapGeneratorScript.build(20260909, false, _catalog)
	assert_eq(a, b, "same seed must yield an identical route including rolled bosses")


func test_no_boss_repeats_on_adjacent_layers() -> void:
	for seed_value in range(1, 21):
		var by_layer := _boss_by_layer(MapGeneratorScript.build(seed_value, false, _catalog))
		for layer in [1, 2, 3, 4]:
			assert_true(by_layer.has(layer) and by_layer.has(layer + 1),
					"seed %d must have a boss on L%d and L%d" % [seed_value, layer, layer + 1])
			assert_ne(str(by_layer[layer]), str(by_layer[layer + 1]),
					"seed %d: L%d and L%d rolled the same boss" % [seed_value, layer, layer + 1])


func test_final_boss_stays_fixed() -> void:
	# final_boss_stand 与「瘴脉尽头、蛊主把守升仙窗口」叙事绑定，本轮不随机化。
	for seed_value in [1, 2, 3, 7, 42, 777]:
		for node_value in MapGeneratorScript.build(seed_value, false, _catalog):
			var node: Dictionary = node_value
			if str(node.get("template_id", "")) == "final_boss_stand":
				assert_eq(str(node.get("enemy_kind", "")), "miasma_vein_lord",
						"seed %d final boss must stay miasma_vein_lord" % seed_value)


func test_without_catalog_falls_back_to_template_boss() -> void:
	# 无 catalog 时 `_roll_boss_for` 返回空字典 ⇒ 关底台保持模板自带的 enemy_kind
	# （回退即"行为同今天"）。这也证明该功能对既有裸调路径零影响。
	for node_value in MapGeneratorScript.build(20260909, false):
		var node: Dictionary = node_value
		if str(node.get("template_id", "")) == "layer_boss_stand_1":
			assert_eq(str(node.get("enemy_kind", "")), "crag_serpent_matriarch",
					"no-catalog build must keep the template boss")
