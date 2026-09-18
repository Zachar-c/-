class_name SettingsSnapshot
extends RefCounted


# W12 split: the Settings screen snapshot, moved verbatim from
# run_snapshot_builder.gd. Read-only projection; multi-screen shared helpers
# stay on RunSnapshotBuilder.


const GameVersionScript = preload("res://scripts/domain/game_version.gd")
const AppSettingsScript = preload("res://scripts/domain/app_settings.gd")


## 设置屏快照：客户端偏好只投影（同大厅 A6 设置面板字段），绝不写回。
static func build(controller) -> Dictionary:
	var base := RunSnapshotBuilder._gui_state(controller)
	base["title"] = "设置"
	base["subtitle"] = "声色之调 · 存于机匣"
	base["master_volume"] = AppSettingsScript.clamp_volume(int(controller.app_settings.master_volume)) if controller.get("app_settings") != null else 100
	base["resolution_index"] = int(controller.app_settings.resolution_index) if controller.get("app_settings") != null else 0
	base["resolution_options"] = AppSettingsScript.resolution_labels()
	base["version_label"] = GameVersionScript.display()
	return base
