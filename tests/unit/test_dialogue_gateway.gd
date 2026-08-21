extends GutTest


func test_invalid_cloud_payload_uses_template_response() -> void:
	var gateway := CloudDialogueGateway.new(BadTransport.new())
	var result := gateway.respond({"intent": "trade", "disposition": "neutral"})
	assert_eq(result["source"], "template")
	assert_eq(result["intent"], "trade")
	assert_eq(result["text"], "The steward accepts the ledger and opens a guarded route.")


class BadTransport extends RefCounted:
	func respond(_context: Dictionary) -> Dictionary:
		return {"unexpected": "payload"}
