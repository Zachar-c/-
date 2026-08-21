class_name TemplateDialogueGateway
extends DialogueGateway


const ALLOWED_INTENTS := ["probe", "trade", "pressure", "leave", "clarify"]
const ALLOWED_KEYS := ["intent", "confidence", "conditions", "text", "needs_clarification"]


func respond(context: Dictionary) -> Dictionary:
	var intent := str(context.get("intent", "clarify"))
	var templates := _load_templates()
	var response: Dictionary = templates.get(intent, templates.get("clarify", {})).duplicate(true)
	if not _is_valid(response):
		return _clarify_response()
	return response


func _load_templates() -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string("res://data/dialogue_templates.json")) != OK:
		return {}
	if not json.data is Dictionary:
		return {}
	return json.data.get("responses", {})


func _is_valid(response: Dictionary) -> bool:
	if response.keys().size() != ALLOWED_KEYS.size():
		return false
	for key in response:
		if not ALLOWED_KEYS.has(key):
			return false
	return ALLOWED_INTENTS.has(response.get("intent", "")) \
		and response.get("confidence", -1.0) >= 0.0 \
		and response.get("confidence", 2.0) <= 1.0 \
		and response.get("conditions", null) is Array \
		and response.get("text", "") is String \
		and response.get("needs_clarification", null) is bool


func _clarify_response() -> Dictionary:
	return {
		"intent": "clarify",
		"confidence": 0.0,
		"conditions": [],
		"text": "The steward asks what terms you are offering.",
		"needs_clarification": true,
	}
