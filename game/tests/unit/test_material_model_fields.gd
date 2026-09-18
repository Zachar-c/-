extends "res://addons/gut/test.gd"


# Q8-G 1-B1 material front batch (2026-09-13, rev 2 after the world-model
# review): guards the frozen 1-B0-M material model in three gates.
#
#   Schema Gate            - the five attribute classes exist and enums hold.
#   Data Integrity Gate    - catalog validates clean; primary-dao convention.
#   World Semantic Gate    - origin tracking + semantic basis are declared, and
#                            the nineteen school candidates stay flagged as
#                            design candidates until each one passes the
#                            per-school world-semantic review (M-11). A naming
#                            association must never silently pass as a world
#                            fact (骨 ≠ 骨道).


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")

const DESIGN_CANDIDATE_SCHOOLS := [
	"blood", "qi", "force", "soul", "refine", "wisdom", "dream", "luck", "sword",
	"wood", "fire", "water", "wind", "gold", "earth", "slave", "heaven", "human", "bone",
]


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func materials() -> Dictionary:
	return catalog()["loot_tables"]["materials"]


# ---------------------------------------------------------------- Schema Gate

func test_every_material_declares_the_five_attribute_classes() -> void:
	var mats := materials()
	assert_gt(mats.size(), 20)
	for material_id in mats:
		var entry: Dictionary = mats[material_id]
		assert_false(str(entry.get("form", "")).is_empty(), "%s missing form" % material_id)
		assert_true(ContentCatalogScript.MATERIAL_SOURCE_CLASSES.has(str(entry.get("source_class", ""))),
				"%s bad source_class" % material_id)
		assert_true(ContentCatalogScript.MATERIAL_ACQUISITION_MODES.has(str(entry.get("acquisition_mode", ""))),
				"%s bad acquisition_mode" % material_id)
		assert_true(ContentCatalogScript.MATERIAL_QUALITY_BANDS.has(str(entry.get("quality_band", ""))),
				"%s bad quality_band" % material_id)


func test_validation_rejects_an_unknown_source_class() -> void:
	var cat := catalog()
	cat["loot_tables"]["materials"]["beast_bone"]["source_class"] = "tier_2_beast"
	var errors: Array[String] = ContentCatalogScript.validate(cat)
	assert_has(errors, "material beast_bone source_class tier_2_beast is not a declared source class")


func test_validation_rejects_an_unknown_quality_band() -> void:
	var cat := catalog()
	cat["loot_tables"]["materials"]["beast_bone"]["quality_band"] = "tier_5"
	var errors: Array[String] = ContentCatalogScript.validate(cat)
	assert_has(errors, "material beast_bone quality_band tier_5 is not a declared quality band")


func test_source_class_vocabulary_is_type_labels_not_a_tier_ladder() -> void:
	# M-4: source classes are unordered type labels. The vocabulary must not gain
	# numeric members that would invite a 1=凡兽 2=荒兽 style tier axis.
	for label in ContentCatalogScript.MATERIAL_SOURCE_CLASSES:
		assert_false(label.is_valid_int(), "source_class %s looks like a tier rank" % label)
	assert_true(ContentCatalogScript.MATERIAL_SOURCE_CLASSES.has("beast_king"))
	assert_true(ContentCatalogScript.MATERIAL_ACQUISITION_MODES.has("trade"))


# --------------------------------------------------------- Data Integrity Gate

func test_catalog_still_validates_clean() -> void:
	assert_eq(ContentCatalogScript.validate(catalog()), [])


func test_primary_dao_mark_is_the_first_tag() -> void:
	# Frozen convention: dao_tags[0] is the primary dao mark. beast_blood keeps
	# its blood+qi dual tag with blood first, and the divisible guard still holds.
	var beast_blood: Dictionary = materials()["beast_blood"]
	assert_eq(str(beast_blood["dao_tags"][0]), "blood")
	assert_true(bool(beast_blood["divisible"]))


# ------------------------------------------------------- World Semantic Gate

func test_every_material_declares_origin_status_and_semantic_basis() -> void:
	for material_id in materials():
		var entry: Dictionary = materials()[material_id]
		assert_true(ContentCatalogScript.MATERIAL_ORIGIN_STATUS.has(str(entry.get("origin_status", ""))),
				"%s bad origin_status" % material_id)
		var basis: Variant = entry.get("semantic_basis", null)
		assert_true(basis is Dictionary, "%s missing semantic_basis" % material_id)
		if basis is Dictionary:
			assert_true(ContentCatalogScript.MATERIAL_SEMANTIC_BASIS_TYPES.has(str(basis.get("type", ""))),
					"%s bad semantic_basis type" % material_id)
			assert_false(str(basis.get("rationale", "")).is_empty(),
					"%s empty semantic_basis rationale" % material_id)


