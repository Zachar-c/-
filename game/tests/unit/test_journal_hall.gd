extends GutTest


# Task N1 §16.9: hall journal library. journal.json table + catalog schema
# guard, MetaProgress route/ending unlock evaluation (narrative-only, zero
# combat power), snapshot exposure and ending-page text preference.


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")


const ALWAYS_IDS := ["blood_pact", "miser_pact", "essence_tide"]

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _has(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false


# ---- D1 data table + validation ----

func test_journal_table_ships_eight_hall_entries_and_validates_clean() -> void:
	var entries: Array = catalog["journal"]["entries"]
	assert_eq(entries.size(), 8)
	var by_id: Dictionary = catalog["journal_entry_by_id"]
	assert_eq(by_id.size(), 8)
	for id in [
		"journal_risky_arrival", "journal_gu_fall", "journal_ascension_success",
		"journal_first_swear", "journal_boss_slain",
		"journal_notorious", "journal_barter_deal", "journal_rest_purge",
	]:
		assert_true(by_id.has(id), id)
		assert_eq(str(by_id[id]["layer"]), "hall")
		assert_false(str(by_id[id]["title"]).is_empty(), id)
		assert_false(str(by_id[id]["text"]).is_empty(), id)
		assert_true(str(by_id[id]["text"]).length() <= 120, id)
	var ending_kinds := 0
	for entry_value in entries:
		if str(entry_value["unlock"]["kind"]) == "ending":
			ending_kinds += 1
	assert_eq(ending_kinds, 3)
	assert_true(ContentCatalog.validate(catalog).is_empty())


func test_journal_ending_texts_cover_every_ending_type() -> void:
	var texts: Dictionary = catalog["journal"]["ending_texts"]
	for etype in ["success", "risky", "death", "gu_fall", "retreat", "true_ending"]:
		assert_false(str(texts.get(etype, "")).is_empty(), etype)


func test_journal_validation_rejects_bad_schema() -> void:
	var tuned := catalog.duplicate(true)
	tuned["journal"] = catalog["journal"].duplicate(true)
	tuned["journal"]["entries"] = catalog["journal"]["entries"].duplicate(true)

	var dup: Dictionary = (catalog["journal_entry_by_id"]["journal_first_swear"] as Dictionary).duplicate(true)
	tuned["journal"]["entries"].append(dup)
	var bad_layer: Dictionary = (catalog["journal_entry_by_id"]["journal_first_swear"] as Dictionary).duplicate(true)
	bad_layer["id"] = "bad_layer"
	bad_layer["layer"] = "battle"
	tuned["journal"]["entries"].append(bad_layer)
	var bad_marker: Dictionary = (catalog["journal_entry_by_id"]["journal_first_swear"] as Dictionary).duplicate(true)
	bad_marker["id"] = "bad_marker"
	bad_marker["unlock"] = {"kind": "route", "markers": ["invented_marker"]}
	tuned["journal"]["entries"].append(bad_marker)
	var empty_markers: Dictionary = (catalog["journal_entry_by_id"]["journal_first_swear"] as Dictionary).duplicate(true)
	empty_markers["id"] = "empty_markers"
	empty_markers["unlock"] = {"kind": "route", "markers": []}
	tuned["journal"]["entries"].append(empty_markers)
	var bad_ending: Dictionary = (catalog["journal_entry_by_id"]["journal_risky_arrival"] as Dictionary).duplicate(true)
	bad_ending["id"] = "bad_ending"
	bad_ending["unlock"] = {"kind": "ending", "endings": ["eternal"]}
	tuned["journal"]["entries"].append(bad_ending)
	var no_title: Dictionary = (catalog["journal_entry_by_id"]["journal_first_swear"] as Dictionary).duplicate(true)
	no_title["id"] = "no_title"
	no_title["title"] = ""
	tuned["journal"]["entries"].append(no_title)

	var errors := ContentCatalog.validate(tuned)
	assert_true(_has(errors, "duplicate journal id"), str(errors))
	assert_true(_has(errors, "unknown layer"), str(errors))
	assert_true(_has(errors, "unknown marker"), str(errors))
	assert_true(_has(errors, "route unlock needs markers"), str(errors))
	assert_true(_has(errors, "unknown ending"), str(errors))
	assert_true(_has(errors, "missing title"), str(errors))


# ---- D2 hall unlock execution ----

func test_record_run_end_unlocks_ending_journal_on_matching_etype() -> void:
	var risky := MetaProgress.new_empty()
	risky = risky.record_run_end(RunState.new_run(101), "risky", catalog, "risky")
	assert_true(risky.journal_unlocked.has("journal_risky_arrival"))
	assert_false(risky.journal_unlocked.has("journal_ascension_success"))

	var gu_fall := MetaProgress.new_empty()
	gu_fall = gu_fall.record_run_end(RunState.new_run(102), "gu_fall", catalog, "gu_fall")
	assert_true(gu_fall.journal_unlocked.has("journal_gu_fall"))

	var dead := MetaProgress.new_empty()
	dead = dead.record_run_end(RunState.new_run(103), "dead", catalog, "death")
	assert_eq(dead.journal_unlocked, [])


func test_record_run_end_route_markers_come_from_real_event_log_actions() -> void:
	var run := RunState.new_run(101)

	var sworn := ResolverScript.apply(run, {"type": "swear_contracts", "ids": ["blood_pact"], "allowed_ids": ALWAYS_IDS}, catalog)
	assert_true(bool(sworn["result"]["ok"]), str(sworn))

	var boss := ResolverScript.apply(sworn["state"], {"type": "record_boss_defeated"}, catalog)
	assert_true(bool(boss["result"]["ok"]), str(boss))

	var notorious := ResolverScript.gain_notoriety(boss["state"], 3, "elite_cost")
	notorious = ResolverScript.gain_notoriety(notorious, 3, "broken_trust")

	# Black-market barter needs a refined input gu matching the offer.
	var trader := notorious
	trader.cave_aperture["stored_gu_instance_ids"].append("gu_002")
	trader.gu_instances["gu_002"] = {
		"instance_id": "gu_002",
		"definition_id": "qi_rec_2_14_gu",
		"state": "refined",
	}
	var barter := ResolverScript.apply(trader, {"type": "shop_barter", "offer_id": "barter_unknown_gu"}, catalog)
	assert_true(bool(barter["result"]["ok"]), str(barter))

	var resting: RunState = barter["state"]
	resting.current_node_id = "rest_hollow"
	resting = CurseRegistryScript.gain_curse(resting, "gu_erosion", "test_source")
	var purged := ResolverScript.apply(resting, {"type": "rest", "mode": "remove_curse", "curse_id": "gu_erosion"}, catalog)
	assert_true(bool(purged["result"]["ok"]), str(purged))

	var meta := MetaProgress.new_empty()
	meta = meta.record_run_end(purged["state"], "dead", catalog, "death")
	for id in ["journal_first_swear", "journal_boss_slain", "journal_notorious", "journal_barter_deal", "journal_rest_purge"]:
		assert_true(meta.journal_unlocked.has(id), id)


func test_route_journal_stays_locked_without_matching_behavior() -> void:
	var meta := MetaProgress.new_empty()
	meta = meta.record_run_end(RunState.new_run(7), "dead", catalog, "death")
	for id in ["journal_first_swear", "journal_boss_slain", "journal_notorious", "journal_barter_deal", "journal_rest_purge"]:
		assert_false(meta.journal_unlocked.has(id), id)


func test_low_notoriety_does_not_unlock_notoriety_journal() -> void:
	var run := ResolverScript.gain_notoriety(RunState.new_run(5), 3, "elite_cost")
	var meta := MetaProgress.new_empty()
	meta = meta.record_run_end(run, "dead", catalog, "death")
	assert_false(meta.journal_unlocked.has("journal_notorious"))


func test_run_markers_skip_malformed_notoriety_payloads() -> void:
	var run := RunState.new_run(13)
	run.event_log.append({"action": "gain_notoriety", "reason": "broken_trust", "after": "not_a_dict"})
	run.event_log.append({"action": "gain_notoriety", "reason": "broken_trust", "after": {"cultivator": 42}})
	run.event_log.append({"action": "gain_notoriety", "reason": "broken_trust", "after": {}})
	assert_false(MetaProgress._run_markers(run).has("notoriety_gte_5"))

	# A well-formed payload still produces the marker after the malformed ones.
	run.event_log.append({"action": "gain_notoriety", "reason": "broken_trust", "after": {"cultivator": {"notorious": 6}}})
	assert_true(MetaProgress._run_markers(run).has("notoriety_gte_5"))


func test_paid_curse_removal_does_not_unlock_rest_journal() -> void:
	var run := CurseRegistryScript.gain_curse(RunState.new_run(5), "gu_erosion", "test_source")
	var paid := ResolverScript.apply(
			run,
			{"type": "remove_curse", "curse_id": "gu_erosion"},
			catalog)
	assert_true(bool(paid["result"]["ok"]), str(paid))
	var meta := MetaProgress.new_empty()
	meta = meta.record_run_end(paid["state"], "dead", catalog, "death")
	assert_false(meta.journal_unlocked.has("journal_rest_purge"))


func test_record_run_end_is_idempotent_for_journal_unlocks() -> void:
	var meta := MetaProgress.new_empty()
	meta = meta.record_run_end(RunState.new_run(9), "risky", catalog, "risky")
	meta = meta.record_run_end(RunState.new_run(10), "risky", catalog, "risky")
	var hits: Array = meta.journal_unlocked.filter(func(id): return str(id) == "journal_risky_arrival")
	assert_eq(hits.size(), 1)


func test_meta_save_round_trip_carries_journal_and_defaults_old_saves() -> void:
	var meta := MetaProgress.new_empty()
	var typed: Array[String] = ["journal_gu_fall"]
	meta.journal_unlocked = typed
	var loaded = SaveRepository.load_meta_from_data(SaveRepository.serialize_meta(meta))
	assert_not_null(loaded)
	assert_eq(loaded.journal_unlocked, ["journal_gu_fall"])

	var legacy_data := {
		"gu_codex_ids": [],
		"recipe_codex_ids": [],
		"relic_codex_ids": [],
		"inheritance_codex_ids": [],
		"unlocked_content_ids": [],
		"unlocked_random_outcomes": {},
		"statistics": {"runs_started": 1, "runs_won": 0, "deaths": 0},
	}
	var legacy_payload := {
		"version": SaveRepository.SAVE_VERSION,
		"meta": legacy_data,
		"_checksum": SaveRepository._checksum_value(legacy_data),
	}
	var legacy = SaveRepository.load_meta_from_data(legacy_payload)
	assert_not_null(legacy)
	assert_eq(legacy.journal_unlocked, [])



# ---- D3 snapshot exposure ----

class StubController:
	var state
	var catalog
	var meta
	var _hall_subview := "main"
	var _selected_school := ""
	var _selected_buffs: Array = []


func _stub(state, meta) -> StubController:
	var stub := StubController.new()
	stub.state = state
	stub.catalog = catalog
	stub.meta = meta
	return stub


func test_hall_snapshot_exposes_unlocked_journal_and_locked_count() -> void:
	var meta := MetaProgress.new_empty()
	meta = meta.record_run_end(RunState.new_run(3), "risky", catalog, "risky")

	var snapshot: Dictionary = RunSnapshotBuilderScript.hall(_stub(RunState.new_run(4), meta))
	var journal: Dictionary = snapshot["journal"]
	assert_eq(int(journal["count"]), 1)
	assert_eq(int(journal["journal_locked_count"]), 7)
	var entries: Array = journal["entries"]
	assert_eq(entries.size(), 1)
	var first: Dictionary = entries[0]
	assert_eq(str(first["id"]), "journal_risky_arrival")
	assert_false(str(first["title"]).is_empty())
	assert_false(str(first["text"]).is_empty())

	var fresh: Dictionary = RunSnapshotBuilderScript.hall(_stub(RunState.new_run(5), MetaProgress.new_empty()))
	var fresh_journal: Dictionary = fresh["journal"]
	assert_eq(int(fresh_journal["count"]), 0)
	assert_eq((fresh_journal["entries"] as Array).size(), 0)
	assert_eq(int(fresh_journal["journal_locked_count"]), 8)


func test_journal_snapshot_entries_carry_dual_shape_keys() -> void:
	var meta := MetaProgress.new_empty()
	meta = meta.record_run_end(RunState.new_run(11), "risky", catalog, "risky")
	var snapshot: Dictionary = RunSnapshotBuilderScript.hall(_stub(RunState.new_run(12), meta))
	var entry: Dictionary = ((snapshot["journal"] as Dictionary)["entries"] as Array)[0]
	# Old consumer keys (hall_view): title + body.
	assert_true(entry.has_all(["title", "body"]))
	# New consumer keys: id + title + text.
	assert_true(entry.has_all(["id", "title", "text"]))
	# body is a same-value alias of text.
	assert_eq(str(entry["body"]), str(entry["text"]))
	assert_false(str(entry["body"]).is_empty())


func test_ending_snapshot_prefers_journal_ending_texts_with_hardcoded_fallback() -> void:
	var controller := _stub(RunState.new_run(6), MetaProgress.new_empty())
	var outcome := {"outcome": "success"}
	var ending: Dictionary = RunSnapshotBuilderScript.ending(controller, outcome, [], {})
	assert_eq(str(ending["aftermath"]),
			str(catalog["journal"]["ending_texts"]["success"]))

	var bare := _stub(RunState.new_run(7), MetaProgress.new_empty())
	bare.catalog = {}
	var fallback: Dictionary = RunSnapshotBuilderScript.ending(bare, outcome, [], {})
	assert_eq(str(fallback["aftermath"]), "修行札记已留存，可于大厅图鉴查阅本次所得。")
