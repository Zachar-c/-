extends RefCounted

## A7：设置/窗口/退出（§16.22 客户端偏好）外提。controller 保持同名一行包装。


const AppSettingsScript = preload("res://scripts/domain/app_settings.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")


static func toggle_dda(controller) -> void:
	if controller.meta == null:
		return
	controller.meta.dda_state_adaptive_enabled = not controller.meta.dda_state_adaptive_enabled
	SaveRepositoryScript.save_meta_file(controller.meta)
	controller._render()


static func step_master_volume(controller, delta: int) -> void:
	if controller.app_settings == null:
		return
	controller.app_settings.master_volume = AppSettingsScript.clamp_volume(
			int(controller.app_settings.master_volume) + delta)
	AppSettingsScript.save_settings(controller.app_settings)
	apply_master_volume(controller)
	controller._render()


static func cycle_resolution(controller) -> void:
	if controller.app_settings == null:
		return
	controller.app_settings.resolution_index = AppSettingsScript.next_resolution_index(
			int(controller.app_settings.resolution_index))
	AppSettingsScript.save_settings(controller.app_settings)
	apply_window_mode(controller)
	controller._render()


static func set_resolution_index(controller, index: int) -> void:
	if controller.app_settings == null:
		return
	if int(index) < 0 or int(index) >= AppSettingsScript.RESOLUTIONS.size():
		return
	controller.app_settings.resolution_index = int(index)
	AppSettingsScript.save_settings(controller.app_settings)
	apply_window_mode(controller)
	controller._render()


static func toggle_mute(controller) -> void:
	if controller.app_settings == null:
		return
	var current := AppSettingsScript.clamp_volume(int(controller.app_settings.master_volume))
	if current > 0:
		controller.app_settings.pre_mute_volume = current
		controller.app_settings.master_volume = 0
	else:
		controller.app_settings.master_volume = AppSettingsScript.clamp_volume(
				int(controller.app_settings.pre_mute_volume))
	AppSettingsScript.save_settings(controller.app_settings)
	apply_master_volume(controller)
	controller._render()


static func apply_master_volume(controller) -> void:
	var percent := AppSettingsScript.clamp_volume(int(controller.app_settings.master_volume)) \
			if controller.app_settings != null else 100
	if AudioServer.get_bus_count() < 1:
		return
	var bus := 0
	AudioServer.set_bus_mute(bus, percent <= 0)
	if percent > 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(float(percent) / 100.0))


static func apply_window_mode(controller) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var option: Dictionary = AppSettingsScript.resolution_at(int(controller.app_settings.resolution_index)) \
			if controller.app_settings != null else {}
	if option.is_empty():
		return
	if bool(option.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size: Vector2i = option.get("size", Vector2i(1920, 1080))
		controller.call_deferred("_deferred_set_window_size", size)


static func request_quit(controller) -> void:
	controller.quit_requested = true


static func quit_game(controller) -> void:
	request_quit(controller)
	if controller.is_inside_tree() and not Engine.is_editor_hint():
		controller.get_tree().quit()
