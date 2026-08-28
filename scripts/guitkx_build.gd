extends SceneTree

# Headless entry point for the generated RUI siblings consumed by GUT and capture scripts.
const Codegen = preload("res://addons/reactive_ui_toolkit/guitkx/guitkx_codegen.gd")


func _initialize() -> void:
	var result: Dictionary = Codegen.compile_all("res://")
	for failure in result.get("errors", []):
		push_error("[guitkx-build] %s" % str(failure))
	if not result.get("held", []).is_empty():
		push_error("[guitkx-build] environment held: %s" % str(result["held"]))
	print("[guitkx-build] compiled=%d errors=%d held=%d total=%d" % [
		result.get("compiled", []).size(),
		result.get("errors", []).size(),
		result.get("held", []).size(),
		int(result.get("total", 0)),
	])
	quit(1 if not result.get("errors", []).is_empty() or not result.get("held", []).is_empty() else 0)