func test_validation_rejects_a_missing_semantic_basis() -> void:
	var cat := catalog()
	cat["loot_tables"]["materials"]["beast_bone"].erase("semantic_basis")
	var errors: Array[String] = ContentCatalogScript.validate(cat)
	assert_has(errors, "material beast_bone semantic_basis must declare a known basis type and a non-empty rationale")


func test_text_free_materials_are_flagged_as_design_extensions() -> void:
	# Fact base: 月露 and 毒囊 have zero hits in the original text (E0). They may
	# exist as game materials, but the flag must travel with the instance so a
	# future agent cannot mistake them for world-model-approved natives.
	assert_eq(str(materials()["moon_dew"]["origin_status"]), "design_extension")
	assert_eq(str(materials()["venom_sac"]["origin_status"]), "design_extension")


func test_nineteen_school_candidates_stay_pending_world_semantic_acceptance() -> void:
	# M-11: "primary dao = school" is a design default candidate, never an
	# automatic rule. All nineteen candidates must remain flagged as design
	# candidates until their per-school world-semantic review (this test fails
	# loudly if anyone silently promotes them to approved facts).
	var mats := materials()
	for school in DESIGN_CANDIDATE_SCHOOLS:
		var candidate_id := "mat_%s_1" % school
		assert_true(mats.has(candidate_id), "missing crude main material %s" % candidate_id)
		if mats.has(candidate_id):
			var entry: Dictionary = mats[candidate_id]
			assert_eq(str(entry["dao_tags"][0]), str(school), "%s primary dao drift" % candidate_id)
			assert_eq(str(entry["quality_band"]), "crude")


func test_eighteen_schools_accepted_bone_stays_pending() -> void:
	# World-semantic ruling (2026-09-13): 18 schools accepted (blood derived_D2,
	# force/gold/earth derived_D1, the rest design_only) and promoted to
	# design_extension; bone alone stays a pending design candidate.
	var mats := materials()
	for school in DESIGN_CANDIDATE_SCHOOLS:
		var entry: Dictionary = mats["mat_%s_1" % school]
		if school == "bone":
			assert_eq(str(entry["origin_status"]), "design_candidate", "bone must stay pending")
			assert_eq(str(entry["semantic_basis"]["type"]), "design_only")
			assert_true(str(entry["semantic_basis"]["rationale"]).contains("不得反向利用 D3"),
					"bone rationale lost the anti-self-proof lock")
		else:
			assert_eq(str(entry["origin_status"]), "design_extension",
					"%s should be accepted" % school)
	var blood_basis: Dictionary = mats["mat_blood_1"]["semantic_basis"]
	assert_eq(str(blood_basis["type"]), "derived_D2")
	for school in ["force", "gold", "earth"]:
		assert_eq(str(mats["mat_%s_1" % school]["semantic_basis"]["type"]), "derived_D1")


func test_sword_candidate_uses_the_ruled_relic_origin() -> void:
	# Ruling: option B - ancient-battlefield broken blades from the environment,
	# gathered by exploring. No "gu-master corpse drops" ecosystem was created.
	var sword: Dictionary = materials()["mat_sword_1"]
	assert_eq(str(sword["source_class"]), "environment")
	assert_eq(str(sword["acquisition_mode"]), "gather")


func test_same_form_can_carry_different_dao_marks() -> void:
	# M-1/M-2 living proof kept on purpose: mat_qi_1 and moon_dew are both dew.
	# The ruling explicitly rejected forcing a form rename - identical carrier
	# forms with different dao marks ARE the orthogonality evidence.
	assert_eq(str(materials()["mat_qi_1"]["form"]), "dew")
	assert_eq(str(materials()["moon_dew"]["form"]), "dew")
	assert_true(materials()["mat_qi_1"]["dao_tags"].has("qi"))
	assert_true(materials()["moon_dew"]["dao_tags"].has("moon"))


func test_bone_candidate_keeps_the_form_vs_dao_caution() -> void:
	# The fact base proved 骨(形态)≠骨道 with E4 evidence (142182 象腿骨蕴含力道
	# 道痕). mat_bone_1 may exist as a candidate, but its rationale must carry
	# the caution so the old "骨族=骨道" assumption never sneaks back in.
	var basis: Dictionary = materials()["mat_bone_1"]["semantic_basis"]
	assert_eq(str(basis["type"]), "design_only")
	assert_true(str(basis["rationale"]).contains("骨≠骨道"), "mat_bone_1 rationale lost the form-vs-dao caution")
