class_name DdaResolver
extends RefCounted


# R14.5/R14.6 (§16.11, night batch): state-driven dynamic difficulty, pure
# domain module — no state mutation, no engine deps. The evaluation reads
# ONLY current-run state; the swap reuses the SeededRoll formula home.
#
# Levers per spec priority: enemy pool/behavior swap is lever 1 (implemented),
# map/reward/economy levers are out of scope for this batch. No numeric
# multipliers, no direct power grants, no cross-run reads.


const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")

const SYS_MARKER_PREFIX := "sys:"
const SWAP_SALT := "dda.enemy.swap"


static func active_marker(state: RunState) -> String:
	if state == null or not state.dda_state_adaptive_enabled:
		return ""
	for key in state.meta_rules:
		if str(key).begins_with(SYS_MARKER_PREFIX):
			return str(key)
	return ""


static func active_curse_count(state: RunState) -> int:
	var count := 0
	for status_value in state.cultivator.get("statuses", {}).values():
		var status: Dictionary = status_value
		count += 1 if int(status.get("layers", 0)) > 0 else 0
	return count


static func player_rule_count(meta_rules: Dictionary) -> int:
	var count := 0
	for key in meta_rules:
		if not str(key).begins_with(SYS_MARKER_PREFIX):
			count += 1
	return count


# Evaluates a 0..max score from current-run signals and returns the band
# record for that score: {score, band, marker, label, enabled}.
static func evaluate(state: RunState, catalog: Dictionary) -> Dictionary:
	var cfg: Dictionary = catalog.get("dda", {})
	var max_score := int(cfg.get("max_score", 10))
	var weights: Dictionary = cfg.get("weights", {})
	var score := 0
	var ratio := 0.0
	if state.max_health > 0:
		ratio = float(state.health) / float(state.max_health)
	if ratio <= 0.34:
		score += int(weights.get("low_health", 0))
	if active_curse_count(state) >= 2:
		score += int(weights.get("many_curses", 0))
	if int(state.stone) < 6:
		score += int(weights.get("low_stone", 0))
	var loss_count := 0
	for index in range(maxi(0, state.event_log.size() - 6), state.event_log.size()):
		var event := state.event_log[index]
		var reason := str(event.get("reason", ""))
		if reason.begins_with("battle_") and (reason.contains("failed") or reason.contains("dead")):
			loss_count += 1
	if loss_count >= 2:
		score += int(weights.get("recent_losses", 0))
	if int(state.synthesis_fail_streak) >= 3:
		score += int(weights.get("synthesis_streak", 0))
	score = clampi(score, 0, max_score)
	var chosen: Dictionary = cfg.get("bands", [{}])[0] if not (cfg.get("bands", []) as Array).is_empty() else {}
	for band_value in cfg.get("bands", []):
		var band: Dictionary = band_value
		if int(band.get("min_score", 0)) <= score:
			chosen = band
	return {
		"score": score,
		"band": str(chosen.get("marker", "")),
		"label": str(chosen.get("label", "")),
		"marker": str(chosen.get("marker", "")),
		"enabled": state.dda_state_adaptive_enabled,
	}


# Diff of the current marker vs the evaluated band. Returns {} when nothing
# changes (no write) or the hall toggle is off (fixed progress difficulty).
static func refresh(state: RunState, catalog: Dictionary) -> Dictionary:
	if not state.dda_state_adaptive_enabled:
		return {}
	var evaluated := evaluate(state, catalog)
	var current := active_marker(state)
	if evaluated["marker"] == current:
		return {}
	var after := state.meta_rules.duplicate(true)
	if str(evaluated["marker"]).is_empty():
		after.erase(current)
	elif after.has(str(evaluated["marker"])):
		return {}
	else:
		for key in after.keys():
			if str(key).begins_with(SYS_MARKER_PREFIX):
				after.erase(key)
		after[str(evaluated["marker"])] = true
	return {
		"score": int(evaluated["score"]),
		"label": str(evaluated["label"]),
		"marker": str(evaluated["marker"]),
		"before": current,
		"after": after,
		"reason": "dda_clear" if str(evaluated["marker"]).is_empty() else ("dda_decay" if str(evaluated["marker"]) == "sys:dda_decay" else "dda_peril"),
	}


# Lever 1: swap the requested enemy kind per the active marker's pool, seeded.
# Never swaps bosses, the final boss, empty pools, or when the pool would
# return the same kind. Deterministic per (seed, event position).
static func battle_enemy_kind(state: RunState, requested_kind: String, catalog: Dictionary) -> String:
	var marker := active_marker(state)
	if marker.is_empty():
		return requested_kind
	var definition: Dictionary = catalog.get("enemy_by_id", {}).get(requested_kind, {})
	if str(definition.get("tier", "")) == "boss":
		return requested_kind
	if requested_kind == "miasma_vein_lord":
		return requested_kind
	var pools: Dictionary = catalog.get("dda", {}).get("enemy_swap_pools", {})
	var pool: Array = pools.get(marker, [])
	if pool.is_empty():
		return requested_kind
	var pick := SeededRollScript.index(pool.size(), int(state.seed), SWAP_SALT, state.event_log.size())
	var swapped := str(pool[pick])
	if swapped == requested_kind and pool.size() > 1:
		swapped = str(pool[(pick + 1) % pool.size()])
	return swapped


static func score_label(state: RunState, catalog: Dictionary) -> String:
	var evaluated := evaluate(state, catalog)
	return "%d/%d %s" % [int(evaluated["score"]), int(catalog.get("dda", {}).get("max_score", 10)), str(evaluated["label"])]


# Top-bar anomaly section: {id, label} for the active system marker.
static func marker_meta(state: RunState, catalog: Dictionary) -> Array:
	var marker := active_marker(state)
	if marker.is_empty():
		return []
	var evaluated := evaluate(state, catalog)
	return [{"id": marker, "label": str(evaluated["label"])}]



static func marker_label(marker: String, catalog: Dictionary) -> String:
	for band_value in catalog.get("dda", {}).get("bands", []):
		var band: Dictionary = band_value
		if str(band.get("marker", "")) == marker:
			return str(band.get("label", ""))
	return marker


# R14.6⑦ (night batch): boss-local adaptation — when a configured condition
# matches the player's current-run build, return the counter intent id to
# prioritize (only within the boss's own phase pool; see _select_enemy_intent).
static func boss_counter_intent(battle: Dictionary, state: RunState, catalog: Dictionary) -> String:
	var kind := str(battle.get("enemy_kind", ""))
	var definition: Dictionary = catalog.get("enemy_by_id", {}).get(kind, {})
	if str(definition.get("tier", "")) != "boss":
		return ""
	if not state.dda_state_adaptive_enabled:
		return ""
	for rule_value in catalog.get("dda", {}).get("boss_local", []):
		var rule: Dictionary = rule_value
		if str(rule.get("when", "")) == "many_curses" and active_curse_count(state) >= 2:
			return str(rule.get("intent_id", ""))
	return ""