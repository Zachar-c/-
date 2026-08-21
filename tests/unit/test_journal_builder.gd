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
	state.body_imprints = ["iron_bone"]
	state.known_facts = ["iron_bone_defense", "iron_bone_stealth_drawback"]
	state.ascension = {
		"aperture_foundation": true,
		"heaven_earth_qi": true,
		"site": true,
		"protection": true,
		"external_interference": false,
	}
	var entries := JournalBuilder.build(state, {"outcome": "success", "conditions": state.ascension})
	var visible_fact_count := 0
	for entry in entries:
		for fact in entry["visible_facts"]:
			visible_fact_count += 1
			assert_true(state.known_facts.has(fact))
	assert_eq(visible_fact_count, 2)
