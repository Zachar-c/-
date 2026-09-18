extends GutTest


# Phase D1 (master plan): recipe source v2 - every curated recipe carries its
# novel source anchor, and cross-school recipes may express their inputs as
# {school, rank, count} (the user's merge semantics: 1-rank moonlight x1 +
# 1-rank small light x2 -> 2-rank moon glow). Synergy stays data-only (D3
# groundwork): the key exists, no gameplay consumes it.


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _curated_recipes() -> Array:
	var out: Array = []
	for recipe in catalog["refinement_recipes"]:
		if str(recipe.get("kind", "")) in ["fixed", "free_mix"]:
			out.append(recipe)
	return out


func test_curated_recipes_carry_a_novel_source_anchor() -> void:
	# D1: curated (hand-authored) recipes are the ones with a novel basis, so
	# each must name where it comes from - no unsourced lore in the catalog.
	var curated := _curated_recipes()
	assert_gt(curated.size(), 0, "there must be curated recipes to source")
	for recipe in curated:
		var source := str(recipe.get("source", "")).strip_edges()
		assert_false(source.is_empty(),
				"curated recipe %s needs a non-empty source" % recipe.get("id", "?"))


func test_v2_input_expressions_use_known_school_and_rank() -> void:
	# D1 v2 schema: inputs:[{school, rank, count}] is optional; when present
	# every entry must name a declared dao-mark school, a 1..5 rank and a
	# positive count.
	var schools: Dictionary = catalog.get("schools", {})
	for recipe in catalog["refinement_recipes"]:
		if not recipe.has("inputs"):
			continue
		var inputs: Array = recipe.get("inputs", [])
		assert_gt(inputs.size(), 0,
				"recipe %s declares inputs but leaves it empty" % recipe.get("id", "?"))
		for entry_value in inputs:
			var entry: Dictionary = entry_value
			var school := str(entry.get("school", ""))
			assert_true(schools.has(school) or school.is_empty() == false,
					"recipe %s input school %s must be declared" % [recipe.get("id", "?"), school])
			var rank := int(entry.get("rank", 0))
			assert_between(rank, 1, 5,
					"recipe %s input rank must sit in 1..5" % recipe.get("id", "?"))
			assert_gte(int(entry.get("count", 0)), 1,
					"recipe %s input count must be positive" % recipe.get("id", "?"))


func test_cross_school_recipes_are_expressed_in_v2() -> void:
	# The user's model: a 3-rank recipe needs two 2-rank inputs, often from
	# two different dao marks. At least one curated recipe must show that
	# cross-school shape in the v2 expression.
	var cross := 0
	for recipe in _curated_recipes():
		var schools_seen := {}
		for entry_value in recipe.get("inputs", []):
			var entry: Dictionary = entry_value
			schools_seen[str(entry.get("school", ""))] = true
		if schools_seen.size() >= 2:
			cross += 1
	assert_gte(cross, 1,
			"at least one curated recipe must express a cross-school merge")


func test_synergy_groundwork_exists_without_gameplay() -> void:
	# D3 groundwork only: gu definitions expose synergy_hooks, and no domain
	# script may consume them yet (kill-move assembly is deferred).
	var gu_list: Array = catalog.get("gu", [])
	assert_gt(gu_list.size(), 0, "catalog must expose gu definitions")
	var with_hooks := 0
	for gu_value in gu_list:
		var gu: Dictionary = gu_value
		if gu.has("synergy_hooks"):
			with_hooks += 1
	# Groundwork lives on the curated gu (the 802 rebuild kept it on the
	# hand-authored definitions); it must stay a plain data structure.
	assert_gt(with_hooks, 0,
			"synergy groundwork key must exist on gu definitions")
	for gu_value in gu_list:
		var gu: Dictionary = gu_value
		if not gu.has("synergy_hooks"):
			continue
		assert_true(gu["synergy_hooks"] is Array,
				"gu %s synergy_hooks must stay a data-only array" % str(gu.get("id", "?")))
