class_name RelicHookResolver
extends RefCounted

const SchoolRulesScript = preload("res://scripts/domain/school_rules.gd")

# Data-driven enumerable relic hooks. Each relic in relics.json declares
# `hooks: [{ trigger, effect: { kind, amount } }]`. This resolver is pure
# domain logic: it never touches UI, never calls RNG, and only mutates the
# battle dictionary passed to it (deep-duplicated by callers) or appends
# immutable events to RunState. Unknown triggers/effects are rejected at
# ContentCatalog.validate time and skipped defensively here.

const TRIGGERS := [
	"on_battle_start",
	"on_draw_card",
	"on_play_card",
	"on_take_damage",
	"on_estimate_feeding",
	"on_backlash_gained",
	"on_battle_end",
]

const EFFECT_KINDS := [
	"grant_first_turn_energy",
	"draw_extra_card",
	"gain_essence_on_play",
	"reduce_incoming_damage",
	"add_feeding_points",
	"convert_backlash_to_draw",
	"reduce_curse_intensity",
	"grant_stone_on_battle_end",
]


static func apply_battle_start(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	# Battle-local first-turn energy budget. BattleResolver.start seeds the
	# base grant (1); each grant_first_turn_energy effect stacks on top of it
	# in battle["first_turn_energy"] and battle["action_energy"].
	var base := int(battle.get("first_turn_energy", 0))
	var energy := base
	for hook in _hooks(state, catalog, "on_battle_start"):
		if str(hook.get("effect", {}).get("kind", "")) == "grant_first_turn_energy":
			energy += _amount(hook)
	battle["first_turn_energy"] = energy
	battle["action_energy"] = energy
	var feeds: Array[String] = []
	if energy > base:
		feeds.append("relic_first_turn_energy")
	# R4.x reduce_curse_intensity: battle-local curse projections lose
	# `amount` intensity each (floor 0); run-scoped statuses stay untouched
	# because battles only ever project curses.
	var reduction := 0
	for hook in _hooks(state, catalog, "on_battle_start"):
		if str(hook.get("effect", {}).get("kind", "")) == "reduce_curse_intensity":
			reduction += _amount(hook)
	if reduction > 0:
		battle["curses"] = _intensity_reduced(battle.get("curses", []), reduction)
		feeds.append("relic_curse_reduced")
	return {"battle": battle, "state": state, "feeds": feeds}


static func _intensity_reduced(projections: Array, reduction: int) -> Array:
	var reduced: Array = projections.duplicate(true)
	for index in reduced.size():
		var projection: Dictionary = reduced[index]
		projection["intensity"] = maxi(0, int(projection.get("intensity", 0)) - reduction)
		reduced[index] = projection
	return reduced


# R4.x on_backlash_gained: fires once per curse layer that becomes known to an
# ACTIVE battle (projection at battle start today; any later battle-dict curse
# update would route through here too). Run-scoped gains outside battles never
# reach this resolver, so they never fire hooks. convert_backlash_to_draw
# queues bonus cards for the NEXT refill draw; battle_resolver consumes and
# clears battle["pending_extra_draws"] exactly once.
static func apply_backlash_gained(battle: Dictionary, state: RunState, catalog: Dictionary, layers_gained: int) -> Dictionary:
	var queued := 0
	for hook in _hooks(state, catalog, "on_backlash_gained"):
		if str(hook.get("effect", {}).get("kind", "")) == "convert_backlash_to_draw":
			queued += _amount(hook) * maxi(0, layers_gained)
	# R4.7 soul anchor: soul school converts backlash to draw at double rate.
	if SchoolRulesScript.is_soul(state):
		queued *= 2
	var feeds: Array[String] = []
	if queued > 0:
		battle["pending_extra_draws"] = int(battle.get("pending_extra_draws", 0)) + queued
		feeds.append("relic_backlash_converted")
	return {"battle": battle, "state": state, "feeds": feeds}


# R4.x on_battle_end: fired from battle_resolver's single finalization funnel
# (victory / retreat / death) so grant_stone_on_battle_end appends ONE immutable
# stone event per finished battle no matter which path ends it.
static func apply_battle_end(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var stone_gain := 0
	for hook in _hooks(state, catalog, "on_battle_end"):
		if str(hook.get("effect", {}).get("kind", "")) == "grant_stone_on_battle_end":
			stone_gain += _amount(hook)
	var feeds: Array[String] = []
	if stone_gain <= 0:
		return {"battle": battle, "state": state, "feeds": feeds}
	state = state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "relic_stone_gain",
		"before": {"stone": state.stone},
		"after": {"stone": state.stone + stone_gain},
		"reason": "relic_stone_on_battle_end",
		"source": "relic_hook_resolver",
		"targets": [],
	})
	feeds.append("relic_battle_stone")
	return {"battle": battle, "state": state, "feeds": feeds}


