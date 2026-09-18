extends GutTest


func test_map_generator_can_build_from_validated_catalog_config() -> void:
	var catalog := ContentCatalog.load_all()
	var custom_first_run: Dictionary = (catalog["first_run"] as Dictionary).duplicate(true)
	custom_first_run["route_ids"] = ["neutral_wanderer", "ridge_caravan"]
	catalog["first_run"] = custom_first_run
	var route := MapGenerator.build(101, true, catalog)
	assert_eq(route.size(), 2)
	assert_eq(route[0]["template_id"], "neutral_wanderer")
	assert_eq(route[1]["template_id"], "ridge_caravan")
