class_name Battle2TurnEngine
extends RefCounted


# Spec-v4 phase-2 (T4.1): discrete-turn round engine - phase sequence
# (§12.4), thought pool (§12.1/§12.2) and per-turn usage ledger (§12.3).
# Pure domain / pure data: no UI, no dice, no shared mutable state.
# Every mutation takes the round ledger as a parameter and returns a new
# ledger. can_enact is the single preflight source that enact also runs
# (§17.3 preflight=execution). Battle settlement is deterministic by spec -
# this module never rolls dice.


const PHASE_DECLARE := "declare"
const PHASES := ["instant", "quick", "standard", "windup", "end"]
const BASIC_ACTIONS := ["move", "strike", "dodge", "grapple"]
const ONGOING_ACTION_KINDS := ["grapple_hold", "windup"]


# §12.4 round sequence: 声明 -> 瞬时 -> 快速 -> 标准 -> 蓄势 -> 回合结束.
static func next_phase(phase: String) -> String:
	if phase == PHASE_DECLARE:
		return "instant"
	var index := PHASES.find(phase)
	if index < 0 or index >= PHASES.size() - 1:
		return "end"
	return PHASES[index + 1]


# battle2 round ledger shape (the T9.1 snapshot will consume this):
# {
#   "phase": "declare"|...|"end",
#   "thoughts_left": int,   # playable pool this round (capacity - claims)
#   "thought_used": int,    # spent this round, never refunded
#   "reserved": int,        # thoughts parked for reaction windows
#   "gu_used": {instance_id: true},      # active activations per round
#   "actions_used": {"move"/"strike"/"dodge"/"grapple": bool},
#   "maintained": [instance_id],          # actively maintained gu
#   "ongoing": [{"kind","action","instance_id","thought","turns_left"}],
# }
static func new_turn(capacity: int) -> Dictionary:
	return {
		"phase": PHASE_DECLARE,
		"thoughts_left": maxi(0, capacity),
		"thought_used": 0,
		"reserved": 0,
		"gu_used": {},
		"actions_used": {
			"move": false, "strike": false, "dodge": false, "grapple": false,
		},
		"maintained": [],
		"ongoing": [],
	}


static func thoughts_left(turn: Dictionary) -> int:
	return int(turn.get("thoughts_left", 0))


static func thought_used(turn: Dictionary) -> int:
	return int(turn.get("thought_used", 0))


# §12.1/§12.5: at the round boundary spent thoughts clear and the pool resets;
# maintenance claims its thought before anything else. Ongoing entries: the
# player declares which ids continue (continue_ids; null keeps the legacy
# "all continue" behaviour). Uncontinued entries default to a stop (§12.5 -
# already-resulted facts stay, unfinished abstract progress clears). A
# continued entry that the pool cannot afford also stops - the pool is judged
# first and never goes negative.
static func start_turn(turn: Dictionary, capacity: int, continue_ids: Variant = null) -> Dictionary:
	var out := turn.duplicate(true)
	out["phase"] = PHASE_DECLARE
	out["thoughts_left"] = maxi(0, capacity)
	out["thought_used"] = 0
	out["reserved"] = 0
	out["gu_used"] = {}
	out["actions_used"] = {
		"move": false, "strike": false, "dodge": false, "grapple": false,
	}
	out["maintained"] = []
	for instance_id in turn.get("maintained", []):
		out = _spend(out, 1)
	var continuing := {}
	if continue_ids != null:
		for id_value in continue_ids:
			continuing[str(id_value)] = true
	var remaining: Array = []
	for entry in turn.get("ongoing", []):
		var entry_id := str((entry as Dictionary).get("id", ""))
		if continue_ids != null and not continuing.has(entry_id):
			continue
		var turns_left := int((entry as Dictionary).get("turns_left", 0)) - 1
		if turns_left < 0:
			continue
		var thought := int((entry as Dictionary).get("thought", 1))
		if int(out.get("thoughts_left", 0)) < thought:
			continue
		var kept: Dictionary = (entry as Dictionary).duplicate(true)
		kept["turns_left"] = turns_left
		remaining.append(kept)
		out = _spend(out, thought)
		out = _claim_entry_usage(out, kept)
	out["ongoing"] = remaining
	return out


static func action_used(turn: Dictionary, action: String) -> bool:
	return bool(turn.get("actions_used", {}).get(action, false))


static func gu_used(turn: Dictionary, instance_id: String) -> bool:
	return bool(turn.get("gu_used", {}).has(str(instance_id)))


# §12.5 cross-round registration (grapple holds, windups, complex terrain).
# While turns_left >= 0 the entry keeps occupying its slot and thought.
static func add_ongoing(turn: Dictionary, entry: Dictionary) -> Dictionary:
	var out := turn.duplicate(true)
	var list: Array = (out.get("ongoing", []) as Array).duplicate()
	list.append(entry.duplicate(true))
	out["ongoing"] = list
	return out


