extends GutTest


func test_catalog_has_twenty_gu_and_three_inheritances() -> void:
	var catalog := ContentCatalog.load_all()
	assert_eq(catalog["gu"].size(), 20)
	assert_eq(catalog["inheritances"].size(), 3)
	assert_eq(ContentCatalog.validate(catalog), [])


func test_catalog_rejects_missing_inheritance_gu_reference() -> void:
	var catalog := ContentCatalog.load_all()
	catalog["inheritances"][0]["required_gu_ids"] = ["missing_gu"]
	assert_eq(ContentCatalog.validate(catalog).size(), 1)
