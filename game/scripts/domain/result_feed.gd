class_name ResultFeed
extends RefCounted


static func entry(action: String, text_key: String, changes: Dictionary, facts: Array[String]) -> Dictionary:
	return {
		"action": action,
		"text_key": text_key,
		"changes": changes.duplicate(true),
		"facts": facts.duplicate(),
	}
