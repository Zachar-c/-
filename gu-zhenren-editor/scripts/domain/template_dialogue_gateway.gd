class_name TemplateDialogueGateway
extends DialogueGateway


static var _templates_cache: Dictionary = {}


static func clear_cache() -> void:
	_templates_cache = {}


func respond(context: Dictionary) -> Dictionary:
	var intent := str(context.get("intent", "clarify"))
	var templates := _load_templates()
	var response: Dictionary = templates.get(intent, templates.get("clarify", {})).duplicate(true)
	if not _is_valid(response):
		return _clarify_response()
	return response


func _load_templates() -> Dictionary:
	if not _templates_cache.is_empty():
		return _templates_cache
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string("res://data/dialogue_templates.json")) != OK:
		return {}
	if not json.data is Dictionary:
		return {}
	_templates_cache = json.data.get("responses", {})
	return _templates_cache


func _is_valid(response: Dictionary) -> bool:
	return DialogueGateway.is_valid_response(response)


func _clarify_response() -> Dictionary:
	return {
		"intent": "clarify",
		"confidence": 0.0,
		"conditions": [],
		"text": "管事追问你究竟想提出什么条件。",
		"needs_clarification": true,
	}
