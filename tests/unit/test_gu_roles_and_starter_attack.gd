extends GutTest


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_small_light_starter_deals_attack_damage() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "wild_boar"}, run, catalog)
	var card := _hand_card(battle, "light_probe")
	var internal := BattleResolver._command_for_card_instance(card, catalog)
	var result := BattleResolver.take_turn(battle, internal, run, catalog)

	assert_true(result["accepted"])
	assert_eq(int(result["battle"]["enemy_hp"]), int(battle["enemy_hp"]) - 1)


func test_small_light_attack_keeps_reveal_aspect() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "wild_boar"}, run, catalog)
	var card := _hand_card(battle, "light_probe")
	var result := BattleResolver.take_turn(battle, BattleResolver._command_for_card_instance(card, catalog), run, catalog)

	assert_true(result["battle"]["flags"].has("revealed"))
	assert_eq(int(result["battle"]["delay_progress"]), 1)


func test_small_light_preview_summary_mentions_damage() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "wild_boar"}, run, catalog)
	var cards: Array = ActionPreviewServiceScript.preview_battle_actions(battle, run, catalog)
	var card := _preview_card(cards, battle, "light_probe")
	assert_string_contains(str(card["summary"]), "伤敌")


func test_every_gu_carries_one_of_six_roles() -> void:
	var roles := ["attack", "defense", "movement", "healing", "logistics", "recon"]
	for gu in catalog.get("gu", []):
		var role := str(gu.get("role", ""))
		assert_true(roles.has(role), "gu %s must carry a valid role, got %s" % [gu["id"], role])


func test_role_validation_rejects_missing_and_unknown_role() -> void:
	var tuned := catalog.duplicate(true)
	var gu_list: Array = tuned["gu"]
	var first: Dictionary = gu_list[0].duplicate(true)
	first.erase("role")
	gu_list[0] = first
	tuned["gu"] = gu_list
	tuned["gu_by_id"] = {}
	for gu in gu_list:
		tuned["gu_by_id"][gu["id"]] = gu
	assert_true(_has_hint(ContentCatalogScript.validate(tuned), "missing role"))

	var bad := catalog.duplicate(true)
	var bad_gu: Dictionary = bad["gu"][0].duplicate(true)
	bad_gu["role"] = "utility"
	bad["gu"][0] = bad_gu
	bad["gu_by_id"] = {}
	for gu in bad["gu"]:
		bad["gu_by_id"][gu["id"]] = gu
	assert_true(_has_hint(ContentCatalogScript.validate(bad), "invalid role"))


func _hand_card(battle: Dictionary, definition_id: String) -> Dictionary:
	for card in battle["hand"]:
		if str(card["definition_id"]) == definition_id:
			return card
	push_error("Missing hand card %s" % definition_id)
	return {}


func _preview_card(cards: Array, battle: Dictionary, definition_id: String) -> Dictionary:
	for card in cards:
		if str(card["id"]) == "battle.%s.%s" % [battle["battle_id"], _hand_card(battle, definition_id)["instance_id"]]:
			return card
	push_error("Missing preview card for %s" % definition_id)
	return {}


func _has_hint(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false