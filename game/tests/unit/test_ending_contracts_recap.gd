extends GutTest


# P2a §16.13/§16.5: the ending recap block lists every sworn contract with its
# catalog label/desc and verbatim rules, ordered exactly like state.contracts;
# runs without contracts keep an empty recap plus a zero count.


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


class StubController:
	var state
	var catalog
	var meta
	var _hall_subview := "main"
	var _selected_school := ""


func _sworn(ids: Array) -> RunState:
	var run := RunState.new_run(21)
	run.current_node_id = "trailhead"
	var allowed: Array = []
	for entry_value in catalog["contracts"]["entries"]:
		allowed.append(str(entry_value["id"]))
	var result: Dictionary = ResolverScript.apply(
		run, {"type": "swear_contracts", "ids": ids, "allowed_ids": allowed}, catalog)
	assert_true(bool(result["result"]["ok"]), str(result["result"]))
	return result["state"]


func _ending(state) -> Dictionary:
	var controller := StubController.new()
	controller.state = state
	controller.catalog = catalog
	controller.meta = null
	return RunSnapshotBuilderScript.ending(controller, {"outcome": "success"}, [], {})


func test_ending_snapshot_lists_sworn_contracts_in_state_order() -> void:
	# Deliberately non-catalog order proves the recap follows state.contracts.
	var state := _sworn(["miser_pact", "blood_pact"])
	var ending: Dictionary = _ending(state)
	var recap: Array = ending["contracts_recap"]

	assert_eq(recap.size(), 2)
	assert_eq(str(recap[0]["id"]), "miser_pact")
	assert_eq(str(recap[0]["label"]), str(catalog["contract_entry_by_id"]["miser_pact"]["label"]))
	assert_eq(str(recap[0]["desc"]), str(catalog["contract_entry_by_id"]["miser_pact"]["desc"]))
	assert_eq(recap[0]["rules"], catalog["contract_entry_by_id"]["miser_pact"]["rules"])
	assert_eq(str(recap[1]["id"]), "blood_pact")
	assert_eq(str(recap[1]["label"]), str(catalog["contract_entry_by_id"]["blood_pact"]["label"]))
	assert_eq(int(ending["contracts_sworn_count"]), 2)


func test_ending_snapshot_without_contracts_keeps_empty_recap() -> void:
	var ending: Dictionary = _ending(RunState.new_run(22))

	assert_eq((ending["contracts_recap"] as Array).size(), 0)
	assert_eq(int(ending["contracts_sworn_count"]), 0)
