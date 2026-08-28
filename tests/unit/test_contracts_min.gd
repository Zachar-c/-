extends GutTest


# Task C1-min §16.13 part 1: contract data table + validation, the swear
# command gate, rule aggregation and every in-run consumer (battle damage,
# shop price, loot materials, turn essence, hp max penalty) plus the run-save
# round trip.


const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
const LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")


const ALWAYS_IDS := ["blood_pact", "miser_pact", "essence_tide"]

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _swear(state: RunState, ids: Array, cat = null, allowed: Array = []) -> Dictionary:
	var payload := {"type": "swear_contracts", "ids": ids}
	payload["allowed_ids"] = ALWAYS_IDS if allowed.is_empty() else allowed
	return ResolverScript.apply(state, payload, catalog if cat == null else cat)


func _has(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false


func test_contracts_table_ships_four_entries_and_validates_clean() -> void:
	assert_eq(int(catalog["contracts"]["contract_cap"]), 6)
	var entries: Array = catalog["contracts"]["entries"]
	assert_eq(entries.size(), 4)
	var by_id: Dictionary = catalog["contract_entry_by_id"]
	for id in ["blood_pact", "miser_pact", "essence_tide", "ascetic_path"]:
		assert_true(by_id.has(id), id)
		assert_false((by_id[id]["rules"] as Array).is_empty(), id)
		assert_false(str(by_id[id]["desc"]).is_empty(), id)
		assert_false(str(by_id[id]["label"]).is_empty(), id)
	assert_eq(str(by_id["blood_pact"]["unlock"]["kind"]), "always")
	assert_eq(str(by_id["ascetic_path"]["unlock"]["kind"]), "ending")
	assert_true(ContentCatalog.validate(catalog).is_empty())


func test_contract_validation_rejects_bad_schema() -> void:
	var tuned := catalog.duplicate(true)
	tuned["contracts"] = catalog["contracts"].duplicate(true)
	tuned["contracts"]["entries"] = catalog["contracts"]["entries"].duplicate(true)
	var bad_key: Dictionary = catalog["contract_entry_by_id"]["blood_pact"].duplicate(true)
	bad_key["id"] = "bad_key"
	bad_key["rules"] = [{"key": "free_win_pct", "value": 100}]
	tuned["contracts"]["entries"].append(bad_key)
	var errors := ContentCatalog.validate(tuned)
	assert_true(_has(errors, "unknown rule key"))

	tuned["contracts"] = catalog["contracts"].duplicate(true)
	tuned["contracts"]["entries"] = [catalog["contract_entry_by_id"]["blood_pact"].duplicate(true)]
	tuned["contracts"]["contract_cap"] = 0
	errors = ContentCatalog.validate(tuned)
	assert_true(_has(errors, "contract_cap"))

	tuned["contracts"] = catalog["contracts"].duplicate(true)
	tuned["contracts"]["entries"] = catalog["contracts"]["entries"].duplicate(true)
	var mutex_ghost: Dictionary = catalog["contract_entry_by_id"]["blood_pact"].duplicate(true)
	mutex_ghost["id"] = "mutex_ghost"
	mutex_ghost["mutual_exclusive"] = ["ghost_pact"]
	tuned["contracts"]["entries"].append(mutex_ghost)
	errors = ContentCatalog.validate(tuned)
	assert_true(_has(errors, "mutual_exclusive references unknown id"))

	tuned["contracts"] = catalog["contracts"].duplicate(true)
	tuned["contracts"]["entries"] = [catalog["contract_entry_by_id"]["blood_pact"].duplicate(true)]
	var bad_unlock: Dictionary = catalog["contract_entry_by_id"]["blood_pact"].duplicate(true)
	bad_unlock["id"] = "bad_unlock"
	bad_unlock["unlock"] = {"kind": "count", "count": 3}
	tuned["contracts"]["entries"].append(bad_unlock)
	errors = ContentCatalog.validate(tuned)
	assert_true(_has(errors, "unknown unlock kind"))

	tuned["contracts"] = catalog["contracts"].duplicate(true)
	tuned["contracts"]["entries"] = [catalog["contract_entry_by_id"]["blood_pact"].duplicate(true)]
	tuned["contracts"]["entries"].append(catalog["contract_entry_by_id"]["blood_pact"].duplicate(true))
	errors = ContentCatalog.validate(tuned)
	assert_true(_has(errors, "duplicate contract id"))


# Quality batch ③: every player-facing contract desc must state its rule
# numbers, so the text cannot drift away from the configured values.
func test_contract_validation_rejects_desc_numeral_drift() -> void:
	var tuned := catalog.duplicate(true)
	tuned["contracts"] = catalog["contracts"].duplicate(true)
	tuned["contracts"]["entries"] = [catalog["contract_entry_by_id"]["blood_pact"].duplicate(true)]
	tuned["contracts"]["entries"][0]["desc"] = "打击伤害+40%，敌方意图伤害+20%。"

	var errors := ContentCatalog.validate(tuned)
	assert_true(_has(errors, "lacks numeral 30"))
	assert_true(_has(errors, "strike_damage_pct"))
	assert_false(_has(errors, "lacks numeral 20"))

	tuned["contracts"]["entries"][0]["rules"] = [
		{"key": "strike_damage_pct", "value": 40},
		{"key": "enemy_damage_pct", "value": 20},
	]
	assert_true(ContentCatalog.validate(tuned).is_empty(),
			str(ContentCatalog.validate(tuned)))


func test_contract_validation_desc_numeral_must_be_standalone_token() -> void:
	var entry := {
		"id": "token_probe",
		"label": "令牌探针",
		"desc": "数值为 130 与 2，条目合计 1300。",
		"rules": [
			{"key": "material_bonus", "value": 2},
			{"key": "material_penalty", "value": -30},
		],
		"mutual_exclusive": [],
		"unlock": {"kind": "always"},
	}
	var tuned := catalog.duplicate(true)
	tuned["contracts"] = {"contract_cap": 6, "entries": [entry]}
	var errors := ContentCatalog.validate(tuned)
	assert_true(_has(errors, "lacks numeral 30"), "digit runs inside 130/1300 must not satisfy 30")
	assert_false(_has(errors, "lacks numeral 2"))

	entry["desc"] = "数值为 30 与 2，条目合计 1300。"
	assert_true(ContentCatalog.validate(tuned).is_empty(),
			"extra numerals are allowed once every rule value is stated")


func test_swear_writes_contracts_flag_and_event_once_at_trailhead() -> void:
	var run := RunState.new_run(101)
	var result := _swear(run, ["blood_pact", "miser_pact"])
	assert_true(result["result"]["ok"])
	var next: RunState = result["state"]
	assert_eq(next.contracts, ["blood_pact", "miser_pact"])
	assert_eq(str(next.node_flags.get("contracts_sworn", "")), "true")
	var event: Dictionary = next.event_log.back()
	assert_eq(str(event["action"]), "contracts_sworn")
	assert_eq(event["targets"], ["blood_pact", "miser_pact"])

	var again := _swear(next, ["essence_tide"], null, ["essence_tide"])
	assert_false(again["result"]["ok"])
	assert_eq(str(again["result"]["reason"]), "contracts_already_sworn")
	assert_eq(again["state"].contracts, ["blood_pact", "miser_pact"])


func test_swear_rejects_unknown_locked_duplicate_empty_and_off_trailhead() -> void:
	var run := RunState.new_run(101)
	assert_eq(str(_swear(run, ["ghost_pact"])["result"]["reason"]), "unknown_contract")
	assert_eq(str(_swear(run, ["ascetic_path"])["result"]["reason"]), "contract_locked")
	assert_eq(str(_swear(run, ["blood_pact", "blood_pact"])["result"]["reason"]), "duplicate_contract")
	assert_eq(str(_swear(run, [])["result"]["reason"]), "no_contracts_selected")

	var moved_result := ResolverScript.apply(run, {"type": "travel", "node_id": "ridge_caravan"}, catalog)
	var moved: RunState = moved_result["state"]
	assert_eq(str(_swear(moved, ["blood_pact"])["result"]["reason"]), "contracts_trailhead_only")


func test_swear_enforces_configured_cap_and_mutual_exclusion() -> void:
	var tuned := catalog.duplicate(true)
	tuned["contracts"] = {
		"contract_cap": 2,
		"entries": [
			catalog["contract_entry_by_id"]["blood_pact"],
			catalog["contract_entry_by_id"]["miser_pact"],
			catalog["contract_entry_by_id"]["essence_tide"],
			{
				"id": "mutex_a",
				"label": "互斥甲",
				"desc": "测试用。",
				"rules": [{"key": "material_bonus", "value": 1}],
				"mutual_exclusive": ["mutex_b"],
				"unlock": {"kind": "always"},
			},
			{
				"id": "mutex_b",
				"label": "互斥乙",
				"desc": "测试用。",
				"rules": [{"key": "material_penalty", "value": -1}],
				"mutual_exclusive": ["mutex_a"],
				"unlock": {"kind": "always"},
			},
		],
	}
	var run := RunState.new_run(101)
	var all_allowed: Array = ["blood_pact", "miser_pact", "essence_tide", "mutex_a", "mutex_b"]
	assert_eq(str(_swear(run, ALWAYS_IDS, tuned, all_allowed)["result"]["reason"]), "contract_cap_exceeded")
	assert_eq(str(_swear(run, ["mutex_a", "mutex_b"], tuned, all_allowed)["result"]["reason"]), "contract_mutual_exclusive")


func test_essence_tide_applies_hp_max_penalty_with_lethal_precheck() -> void:
	var run := RunState.new_run(101)
	var result := _swear(run, ["essence_tide"])
	assert_true(result["result"]["ok"])
	var next: RunState = result["state"]
	assert_eq(int(next.max_health), 6)
	assert_eq(int(next.health), 6)
	assert_eq(int(next.cultivator["max_health"]), 6)

	var tuned := catalog.duplicate(true)
	tuned["contracts"] = {
		"contract_cap": 6,
		"entries": [{
			"id": "death_wish",
			"label": "求死之约",
			"desc": "生命上限-9。",
			"rules": [{"key": "hp_max_penalty", "value": -9}],
			"mutual_exclusive": [],
			"unlock": {"kind": "always"},
		}],
	}
	var frail := RunState.new_run(101)
	var rejected := _swear(frail, ["death_wish"], tuned, ["death_wish"])
	assert_false(rejected["result"]["ok"])
	assert_eq(str(rejected["result"]["reason"]), "contract_hp_max_lethal")
	assert_eq(rejected["state"].contracts, [])
	assert_eq(int(rejected["state"].max_health), 8)


func test_aggregate_sums_signed_rule_values_across_sworn_contracts() -> void:
	var plain := RunState.new_run(101)
	assert_eq(ContractRulesScript.aggregate(plain, catalog), {})
	var sworn := RunState.new_run(101)
	var ids: Array[String] = ["miser_pact", "ascetic_path"]
	sworn.contracts = ids
	var totals: Dictionary = ContractRulesScript.aggregate(sworn, catalog)
	assert_eq(int(totals.get("material_bonus", 0)), 1)
	assert_eq(int(totals.get("material_penalty", 0)), -1)
	assert_eq(int(totals.get("shop_price_pct", 0)), 25)
	assert_eq(int(totals.get("hall_material_bonus_pct", 0)), 50)


func test_strike_damage_pct_scales_player_strikes_not_curse_channel() -> void:
	var battle := {"enemy_hp": 100, "intel_bonus": 0, "contract_mods": {"strike_damage_pct": 30}}
	BattleResolver._strike(battle, 10)
	assert_eq(int(battle["enemy_hp"]), 87)

	var floored := {"enemy_hp": 100, "intel_bonus": 0, "contract_mods": {"strike_damage_pct": 25}}
	BattleResolver._strike(floored, 1)
	assert_eq(int(floored["enemy_hp"]), 99)

	var intel_flat := {"enemy_hp": 100, "intel_bonus": 2, "contract_mods": {}}
	BattleResolver._strike(intel_flat, 3)
	assert_eq(int(intel_flat["enemy_hp"]), 95)

	var cursed := {"pending_curse_damage": 0, "contract_mods": {"strike_damage_pct": 100}}
	BattleResolver._strike(cursed, 5, "curse")
	assert_eq(int(cursed["pending_curse_damage"]), 5)


func test_enemy_damage_pct_scales_enemy_intent_damage() -> void:
	var plain := RunState.new_run(7)
	plain.health = 20
	plain.max_health = 20
	var control := BattleResolver.apply_enemy_pre_turn(
			BattleResolver.start({"enemy_kind": "ridge_hound", "first_mover": "enemy"}, plain, catalog),
			plain, catalog)
	assert_eq(int(control["state"].health), 18)

	var sworn := RunState.new_run(7)
	sworn.health = 20
	sworn.max_health = 20
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound", "first_mover": "enemy"}, sworn, catalog)
	battle["contract_mods"] = {"enemy_damage_pct": 50}
	var boosted := BattleResolver.apply_enemy_pre_turn(battle, sworn, catalog)
	# Pounce deals 2 since the opening-fairness retune: floor(2 * 1.5) = 3.
	assert_eq(int(boosted["state"].health), 17)


func test_turn_essence_bonus_grants_essence_at_player_turn_start() -> void:
	var run := RunState.new_run(11)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	battle["contract_mods"] = {"turn_essence_bonus": 1}
	var before := int(run.essence)
	var turn := BattleResolver.take_turn(battle, {"type": "end_turn"}, run, catalog)
	assert_false(bool(turn["finished"]))
	# 收势回气 (regen 3) lands before the tide; essence caps at capacity 4.
	assert_eq(int(turn["state"].essence), mini(before + 3, 4))
	assert_eq(str(turn["state"].event_log.back()["action"]), "contract_essence_tide")

	var clean := RunState.new_run(11)
	var plain := BattleResolver.start({"enemy_kind": "ridge_hound"}, clean, catalog)
	var unchanged := BattleResolver.take_turn(plain, {"type": "end_turn"}, clean, catalog)
	# 无潮汐时仍有收势回气 (regen 3, cap 4)。
	assert_eq(int(unchanged["state"].essence), mini(int(clean.essence) + 3, 4))


func test_shop_price_pct_lifts_buy_prices_only() -> void:
	var miser := RunState.new_run(101)
	var ids: Array[String] = ["miser_pact"]
	miser.contracts = ids
	assert_eq(ResolverScript.price_for(catalog, miser, 100), 125)
	assert_eq(ResolverScript.service_price_for(catalog, miser, "remove_card", 120), 150)

	miser.cultivator["notorious"] = 1
	# Base 95 keeps the 10% notoriety factor off the float-epsilon boundary.
	assert_eq(ResolverScript.price_for(catalog, miser, 95), 131)

	var plain := RunState.new_run(101)
	plain.cultivator["notorious"] = 1
	assert_eq(ResolverScript.price_for(catalog, plain, 95), 105)
	assert_eq(ResolverScript.sell_price_for(catalog, plain, 100), 90)
	assert_eq(ResolverScript.sell_price_for(catalog, miser, 100), 90)


func test_material_bonus_and_penalty_adjust_loot_counts_with_zero_clamp() -> void:
	var base := LootResolverScript.settle_victory({"enemy_kind": "ridge_hound"}, RunState.new_run(424242), catalog)
	assert_eq((base["loot"]["material_ids"] as Array).size(), 1)

	var boosted_state := RunState.new_run(424242)
	var bonus_ids: Array[String] = ["miser_pact"]
	boosted_state.contracts = bonus_ids
	var boosted := LootResolverScript.settle_victory({"enemy_kind": "ridge_hound"}, boosted_state, catalog)
	assert_eq((boosted["loot"]["material_ids"] as Array).size(), 2)

	var cut_state := RunState.new_run(424242)
	var penalty_ids: Array[String] = ["ascetic_path"]
	cut_state.contracts = penalty_ids
	var cut := LootResolverScript.settle_victory({"enemy_kind": "ridge_hound"}, cut_state, catalog)
	assert_eq((cut["loot"]["material_ids"] as Array).size(), 0)


# N1 §16.13 MINOR closeout: the enemy-damage boost must never multiply the
# backlash channel, the essence tide must respect the aperture cap, and the
# shop lift stays clamped at zero until §16.13 grows discount rule keys.
func test_blood_pact_declares_backlash_channel_exemption() -> void:
	assert_true(str(catalog["contract_entry_by_id"]["blood_pact"]["desc"]).contains("反噬直扣不受此加成"))


func test_enemy_damage_pct_never_multiplies_curse_channel() -> void:
	var cursed := RunState.new_run(7)
	cursed.health = 20
	cursed.max_health = 20
	cursed = CurseRegistryScript.gain_curse(cursed, "gu_erosion", "test_source")
	var battle := BattleResolverScript.start({"enemy_kind": "ridge_hound"}, cursed, catalog)
	battle["contract_mods"] = {"enemy_damage_pct": 50}
	var turn := BattleResolverScript.take_turn(battle, {"type": "end_turn"}, cursed, catalog)
	# Intent damage 2 -> floor(2 * 1.5) = 3; gu_erosion stage-one intensity 1
	# rides the backlash channel and stays exactly 1.
	assert_eq(int(turn["state"].health), 16)


func test_essence_tide_clamps_to_aperture_cap_and_declares_it() -> void:
	assert_true(str(catalog["contract_entry_by_id"]["essence_tide"]["desc"]).contains("不超过真元上限"))

	var run := RunState.new_run(11)
	var cap := int(run.cave_aperture["essence_max"])
	run.essence = cap
	var battle := BattleResolverScript.start({"enemy_kind": "ridge_hound"}, run, catalog)
	battle["contract_mods"] = {"turn_essence_bonus": 1}
	var turn := BattleResolverScript.take_turn(battle, {"type": "end_turn"}, run, catalog)
	assert_eq(int(turn["state"].essence), cap)


func test_shop_price_pct_negative_values_stay_clamped_at_zero() -> void:
	var tuned := catalog.duplicate(true)
	tuned["contract_entry_by_id"] = catalog["contract_entry_by_id"].duplicate(true)
	var miser: Dictionary = (catalog["contract_entry_by_id"]["miser_pact"] as Dictionary).duplicate(true)
	miser["rules"] = [{"key": "shop_price_pct", "value": -25}]
	tuned["contract_entry_by_id"]["miser_pact"] = miser
	var shopper := RunState.new_run(101)
	var typed: Array[String] = ["miser_pact"]
	shopper.contracts = typed
	assert_eq(ResolverScript.price_for(tuned, shopper, 100), 100)


func test_run_save_round_trip_preserves_sworn_contracts() -> void:
	var run := RunState.new_run(101)
	run = _swear(run, ["blood_pact"])["state"]
	var data := SaveRepositoryScript.serialize_run(run, [{"id": "trailhead"}], [])
	var loaded: Dictionary = SaveRepositoryScript.load_run_from_data(data)
	assert_false(loaded.is_empty())
	var restored: RunState = loaded["state"]
	assert_eq(restored.contracts, ["blood_pact"])
	assert_eq(str(restored.node_flags.get("contracts_sworn", "")), "true")
