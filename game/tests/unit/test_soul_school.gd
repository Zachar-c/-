extends "res://addons/gut/test.gd"


# Task S1 leftovers that survived the V1 battle convergence (B1 bucket C):
# soul-school starter data must stay whole. The overchannel / backlash-to-draw
# mechanics once tested here were legacy-engine-only (use_gu overchannel, mercy
# clamp, active_effect_registry) and died with battle_resolver.gd — V1 replaced
# high-rank activation with a cultivation gate (CultivatorRules.can_activate)
# and has no soul-drain channel.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func test_school_starters_exist_and_match_school() -> void:
	var cat := catalog()
	var schools: Dictionary = cat["schools"]
	assert_true(schools.has("soul"), "soul school present")
	for gu_id in schools["soul"]["starter_gu_ids"]:
		var gu: Dictionary = cat["gu_by_id"][str(gu_id)]
		assert_eq(str(gu["school"]), "soul", "starter %s" % str(gu_id))
