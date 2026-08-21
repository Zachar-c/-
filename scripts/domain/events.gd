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
