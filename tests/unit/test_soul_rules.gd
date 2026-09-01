extends GutTest


# Spec-v4 phase-2 (T8.2): soul dao - the five soul quantities (§15.4),
# three operations (strengthen / refine / calm), gated soul collection
# (§15.3, acceptance #17) and the bestiality endpoint gate (§16.10).
# The new keys never touch the legacy soul / soul_max / soul_control_limit
# (T10.1 retirement scope) - zero coupling is asserted. Irreversible paths
# (float-burst death, bestiality) only produce confirmation markers.


const SoulRulesScript = preload("res://scripts/domain/soul_rules.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _cultivator(extra: Dictionary = {}) -> Dictionary:
	var cultivator := {
		"soul_magnitude": 1.0,
		"soul_safe_capacity": 4.0,
		"soul_calm": 60,
		"soul_nature": "human",
		"beast_nature": 0.0,
		"soul": 1, "soul_max": 4, "soul_control_limit": 2,
	}
	for key in extra:
		cultivator[key] = extra[key]
	return cultivator


func test_five_quantities_declared_and_decoupled_from_legacy_keys() -> void:
	# §15.4: magnitude / safe capacity / calm 0-100 / single nature / beast
	# nature; mutating the legacy soul keys never moves the five quantities.
	var cultivator := _cultivator()
	assert_eq(SoulRulesScript.quantity_names().size(), 5)
	var before := SoulRulesScript.snapshot(cultivator)
	cultivator["soul"] = 99
	cultivator["soul_max"] = 99
	cultivator["soul_control_limit"] = 99
	var after := SoulRulesScript.snapshot(cultivator)
	assert_eq(after, before, "legacy soul keys must not couple into the five quantities")


func test_soul_nature_is_singular_and_replacing() -> void:
	# §15.4: one nature at a time - assigning replaces, never mixes.
	var cultivator := _cultivator()
	var verdict := SoulRulesScript.set_nature(cultivator, "wolf_spirit")
	assert_true(bool(verdict["ok"]), str(verdict))
	assert_eq(str(verdict["cultivator"]["soul_nature"]), "wolf_spirit")
	var mixed := SoulRulesScript.validate_nature({"soul_nature": ["human", "wolf_spirit"]})
	assert_false(bool(mixed["ok"]))


func test_three_operations_respect_boundaries() -> void:
	# strengthen raises magnitude, refine raises safe capacity, calm raises
	# composure; each is a pure rule over the declared inputs.
	var strengthened := SoulRulesScript.strengthen_soul(_cultivator(), 5.0)
	assert_almost_eq(float(strengthened["cultivator"]["soul_magnitude"]), 6.0, 0.0001)
	var refined := SoulRulesScript.refine_soul(_cultivator(), 2.0)
	assert_almost_eq(float(refined["cultivator"]["soul_safe_capacity"]), 6.0, 0.0001)
	var calmed := SoulRulesScript.calm_soul(_cultivator(), 15.0)
	assert_almost_eq(float(calmed["cultivator"]["soul_calm"]), 75.0, 0.0001)
	var bust := SoulRulesScript.strengthen_soul(_cultivator(), -1.0)
	assert_false(bool(bust["ok"]))
	assert_eq(str(bust["reason"]), "invalid_amount")


func test_collect_soul_gates_by_soul_and_means() -> void:
	# Acceptance #17: soulless targets yield zero with a reason; ordinary
	# souls need a declared means (capacity / efficiency / loss); no means or
	# a full capacity means no stock is created at all.
	var soulless := SoulRulesScript.collect_soul({"has_soul": false}, {}, _cultivator())
	assert_false(bool(soulless["ok"]))
	assert_almost_eq(float(soulless["yield"]), 0.0, 0.0001)
	var no_means := SoulRulesScript.collect_soul({"has_soul": true}, {}, _cultivator())
	assert_false(bool(no_means["ok"]))
	assert_eq(str(no_means["reason"]), "no_means_declared")
	var full := SoulRulesScript.collect_soul({"has_soul": true, "soul_weight": 5.0},
			{"capacity": 4.0, "efficiency": 1.0, "loss": 0.0}, _cultivator())
	assert_false(bool(full["ok"]))
	assert_eq(str(full["reason"]), "means_capacity_full")
	var collected := SoulRulesScript.collect_soul({"has_soul": true, "soul_weight": 5.0},
			{"capacity": 10.0, "efficiency": 0.8, "loss": 0.1}, _cultivator())
	assert_true(bool(collected["ok"]), str(collected))
	assert_almost_eq(float(collected["yield"]), 5.0 * 0.8 * (1.0 - 0.1), 0.0001)


func test_float_above_capacity_allowed_but_burst_death_needs_confirm() -> void:
	# §15.4: floating above capacity is legal and unstable; an expected
	# direct burst death carries the second-confirmation marker (soul_burst).
	var cultivator := _cultivator()
	cultivator["soul_magnitude"] = 6.0
	assert_true(bool(SoulRulesScript.float_above_capacity(cultivator)))
	var forecast := SoulRulesScript.soul_growth_forecast(cultivator, 10.0)
	assert_true(bool(forecast["lethal_confirm_required"]))
	assert_eq(str(forecast["cause"]), "soul_burst")


func test_calm_stages_and_beast_nature_layer() -> void:
	# §15.4: low composure layers (emotional -> beast emerging -> soul
	# departure / loss of control); beast nature accumulates independently;
	# the raving threshold is exposed with keep/use/purify options.
	var layered := SoulRulesScript.composure_layers(_cultivator({"soul_calm": 20}))
	assert_true(layered.has("emotional"))
	var beast := _cultivator({"soul_calm": 20, "beast_nature": 0.6})
	assert_true(bool(SoulRulesScript.beast_nature_emerging(beast)))
	var expose := SoulRulesScript.beast_sight(beast)
	assert_true(float(expose["current_beast"]) > 0.0)
	assert_true((expose["options"] as Array).has("keep"))
	assert_true((expose["options"] as Array).has("use"))
	assert_true((expose["options"] as Array).has("purify"))


func test_bestiality_endpoint_only_marks_never_silently_ends() -> void:
	# §16.10: reaching the danger condition only returns a trigger marker;
	# the run never silently terminates on any numeric threshold.
	var cultivator := _cultivator({"beast_nature": 2.0, "soul_calm": 5})
	var verdict := SoulRulesScript.bestiality_endpoint_check(cultivator)
	assert_true(bool(verdict["beastiality_triggered"]))
	assert_true(bool(verdict["confirm_required"]))
	assert_false(bool(verdict.get("terminal", false)),
			"a threshold must never silently end the run")
	assert_eq(str(verdict["endpoint"]), "bestiality")


func test_new_run_declares_the_five_quantities() -> void:
	var state: RunState = RunStateScript.new_run(31)
	var cultivator: Dictionary = state.cultivator
	for key in ["soul_magnitude", "soul_safe_capacity", "soul_calm", "soul_nature", "beast_nature"]:
		assert_true(cultivator.has(key), "new_run must declare %s" % key)