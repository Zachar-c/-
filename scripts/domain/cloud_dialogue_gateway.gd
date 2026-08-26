class_name CloudDialogueGateway
extends DialogueGateway


const API_KEY_ENV := "NANJIANG_CLOUD_DIALOGUE_KEY"


var transport: RefCounted
var template_gateway := TemplateDialogueGateway.new()


func _init(transport_adapter: RefCounted = null) -> void:
	transport = transport_adapter


func respond(context: Dictionary) -> Dictionary:
	if transport != null and transport.has_method("respond"):
		var payload: Variant = transport.respond(context)
		if payload is Dictionary and DialogueGateway.is_valid_response(payload):
			var cloud_response: Dictionary = payload.duplicate(true)
			cloud_response["source"] = "cloud"
			return cloud_response
	return _template_response(context)


func _template_response(context: Dictionary) -> Dictionary:
	var fallback := template_gateway.respond(context)
	fallback["source"] = "template"
	return fallback
