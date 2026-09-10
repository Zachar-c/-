extends "res://addons/gut/test.gd"


# B5 content expansion survivors after the V1 battle convergence (B1 bucket C):
# the two novel-sourced enemies validate and start V1 battles, the greedy
# wanderer node still faces thunder_crown_wolf, the 802 catalog counts hold,
# and a fresh battle offers preview cards. The card-era effect legs (reveal /
# delay_progress / intel_bonus / temp damage) ran on the legacy engine and
# died with it — V1 resolves those through slot effects instead.


const FacadeScript := preload("res://scripts/domain/battle_command_facade.gd")
const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")
const ActionPreviewServiceScript := preload("res://scripts/domain/action_preview_service.gd")
const EnemyCatalogScript := preload("res://scripts/domain/enemy_catalog.gd")


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func make_state(run_seed: int = 2026) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func test_new_enemies_pass_validation_and_start_v1_battles() -> void:
	var cat: Dictionary = catalog()
	assert_eq(ContentCatalogScript.validate(cat), [])
	for enemy_id in ["iron_hide_boar", "thunder_crown_wolf"]:
		var enemy: Dictionary = cat["enemy_by_id"][enemy_id]
		assert_true(cat["enemy_by_id"].has(enemy_id))
		assert_true(int(enemy["hp"]) > 0)
		assert_true(int(enemy["intent"].get("speed", 0)) >= 0)
		assert_true((enemy.get("clues", []) as Array).size() >= 2)
		var battle: Dictionary = FacadeScript.start(
			{"enemy_kind": enemy_id}, make_state(), cat)
		assert_eq(str(battle["enemy_kind"]), enemy_id)


func test_greedy_wanderer_now_faces_thunder_crown_wolf() -> void:
	var cat: Dictionary = catalog()
	var matched := false
	for node in cat["nodes"]:
		if str(node.get("id", "")) == "greedy_wanderer":
			matched = true
			assert_eq(str(node.get("enemy_kind", "")), "thunder_crown_wolf")
	assert_true(matched, "greedy_wanderer node missing from catalog")


func test_catalog_counts_after_802_rebuild() -> void:
	var cat: Dictionary = catalog()
	# 802 重建：gu.json 802 蛊（20 道×40）。B2 卡层退役后不再有卡蓝图。
	assert_eq(cat["gu"].size(), 802)


func test_fresh_v1_battle_preview_offers_actions() -> void:
	var cat: Dictionary = catalog()
	var state := make_state()
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "neutral_stone_wanderer"}, state, cat)
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_battle_actions(battle, state, cat)
	assert_true(cards.size() > 0)


# ---------------------------------------------------------------------------
# 敌人池契约（2026-09-10 从原著提取扩池时固化）
# ---------------------------------------------------------------------------

## 线索是玩家出手前的敌情预警载体。旧版只抽查两条敌人，导致另外 6 条
## 只有 1 条线索的敌人长期漏网；这里改为遍历**全部**敌人。
func test_every_enemy_declares_at_least_two_clues() -> void:
	var cat: Dictionary = catalog()
	var thin: Array[String] = []
	for entry_value in cat["enemies"]:
		var entry: Dictionary = entry_value
		if (entry.get("clues", []) as Array).size() < 2:
			thin.append(str(entry.get("id", "")))
	assert_eq(thin, [] as Array[String], "每个敌人至少需要 2 条线索（clues）")


## 每个主题都必须有**非 boss** 成员，否则该主题的按层抽取池取不到普通遭遇。
func test_every_theme_has_a_non_boss_enemy_for_pool_draw() -> void:
	var cat: Dictionary = catalog()
	var ids_by_theme: Dictionary = cat["enemy_ids_by_theme"]
	for theme_value in EnemyCatalogScript.THEMES:
		var theme := str(theme_value)
		var pool: Array = ids_by_theme[theme]
		assert_true(pool.size() > 0, "主题 %s 没有任何敌人" % theme)
		var has_non_boss := false
		for enemy_id_value in pool:
			var definition: Dictionary = cat["enemy_by_id"][str(enemy_id_value)]
			if str(definition.get("tier", "")) != "boss":
				has_non_boss = true
				break
		assert_true(has_non_boss, "主题 %s 只有 boss，按层抽取拿不到普通遭遇" % theme)


## 每个敌人必须能起一场 V1 战斗（意图/反应/阶段数据自洽）。
func test_every_enemy_starts_a_v1_battle() -> void:
	var cat: Dictionary = catalog()
	var state := make_state()
	var broken: Array[String] = []
	for entry_value in cat["enemies"]:
		var enemy_id := str((entry_value as Dictionary).get("id", ""))
		var battle: Dictionary = FacadeScript.start({"enemy_kind": enemy_id}, state, cat)
		if (battle.get("enemies", []) as Array).is_empty():
			broken.append(enemy_id)
	assert_eq(broken, [] as Array[String], "这些敌人起不了战斗")
