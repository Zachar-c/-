class_name WenzhenAssetManifest
extends RefCounted

const REQUIRED_FIELDS := ["id", "path", "kind", "source", "license", "author", "facing"]


static func validate(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(manifest.get("schema_version", 0)) <= 0:
		errors.append("manifest missing schema_version")
	if str(manifest.get("usage_notice", "")).is_empty():
		errors.append("manifest missing usage_notice")
	var assets = manifest.get("assets", null)
	if not (assets is Array):
		errors.append("manifest missing assets[]")
		return errors
	var seen := {}
	for entry in assets:
		if not (entry is Dictionary):
			errors.append("manifest asset entry is not an object")
			continue
		for field in REQUIRED_FIELDS:
			if not entry.has(field):
				errors.append("%s missing %s" % [str(entry.get("id", "<no-id>")), field])
				continue
			if str(entry[field]).is_empty():
				errors.append("%s has empty %s" % [str(entry.get("id", "<no-id>")), field])
		if entry.has("watermark") and str(entry["watermark"]).is_empty():
			errors.append("%s has empty watermark" % str(entry.get("id", "<no-id>")))
		if entry.has("sha256"):
			if not _is_sha256(str(entry["sha256"])):
				errors.append("%s sha256 must be 64 hex chars" % str(entry.get("id", "<no-id>")))
		var id := str(entry.get("id", ""))
		if seen.has(id):
			errors.append("duplicate id %s" % id)
		seen[id] = true
		var path := str(entry.get("path", ""))
		if not path.is_empty() and not FileAccess.file_exists("res://" + path):
			errors.append("%s path does not exist: %s" % [id, path])
	return errors


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for i in range(value.length()):
		var c := value.unicode_at(i)
		if not (c >= 48 and c <= 57) and not (c >= 97 and c <= 102) and not (c >= 65 and c <= 70):
			return false
	return true
