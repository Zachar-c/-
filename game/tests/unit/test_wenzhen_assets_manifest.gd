extends GutTest

const ManifestScript := preload("res://scripts/presentation/wenzhen_asset_manifest.gd")


func test_wenzhen_manifest_is_valid() -> void:
	var manifest := _load_manifest()
	assert_eq(ManifestScript.validate(manifest), [])


func test_wenzhen_manifest_rejects_missing_required_fields() -> void:
	var manifest := {
		"schema_version": 1,
		"usage_notice": "authorized",
		"assets": [{"id": "title", "path": "assets/wenzhen/fonts/LXGWZhiSongCL-Regular.ttf"}],
	}
	var errors: Array[String] = ManifestScript.validate(manifest)
	assert_true(_contains_error(errors, "missing kind"))
	assert_true(_contains_error(errors, "missing license"))


func test_wenzhen_manifest_rejects_duplicate_ids_and_bad_hash() -> void:
	var manifest := _load_manifest()
	var duplicate: Dictionary = (manifest["assets"] as Array)[0].duplicate(true)
	duplicate["id"] = (manifest["assets"] as Array)[1]["id"]
	duplicate["sha256"] = "not-a-sha256"
	(manifest["assets"] as Array).append(duplicate)
	var errors: Array[String] = ManifestScript.validate(manifest)
	assert_true(_contains_error(errors, "duplicate id"))
	assert_true(_contains_error(errors, "sha256"))


func test_wenzhen_manifest_rejects_missing_asset_file() -> void:
	var manifest := _load_manifest()
	(manifest["assets"] as Array)[0]["path"] = "assets/wenzhen/missing.ttf"
	var errors: Array[String] = ManifestScript.validate(manifest)
	assert_true(_contains_error(errors, "path does not exist"))


func _load_manifest() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/wenzhen/assets_manifest.json"))
	return parsed if parsed is Dictionary else {}


func _contains_error(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false
