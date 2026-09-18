extends GutTest


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_settling_stage_ledger_grants_lifespan_milestone_once() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "stage_one_ledger"
	state.stone = 20
	var first := ResolverScript.apply(state, {"type": "settle_feeding"}, catalog)
	assert_true(first["result"]["ok"])
	assert_eq(int(first["state"].cultivator["lifespan"]), 70)
	assert_eq(first["state"].event_log.back()["reason"], "lifespan_milestone_gained")
	assert_eq(first["state"].event_log.back()["targets"], ["stage_one_ledger"])

	var second := ResolverScript.apply(first["state"], {"type": "settle_feeding"}, catalog)
	assert_true(second["result"]["ok"])
	assert_eq(int(second["state"].cultivator["lifespan"]), 70)


func test_boss_defeat_grants_lifespan_milestone_once() -> void:
	var first := ResolverScript.apply(RunState.new_run(101), {"type": "record_boss_defeated"}, catalog)
	assert_eq(int(first["state"].cultivator["lifespan"]), 70)

	var second := ResolverScript.apply(first["state"], {"type": "record_boss_defeated"}, catalog)
	assert_eq(int(second["state"].cultivator["lifespan"]), 70)


func test_missing_milestone_entry_grants_nothing_without_error() -> void:
	var tuned := catalog.duplicate(true)
	tuned["pacing"] = {"lifespan_milestones": {}}
	var state := RunState.new_run(101)
	state.current_node_id = "stage_one_ledger"
	state.stone = 20
	var result := ResolverScript.apply(state, {"type": "settle_feeding"}, tuned)
	assert_true(result["result"]["ok"])
	assert_eq(int(result["state"].cultivator["lifespan"]), 60)


func test_negative_milestone_value_fails_catalog_validation() -> void:
	var tuned := catalog.duplicate(true)
	tuned["pacing"] = {"lifespan_milestones": {"stage_one_ledger": -5}}
	var errors: Array[String] = ContentCatalogScript.validate(tuned)
	var hit := false
	for error in errors:
		if error.contains("pacing") and error.contains("non-negative"):
			hit = true
	assert_true(hit)