extends "res://addons/gut/test.gd"


# B4 stance trio (N1/N3/N5/N6) plus the soul pill shop offer.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const EncounterSessionResolverScript := preload("res://scripts/domain/encounter_session_resolver.gd")
const ActionPreviewServiceScript := preload("res://scripts/domain/action_preview_service.gd")
const ResolverScript := preload("res://scripts/domain/resolver.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func make_state(run_seed: int = 2026) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func test_zero_notoriety_starts_neutral_stance() -> void:
	var state := make_state()
	var begun: Dictionary = EncounterSessionResolverScript.begin(state, {"id": "ridge_black_market", "type": "shop"}, catalog())
	assert_eq(str(begun["session"].get("stance", "")), "neutral")


func test_high_notoriety_forces_hostile_or_extreme_stance() -> void:
	var state := make_state()
	state.cultivator["notorious"] = 10
	var begun: Dictionary = EncounterSessionResolverScript.begin(state, {"id": "ridge_black_market", "type": "shop"}, catalog())
	var stance := str(begun["session"].get("stance", ""))
	assert_true(stance in ["hostile", "extreme_hostile"], "got stance %s" % stance)
	assert_true(
		bool(begun["session"].get("flags", {}).get("reputation_hostile", false)) or bool(begun["session"].get("flags", {}).get("reputation_extreme", false))
	)


func test_same_seed_reproduces_same_stance() -> void:
	var first: Dictionary = EncounterSessionResolverScript.begin(make_state(777), {"id": "ridge_black_market", "type": "shop"}, catalog())
	var second: Dictionary = EncounterSessionResolverScript.begin(make_state(777), {"id": "ridge_black_market", "type": "shop"}, catalog())
	assert_eq(str(first["session"].get("stance", "")), str(second["session"].get("stance", "")))


func test_extreme_stance_blocks_leaving() -> void:
	var state := make_state()
	var begun: Dictionary = EncounterSessionResolverScript.begin(state, {"id": "ridge_caravan", "type": "caravan"}, catalog())
	var session: Dictionary = begun["session"]
	session["stance"] = "extreme_hostile"
	session["flags"]["reputation_extreme"] = true
	var left: Dictionary = EncounterSessionResolverScript.apply(state, session, {"type": "leave_node"}, catalog(), {"id": "ridge_caravan", "type": "caravan"})
	assert_false(bool(left["result"].get("ok", true)))
	assert_eq(str(left["result"].get("reason", "")), "feud_no_escape")


func test_extreme_stance_disables_non_fight_cards() -> void:
	var state := make_state()
	state.encounter_session["stance"] = "extreme_hostile"
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(state, {"id": "toxin_test", "type": "contact", "choices": ["probe", "fight"]}, catalog())
	for card in cards:
		var command: Dictionary = card.get("command", {})
		# 交锋卡两形态（旧 action_id=fight 与散修 resolve_contact/fight）都必须保留。
		var is_fight: bool = str(command.get("action_id", "")) == "fight" \
			or (str(command.get("type", "")) == "resolve_contact" and str(command.get("approach", "")) == "fight")
		if is_fight:
			assert_true(bool(card.get("executable", false)))
		elif str(command.get("type", "")) == "leave_node":
			assert_true(bool(card.get("executable", false)))
		else:
			assert_false(bool(card.get("executable", true)), "非战卡 %s 必须禁用" % str(card.get("id", "")))


func test_probe_procures_weakness_fact() -> void:
	var state := make_state()
	state.known_facts.append("ledger_evidence")
	var probed: Dictionary = ResolverScript.apply_social_action(state, {"type": "choose_action", "action_id": "probe", "npc_id": "caravan_steward"}, catalog())
	assert_true(probed["state"].known_facts.has("procured_weakness"))


func test_soul_pill_boosts_soul_and_pays_stone() -> void:
	var state := make_state()
	state.cultivator["soul"] = 2
	state.stone = 10
	var bought: Dictionary = ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": "soul_pill"}, catalog())
	assert_true(bool(bought["result"].get("ok", false)))
	assert_eq(int(bought["state"].cultivator.get("soul", 0)), 3)
	assert_eq(bought["state"].stone, 4)


func test_soul_pill_rejects_full_soul() -> void:
	var state := make_state()
	state.cultivator["soul"] = 4
	state.stone = 10
	var bought: Dictionary = ResolverScript.apply(state, {"type": "shop_purchase", "offer_id": "soul_pill"}, catalog())
	assert_false(bool(bought["result"].get("ok", false)))
	assert_eq(str(bought["result"].get("reason", "")), "soul_at_max")


func test_shop_preview_shows_soul_pill_card() -> void:
	var state := make_state()
	state.cultivator["soul"] = 3
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(state, {"id": "ridge_black_market", "type": "shop"}, catalog())
	var found := false
	for card in cards:
		if str(card.get("id", "")) == "shop.soul_pill":
			found = true
			assert_true(bool(card.get("executable", false)))
	assert_true(found)