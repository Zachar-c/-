extends GutTest


func test_display_text_translates_known_ids_without_leaking_internal_ids() -> void:
	assert_eq(DisplayText.node("village_short_work"), "山村短工")
	assert_eq(DisplayText.type("market"), "市集")
	assert_eq(DisplayText.action("buy_information"), "购买情报")
	assert_eq(DisplayText.gu("small_light_gu"), "小光蛊")
	assert_eq(DisplayText.inheritance("moonlit_trace"), "月下寻迹")
	assert_eq(DisplayText.enemy("beast_swarm"), "兽群")
	assert_eq(DisplayText.outcome("risky_success"), "险中功成")


func test_display_text_uses_chinese_fallbacks_for_unknown_ids() -> void:
	assert_eq(DisplayText.node("unlisted_node"), "未知地点")
	assert_eq(DisplayText.fact("unlisted_fact"), "未知情报")
	assert_eq(DisplayText.result({"ok": false, "reason": "unlisted_reason"}), "行动未能完成。")


func test_result_summary_is_chinese_and_never_serializes_dictionary() -> void:
	var summary := DisplayText.result({"ok": true, "npc_reaction": "caution"})
	assert_eq(summary, "对方保持谨慎。")
	assert_false(summary.contains("{"))
	assert_false(summary.contains("npc_reaction"))


func test_result_summary_shows_chinese_dialogue_text_when_present() -> void:
	var summary := DisplayText.result({
		"ok": true,
		"npc_reaction": "caution",
		"dialogue": {"text": "管事收下账册证据，为你打开一条有人照看的路。"},
	})
	assert_eq(summary, "管事收下账册证据，为你打开一条有人照看的路。")
	assert_false(summary.contains("{"))


func test_result_summary_describes_standard_encounter_action() -> void:
	assert_eq(DisplayText.result({"ok": true, "action_id": "work"}), "你做完短工，换得了元石。")


func test_result_summary_never_shows_non_chinese_dialogue_text() -> void:
	var summary := DisplayText.result({
		"ok": true,
		"npc_reaction": "caution",
		"dialogue": {"text": "The steward asks what terms you are offering."},
	})
	assert_eq(summary, "对方保持谨慎。")


func test_cost_text_translates_gu_ids_for_player_display() -> void:
	var view := EncounterView.new()
	var cost := view._cost_text({"gu_ids": ["small_light_gu", "trail_eye_gu"]})

	assert_eq(cost, "输入蛊 小光蛊、寻迹眼蛊")
	assert_false(cost.contains("small_light_gu"))
	view.free()


func test_actual_change_text_uses_same_bbcode_color_as_result_history() -> void:
	var view := EncounterView.new()
	var text := view._actual_change_text([{"message": "元石增加 2。"}])

	assert_eq(text, "[color=#b8d5cc]结算：元石增加 2。[/color]")
	view.free()
