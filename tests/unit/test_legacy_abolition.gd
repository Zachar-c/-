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
	# retired. B1 deletes v2_commands.gd outright, so a missing file is the
	# strongest form of this proof.
	var v2_path := "res://scripts/domain/v2_commands.gd"
	assert_true(not _gd_exists(v2_path)
			or not FileAccess.get_file_as_string(v2_path).contains("func destroy_gu"),
			"family 8: only one destroy_gu implementation may remain")


const _B1_DELETED := [
	"res://scripts/domain/battle_resolver.gd",
	"res://scripts/domain/v2_commands.gd",
	"res://scripts/domain/battle2/action_resolver.gd",
	"res://scripts/domain/battle2/body_rules.gd",
]

# Preserved on purpose: the turn ledger is an accepted V1 domain usage.
const _B1_PRESERVED := [
	"res://scripts/domain/battle2/turn_engine.gd",
	"res://scripts/domain/battle2/combat_constants.gd",
]


func _collect_gd_texts(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var child := dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_gd_texts(child, out)
		elif entry.ends_with(".gd"):
			out.append([child, FileAccess.get_file_as_string(child)])
		entry = dir.get_next()
	dir.list_dir_end()


func test_abolished_9_legacy_battle_engine_is_gone() -> void:
	# B1 (master plan Phase B1): the legacy battle engine is converged to V1
	# only. No legacy file may exist and no production script may reference it
	# (comments included). Scrubbed before matching: `v1_battle_resolver`
	# (file path) and `V1BattleResolver` (preload const name), both live.
	for path in _B1_DELETED:
		assert_false(_gd_exists(path), "b1: %s must be deleted" % path)
	for path in _B1_PRESERVED:
		assert_true(_gd_exists(path), "b1: %s is the V1 ledger and must stay" % path)
	var collected: Array = []
	_collect_gd_texts("res://scripts", collected)
	for pair in collected:
		var path := str(pair[0])
		# Deleted-family files still on disk are already pinned red by the
		# existence asserts above; token-scanning their own bodies would only
		# add noise (they vanish with the deletion commit).
		if _B1_DELETED.has(path):
			continue
		var scrubbed := str(pair[1]) \
				.replace("V1BattleResolverScript", "") \
				.replace("V1BattleResolver", "") \
				.replace("v1_battle_resolver", "")
		# Token set covers both reference forms: preload paths / file names
		# (battle_resolver) and the global class_name call surface
		# (BattleResolver. / BattleResolverScript) that outlived preloads and
		# slipped the original lowercase scan (2026-09-06 audit).
		for token in [
				"battle_resolver", "v2_commands", "battle2/action_resolver",
				"battle2/body_rules", "BattleResolverScript", "BattleResolver."]:
			assert_false(scrubbed.contains(token),
					"b1: %s still references %s" % [path, token])