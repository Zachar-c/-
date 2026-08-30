extends GutTest


func test_missing_template_uses_chinese_fallback_response() -> void:
	var gateway := MissingTemplateGateway.new()
	var result := gateway.respond({"intent": "trade"})
	assert_eq(result["text"], "管事追问你究竟想提出什么条件。")


func test_template_gateway_reuses_cached_templates_until_cache_is_cleared() -> void:
	TemplateDialogueGateway.clear_cache()
	var gateway := TemplateDialogueGateway.new()
	var first := gateway._load_templates()
	var second := gateway._load_templates()

	assert_same(first, second)
	first["test_cache_marker"] = true
	assert_true(second.has("test_cache_marker"))
	TemplateDialogueGateway.clear_cache()
	var reloaded := gateway._load_templates()
	assert_false(reloaded.has("test_cache_marker"))


class MissingTemplateGateway extends TemplateDialogueGateway:
	func _load_templates() -> Dictionary:
		return {}
