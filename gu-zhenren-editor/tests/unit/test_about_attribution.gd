extends GutTest


## W3b 守门（2026-09-09）：game-icons.net 图标以 CC BY 3.0 使用，该许可要求
## 游戏内署名（仅项目级 CREDITS.md 不够）。实现载体：hall 屏设置面板
## `_build_about_panel` / CreditsDialog（scripts/presentation/screens/
## hall_screen_view.gd，2026-09-06 第 18 批）。本测试守两条事实：
## 1) game-icons 目录在用且非空；2) 署名界面源码必须含 "game-icons" 与 "CC BY"。
## 谁删署名文案（如把面板改成自绘图标独占）谁负责同步本门。


const HALL_VIEW_PATH := "res://scripts/presentation/screens/hall_screen_view.gd"
const GAME_ICONS_DIR := "res://assets/wenzhen/icons/game-icons"


func test_game_icons_dir_is_present_and_nonempty() -> void:
	var dir := DirAccess.open(GAME_ICONS_DIR)
	assert_true(dir != null, "assets/wenzhen/icons/game-icons/ must exist")
	if dir == null:
		return
	var count := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".svg"):
			count += 1
		entry = dir.get_next()
	dir.list_dir_end()
	assert_gt(count, 0, "game-icons dir must hold svg icons (got %d)" % count)


func test_attribution_screen_mentions_game_icons_and_cc_by() -> void:
	var source := FileAccess.get_file_as_string(HALL_VIEW_PATH)
	assert_true(source.contains("game-icons"),
			"about/attribution panel must mention game-icons.net")
	assert_true(source.contains("CC BY"),
			"about/attribution panel must state the CC BY licence")
