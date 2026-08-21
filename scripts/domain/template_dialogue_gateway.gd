class_name TemplateDialogueGateway
extends DialogueGateway


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
	return DialogueGateway.is_valid_response(response)


func _clarify_response() -> Dictionary:
	return {
		"intent": "clarify",
		"confidence": 0.0,
		"conditions": [],
		"text": "管事追问你究竟想提出什么条件。",
		"needs_clarification": true,
	}
