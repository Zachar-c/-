extends "res://addons/gut/test.gd"


# S2 refine-school battle-synthesis once ran inside the legacy engine
# (take_turn {"type": "refine"} minting temp cards / blind-box curses /
# synthesis_fail_streak). The V1 convergence dropped the in-battle refine
# command (B1 bucket C), so those legs are gone; the two engine-agnostic
# contracts below survive: the synthesis tables validate, and the gu
# transaction ledger rejects unknown outputs before mutating state.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func test_synthesis_tables_pass_catalog_validation() -> void:
	assert_eq(ContentCatalogScript.validate(catalog()), [])


func test_unknown_transaction_output_is_rejected_before_ledger_mutation() -> void:
	var state := RunStateScript.new_run(101, null)
	var cat := catalog()
	var before_instances := state.gu_instances.duplicate(true)
	var before_aperture := state.cave_aperture.duplicate(true)
	var result := GuInstance.transaction_ledger(
		state.gu_instances, state.cave_aperture, "missing_output_gu", cat, ["small_light_gu"])
	assert_true(result.has("error"))
	if not result.has("error"):
		return
	assert_eq(str(result["error"]), "unknown_gu_definition")
	assert_eq(state.gu_instances, before_instances)
	assert_eq(state.cave_aperture, before_aperture)
