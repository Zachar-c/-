extends GutTest


# Spec-v4 phase-2 (T3.2): cultivator model - true-yuan activation gate
# (§11.2), down-rank cost delegation (§11.2), natural recovery (§11.4),
# thought capacity (§12.1) and the mortal body (§14.1). The rules are pure
# statics; every tuning value comes from balance.json via GuBalance, which is
# the only formula source (growth gate).


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_ascension_never_auto_grows_thought_or_body() -> void:
	# Acceptance #5 numeric half: a low-turn and a high-turn cultivator
	# project identical thought capacity and body - 升转零自动增长.
	var low := {"stage": 0, "cultivation": 1, "speed": 2, "soul": 1}
	var high := {"stage": 2, "cultivation": 5, "speed": 2, "soul": 1}
	var low_body := CultivatorRulesScript.body(low, catalog)
	var high_body := CultivatorRulesScript.body(high, catalog)
	for key in ["health", "strength", "body_capacity"]:
		assert_eq(float(low_body[key]), float(high_body[key]),
				"%s must not grow with ascension" % key)
	assert_eq(int(CultivatorRulesScript.thought_capacity(low, catalog)),
			int(CultivatorRulesScript.thought_capacity(high, catalog)))
	assert_eq(int(low["speed"]), int(high["speed"]))


func test_low_rank_cannot_drive_high_rank_unless_exception() -> void:
	# Acceptance #6: §11.2 gate - 1-turn true yuan cannot drive a 2-turn gu;
	# rare gu pass low_rank_exception; equal or higher rank always allowed.
	assert_false(CultivatorRulesScript.can_activate(1, 2))
	assert_false(CultivatorRulesScript.can_activate(1, 5))
	assert_true(CultivatorRulesScript.can_activate(2, 2))
	assert_true(CultivatorRulesScript.can_activate(2, 1))
	assert_true(CultivatorRulesScript.can_activate(1, 2, true))


func test_down_rank_cost_delegates_and_matches_spec() -> void:
	# Acceptance #6 formula half: 2-turn cultivator driving a 1-turn 10% gu
	# costs 5%; same rank keeps the native 10%. The CultivatorRules entry is a
	# thin delegate - GuBalance remains the only formula implementation.
	var via_rules := float(CultivatorRulesScript.actual_cost_percent(0.1, 1, 2, catalog))
	var via_balance := float(GuBalanceScript.actual_cost_percent(0.1, 1, 2, catalog))
	assert_almost_eq(via_rules, 0.05, 0.0001)
	assert_almost_eq(via_rules, via_balance, 0.0001)
	assert_almost_eq(float(CultivatorRulesScript.actual_cost_percent(0.1, 2, 2, catalog)),
			0.1, 0.0001)


func test_human_body_projects_the_100_scale() -> void:
	# Acceptance #14 numeric half: the cultivator body is 100-scale, derived
	# from the human_base_* anchors, never from ascension or soul.
	var body := CultivatorRulesScript.body({"stage": 0, "soul": 9}, catalog)
	assert_almost_eq(float(body["health"]), 100.0, 0.0001)
	assert_almost_eq(float(body["strength"]), 100.0, 0.0001)
	assert_almost_eq(float(body["body_capacity"]), 100.0, 0.0001)


func test_thought_capacity_is_decoupled_from_soul_and_catalog_driven() -> void:
	# §12.1: thoughts are wholly separate from soul - changing the soul value
	# never moves the thought capacity; the wisdom bonus comes from the
	# catalog's wisdom-tagged gu, and the base rides balance.json.
	assert_eq(int(CultivatorRulesScript.thought_capacity({"soul": 99}, catalog)), 3)
	assert_eq(int(CultivatorRulesScript.thought_capacity({"soul": 1}, catalog)), 3)

	var tuned := catalog.duplicate(true)
	var gus: Array = (catalog["gu"] as Array).duplicate(true)
	gus.append({"id": "wisdom_origin_gu", "tags": ["wisdom", "light"]})
	tuned["gu"] = gus
	assert_eq(int(CultivatorRulesScript.thought_capacity({"soul": 5}, tuned)), 4)

	var balance_tuned := (tuned["balance"] as Dictionary).duplicate(true)
	balance_tuned["thought_base_capacity"] = 4
	tuned["balance"] = balance_tuned
	assert_eq(int(CultivatorRulesScript.thought_capacity({"soul": 5}, tuned)), 5)