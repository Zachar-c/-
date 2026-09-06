extends GutTest


# Opening fairness regression (2026-08-27 playthrough findings), re-anchored
# on the V1 battle (B1 bucket C 2026-09-06):
# 1. A broke player could not play a single gu card on turn 1. In V1 the fix
#    is structural: punch costs zero true_qi (one thought only) and thoughts
#    are seeded from soul at battle start, so a 0-true-qi opener can always
#    act. Gu casts at 0 true_qi are rejected (insufficient_true_qi).
# 2. ridge_hound pounce at 3 damage per turn vs 6 opening HP was a forced
#    loss against a 3 HP enemy; the intent now deals 2 (data pin below).
# NOTE: the in-battle preview legs (punch warns about the live counter, the
# light probe must not claim it, guarding clears it) asserted over the legacy
# battle envelope (battle.hand + enemy reactions arrays). V1 battles carry no
# reaction dicts, so those fixtures cannot migrate; re-basing the counter
# forewarning onto the V1 shape is tracked with the action_preview_service
# work item (B1 bucket C).

const RunStateScript = preload("res://scripts/domain/run_state.gd")
const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_ridge_hound_intent_deals_two_damage() -> void:
	var enemy: Dictionary = catalog.get("enemy_by_id", {}).get("ridge_hound", {})
	assert_false(enemy.is_empty(), "ridge_hound must exist in the catalog")
	assert_eq(int(enemy.get("intent", {}).get("damage", -1)), 2,
		"pounce damage must be 2 so a 6 HP opener is survivable")


func test_battle_starts_with_full_action_pool() -> void:
	var run = RunStateScript.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "ridge_hound"}, run, catalog)
	assert_true(bool(battle.get("player", {}).has("thoughts")), "V1 battle seeds thoughts")
	var thoughts := int(battle["player"]["thoughts"])
	assert_gt(thoughts, 0, "起手必有念头可行动")
	assert_eq(int(battle["player"]["used_this_turn"]), 0, "起手全部念头可用")
	assert_eq(int(battle["player"]["true_qi"]), int(battle["player"]["true_qi_max"]),
		"V1 起手真元满（不存在零真元开局卡死）")


func test_zero_true_qi_player_still_acts_via_punch_then_blocks() -> void:
	# 真元 0 不能催蛊，但拳脚零真元耗 1 念头；魂魄 1 → 2 念头起手必然可行动。
	var run = RunStateScript.new_run(101)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var slots: Array = battle.get("gu_slots", [])
	assert_false(slots.is_empty(), "starter gu must be offered in V1 slots")
	battle["player"]["true_qi"] = 0
	var instance_id := str((slots[0] as Dictionary).get("instance_id", ""))
	var gu_attempt := FacadeScript.apply_turn(battle, run, {"type": "use_gu", "instance_id": instance_id}, catalog)
	assert_false(bool(gu_attempt.get("accepted", true)), "零真元催蛊被拒")
	assert_eq(gu_attempt.get("feeds", []), ["insufficient_true_qi"])
	var thoughts_before := int(battle["player"]["thoughts"])
	var punch := FacadeScript.apply_turn(battle, run, {"type": "basic_attack"}, catalog)
	assert_true(bool(punch.get("accepted", false)), "拳脚零真元可行动")
	assert_eq(int(punch["battle"]["player"]["thoughts"]), thoughts_before - 1, "拳脚耗 1 念头")

