extends GutTest


const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")


func test_entry_preserves_action_changes_and_visible_facts() -> void:
	var entry: Dictionary = ResultFeedScript.entry(
		"deceive",
		"contact_deceive_success",
		{"stone": 2},
		["wanderer_misdirected"]
	)

	assert_eq(entry["action"], "deceive")
	assert_eq(entry["text_key"], "contact_deceive_success")
	assert_eq(entry["changes"]["stone"], 2)
	assert_eq(entry["facts"], ["wanderer_misdirected"])
