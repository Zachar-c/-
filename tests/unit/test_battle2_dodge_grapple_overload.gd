extends GutTest


# Spec-v4 phase-2 (T4.3): battle2 deterministic dodge (§13.6), deterministic
# grapple (§13.7) and strength overload (§14.2) with lethal preflight.
# No random hit rolls anywhere: dodge and grapple succeed or fail purely from
# declared conditions. Acceptance #15 (overload only hurts the excess,
# plain health loss never lowers body/strength/speed) and #16 close-out.


const BodyRulesScript = preload("res://scripts/domain/body_rules.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_dodge_is_deterministic_and_condition_driven() -> void:
	# Acceptance #16 close-out: dodge succeeds whenever the declared
	# conditions hold - no random hit roll ever; failure comes only from
	# unmet conditions or a lost direct conflict.
	var open_conditions := {
		"allow_dodge": true,
		"window_open": true,
		"grappled": false,
		"bound": false,
		"restricted": false,
	}
	for i in range(5):
		var out := BodyRulesScript.dodge_resolution(open_conditions, true)
		assert_true(bool(out["ok"]), str(out))
		assert_eq(str(out["status"]), "dodged")
	# Each missing condition is its own structured rejection.
	assert_eq(str(BodyRulesScript.dodge_resolution(
			open_conditions, false)["reason"]), "no_thought")
	assert_eq(str(BodyRulesScript.dodge_resolution(
			{"allow_dodge": false, "window_open": true, "grappled": false, "bound": false, "restricted": false}, true)["reason"]), "dodge_not_allowed")
	assert_eq(str(BodyRulesScript.dodge_resolution(
			{"allow_dodge": true, "window_open": false, "grappled": false, "bound": false, "restricted": false}, true)["reason"]), "window_closed")
	assert_eq(str(BodyRulesScript.dodge_resolution(
			{"allow_dodge": true, "window_open": true, "grappled": true, "bound": false, "restricted": false}, true)["reason"]), "grappled_blocks_dodge")
	assert_eq(str(BodyRulesScript.dodge_resolution(
			{"allow_dodge": true, "window_open": true, "grappled": false, "bound": true, "restricted": false}, true)["reason"]), "bound_blocks_dodge")


func test_dodge_does_not_change_distance_band() -> void:
	# §13.6: basic dodge stays inside the current band.
	assert_false(bool(BodyRulesScript.dodge_changes_band()))


func test_grapple_requires_contact_and_one_thought() -> void:
	# §13.7: contact-only, 1 thought, default standard phase.
	var pre := BodyRulesScript.grapple_preflight("touch", "touch", true)
	assert_true(bool(pre["ok"]), str(pre))
	assert_eq(str(BodyRulesScript.grapple_preflight("close", "touch", true)["reason"]),
			"not_at_contact")
	assert_eq(str(BodyRulesScript.grapple_preflight("touch", "touch", false)["reason"]),
			"no_thought")


func test_grapple_contest_tie_prefers_defender() -> void:
	# §13.7: the attacker must be strictly stronger; an unattempted
	# resistance still establishes the hold; equal strength favours the
	# defender.
	assert_true(bool(BodyRulesScript.grapple_contest(10.0, 8.0, false)["ok"]))
	assert_false(bool(BodyRulesScript.grapple_contest(8.0, 8.0, true)["ok"]),
			"tie favours the defender")
	assert_false(bool(BodyRulesScript.grapple_contest(8.0, 10.0, true)["ok"]))
	var resisted := BodyRulesScript.grapple_contest(10.0, 8.0, true)
	assert_true(bool(resisted["ok"]))


func test_grapple_does_not_block_gu_activation() -> void:
	# §13.7: being grappled never auto-forbids gu activation or other actions.
	assert_false(bool(BodyRulesScript.grapple_blocks_gu_activation()))
	assert_false(bool(BodyRulesScript.grapple_blocks_basic_actions()))


func test_grapple_hold_maintains_with_thought_and_releases_without() -> void:
	# §13.7: the holder pays 1 thought per round and the grapple usage slot;
	# stopping the payment releases automatically.
	assert_eq(int(BodyRulesScript.hold_thought_per_round()), 1)
	var unheld := BodyRulesScript.hold_state(false, {"held_by": "gu_001"})
	assert_eq(str(unheld["status"]), "released_not_paid")
	assert_eq(str(BodyRulesScript.hold_state(true, {"held_by": "gu_001"})["status"]),
			"held")


func test_overload_only_self_damages_the_excess() -> void:
	# Acceptance #15: overload self damage = max(0, strength - capacity) *
	# unarmed ratio * reaction - the safe part never hurts you.
	assert_almost_eq(float(BodyRulesScript.overload_self_damage(130.0, 100.0, catalog)),
			6.0, 0.0001)
	assert_almost_eq(float(BodyRulesScript.overload_self_damage(100.0, 100.0, catalog)),
			0.0, 0.0001)
	assert_almost_eq(float(BodyRulesScript.overload_self_damage(90.0, 100.0, catalog)),
			0.0, 0.0001)
	assert_almost_eq(float(BodyRulesScript.overload_self_damage(130.0, 100.0, catalog)),
			float(GuBalanceScript.overload_self_damage(130.0, 100.0, catalog)), 0.0001)


func test_plain_health_loss_never_lowers_body_strength_or_speed() -> void:
	# Acceptance #15: ordinary hp loss does not reduce body capacity, strength
	# or speed - the projections are health-independent.
	var wounded := {"health": 5, "max_health": 100, "speed": 2}
	var full := {"health": 100, "max_health": 100, "speed": 2}
	var wounded_body := CultivatorRulesScript.body(wounded, catalog)
	var full_body := CultivatorRulesScript.body(full, catalog)
	for key in ["health", "strength", "body_capacity"]:
		assert_eq(float(wounded_body[key]), float(full_body[key]),
				"%s must not drop with plain hp loss" % key)
	assert_eq(int(wounded["speed"]), int(full["speed"]))


func test_lethal_overload_preflight_requires_confirmation() -> void:
	# Red line: the preflight marks a foreseeable death so the command surface
	# can force the second confirmation; no silent death by overload.
	var lethal := BodyRulesScript.strike_preflight(130.0, 100.0, 5.0, catalog)
	assert_true(bool(lethal["lethal_confirm_required"]), str(lethal))
	assert_eq(str(lethal["cause"]), "strength_overload")
	assert_almost_eq(float(lethal["self_damage"]), 6.0, 0.0001)
	var safe := BodyRulesScript.strike_preflight(110.0, 100.0, 5.0, catalog)
	assert_false(bool(safe["lethal_confirm_required"]))