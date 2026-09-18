extends GutTest

## Bucket B (B1-5): preview retreat gate must read the SAME boss marker as
## the V1 runtime (flags.boss_battle, set by facade.start for tier=="boss").
## Regression proof for the two-shape gap: the legacy BattleResolver helper
## checked enemy.definition.tier / enemy_definition.tier, which V1 battles
## never carry, so the preview card silently unblocked retreat in boss fights
## while the runtime still rejected it (SS16.5 no-silent-block violation).


const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


func _retreat_card(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	for card in ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog):
		if str(card.get("id", "")) == "battle.retreat":
			return card
	return {}


func test_v1_boss_battle_preview_blocks_retreat() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var state := RunState.new_run(101)
	state.stone = 5
	# tier=="boss" enemy → facade.start stamps flags.boss_battle.
	var boss: Dictionary = FacadeScript.start(
		{"enemy_kind": "miasma_vein_lord", "terrain": "path"}, state, catalog)
	assert_true(bool(boss["flags"].get("boss_battle", false)), "fixture must be a boss battle")

	var retreat := _retreat_card(boss, state, catalog)
	assert_false(retreat.is_empty(), "retreat card must exist in boss preview")
	assert_false(bool(retreat.get("executable", true)),
		"boss fight preview must show retreat blocked")
	assert_string_contains(str(retreat.get("block_reason", "")), "退无可退")
	assert_true((retreat.get("remedy_hints", []) as Array).is_empty(),
		"boss block leaves no remedy hint")


func test_v1_trivial_battle_preview_allows_retreat_when_terrain_allows() -> void:
	var catalog: Dictionary = ContentCatalog.load_all()
	var state := RunState.new_run(101)
	state.stone = 5
	var battle: Dictionary = FacadeScript.start(
		{"enemy_kind": "ridge_hound", "terrain": "path"}, state, catalog)
	assert_false(bool(battle["flags"].get("boss_battle", false)), "fixture must be a trivial fight")

	var retreat := _retreat_card(battle, state, catalog)
	assert_false(retreat.is_empty())
	assert_true(bool(retreat.get("executable", false)),
		"trivial path fight with stones may retreat")
	assert_eq(str(retreat.get("block_reason", "")), "")


func test_v1_retreat_still_terrain_gated() -> void:
	# Legacy can_retreat semantics (terrain in path/ridge/marsh) are kept
	# inline; V1 battles with no terrain must not advertise retreat.
	var catalog: Dictionary = ContentCatalog.load_all()
	var state := RunState.new_run(101)
	state.stone = 5
	var battle: Dictionary = FacadeScript.start(
		{"enemy_kind": "ridge_hound"}, state, catalog)
	assert_eq(str(battle.get("terrain", "")), "")

	var retreat := _retreat_card(battle, state, catalog)
	assert_false(retreat.is_empty())
	assert_false(bool(retreat.get("executable", true)),
		"no terrain means retreat is not open")
	assert_string_contains(str(retreat.get("block_reason", "")), "地形")
