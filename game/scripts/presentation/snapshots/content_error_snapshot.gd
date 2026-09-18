class_name ContentErrorSnapshot
extends RefCounted


# W12 split: the ContentError screen snapshot, moved verbatim from
# run_snapshot_builder.gd. Read-only projection.


static func build(controller) -> Dictionary:
	var errors: Array = controller.get("_content_errors") if controller != null else []
	return {
		"title": "内容配置无法加载",
		"error_count": errors.size(),
		"errors": errors.duplicate(),
	}
