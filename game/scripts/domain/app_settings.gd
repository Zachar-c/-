class_name AppSettings
extends RefCounted

# Client preferences that are neither RunData nor hall progress (§16.12/§16.22):
# volume and display live in their own ConfigFile so wiping a run or the meta
# save never touches them, and they never enter any run snapshot as gameplay
# state. Pure data + persistence; engine effects (AudioServer bus, window
# mode) are applied by the presentation layer (RunController).

const SETTINGS_PATH := "user://nanjiang_smoke_settings.cfg"

# Resolution options: index 0 is fullscreen; the rest are windowed sizes the
# 1920x1080 canvas_items viewport scales onto cleanly.
const RESOLUTIONS := [
	{"label": "全屏", "fullscreen": true, "size": Vector2i(1920, 1080)},
	{"label": "1920×1080 · 窗口", "fullscreen": false, "size": Vector2i(1920, 1080)},
	{"label": "1600×900 · 窗口", "fullscreen": false, "size": Vector2i(1600, 900)},
	{"label": "1280×720 · 窗口", "fullscreen": false, "size": Vector2i(1280, 720)},
]

var master_volume: int = 100
var resolution_index: int = 0
## 静音前的音量（静音切换恢复用，随设置持久化）。
var pre_mute_volume: int = 100


static func clamp_volume(value: int) -> int:
	return clampi(value, 0, 100)


static func resolution_labels() -> Array:
	var labels: Array = []
	for option in RESOLUTIONS:
		labels.append(str(option["label"]))
	return labels


static func next_resolution_index(index: int) -> int:
	var count := RESOLUTIONS.size()
	if count == 0:
		return 0
	return posmod(index + 1, count)


## Defensive read: an out-of-range persisted index falls back to fullscreen
## instead of crashing the settings screen.
static func resolution_at(index: int) -> Dictionary:
	if index < 0 or index >= RESOLUTIONS.size():
		return RESOLUTIONS[0]
	return RESOLUTIONS[index]


static func has_saved_file() -> bool:
	return FileAccess.file_exists(SETTINGS_PATH)


static func save_settings(settings: AppSettings) -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", int(settings.master_volume))
	config.set_value("audio", "pre_mute_volume", int(settings.pre_mute_volume))
	config.set_value("display", "resolution_index", int(settings.resolution_index))
	config.save(SETTINGS_PATH)


static func load_settings() -> AppSettings:
	var settings := new()
	if not has_saved_file():
		return settings
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return settings
	settings.master_volume = clamp_volume(int(config.get_value("audio", "master_volume", 100)))
	settings.pre_mute_volume = clamp_volume(int(config.get_value("audio", "pre_mute_volume", 100)))
	settings.resolution_index = int(config.get_value("display", "resolution_index", 0))
	if settings.resolution_index < 0 or settings.resolution_index >= RESOLUTIONS.size():
		settings.resolution_index = 0
	return settings
