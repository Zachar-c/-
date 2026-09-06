extends GutTest


## Phase S4 slice 2: support synergy must be visible where the player looks -
## the snapshot hand cards are the real UI data source for the battle screen
## (the preview service still rides the legacy blueprint layer). Static
## declaration rides on the small light card copy; the live in-turn boost
## shows up on same-school cards while battle.turn_supports is set.


const V1 := preload("res://scripts/domain/v1_battle_resolver.gd")
const Preview := preload("res://scripts/domain/action_preview_service.gd")
const SnapshotBuilder := preload("res://scripts/presentation/run_snapshot_builder.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = _catalog_with_demo_gu()


func test_small_light_card_declares_the_support_statically() -> void:
	var run := _run_with_gu([
		{"definition_id": "s4_small_light_gu"},
		{"definition_id": "s4_moonlight_gu"},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy(20)])
	var cards := SnapshotBuilder._v1_hand(battle, catalog)
	var card := _card_for_gu(cards, "s4_small_light_gu")
	assert_false(card.is_empty(), "small light card must be in the hand snapshot")
	assert_string_contains(str(card["summary"]), "+2",
			"support declaration must ride on the card copy")


func test_active_support_is_visible_on_same_school_card() -> void:
	var run := _run_with_gu([
		{"definition_id": "s4_small_light_gu"},
		{"definition_id": "s4_moonlight_gu"},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy(20)])
	battle = V1.play_gu(battle, 0)["battle"]  # small light registers light +2
	var cards := SnapshotBuilder._v1_hand(battle, catalog)
	var card := _card_for_gu(cards, "s4_moonlight_gu")
	assert_false(card.is_empty(), "moonlight card must be in the hand snapshot")
	var risks := (card["known_risk"] as Array).map(func(v): return str(v))
	var joined := " / ".join(PackedStringArray(risks))
	assert_string_contains(joined, "光道", "active support must name the school")
	assert_string_contains(joined, "+2", "active support must name the bonus")


func test_no_support_hint_without_a_registered_boost() -> void:
	var run := _run_with_gu([{"definition_id": "s4_moonlight_gu"}])
	var battle: Dictionary = V1.start(run, catalog, [_enemy(20)])
	var cards := SnapshotBuilder._v1_hand(battle, catalog)
	var card := _card_for_gu(cards, "s4_moonlight_gu")
	var risks := " / ".join(PackedStringArray((card["known_risk"] as Array).map(func(v): return str(v))))
	assert_false(risks.contains("支援"), "no support hint without small light")


func test_turn_supports_are_projected_into_the_battle_snapshot() -> void:
	# The transparency red line at the data level: the snapshot battle() view
	# carries turn_supports so any widget can read the live state.
	var run := _run_with_gu([
		{"definition_id": "s4_small_light_gu"},
		{"definition_id": "s4_moonlight_gu"},
	])
	var battle: Dictionary = V1.start(run, catalog, [_enemy(20)])
	battle = V1.play_gu(battle, 0)["battle"]
	var projected: Dictionary = SnapshotBuilder.battle_turn_supports(battle)
	assert_eq(int(projected.get("light", 0)), 2,
			"turn_supports must be projected into the snapshot")


# ---------- fixtures ----------


func _catalog_with_demo_gu() -> Dictionary:
	var cat := ContentCatalog.load_all()
	cat["gu_by_id"]["s4_small_light_gu"] = {
		"id": "s4_small_light_gu", "combat": "reveal_hidden_bonus", "school": "light",
		"role": "scout", "rarity": "common", "true_qi_cost": 1,
		"v1_effect": {"kind": "strike", "amount": 1, "support_school": "light", "support_bonus": 2},
	}
	cat["gu_by_id"]["s4_moonlight_gu"] = {
		"id": "s4_moonlight_gu", "combat": "moonlight_strike", "school": "light",
		"role": "attack", "rarity": "common", "true_qi_cost": 1,
		"v1_effect": {"kind": "strike", "amount": 3},
	}
	return cat


func _run_with_gu(entries: Array) -> RunState:
	var run := RunState.new_run(20260906)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var instance_id := "gu_%03d" % (index + 1)
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": str(entry["definition_id"]),
			"state": "refined",
			"rank": int(entry.get("rank", 1)),
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()
	return run


func _enemy(hp: int) -> Dictionary:
	return {
		"id": "s4_enemy", "label": "测试敌人", "hp": hp, "alive": true,
		"intent": {"kind": "attack", "label": "测试意图", "damage": 0},
	}


func _card_for_gu(cards: Array[Dictionary], gu_id: String) -> Dictionary:
	for card_value in cards:
		var card: Dictionary = card_value
		if str(card.get("name", "")) == DisplayText.gu(gu_id):
			return card
	return {}