static func apply_draw_card(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	# Returns an extra-draw count that battle_resolver applies with its own
	# seeded shuffle so RNG mechanics stay inside the resolver layer.
	var extra := 0
	for hook in _hooks(state, catalog, "on_draw_card"):
		if str(hook.get("effect", {}).get("kind", "")) == "draw_extra_card":
			extra += _amount(hook)
	var feeds: Array[String] = []
	if extra > 0:
		feeds.append("relic_draw_extra")
	return {"battle": battle, "state": state, "draw_extra": extra, "feeds": feeds}


static func apply_play_card(battle: Dictionary, state: RunState, catalog: Dictionary, _definition: Dictionary) -> Dictionary:
	# RunState-affecting hook: must append an immutable event so the gain is
	# reproducible and attributable by the ending journal.
	var gain := 0
	for hook in _hooks(state, catalog, "on_play_card"):
		if str(hook.get("effect", {}).get("kind", "")) == "gain_essence_on_play":
			gain += _amount(hook)
	var feeds: Array[String] = []
	if gain > 0:
		state = state.append_event({
			"stage": state.stage,
			"time": state.event_log.size(),
			"node_id": state.current_node_id,
			"action": "relic_essence_gain",
			"before": {"essence": state.essence},
			"after": {"essence": state.essence + gain},
			"reason": "relic_gain_essence_on_play",
			"source": "relic_hook_resolver",
			"targets": [],
		})
		feeds.append("relic_essence_gain")
	return {"battle": battle, "state": state, "feeds": feeds}


static func apply_take_damage(battle: Dictionary, state: RunState, catalog: Dictionary, damage: int) -> Dictionary:
	# Damage reduction computed here; the final health write stays in
	# battle_resolver._end_turn so it remains a single immutable event.
	var reduction := 0
	for hook in _hooks(state, catalog, "on_take_damage"):
		if str(hook.get("effect", {}).get("kind", "")) == "reduce_incoming_damage":
			reduction += _amount(hook)
	var feeds: Array[String] = []
	if reduction > 0:
		feeds.append("relic_damage_reduced")
	return {"battle": battle, "state": state, "damage": maxi(0, damage - reduction), "feeds": feeds}


static func feeding_extra(state: RunState, catalog: Dictionary) -> int:
	# Read-only query for upkeep estimation (no event writes, it is a query).
	var total := 0
	for hook in _hooks(state, catalog, "on_estimate_feeding"):
		if str(hook.get("effect", {}).get("kind", "")) == "add_feeding_points":
			total += _amount(hook)
	return total


static func _hooks(state: RunState, catalog: Dictionary, trigger: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var relic_by_id: Dictionary = catalog.get("relic_by_id", {})
	var ordered := state.relic_ids.duplicate()
	ordered.sort()
	for relic_id_value in ordered:
		var relic_id := str(relic_id_value)
		var relic: Dictionary = relic_by_id.get(relic_id, {})
		for hook in relic.get("hooks", []):
			if str(hook.get("trigger", "")) == trigger:
				result.append(hook)
	return result


static func _amount(hook: Dictionary) -> int:
	return maxi(0, int(hook.get("effect", {}).get("amount", 0)))
