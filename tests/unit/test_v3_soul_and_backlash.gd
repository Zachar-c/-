extends GutTest


# 2026-08-31 数值重做：魂魄并发反噬与转阶反噬已移除（蛊虫无负面效果）。
# 本文件钉住两件事：时限效果仍注册/过期；催动不再扣魂魄与气血。


const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _run_with_gu(gu_ids: Array) -> RunState:
	var run := RunState.new_run(101)
	run.refined_gu_ids = []
	for gu_id in gu_ids:
		run.refined_gu_ids.append(str(gu_id))
	run.gu_ids = run.refined_gu_ids.duplicate()
	var index := 2
	for gu_id in run.refined_gu_ids:
		var instance_id := "gu_%03d" % index
		run.gu_instances[instance_id] = {"instance_id": instance_id, "definition_id": str(gu_id), "state": "refined"}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
		index += 1
	run.essence = 5000
	run.essence_capacity = 5000
	return run


func _command_for_definition(battle: Dictionary, definition_id: String) -> Dictionary:
	var target_id := ""
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", false)) and int(enemy.get("hp", 0)) > 0:
			target_id = str(enemy.get("enemy_id", ""))
			break
	for card_value in battle.get("hand", []):
		var card: Dictionary = card_value
		if str(card.get("definition_id", "")) == definition_id:
			return {
				"type": "action_card",
				"action_id": "battle.%s.%s" % [str(battle.get("battle_id", "")), str(card.get("instance_id", ""))],
				"card_id": definition_id,
				"target_id": target_id,
				"state_version": int(battle.get("hand_version", 0)),
				"expected_phase": str(battle.get("phase", "player")),
			}
	return {}


func test_duration_effect_registers_and_expires_without_soul_cost() -> void:
	var run := _run_with_gu(["stone_shell_gu"])
	var battle := BattleResolverScript.start({"enemy_kind": "ridge_hound", "first_mover": "player"}, run, catalog)
	var result := BattleResolverScript.apply_action_card(battle, run, _command_for_definition(battle, "stone_guard"), catalog)
	assert_true(bool(result.get("accepted", false)), "石甲催动 OK")
	assert_false(result["battle"]["active_effect_registry"].is_empty(), "时限效果注册")
	assert_eq(int(result["state"].cultivator["soul"]), int(run.cultivator["soul"]), "魂魄无损")
	var expired := BattleResolverScript.take_turn(result["battle"], {"type": "end_turn"}, result["state"], catalog)
	assert_true(bool(expired.get("accepted", false)))
	assert_true(expired["battle"]["active_effect_registry"].is_empty(), "到期清除")
	assert_true(expired["battle"]["active_gu_instance_ids"].is_empty())


func test_low_rank_cultivator_uses_higher_rank_gu_without_backlash() -> void:
	# 2026-08-31 裁定：移除所有蛊虫负面效果——低修为催高转蛊无反噬。
	var tuned := catalog.duplicate(true)
	tuned["gu_by_id"] = tuned["gu_by_id"].duplicate(true)
	var tuned_gu: Dictionary = (tuned["gu_by_id"]["small_light_gu"] as Dictionary).duplicate(true)
	tuned_gu["rank"] = 5
	tuned["gu_by_id"]["small_light_gu"] = tuned_gu
	var run := _run_with_gu(["small_light_gu"])
	run.cultivator["soul"] = 1
	var battle := BattleResolverScript.start({"enemy_kind": "ridge_hound", "first_mover": "player"}, run, catalog)
	var result := BattleResolverScript.apply_action_card(battle, run, _command_for_definition(battle, "light_probe"), catalog)
	assert_true(bool(result.get("accepted", false)))
	assert_eq(int(result["state"].cultivator["soul"]), 1, "魂魄无损")
	assert_eq(int(result["state"].health), int(run.health), "气血无损")
	assert_false(result["feeds"].has("rank_backlash"))
	assert_false(result["feeds"].has("soul_backlash"))
