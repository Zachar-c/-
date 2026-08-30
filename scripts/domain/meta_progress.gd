class_name MetaProgress
extends RefCounted


const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const SAVE_FIELDS := [
	"gu_codex_ids", "recipe_codex_ids", "relic_codex_ids", "inheritance_codex_ids",
	"unlocked_content_ids", "unlocked_random_outcomes", "contracts_unlocked",
	"journal_unlocked", "hall_material_bonus_accrued", "dda_state_adaptive_enabled",
	"statistics",
]


var gu_codex_ids: Array[String] = []
var recipe_codex_ids: Array[String] = []
var relic_codex_ids: Array[String] = []
var inheritance_codex_ids: Array[String] = []
var unlocked_content_ids: Array[String] = []
var unlocked_random_outcomes: Dictionary = {}
# C1-min §16.13: contract unlocks persist in the hall save only.
var contracts_unlocked: Array[String] = []
# N1 §16.9: hall journal unlock ledger; narrative-only, never grants power.
var journal_unlocked: Array[String] = []
# Display-only ledger of accrued hall material bonus percentages (never
# grants in-run power).
var hall_material_bonus_accrued: int = 0
# R14.6⑧ (night batch): OFF = fixed progress difficulty only (no state
# adaptive markers). Copied into each new run at birth.
var dda_state_adaptive_enabled: bool = true
var statistics: Dictionary = {
	"runs_started": 0,
	"runs_won": 0,
	"runs_risky": 0,
	"deaths": 0,
}



static func new_empty() -> MetaProgress:
	return MetaProgress.new()


static func from_save_data(data: Dictionary) -> MetaProgress:
	var meta = new_empty()
	meta.gu_codex_ids = _string_array(data.get("gu_codex_ids", []))
	meta.recipe_codex_ids = _string_array(data.get("recipe_codex_ids", []))
	meta.relic_codex_ids = _string_array(data.get("relic_codex_ids", []))
	meta.inheritance_codex_ids = _string_array(data.get("inheritance_codex_ids", []))
	meta.unlocked_content_ids = _string_array(data.get("unlocked_content_ids", []))
	var outcomes: Variant = data.get("unlocked_random_outcomes", {})
	meta.unlocked_random_outcomes = outcomes.duplicate(true) if outcomes is Dictionary else {}
	meta.contracts_unlocked = _string_array(data.get("contracts_unlocked", []))
	meta.journal_unlocked = _string_array(data.get("journal_unlocked", []))
	meta.hall_material_bonus_accrued = int(data.get("hall_material_bonus_accrued", 0))
	meta.dda_state_adaptive_enabled = bool(data.get("dda_state_adaptive_enabled", true))
	var stats: Variant = data.get("statistics", {})
	if stats is Dictionary:
		meta.statistics = meta.statistics.merged(stats, true)
	return meta


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func record_run_end(run: RunState, outcome: String, catalog: Dictionary = {}, ending_type: String = "") -> RefCounted:
	var next := _copy()
	for gu_id in run.refined_gu_ids:
		if not next.gu_codex_ids.has(gu_id):
			next.gu_codex_ids.append(gu_id)
	for event in run.event_log:
		var reason := str(event.get("reason", ""))
		if reason == "refinement_succeeded":
			for target_value in event.get("targets", []):
				var target := str(target_value)
				if target.begins_with("recipe:"):
					var recipe_id := target.trim_prefix("recipe:")
					if not next.recipe_codex_ids.has(recipe_id):
						next.recipe_codex_ids.append(recipe_id)
		elif reason == "scavenge_recipe_unlocked":
			for target_value in event.get("targets", []):
				var scavenged_recipe := str(target_value)
				if not next.recipe_codex_ids.has(scavenged_recipe):
					next.recipe_codex_ids.append(scavenged_recipe)
		elif reason == "relic_gained":
			# R11.7 encountering a relic unlocks its codex entry; the relic id
			# rides the gain event's targets exactly like recipe unlocks.
			# When a catalog is supplied, stray ids absent from it are skipped.
			for target_value in event.get("targets", []):
				var relic_id := str(target_value)
				if not catalog.is_empty() and not catalog.get("relic_by_id", {}).has(relic_id):
					continue
				if not next.relic_codex_ids.has(relic_id):
					next.relic_codex_ids.append(relic_id)
	if outcome == "won":
		next.statistics["runs_won"] = int(next.statistics.get("runs_won", 0)) + 1
	elif outcome == "risky":
		next.statistics["runs_risky"] = int(next.statistics.get("runs_risky", 0)) + 1
	elif outcome == "dead":
		next.statistics["deaths"] = int(next.statistics.get("deaths", 0)) + 1
	# C1-min §16.13: ending-bound contracts unlock by exact match against the
	# snapshot ending type; repeat endings never matter, only the first match.
	for entry_value in catalog.get("contracts", {}).get("entries", []):
		var entry: Dictionary = entry_value
		var unlock: Dictionary = entry.get("unlock", {})
		if str(unlock.get("kind", "")) != "ending":
			continue
		if ending_type.is_empty() or not (unlock.get("endings", []) as Array).has(ending_type):
			continue
		var contract_id := str(entry.get("id", ""))
		if not contract_id.is_empty() and not next.contracts_unlocked.has(contract_id):
			next.contracts_unlocked.append(contract_id)
	# N1 §16.9: journal entries unlock by ending type or by route markers
	# extracted from the run's immutable event log. Unlocks ride the returned
	# MetaProgress copy (same pattern as contracts); RunState is untouched, so
	# narrative stays a zero-combat-power channel.
	for entry_value in catalog.get("journal", {}).get("entries", []):
		var entry: Dictionary = entry_value
		var journal_id := str(entry.get("id", ""))
		if journal_id.is_empty() or next.journal_unlocked.has(journal_id):
			continue
		var unlock: Dictionary = entry.get("unlock", {})
		var hit := false
		match str(unlock.get("kind", "")):
			"always":
				hit = true
			"ending":
				hit = not ending_type.is_empty() and (unlock.get("endings", []) as Array).has(ending_type)
			"route":
				hit = _markers_cover(unlock.get("markers", []), _run_markers(run))
		if hit:
			next.journal_unlocked.append(journal_id)
	if outcome == "won" or outcome == "risky":
		next.hall_material_bonus_accrued += maxi(0, int(ContractRulesScript.aggregate(run, catalog).get("hall_material_bonus_pct", 0)))
	return next


