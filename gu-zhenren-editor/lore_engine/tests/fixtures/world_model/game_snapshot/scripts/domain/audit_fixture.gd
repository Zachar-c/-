class_name AuditFixture

static func default_v1_effect(definition: Dictionary) -> Dictionary:
	return {"kind": definition.get("role", "utility")}

static func resolve(state):
	var next = state.append_event({"action": "immutable_transition"})
	# refinement feeding transaction combat npc map meta
	return next
