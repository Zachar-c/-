extends GutTest


const VocabularyScript = preload("res://scripts/presentation/resource_vocabulary.gd")


func test_resource_aliases_normalize_to_canonical_ids() -> void:
	assert_eq(VocabularyScript.normalize("stone"), "yuanstone")
	assert_eq(VocabularyScript.normalize("stones"), "yuanstone")
	assert_eq(VocabularyScript.normalize("shouyuan"), "lifespan")
	assert_eq(VocabularyScript.normalize("hunpo"), "soul")
	assert_eq(VocabularyScript.normalize("injury"), "injury")
	assert_eq(VocabularyScript.normalize("intel"), "intel")
	assert_eq(VocabularyScript.normalize("relic"), "relic")


func test_resource_specs_share_labels_suffixes_and_order() -> void:
	assert_eq(VocabularyScript.label("yuanstone"), "元石")
	assert_eq(VocabularyScript.label("lifespan"), "寿元")
	assert_eq(VocabularyScript.label("injury"), "伤势")
	assert_eq(VocabularyScript.label("intel"), "情报")
	assert_eq(VocabularyScript.label("relic"), "遗物")
	assert_eq(VocabularyScript.suffix("lifespan"), "")
	assert_eq(VocabularyScript.display_order(), ["yuanstone", "essence", "lifespan", "soul", "material"])


func test_unknown_resource_is_explicitly_unavailable() -> void:
	assert_eq(VocabularyScript.normalize("unknown_resource"), "")
	assert_eq(VocabularyScript.label("unknown_resource"), "未知资源")
