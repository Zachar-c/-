extends GutTest


# Spec-v4 phase-2 (T10.1): legacy abolition assertions - one test per
# abolished family, red before the deletion commit, green after. Only-delete
# discipline: these assertions prove the old symbols no longer exist.


func _gd_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func test_abolished_1_deck_capacity_slot_gate_is_gone() -> void:
	# Family 1: gu slot hard caps are abolished (feeding soft cap replaces
	# them); the deck-capacity gate file and symbols must not exist.
	assert_false(_gd_exists("res://scripts/domain/deck_capacity.gd"),
			"family 1: deck_capacity.gd must be deleted")
	var resolver_text := FileAccess.get_file_as_string("res://scripts/domain/resolver.gd")
	assert_false(resolver_text.contains("deck_capacity_exceeded"),
			"family 1: no deck_capacity rejection symbol in resolver")


func test_abolished_8_random_refine_and_dual_destroy_are_converged() -> void:
	# Family 8: the v2 parallel destroy_gu body must be gone (one
	# implementation left) and the random refine path's legacy data entry is
	# retired.
	var v2_text := FileAccess.get_file_as_string("res://scripts/domain/v2_commands.gd")
	assert_false(v2_text.contains("func destroy_gu"),
			"family 8: only one destroy_gu implementation may remain")