class_name MetaProgress
extends RefCounted


var gu_codex_ids: Array[String] = []
var recipe_codex_ids: Array[String] = []
var relic_codex_ids: Array[String] = []
var inheritance_codex_ids: Array[String] = []
var unlocked_content_ids: Array[String] = []
var unlocked_random_outcomes: Dictionary = {}
var statistics: Dictionary = {
	"runs_started": 0,
	"runs_won": 0,
	"runs_risky": 0,
	"deaths": 0,
}



static func new_empty() -> RefCounted:
	return load("res://scripts/domain/meta_progress.gd").new()


func record_run_end(run: RunState, outcome: String) -> RefCounted:
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
			for target_value in event.get("targets", []):
				var relic_id := str(target_value)
				if not next.relic_codex_ids.has(relic_id):
					next.relic_codex_ids.append(relic_id)
	if outcome == "won":
		next.statistics["runs_won"] = int(next.statistics.get("runs_won", 0)) + 1
	elif outcome == "risky":
		next.statistics["runs_risky"] = int(next.statistics.get("runs_risky", 0)) + 1
	elif outcome == "dead":
		next.statistics["deaths"] = int(next.statistics.get("deaths", 0)) + 1
	return next


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
		"statistics": statistics.duplicate(true),
	}


func _copy() -> RefCounted:
	var copy = get_script().new()
	copy.gu_codex_ids = gu_codex_ids.duplicate()
	copy.recipe_codex_ids = recipe_codex_ids.duplicate()
	copy.relic_codex_ids = relic_codex_ids.duplicate()
	copy.inheritance_codex_ids = inheritance_codex_ids.duplicate()
	copy.unlocked_content_ids = unlocked_content_ids.duplicate()
	copy.unlocked_random_outcomes = unlocked_random_outcomes.duplicate(true)
	copy.statistics = statistics.duplicate(true)
	return copy
