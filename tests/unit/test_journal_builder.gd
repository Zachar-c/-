extends GutTest


func test_journal_attributes_missing_qi_to_known_event() -> void:
	var state := RunState.new_run(101)
	state.known_facts = ["heaven_earth_qi_unsecured"]
	state.ascension = {
		"aperture_foundation": true,
		"heaven_earth_qi": false,
		"site": true,
		"protection": true,
		"external_interference": false,
	}
	state = state.append_event({
		"action": "social_trade",
		"before": {},
		"after": {"known_facts": state.known_facts},
		"reason": "caravan_trade_declined",
		"source": "resolver",
		"targets": ["caravan_steward"],
	})
	var entries := JournalBuilder.build(state, {
		"outcome": "survived_failure",
		"conditions": state.ascension,
	})
	var qi_entries := entries.filter(func(entry: Dictionary): return entry["heading"] == "Heaven and earth qi")
	assert_eq(qi_entries.size(), 1)
	assert_true(qi_entries[0]["event_ids"].has("event_0001"))
	assert_eq(qi_entries[0]["visible_facts"], ["heaven_earth_qi_unsecured"])


func test_journal_never_reveals_unknown_facts() -> void:
	var state := RunState.new_run(101)
	state = state.append_event({
		"action": "take_body_imprint",
		"before": {},
		"after": {
			"body_imprints": ["iron_bone"],
			"known_facts": ["iron_bone_defense", "iron_bone_stealth_drawback"],
		},
		"reason": "body_imprint_stealth_drawback",
		"source": "resolver",
		"targets": ["iron_bone"],
	})
	var entries := JournalBuilder.build(state, {"outcome": "success"})
	var imprint_entries := entries.filter(func(entry: Dictionary): return entry["heading"] == "Body imprint")
	assert_eq(imprint_entries[0]["visible_facts"], ["iron_bone_defense", "iron_bone_stealth_drawback"])


func test_journal_uses_resource_snapshot_from_event_log() -> void:
	var state := RunState.new_run(101)
	state = state.append_event(EventFactory.resource_changed("stone", 12, 7, "buy_information", "market"))
	state.stone = 99
	var entries := JournalBuilder.build(state, {"outcome": "survived_failure"})
	var stone_entries := entries.filter(func(entry: Dictionary): return entry["heading"] == "Stone balance")
	assert_eq(JournalBuilder.text_for(stone_entries[0]), "The final stone balance was 7.")
