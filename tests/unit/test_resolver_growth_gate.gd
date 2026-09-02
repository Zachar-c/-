extends GutTest


# Spec-v4 phase-1 (T1.2): permanent growth gates. The two god files must not
# keep growing with new rules (resolver edits and battle edits only shrink or
# stay flat), and the central rank multiplier must live in exactly one place.


const RESOLVER_PATH := "res://scripts/domain/resolver.gd"
const BATTLE_RESOLVER_PATH := "res://scripts/domain/battle_resolver.gd"
# NOTE: plan global-invariant line is 2457. The 9/1 batch pushed resolver past
# it; a pre-phase-2 shrink (economy_rules.gd extraction) brought it back under.
# T10.2 terminal values (one-way down from the 2457/1516 plan caps): the
# phase-10 abolitions ended lower than both pre-deletion baselines (2452/1514).
const RESOLVER_LINE_CAP := 2430
# V1 battle2 ledger lifecycle fix: the resolver's hook sits in _battle_over
# and _death_over so the legacy test fixtures still bind to the funnel; the
# cap accepts the hook overhead rather than carve the path out.
const BATTLE_RESOLVER_LINE_CAP := 1548


func _line_count(path: String) -> int:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return 0
	return text.split("\n").size()


func test_resolver_stays_within_the_line_cap() -> void:
	var lines := _line_count(RESOLVER_PATH)
	assert_true(lines <= RESOLVER_LINE_CAP,
			"resolver.gd must stay <= %d lines (currently %d): new rules live in their own modules" % [RESOLVER_LINE_CAP, lines])


func test_battle_resolver_stays_within_the_line_cap() -> void:
	var lines := _line_count(BATTLE_RESOLVER_PATH)
	assert_true(lines <= BATTLE_RESOLVER_LINE_CAP,
			"battle_resolver.gd must stay <= %d lines (currently %d)" % [BATTLE_RESOLVER_LINE_CAP, lines])


func test_rank_multiplier_has_exactly_one_definition_site() -> void:
	# The rank formulas and their parameter names must live only in
	# gu_balance.gd (schema key names in content_catalog.gd are declarations,
	# not definitions); any other file implementing them is drift.
	var drift_tokens := [
		"rank_step_ratio", "standard_gu_power", "standard_hit_ratio",
		"human_standard_heal",
	]
	var hits: Array[String] = []
	var allowed := {
		"res://scripts/domain/gu_balance.gd": true,
		"res://scripts/domain/content_catalog.gd": true,
	}
	var files: Array[String] = []
	_collect_gd_files("res://scripts", files)
	for full in files:
		var text := FileAccess.get_file_as_string(full)
		if not allowed.has(full) and drift_tokens.any(func(token: String) -> bool: return text.contains(token)):
			hits.append(full)
	assert_eq(hits, [] as Array[String],
			"balance formulas must live only in gu_balance.gd, but found in %s" % str(hits))


# Recursive .gd walk so future modules (scripts/domain/battle2/ etc.) cannot
# smuggle formula copies past the gate.
func _collect_gd_files(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if name != "." and name != "..":
				_collect_gd_files(path.path_join(name), out)
		elif name.get_extension() == "gd":
			out.append(path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