func unlocked_contracts(catalog: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for entry_value in catalog.get("contracts", {}).get("entries", []):
		var entry: Dictionary = entry_value
		var contract_id := str(entry.get("id", ""))
		if contract_id.is_empty():
			continue
		var unlock: Dictionary = entry.get("unlock", {})
		if str(unlock.get("kind", "")) == "always" or contracts_unlocked.has(contract_id):
			result.append(contract_id)
	return result


# N1 §16.9: single mapping from real event-log actions/reasons to route
# marker names (whitelisted by ContentCatalog.JOURNAL_MARKER_IDS). Kept in one
# place so tests can pin the contract against the actual writers in resolver.gd
# / curse_registry.gd.
static func _run_markers(run: RunState) -> Array[String]:
	var markers: Array[String] = []
	var events := run.event_log
	for index in events.size():
		var event: Dictionary = events[index]
		match str(event.get("action", "")):
			"record_boss_defeated":
				_push_marker(markers, "boss_defeated")
			# resolver._swear_contracts writes action/reason both as
			# contracts_sworn; the marker name stays journal-side vocabulary.
			"contracts_sworn":
				_push_marker(markers, "sworn_contracts")
			"attempt_ascension":
				_push_marker(markers, "ascension_attempted")
			"shop_barter":
				_push_marker(markers, "shop_barter")
			"gain_notoriety":
				# Malformed payloads (after/cultivator not Dictionary) skip the
				# event instead of crashing the marker scan.
				var after_value: Variant = event.get("after", {})
				if not (after_value is Dictionary):
					continue
				var cultivator_value: Variant = after_value.get("cultivator", {})
				if not (cultivator_value is Dictionary):
					continue
				var notorious := int(cultivator_value.get("notorious", 0))
				if notorious >= 5:
					_push_marker(markers, "notoriety_gte_5")
			"curse_removed":
				# Rest removal consumes the visit immediately before the curse
				# leaves; paid black-market removal writes svc_remove_curse instead.
				if index > 0 and str(events[index - 1].get("reason", "")) == "rest_visit_consumed":
					_push_marker(markers, "rest_curse_removed")
	return markers


static func _push_marker(markers: Array[String], marker: String) -> void:
	if not markers.has(marker):
		markers.append(marker)


static func _markers_cover(required: Array, present: Array[String]) -> bool:
	for marker_value in required:
		if not present.has(str(marker_value)):
			return false
	return true


func record_random_outcome(combination_key: String, outcome_id: String) -> RefCounted:
	var next := _copy()
	var outcomes: Array = next.unlocked_random_outcomes.get(combination_key, []).duplicate()
	if not outcomes.has(outcome_id):
		outcomes.append(outcome_id)
	next.unlocked_random_outcomes[combination_key] = outcomes
	return next


func to_save_data() -> Dictionary:
	return {
		"gu_codex_ids": gu_codex_ids.duplicate(),
		"recipe_codex_ids": recipe_codex_ids.duplicate(),
		"relic_codex_ids": relic_codex_ids.duplicate(),
		"inheritance_codex_ids": inheritance_codex_ids.duplicate(),
		"unlocked_content_ids": unlocked_content_ids.duplicate(),
		"unlocked_random_outcomes": unlocked_random_outcomes.duplicate(true),
		"contracts_unlocked": contracts_unlocked.duplicate(),
		"journal_unlocked": journal_unlocked.duplicate(),
		"hall_material_bonus_accrued": hall_material_bonus_accrued,
		"dda_state_adaptive_enabled": dda_state_adaptive_enabled,
		"statistics": statistics.duplicate(true),
	}


func _copy() -> RefCounted:
	return MetaProgress.from_save_data(to_save_data())
