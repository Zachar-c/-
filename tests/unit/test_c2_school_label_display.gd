extends GutTest


# C2 阶段二验收（2026-09-05）：gu.json 流派落库后，展示层必须透出流派。
# 契约：
#   - 图鉴快照的每只蛊带 school（id）与 school_name（中文流派名，取自 schools.json）。
#   - 战斗手牌（蛊卡）快照带 school_label（中文流派名）；拳脚等非蛊行动不带。
#   - 大厅图鉴屏渲染「流派：<中文名>」，不再是英文 id。


const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


func _gu_entry(codex: Dictionary, gu_id: String) -> Dictionary:
	for e in codex["gu"]:
		if str(e.get("id", "")) == gu_id:
			return e
	return {}


func test_codex_gu_entries_expose_chinese_school_name() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	controller.start_new_run(2026)
	# 大厅屏快照屏名为 Title（SCREEN_PATHS: Title → hall_screen.tscn）。
	var codex: Dictionary = controller._snapshot_for("Title")["codex"]

	var light := _gu_entry(codex, "small_light_gu")
	assert_eq(str(light.get("school", "")), "light", "图鉴条目带流派 id")
	assert_eq(str(light.get("school_name", "")), "光道", "图鉴条目带中文流派名")

	var earth := _gu_entry(codex, "stone_shell_gu")
	assert_eq(str(earth.get("school", "")), "earth")
	assert_eq(str(earth.get("school_name", "")), "土道")


func test_battle_hand_gu_cards_carry_school_label() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	controller.start_new_run(101)
	controller.current_node = {"id": "beast_swarm_pass", "type": "combat", "enemy_kind": "ridge_hound"}
	controller._start_battle()

	# 以领域战斗槽回推每张蛊卡的流派期望，避免中文名断言脆断。
	var cat: Dictionary = ContentCatalogScript.load_all()
	var gu_by_id: Dictionary = cat["gu_by_id"]
	var schools: Dictionary = cat["schools"]
	var expected_by_instance := {}
	for slot in controller.current_battle.get("gu_slots", []):
		var def_id := str((slot as Dictionary).get("definition_id", ""))
		var school_id := str(gu_by_id.get(def_id, {}).get("school", ""))
		expected_by_instance[str((slot as Dictionary).get("instance_id", ""))] = \
				str(schools.get(school_id, {}).get("name", school_id))

	var snapshot: Dictionary = controller._snapshot_for("Battle")
	var gu_cards := 0
	for card in snapshot["hand"]:
		var card_id := str(card.get("id", ""))
		if card_id.begins_with("gu."):
			gu_cards += 1
			var expected := str(expected_by_instance.get(card_id.trim_prefix("gu."), ""))
			assert_false(expected.is_empty(), "手牌蛊卡需可回推流派")
			assert_eq(str(card.get("school_label", "")), expected,
					"蛊卡 %s 流派透出" % str(card.get("name", "")))
		elif card_id == "basic_attack":
			assert_eq(str(card.get("school_label", "")), "", "拳脚不带流派")
	assert_gt(gu_cards, 0, "战斗手牌至少含一只蛊卡")


func test_school_names_match_schools_json_v2() -> void:
	var cat: Dictionary = ContentCatalogScript.load_all()
	for school_id in ContentCatalogScript.SCHOOL_IDS:
		var entry: Dictionary = cat["schools"][school_id]
		assert_false(str(entry.get("name", "")).is_empty(),
				"流派 %s 需中文名供展示透出" % school_id)
