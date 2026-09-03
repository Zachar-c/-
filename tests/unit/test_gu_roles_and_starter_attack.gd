extends GutTest


const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const BattleCommandFacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")


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


func test_starter_combat_gu_are_usable_and_have_observable_effects() -> void:
	var starter_ids := [
		"small_light_gu", "trail_eye_gu", "blood_moss_gu", "thorn_whip_gu",
		"mist_step_gu", "venom_thread_gu", "stone_shell_gu",
	]
	var run := RunState.new_run(101)
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_instances = {}
	for index in starter_ids.size():
		var instance_id := "starter_%02d" % index
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
		run.gu_instances[instance_id] = GuInstanceScript.new_instance(
		starter_ids[index], instance_id, catalog)
	var facade_battle := BattleCommandFacadeScript.start({"enemy_kind": "beast_swarm"}, run, catalog)
	assert_eq((facade_battle["gu_slots"] as Array).size(), starter_ids.size())
	for index in starter_ids.size():
		var before := facade_battle.duplicate(true)
		var slot: Dictionary = before["gu_slots"][index]
		assert_false((slot.get("effect", {}) as Dictionary).is_empty(),
			"starter gu %s must define a V1 effect" % starter_ids[index])
		var result := BattleCommandFacadeScript.apply_turn(
			facade_battle, run, {"type": "use_gu", "instance_id": slot["instance_id"]}, catalog)
		assert_true(bool(result["accepted"]), "starter gu %s must be playable" % starter_ids[index])
		var after: Dictionary = result["battle"]
		assert_true(_battle_changed_by_gu(before, after),
			"starter gu %s must produce an observable effect" % starter_ids[index])
		# Reset the per-turn single-use gate while retaining the tested effect.
		facade_battle = BattleCommandFacadeScript.start({"enemy_kind": "beast_swarm"}, run, catalog)


func _battle_changed_by_gu(before: Dictionary, after: Dictionary) -> bool:
	var before_player: Dictionary = before["player"]
	var after_player: Dictionary = after["player"]
	if int(before_player["hp"]) != int(after_player["hp"]):
		return true
	if int(before_player.get("shield", 0)) != int(after_player.get("shield", 0)):
		return true
	if before_player.get("buffs", {}) != after_player.get("buffs", {}):
		return true
	if before_player.get("statuses", {}) != after_player.get("statuses", {}):
		return true
	if before_player.get("position", 0) != after_player.get("position", 0):
		return true
	for index in (before["enemies"] as Array).size():
		var old_enemy: Dictionary = before["enemies"][index]
		var new_enemy: Dictionary = after["enemies"][index]
		if int(old_enemy["hp"]) != int(new_enemy["hp"]):
			return true
		if old_enemy.get("statuses", {}) != new_enemy.get("statuses", {}):
			return true
	return false


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
