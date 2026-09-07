extends GutTest


# 2026-09-07 数据驱动守卫（用户裁定：Agent 改数值不触碰业务代码）。
# 钉住两个契约：
#   1. 蛊/敌人/道具/事件的数值配置只存在于 data/ 目录（JSON），scripts 只消费 ID 与读取逻辑；
#   2. 行为参数（撤退成本、二转成本）必须从 data/balance.json 读取，
#      不允许在 scripts/domain 中重新硬编码字面量。
# 文本级扫描为机械守卫；语义正确性由 content_catalog schema 校验 + 聚焦测试承担。


func test_balance_json_carries_behavior_cost_keys() -> void:
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/balance.json"))
	var cfg: Variant = parsed
	assert_true(cfg is Dictionary, "balance.json must parse to an object")
	assert_eq(int((cfg as Dictionary).get("retreat_stone_cost", 0)), 2,
			"retreat_stone_cost must stay in balance.json")
	assert_eq(int((cfg as Dictionary).get("cultivate_rank_two_stone_cost", 0)), 5,
			"cultivate_rank_two_stone_cost must stay in balance.json")


func test_resolver_reads_rank_two_cost_from_balance() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/domain/resolver.gd")
	assert_true(text.contains("cultivate_rank_two_stone_cost"),
			"resolver.gd must read cultivate_rank_two_stone_cost from catalog")
	assert_false(text.contains("state.stone < 5"),
			"resolver.gd must not hardcode the rank-two stone cost")


func test_preview_reads_costs_from_balance() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/domain/action_preview_service.gd")
	assert_true(text.contains("retreat_stone_cost"),
			"action_preview_service.gd must read retreat_stone_cost from catalog")
	assert_true(text.contains("cultivate_rank_two_stone_cost"),
			"action_preview_service.gd must read cultivate_rank_two_stone_cost from catalog")


func test_domain_does_not_bake_entity_data_dictionaries() -> void:
	# 蛊/敌人/道具/事件定义必须来自 data/ 下的 JSON；scripts/domain 中禁止
	# 出现以 id + 数值字段直接构造实体的字典字面量（测试夹具 acceptance_driver
	# 与 presentation 层除外）。这里只扫 scripts/domain，排除测试与验收驱动。
	var offenders: Array[String] = []
	var files: Array[String] = []
	_collect_gd_files("res://scripts/domain", files)
	for full in files:
		var text := FileAccess.get_file_as_string(full)
		if _has_entity_literal(text):
			offenders.append(full)
	assert_eq(offenders, [] as Array[String],
			"entity data literals must live in data/, not scripts/domain: %s" % str(offenders))


func _has_entity_literal(text: String) -> bool:
	# 判定特征：一行内出现实体 id 的字典赋值模式（"id": "gu_/enemy_/offer_/event_"
	# 开头）且带数值字段的冒号赋值（"hp": "damage": "cost": "value":）。
	# 只匹配字面量定义，不匹配错误消息文本、catalog.get / instance.get 读取表达式。
	var lines := text.split("\n")
	for line in lines:
		if not line.contains("\"id\": \""):
			continue
		var has_entity_prefix := false
		for prefix in ["\"gu_", "\"enemy_", "\"offer_", "\"event_"]:
			if line.contains("\"id\": \"" + prefix):
				has_entity_prefix = true
				break
		if not has_entity_prefix:
			continue
		if not (line.contains("\"hp\":") or line.contains("\"damage\":")
				or line.contains("\"cost\":") or line.contains("\"value\":")):
			continue
		if not line.contains(".get(") and not line.contains("get("):
			return true
	return false


func _collect_gd_files(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if name != "." and name != "..":
				_collect_gd_files(path.path_join(name), out)
		elif name.get_extension() == "gd":
			out.append(path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
