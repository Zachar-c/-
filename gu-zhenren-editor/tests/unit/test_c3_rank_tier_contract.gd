extends GutTest


## C3 转阶落表（2026-09-05 主计划工单）红门禁：
##   - rank 语义为 1..5 转（5 转对 L1--L5 地图层）；content_catalog 校验 1..5。
##   - test-only 蛊（test_slay_gu 十转杀蛊，low_rank_exception/tags:test）豁免上界，
##     供五层天梯一键验收夹具使用（test_v1_five_layer_clear / final_chapter）。
##   - rarity（common/rare/epic/legendary）与转阶解耦：任一稀有度可出现于任意转，
##     数据允许 epic 1 转、common 2 转等非单调组合。
##   - Boss 量级挂钩：中央倍率 data/v1_battle.json 的 boss_layer_mult / stage_base
##     必须覆盖 L1..L5 全部五层键（one..five，与 battle_command_facade.BOSS_LAYER_IDS
##     消费映射一致），校验拒绝缺失。


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const SLAY_GU_ID := "test_slay_gu"


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_real_catalog_validate_is_green() -> void:
	var errors: Array[String] = ContentCatalogScript.validate(catalog)
	assert_eq(errors, [], "目录校验绿（C3 基线）")


func test_rank_above_cap_is_rejected_unless_exempt() -> void:
	# 取一只普通 1 转蛊抬到 6 转：目录校验必须拒绝（rank 语义上界=5）。
	var gu_by_id: Dictionary = catalog["gu_by_id"]
	var probe: Dictionary = gu_by_id["small_light_gu"]
	probe["rank"] = 6
	var errors: Array[String] = ContentCatalogScript.validate(catalog)
	var hit := false
	for error in errors:
		if str(error).contains("rank") and str(error).contains("6"):
			hit = true
	assert_true(hit, "rank 6 普通蛊须被目录校验拒绝")
	# 同一只蛊若带 test 豁免，则不得再报 rank 越界。
	probe["low_rank_exception"] = true
	var exempt_errors: Array[String] = ContentCatalogScript.validate(catalog)
	var exempt_hit := false
	for error in exempt_errors:
		if str(error).contains("small_light_gu") and str(error).contains("rank"):
			exempt_hit = true
	assert_false(exempt_hit, "low_rank_exception 蛊豁免 rank 越界")


func test_rank_exemption_allows_test_slay_gu() -> void:
	# 十转杀蛊（rank 10）是五层天梯验收的刻意图腾，不得因 rank 越界被拒。
	var errors: Array[String] = ContentCatalogScript.validate(catalog)
	var hits: Array[String] = []
	for error in errors:
		if str(error).contains(SLAY_GU_ID) and str(error).contains("rank"):
			hits.append(str(error))
	assert_eq(hits, [], "test_slay_gu 不得报 rank 越界（实际：%s）" % str(hits))


func test_rarity_and_rank_are_decoupled_in_data() -> void:
	# rarity 独立于转阶：数据同时存在 epic·1转 与 common·2转 的非单调组合，
	# 证明 rarity（掉落/价值层次）与 rank（催动门禁/成长）语义分离。
	# 注意：项目数据以 str_to_var 加载，JSON 数字一律为 float（rank 1.0）；
	# 键构造须先 int() 归一，与 rank 语义（整数转数）对齐。
	var combos := {}
	for gu in catalog["gu"]:
		combos["%s|%s" % [gu["rarity"], int(gu["rank"])]] = true
	assert_true(combos.has("epic|1"), "epic·1转 存在（解耦证据）")
	assert_true(combos.has("common|2"), "common·2转 存在（解耦证据）")


func test_boss_layer_multipliers_and_stage_cover_all_five_layers() -> void:
	# Boss 量级挂钩核对：中央倍率与 L1..L5 一一对应（one..five），逐层为正。
	var battle: Dictionary = catalog["v1_battle"]
	var mults: Dictionary = battle.get("boss_layer_mult", {})
	var stage: Dictionary = battle.get("stage_base", {})
	for layer_key in ["one", "two", "three", "four", "five"]:
		assert_true(mults.has(layer_key), "boss_layer_mult 缺第 %s 层" % layer_key)
		assert_true(stage.has(layer_key), "stage_base 缺第 %s 层" % layer_key)
		if mults.has(layer_key):
			var layer_config: Dictionary = mults[layer_key]
			assert_gte(float(layer_config.get("hp", 0.0)), 1.0, "hp 倍率 ≥ 1.0")
			assert_gte(float(layer_config.get("damage", 0.0)), 1.0, "damage 倍率 ≥ 1.0")
		if stage.has(layer_key):
			assert_gte(int(stage[layer_key]), 1, "stage_base 为正")
