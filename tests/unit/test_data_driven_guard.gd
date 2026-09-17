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
	# 一转一突破（2026-09-15）：2→5 各档成本全部落 JSON。
	assert_eq(int((cfg as Dictionary).get("cultivate_rank_three_stone_cost", 0)), 12,
			"cultivate_rank_three_stone_cost must stay in balance.json")
	assert_eq(int((cfg as Dictionary).get("cultivate_rank_four_stone_cost", 0)), 20,
			"cultivate_rank_four_stone_cost must stay in balance.json")
	assert_eq(int((cfg as Dictionary).get("cultivate_rank_five_stone_cost", 0)), 30,
			"cultivate_rank_five_stone_cost must stay in balance.json")


func test_resolver_reads_rank_two_cost_from_balance() -> void:
	# W11 A4 (2026-09-10): cultivate_rank_two moved to refine_command_rules.gd;
	# the data-driven contract now scans both the router and the new module.
	var text := FileAccess.get_file_as_string("res://scripts/domain/resolver.gd") \
			+ FileAccess.get_file_as_string("res://scripts/domain/refine_command_rules.gd")
	assert_true(text.contains("cultivate_rank_two_stone_cost"),
			"domain must read cultivate_rank_two_stone_cost from catalog")
	assert_false(text.contains("state.stone < 5"),
			"domain must not hardcode the rank-two stone cost")


func test_preview_reads_costs_from_balance() -> void:
	# F-01（2026-09-17）：撤离成本与门禁收归 BattleCommandFacade.retreat_gate 单一来源，
	# 预览只转呈结论——守卫意图（成本键必须从 balance 读、不得出现第二份真值）不变，
	# 改为扫描「唯一来源读键」+「预览不得自行读该键」。
	var facade_text := FileAccess.get_file_as_string("res://scripts/domain/battle_command_facade.gd")
	assert_true(facade_text.contains("retreat_stone_cost"),
			"battle_command_facade.gd must read retreat_stone_cost from catalog")
	assert_true(facade_text.contains('"balance"'),
			"the retreat cost must be read through catalog.balance")
	var text := FileAccess.get_file_as_string("res://scripts/domain/action_preview_service.gd")
	assert_true(text.contains("BattleCommandFacadeScript.retreat_gate"),
			"action_preview_service.gd must take the retreat gate from its single source")
	assert_false(text.contains("retreat_stone_cost"),
			"the preview must not re-read the retreat cost key (single source = facade)")
	# 一转一突破（2026-09-15）：升转档位与成本的**单一来源**移到
	# RefineCommandRules（`cultivate_stone_cost` 读 balance 的
	# cultivate_rank_<n>_stone_cost，其中二转键仍为 cultivate_rank_two_stone_cost）。
	# 守卫意图不变——预览层不得自行硬编码/重复读取成本键——故改为：
	# ① 必须经单一来源取成本；② 禁止在本文件重新散落档位键（防止两份真值）。
	assert_true(text.contains("cultivate_stone_cost"),
			"action_preview_service.gd must read the cultivation cost via RefineCommandRules")
	assert_false(text.contains("cultivate_rank_two_stone_cost"),
			"cost keys must live only in RefineCommandRules.CULTIVATE_COST_BALANCE_KEYS")


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