# §12.3: an actively maintained gu counts as operating and cannot be
# re-activated; maintenance claims its thought (declared by the gu effect).
static func add_maintenance(turn: Dictionary, instance_id: String, thought: int) -> Dictionary:
	var pre := can_enact(turn, {
		"kind": "maintain", "instance_id": instance_id, "thought": thought,
	})
	if not bool(pre["ok"]):
		return turn
	var out := _spend(turn, maxi(1, thought))
	var ids: Array = (out.get("maintained", []) as Array).duplicate()
	ids.append(str(instance_id))
	out["maintained"] = ids
	out["gu_used"][str(instance_id)] = true
	return out


# §12.2: spent thoughts are never refunded; reserve parks thought for the
# reaction windows without executing anything.
static func consume(turn: Dictionary, amount: int) -> Dictionary:
	var out := _spend(turn, maxi(0, amount))
	return out


static func reserve(turn: Dictionary, amount: int) -> Dictionary:
	if int(turn.get("thoughts_left", 0)) < amount:
		return turn
	var out := turn.duplicate(true)
	out["reserved"] = int(out.get("reserved", 0)) + amount
	out["thoughts_left"] = int(out.get("thoughts_left", 0)) - amount
	return out


# §12.3: a parallel group may not repeat an action kind or an instance.
static func parallel_group_valid(group: Array) -> Dictionary:
	var seen_actions := {}
	var seen_instances := {}
	for entry in group:
		var action := str((entry as Dictionary).get("action", ""))
		if seen_actions.has(action):
			return {"ok": false, "reason": "parallel_group_repeats_action"}
		seen_actions[action] = true
		var instance_id := str((entry as Dictionary).get("instance_id", ""))
		if not instance_id.is_empty():
			if seen_instances.has(instance_id):
				return {"ok": false, "reason": "parallel_group_repeats_instance"}
			seen_instances[instance_id] = true
	return {"ok": true, "reason": ""}


# §17.3: can_enact is THE preflight; enact runs the same source of truth.
# proposal shapes:
#   {"kind": "activate_gu", "instance_id", "thought"}  (gu activation)
#   {"kind": "basic_action", "action", "thought"}      (move/strike/dodge/grapple)
#   {"kind": "maintain", "instance_id", "thought"}     (maintenance claim)
static func can_enact(turn: Dictionary, proposal: Dictionary) -> Dictionary:
	var kind := str(proposal.get("kind", ""))
	var thought := int(proposal.get("thought", 1))
	match kind:
		"activate_gu":
			var instance_id := str(proposal.get("instance_id", ""))
			if (turn.get("maintained", []) as Array).has(instance_id):
				return {"ok": false, "reason": "maintenance_blocks_activation"}
			if gu_used(turn, instance_id):
				return {"ok": false, "reason": "gu_already_used_this_turn"}
			if int(turn.get("thoughts_left", 0)) < thought:
				return {"ok": false, "reason": "insufficient_thought"}
			return {"ok": true, "reason": ""}
		"basic_action":
			var action := str(proposal.get("action", ""))
			if not BASIC_ACTIONS.has(action):
				return {"ok": false, "reason": "unknown_action"}
			if action_used(turn, action):
				return {"ok": false, "reason": "action_already_used_this_turn"}
			if int(turn.get("thoughts_left", 0)) < maxi(1, thought):
				return {"ok": false, "reason": "insufficient_thought"}
			return {"ok": true, "reason": ""}
		"maintain":
			if int(turn.get("thoughts_left", 0)) < maxi(1, thought):
				return {"ok": false, "reason": "insufficient_thought"}
			return {"ok": true, "reason": ""}
		_:
			return {"ok": false, "reason": "unknown_proposal_kind"}


static func enact(turn: Dictionary, proposal: Dictionary) -> Dictionary:
	var pre := can_enact(turn, proposal)
	if not bool(pre["ok"]):
		return {"ok": false, "reason": pre["reason"], "ledger": turn}
	var kind := str(proposal.get("kind", ""))
	var thought := int(proposal.get("thought", 1))
	var out := turn
	match kind:
		"activate_gu":
			var instance_id := str(proposal.get("instance_id", ""))
			out = _spend(out, thought)
			out["gu_used"][instance_id] = true
		"basic_action":
			var action := str(proposal.get("action", ""))
			out = _spend(out, maxi(1, thought))
			out["actions_used"][action] = true
		"maintain":
			out = add_maintenance(out, str(proposal.get("instance_id", "")), thought)
	return {"ok": true, "reason": "", "ledger": out}


static func _spend(turn: Dictionary, amount: int) -> Dictionary:
	var out := turn.duplicate(true)
	out["thought_used"] = int(out.get("thought_used", 0)) + maxi(0, amount)
	out["thoughts_left"] = int(out.get("thoughts_left", 0)) - maxi(0, amount)
	return out


static func _claim_entry_usage(turn: Dictionary, entry: Dictionary) -> Dictionary:
	var out := turn.duplicate(true)
	var action := str(entry.get("action", ""))
	if not action.is_empty():
		out["actions_used"][action] = true
	var instance_id := str(entry.get("instance_id", ""))
	if not instance_id.is_empty():
		out["gu_used"][instance_id] = true
	return out