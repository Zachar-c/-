class_name CommandSpec
extends RefCounted


static func definition(
	spec_id: String,
	scope: String,
	freshness_kind: String,
	required_fields: Array[String]
) -> Dictionary:
	return {
		"id": spec_id,
		"scope": scope,
		"freshness_kind": freshness_kind,
		"required_fields": required_fields.duplicate(),
	}


static func ok(freshness_kind: String = "") -> Dictionary:
	return {
		"ok": true,
		"reason": "",
		"freshness": {"kind": freshness_kind, "expected": null, "actual": null},
		"cost": {},
		"remaining": {},
		"remedy_hints": [],
	}


static func reject(
	reason: String,
	freshness_kind: String = "",
	expected: Variant = null,
	actual: Variant = null,
	remedy_hints: Array = []
) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"freshness": {"kind": freshness_kind, "expected": expected, "actual": actual},
		"cost": {},
		"remaining": {},
		"remedy_hints": remedy_hints.duplicate(),
	}
