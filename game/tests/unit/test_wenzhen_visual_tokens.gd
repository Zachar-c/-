extends GutTest

# Task 1: Wen Zhen visual token tests.
# Validates light-on-dark baseline, semantic colors, spacing and radius constants.

const EPSILON := 0.01


func test_wenzhen_tokens_are_light_high_contrast_and_semantic() -> void:
	assert_gt(GuStyle.PAPER_BG.get_luminance(), 0.82,
		"PAPER_BG must be light (宣纸白)")
	assert_lt(GuStyle.INK_PRIMARY.get_luminance(), 0.18,
		"INK_PRIMARY must be dark (近黑墨色)")
	assert_eq(GuStyle.HAIRLINE, 1, "HAIRLINE must be 1px")
	assert_ne(GuStyle.CONTRACT_BLUE, GuStyle.ANOMALY_YELLOW,
		"CONTRACT_BLUE and ANOMALY_YELLOW must differ")
	assert_ne(GuStyle.CINNABAR, GuStyle.ANOMALY_YELLOW,
		"CINNABAR and ANOMALY_YELLOW must differ")
	assert_lte(GuStyle.RADIUS_SMALL, 8,
		"RADIUS_SMALL must be <= 8 per design spec")


func test_spacing_tokens_are_stable_progression() -> void:
	assert_lt(GuStyle.SPACE_1, GuStyle.SPACE_2)
	assert_lt(GuStyle.SPACE_2, GuStyle.SPACE_3)
	assert_lt(GuStyle.SPACE_3, GuStyle.SPACE_4)
	assert_lt(GuStyle.SPACE_4, GuStyle.SPACE_5)
	assert_lt(GuStyle.SPACE_5, GuStyle.SPACE_6)


func test_paper_raised_is_slightly_darker_than_paper_bg() -> void:
	var bg_lum := GuStyle.PAPER_BG.get_luminance()
	var raised_lum := GuStyle.PAPER_RAISED.get_luminance()
	assert_lte(raised_lum, bg_lum + EPSILON,
		"PAPER_RAISED should be same or slightly darker than PAPER_BG")


func test_ink_muted_is_between_ink_primary_and_paper_bg() -> void:
	var ink_lum := GuStyle.INK_PRIMARY.get_luminance()
	var muted_lum := GuStyle.INK_MUTED.get_luminance()
	var paper_lum := GuStyle.PAPER_BG.get_luminance()
	assert_gt(muted_lum, ink_lum, "INK_MUTED lighter than INK_PRIMARY")
	assert_lt(muted_lum, paper_lum, "INK_MUTED darker than PAPER_BG")


func test_hairline_color_exists() -> void:
	assert_ne(GuStyle.HAIRLINE_COLOR, Color.TRANSPARENT,
		"HAIRLINE_COLOR must not be transparent")
