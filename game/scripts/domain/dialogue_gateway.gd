class_name DialogueGateway
extends RefCounted


const ALLOWED_KEYS := ["intent", "confidence", "conditions", "text", "needs_clarification"]
const ALLOWED_INTENTS := ["probe", "trade", "pressure", "leave", "clarify"]


func respond(_context: Dictionary) -> Dictionary:
	return {}


static func is_valid_response(response: Dictionary) -> bool:
	if response.keys().size() != ALLOWED_KEYS.size():
		return false
	for key in response:
		if not ALLOWED_KEYS.has(key):
			return false
	var confidence: Variant = response.get("confidence", -1.0)
	if not (confidence is float or confidence is int):
		return false
	return ALLOWED_INTENTS.has(response.get("intent", "")) \
		and float(confidence) >= 0.0 \
		and float(confidence) <= 1.0 \
		and response.get("conditions", null) is Array \
		and response.get("text", "") is String \
		and response.get("needs_clarification", null) is bool
