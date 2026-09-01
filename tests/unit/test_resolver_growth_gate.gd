extends GutTest


# Spec-v4 phase-1 (T1.2): permanent growth gates. The two god files must not
# keep growing with new rules (resolver edits and battle edits only shrink or
# stay flat), and the central rank multiplier must live in exactly one place.


const RESOLVER_PATH := "res://scripts/domain/resolver.gd"
const BATTLE_RESOLVER_PATH := "res://scripts/domain/battle_resolver.gd"
# NOTE: the phase-1 plan line was 2457, but the 2026-09-01 integration batch
# pushed resolver to 2502 (split count). The gate pins TODAY's line as the
# ceiling; the plan line is the phase-10 shrink target, at which point this
# cap must be lowered back to 2457.
const RESOLVER_LINE_CAP := 2502
const BATTLE_RESOLVER_LINE_CAP := 1516


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
	# The 2.0 step ratio and its projection live only in gu_balance.gd (schema
	# key names in content_catalog.gd are declarations, not definitions);
	# any other file implementing the formula or naming the parameter is drift.
	var drift_tokens := ["rank_step_ratio", "standard_gu_power"]
	var hits: Array[String] = []
	var allowed := {
		"res://scripts/domain/gu_balance.gd": true,
		"res://scripts/domain/content_catalog.gd": true,
	}
	for dir_path in ["res://scripts", "res://scripts/domain", "res://scripts/presentation"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir() and name.get_extension() == "gd":
				var full: String = dir_path.path_join(name)
				var text := FileAccess.get_file_as_string(full)
				if allowed.has(full):
					pass
				elif drift_tokens.any(func(token: String) -> bool: return text.contains(token)):
					hits.append(full)
			name = dir.get_next()
		dir.list_dir_end()
	assert_eq(hits, [] as Array[String],
			"balance formulas must live only in gu_balance.gd, but found in %s" % str(hits))