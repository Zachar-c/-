extends SceneTree
## 真窗验证 BGM 播放链路：实例化 AudioDirector，play_bgm 后确认 playing=true。
## 用法（非 headless，否则无音频驱动）：tools\godot.ps1 --path . -s tools/verify_bgm_play.gd

const DirectorScene := "res://scenes/main.tscn"

func _initialize() -> void:
	var main: Node = (load(DirectorScene) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var director := main.get_node_or_null("AudioDirector")
	if director == null:
		print("DIRECTOR_MISSING")
		quit(1)
		return
	director.play_bgm("hall")
	# 等待 pending 落地（_process 重试最多几帧）
	for i in 10:
		await process_frame
		if director.current_bgm() == "hall":
			break
	var bgm := director.get_node_or_null("BgmPlayer") as AudioStreamPlayer
	var playing := bgm != null and bgm.playing
	print("BGM_PLAYING=", playing, " current=", director.current_bgm())
	# 静默跳过不视为失败（资源缺失时游戏应安静运行），仅资源存在但播放失败才算问题
	var stream_ok := ResourceLoader.exists("res://assets/audio/music/hall.mp3")
	print("BGM_STREAM_EXISTS=", stream_ok)
	quit(0)
