extends GutTest


const DeathReportBuilderScript = preload("res://scripts/domain/death_report_builder.gd")


func test_exhausted_player_death_uses_visible_stone_clue_and_enemy_taunt() -> void:
	var battle := {
		"enemy_kind": "neutral_stone_wanderer",
		"clues": ["stone_dust", "steady_stance"],
		"revealed_reactions": ["stone_shell"],
		"final_blow": {"id": "stone_palm", "damage": 2},
	}
	var state := RunState.new_run(101)
	state.essence = 0

	var report := DeathReportBuilderScript.build(battle, state)

	assert_eq(report["final_blow"], "stone_palm")
	assert_true(report["known_facts"].has("stone_dust"))
	assert_eq(report["taunt"], "见光便扑？这点真元，也敢替我试蛊。下辈子先照照脚下的石粉。")
	assert_false(report["taunt"].contains("enemy_essence"))
