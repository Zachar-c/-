extends GutTest


const CatalogScript = preload("res://scripts/domain/content_catalog.gd")


func _has_hint(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false


func test_load_and_validate_all_includes_external_tables() -> void:
	var loaded: Dictionary = CatalogScript.load_and_validate_all()
	assert_true(loaded.has("catalog"))
	assert_true(loaded.has("errors"))
	assert_true((loaded["catalog"] as Dictionary).has("first_run"))
	assert_true((loaded["catalog"] as Dictionary).has("dialogue_templates"))
	assert_true((loaded["catalog"] as Dictionary).has("names"))
	assert_eq(loaded["errors"], [])


func test_validation_rejects_unknown_event_kind() -> void:
	var catalog := CatalogScript.load_all()
	(catalog["events"] as Array)[0]["kind"] = "unknown_kind"
	assert_true(_has_hint(CatalogScript.validate(catalog), "event"))
	assert_true(_has_hint(CatalogScript.validate(catalog), "kind"))


func test_validation_rejects_first_run_unknown_route_id() -> void:
	var catalog := CatalogScript.load_all()
	(catalog["first_run"] as Dictionary)["route_ids"].append("missing_route_node")
	assert_true(_has_hint(CatalogScript.validate(catalog), "first_run"))
	assert_true(_has_hint(CatalogScript.validate(catalog), "missing_route_node"))


func test_validation_rejects_dialogue_without_clarify_fallback() -> void:
	var catalog := CatalogScript.load_all()
	(catalog["dialogue_templates"] as Dictionary)["responses"].erase("clarify")
	assert_true(_has_hint(CatalogScript.validate(catalog), "dialogue"))
	assert_true(_has_hint(CatalogScript.validate(catalog), "clarify"))
