extends GutTest


func test_invalid_cloud_payload_uses_template_response() -> void:
	var gateway := CloudDialogueGateway.new(BadTransport.new())
	var result := gateway.respond({"intent": "trade", "disposition": "neutral"})
	assert_eq(result["source"], "template")
	assert_eq(result["intent"], "trade")
	assert_eq(result["text"], "管事收下账册证据，为你打开一条有人照看的路。")


func test_missing_template_uses_chinese_fallback_response() -> void:
	var gateway := MissingTemplateGateway.new()
	var result := gateway.respond({"intent": "trade"})
	assert_eq(result["text"], "管事追问你究竟想提出什么条件。")


class BadTransport extends RefCounted:
	func respond(_context: Dictionary) -> Dictionary:
		return {"unexpected": "payload"}


class MissingTemplateGateway extends TemplateDialogueGateway:
	func _load_templates() -> Dictionary:
		return {}
