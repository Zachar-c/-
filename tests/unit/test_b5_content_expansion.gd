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
	# 802 重建：gu.json 802 蛊（20 道×40）+ 现存卡蓝图 15 张。
	assert_eq(cat["cards"].size(), 15)
	assert_eq(cat["gu"].size(), 802)


func test_fresh_v1_battle_preview_offers_actions() -> void:
	var cat: Dictionary = catalog()
	var state := make_state()
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "neutral_stone_wanderer"}, state, cat)
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_battle_actions(battle, state, cat)
	assert_true(cards.size() > 0)
