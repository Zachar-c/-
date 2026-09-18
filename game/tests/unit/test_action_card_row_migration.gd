extends GutTest

const DisplayTextScript := preload("res://scripts/presentation/display_text.gd")
const BuilderScript := preload("res://scripts/presentation/action_card_row_builder.gd")


func test_display_text_owns_action_card_formatting_helpers() -> void:
	var cost := {"stone": 2, "lifespan": 3, "gu_ids": ["small_light_gu"]}
	assert_eq(DisplayTextScript.cost_text(cost), BuilderScript._cost_text(cost))
	var card := {
		"cost": cost,
		"success_rate": 75,
		"expected_gain": ["获得情报"],
		"known_risk": ["反噬"],
		"unknown_note": "仍有未知变数",
		"executable": false,
		"block_reason": "真元不足",
		"remedy_hints": ["先行静修"],
	}
	assert_eq(DisplayTextScript.details(card), BuilderScript._details(card))
	assert_eq(DisplayTextScript.risk_badge(card), BuilderScript.risk_badge(card))


func test_action_card_row_global_names_are_distinct() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/presentation/action_card_row_builder.gd")
	assert_true(source.contains("class_name ActionCardRowBuilder"))
	assert_false(FileAccess.file_exists("res://scripts/presentation/action_card_row.gd"))
