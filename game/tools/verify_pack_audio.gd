extends SceneTree
## 验证导出 pack 内音频资源可达（BGM 4 曲 + 代表性 SFX）。

func _initialize() -> void:
	var pck := "res://.preview/verify_audio.pck"
	var ok := ProjectSettings.load_resource_pack(pck, false)
	print("PCK_LOADED=", ok)
	var checks := [
		"res://assets/audio/music/hall.mp3",
		"res://assets/audio/music/map.ogg",
		"res://assets/audio/music/battle.mp3",
		"res://assets/audio/music/ending.ogg",
		"res://assets/audio/music/rest.mp3",
		"res://assets/audio/music/shop.mp3",
		"res://assets/audio/ui/ui_click.ogg",
		"res://assets/audio/battle/battle_hit.ogg",
		"res://assets/audio/refine/refine_success.ogg",
	]
	var missing: Array = []
	for p in checks:
		var exists := ResourceLoader.exists(p)
		print(("  OK  " if exists else "  MISS") + p)
		if not exists:
			missing.append(p)
	print("MISSING_COUNT=", missing.size())
	quit(0 if missing.is_empty() else 1)
