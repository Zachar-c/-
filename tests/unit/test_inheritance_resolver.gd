extends GutTest


func test_inheritance_move_requires_equipped_gu_and_tag_constraints() -> void:
	var moves := InheritanceResolver.available_moves(
		["small_light_gu", "trail_eye_gu"],
		["moonlit_trace"],
		ContentCatalog.load_all()
	)
	assert_eq(moves.size(), 1)
	assert_eq(moves[0]["move_id"], "moonlit_trace")


func test_inheritance_move_is_unavailable_when_required_gu_is_not_equipped() -> void:
	var moves := InheritanceResolver.available_moves(
		["small_light_gu"],
		["moonlit_trace"],
		ContentCatalog.load_all()
	)
	assert_eq(moves, [])
