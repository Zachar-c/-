extends GutTest


# Spec-v4 phase-2 (T4.2): battle2 basic actions, distance bands, speed
# conflicts and the §10.4 defense pipeline. All beast numbers project through
# GuBalance (never hand-written); battle settlement stays deterministic.
# Acceptance: #13 (fixed defense to zero, durable absorb), #14 numeric half
# (same-rank beasts fight at their own scale) and #16 partial (discrete
# distance / speed / disengage rules - no continuous time units).


const ActionResolverScript = preload("res://scripts/domain/action_resolver.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_fixed_defense_can_reduce_damage_to_zero() -> void:
	# Acceptance #13: §10.4 fixed defense may bring damage to 0; no forced
	# minimum damage.
	var out := ActionResolverScript.resolve_damage(20.0, 0.0, 20.0, 0.0)
	assert_almost_eq(float(out["damage"]), 0.0, 0.0001)
	assert_eq(str(out["order"]), "temp,fixed,ratio")


func test_durable_absorb_consumes_gradually_and_can_deplete_in_one_hit() -> void:
	# Acceptance #13: durable protection is consumed across attacks; one heavy
	# hit can exhaust it; everything the absorb cannot cover moves on down the
	# pipeline.
	var first := ActionResolverScript.resolve_damage(20.0, 30.0, 0.0, 0.0)
	assert_almost_eq(float(first["damage"]), 0.0, 0.0001)
	assert_almost_eq(float(first["temporary_left"]), 10.0, 0.0001)
	var second := ActionResolverScript.resolve_damage(20.0, 10.0, 0.0, 0.0)
	assert_almost_eq(float(second["damage"]), 10.0, 0.0001)
	assert_almost_eq(float(second["temporary_left"]), 0.0, 0.0001)
	var single := ActionResolverScript.resolve_damage(20.0, 5.0, 0.0, 0.0)
	assert_almost_eq(float(single["damage"]), 15.0, 0.0001)
	assert_almost_eq(float(single["temporary_left"]), 0.0, 0.0001)


func test_defense_order_applies_temp_then_fixed_then_ratio() -> void:
	# §10.4: raw -> temporary absorb -> body fixed defense -> ratio -> health.
	var out := ActionResolverScript.resolve_damage(30.0, 10.0, 8.0, 20.0)
	assert_almost_eq(float(out["damage"]), 9.6, 0.0001)
	assert_almost_eq(float(out["temporary_left"]), 0.0, 0.0001)


func test_beast_stats_project_through_gu_balance() -> void:
	# Acceptance #14 numeric half: §14.3 same-rank beast body comes from
	# GuBalance projections - rank 3 -> 800 body, 160 heavy, 32 fixed defense.
	var stats := ActionResolverScript.beast_stats(3, catalog)
	assert_almost_eq(float(stats["health"]), 800.0, 0.0001)
	assert_almost_eq(float(stats["strength"]), 800.0, 0.0001)
	assert_almost_eq(float(stats["body_capacity"]), 800.0, 0.0001)
	assert_almost_eq(float(stats["heavy"]), 160.0, 0.0001)
	assert_almost_eq(float(stats["fixed_defense"]), 32.0, 0.0001)
	# The projection is config-driven, not a copied table.
	var tuned := catalog.duplicate(true)
	var balance := (catalog["balance"] as Dictionary).duplicate(true)
	balance["human_base_health"] = 50
	tuned["balance"] = balance
	var tuned_stats := ActionResolverScript.beast_stats(1, tuned)
	assert_almost_eq(float(tuned_stats["health"]), 100.0, 0.0001)


func test_distance_bands_are_discrete_one_band_per_move() -> void:
	# Acceptance #16: 接触/近距/中距/远距 - a basic move changes one band.
	assert_eq(ActionResolverScript.move_one_band("touch", "farther"), "close")
	assert_eq(ActionResolverScript.move_one_band("close", "farther"), "medium")
	assert_eq(ActionResolverScript.move_one_band("medium", "closer"), "close")
	assert_eq(ActionResolverScript.move_one_band("far", "farther"), "far",
			"far stays at the edge")
	assert_eq(ActionResolverScript.move_one_band("touch", "closer"), "touch")


func test_unarmed_strike_only_from_contact_and_completes_at_damage() -> void:
	# §13.3/§13.2: unarmed strikes are only initiated and landed at contact;
	# the strike's main effect happens at completion.
	assert_true(ActionResolverScript.strike_possible("touch", "touch"))
	assert_false(ActionResolverScript.strike_possible("touch", "close"))
	assert_false(ActionResolverScript.strike_possible("close", "touch"))
	var power := float(ActionResolverScript.unarmed_strike_power(100.0, 1.0, catalog))
	assert_almost_eq(power, 20.0, 0.0001)
	assert_almost_eq(power, float(GuBalanceScript.unarmed_raw_damage(100.0, 1.0, catalog)), 0.0001)


func test_strike_stops_when_target_leaves_contact_before_resolution() -> void:
	# §13.3: if the target leaves contact before resolution the strike stops;
	# the spent thought is not refunded and no entity resources are consumed.
	var outcome := ActionResolverScript.strike_resolution("close", "touch", 20.0)
	assert_eq(str(outcome["status"]), "stopped_target_left_contact")
	assert_false(bool(outcome.get("thought_refunded", false)))


func test_disengage_opens_one_reaction_window_with_no_free_attack() -> void:
	# §13.4: moving from touch to close opens exactly one disengage window; no
	# free attack; reactions need reserved thought plus a legal reaction.
	var disengaged := ActionResolverScript.disengage_window("touch", "close")
	assert_true(bool(disengaged["open"]))
	assert_false(ActionResolverScript.is_legal_disengage_reaction("strike"),
			"ordinary unarmed strike is not a disengage reaction")
	assert_true(ActionResolverScript.is_legal_disengage_reaction("grapple"))
	assert_true(ActionResolverScript.is_legal_disengage_reaction("intercept"))
	var without_thought := ActionResolverScript.reaction_allowed(false, "grapple")
	assert_false(bool(without_thought["ok"]))
	assert_eq(str(without_thought["reason"]), "no_reserved_thought")
	var with_thought := ActionResolverScript.reaction_allowed(true, "grapple")
	assert_true(bool(with_thought["ok"]))


func test_speed_conflict_phase_then_speed_then_simultaneous() -> void:
	# §13.5/§16: phase beats speed; same phase compares conflict_speed; equal
	# speed resolves simultaneously.
	assert_eq(str(ActionResolverScript.conflict_order("standard", 5, "quick", 1)),
			"b_first", "a faster phase resolves first regardless of speed")
	assert_eq(str(ActionResolverScript.conflict_order("quick", 5, "quick", 1)),
			"a_first")
	assert_eq(str(ActionResolverScript.conflict_order("quick", 1, "quick", 5)),
			"b_first")
	assert_eq(str(ActionResolverScript.conflict_order("quick", 3, "quick", 3)),
			"simultaneous")
	assert_eq(int(ActionResolverScript.conflict_speed(3, 1)), 4)


func test_speed_parameters_live_in_balance_json() -> void:
	# §13.5: ordinary base speed 3, common range 1-5, modifiers -1/0/+1.
	var balance: Dictionary = catalog["balance"]
	assert_eq(int(balance["base_speed"]), 3)
	assert_eq(int(balance["speed_min"]), 1)
	assert_eq(int(balance["speed_max"]), 5)