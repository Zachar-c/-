extends GutTest


func test_catalog_has_twenty_gu_and_three_inheritances() -> void:
	var catalog := ContentCatalog.load_all()
	assert_eq(catalog["gu"].size(), 200)
	assert_eq(catalog["inheritances"].size(), 3)
	assert_eq(ContentCatalog.validate(catalog), [])


func test_catalog_rejects_missing_inheritance_gu_reference() -> void:
	var catalog := ContentCatalog.load_all()
	catalog["inheritances"][0]["required_gu_ids"] = ["missing_gu"]
	assert_eq(ContentCatalog.validate(catalog).size(), 1)


func _has_hint(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false


func test_validation_requires_all_five_schools() -> void:
	var catalog := ContentCatalog.load_all()
	(catalog["schools"] as Dictionary).erase("refine")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "refine"))


func test_validation_rejects_school_without_display_name() -> void:
	var catalog := ContentCatalog.load_all()
	var soul: Dictionary = (catalog["schools"] as Dictionary)["soul"]
	soul.erase("name")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "display name"))


func test_validation_rejects_cross_school_pool_entry() -> void:
	var catalog := ContentCatalog.load_all()
	var blood_pool: Array = (catalog["school_pools"] as Dictionary)["blood"]
	blood_pool.append("stone_shell_gu")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "belongs to school"))


func test_validation_rejects_gu_in_two_pools() -> void:
	var catalog := ContentCatalog.load_all()
	var pools: Dictionary = catalog["school_pools"]
	var qi_pool: Array = pools["qi"]
	qi_pool.append(str((pools["blood"] as Array)[0]))
	assert_true(_has_hint(ContentCatalog.validate(catalog), "multiple school pools"))


func test_validation_rejects_missing_pool_gu() -> void:
	var catalog := ContentCatalog.load_all()
	var soul_pool: Array = (catalog["school_pools"] as Dictionary)["soul"]
	soul_pool.append("missing_pool_gu")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "missing gu"))


func test_validation_rejects_missing_exclusive_pool() -> void:
	var catalog := ContentCatalog.load_all()
	(catalog["school_pools"] as Dictionary).erase("force")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "exclusive pool"))
