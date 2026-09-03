class_name EventFactory
extends RefCounted


static func resource_changed(
	key: String,
	before: int,
	after: int,
	reason: String,
	source: String
) -> Dictionary:
	return {
		"stage": "one",
		"time": 0,
		"node_id": source,
		"action": "state_change",
		"before": {key: before},
		"after": {key: after},
		"reason": reason,
		"source": source,
		"targets": [],
	}


## Narrative metadata emitted by the dialogue adapter. Applying a branch still
## goes through Resolver/EncounterSessionResolver; this helper only keeps the
## branch selection shape consistent for feeds, replay, and diagnostics.
## stage/time are intentionally omitted: RunState._normalized_event defaults
## them to the current stage and the event index, so late-run branches are not
## mis-attributed to stage "one" / time zero.
static func dialogue_branch(
	node_id: String,
	branch_id: String,
	event_id: String,
	outcome: String,
	reason: String = ""
) -> Dictionary:
	return {
		"node_id": node_id,
		"action": "dialogue_branch",
		"before": {},
		"after": {
			"branch_id": branch_id,
			"event_id": event_id,
			"outcome": outcome,
		},
		"reason": reason,
		"source": "dialogue_manager_adapter",
		"targets": [branch_id],
	}
