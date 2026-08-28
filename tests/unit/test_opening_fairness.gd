extends GutTest


# Opening fairness regression (2026-08-27 playthrough findings):
# 1. A broke player (essence 0) could not play a single gu card on turn 1 --
#    every battle now starts with a base first-turn energy grant of 1.
# 2. ridge_hound pounce at 3 damage per turn vs 6 opening HP was a forced
#    loss against a 3 HP enemy; the intent now deals 2.
# 3. In-battle card previews must surface live direct-strike reactions
#    (§16.5) on the paths the resolver actually swallows: basic punch and
#    thorn whip strike. The light probe bypasses reactions and must NOT
#    claim the risk.

const RunStateScript = preload("res://scripts/domain/run_state.gd")
const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_ridge_hound_intent_deals_two_damage() -> void:
	var enemy: Dictionary = catalog.get("enemy_by_id", {}).get("ridge_hound", {})
	assert_false(enemy.is_empty(), "ridge_hound must exist in the catalog")
	assert_eq(int(enemy.get("intent", {}).get("damage", -1)), 2,
		"pounce damage must be 2 so a 6 HP opener is survivable")


func test_battle_starts_with_base_first_turn_energy() -> void:
	var run = RunStateScript.new_run(101)
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "ridge_hound"}, run, catalog)
	assert_eq(int(battle["first_turn_energy"]), 1, "base grant guarantees an opening action")
	assert_eq(int(battle["action_energy"]), 1, "base grant is spendable immediately")


func test_essence_zero_player_can_act_on_turn_one_then_blocks() -> void:
	var run = RunStateScript.new_run(101)
	run.essence = 0
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var first := BattleResolverScript.take_turn(battle, {"type": "use_gu", "gu_id": "small_light_gu"}, run, catalog)
	assert_eq(str(first.get("result", "")), "ongoing", "base first-turn energy must fund one card at 0 essence")
	assert_eq(int(first["battle"]["action_energy"]), 0, "the base grant is consumed")
	var second := BattleResolverScript.take_turn(first["battle"], {"type": "use_gu", "gu_id": "small_light_gu"}, first["state"], catalog)
	assert_true(second["feeds"].has("insufficient_essence"), "after the base grant is spent, costs need real essence")


func test_punch_card_warns_about_live_direct_strike_reaction() -> void:
	var run = RunStateScript.new_run(101)
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var cards := ActionPreviewServiceScript.preview_battle_actions(battle, run, catalog)
	var punch := {}
	for card in cards:
		if str(card.get("id", "")) == "battle.basic.punch":
			punch = card
	assert_false(punch.is_empty(), "punch card must be offered")
	var risk_text := "\n".join(punch.get("known_risk", []))
	assert_true(risk_text.contains("反口撕咬"), "punch preview must name the live counter")
	assert_true(risk_text.contains("吞下"), "punch preview must state the consequence")


func test_probe_card_does_not_claim_reaction_risk_it_does_not_trigger() -> void:
	var run = RunStateScript.new_run(101)
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var cards := ActionPreviewServiceScript.preview_battle_actions(battle, run, catalog)
	for card in cards:
		if str(card.get("title", "")) == "小光蛊":
			var risk_text := "\n".join(card.get("known_risk", []))
			assert_false(risk_text.contains("反口撕咬"),
				"the light probe bypasses reactions, its preview must not claim the counter risk")
			return
	assert_true(false, "small light gu card must be offered in the opening hand")


func test_bound_counter_clears_the_punch_warning() -> void:
	var run = RunStateScript.new_run(101)
	var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "ridge_hound"}, run, catalog)
	# The hound's counter is a "guarded"-status reaction: guarding clears it.
	battle["flags"].append("guarded")
	var cards := ActionPreviewServiceScript.preview_battle_actions(battle, run, catalog)
	for card in cards:
		if str(card.get("id", "")) == "battle.basic.punch":
			var risk_text := "\n".join(card.get("known_risk", []))
			assert_false(risk_text.contains("反口撕咬"),
				"a bound enemy cannot retaliate, the warning must clear")
			return
	assert_true(false, "punch card must be offered")
