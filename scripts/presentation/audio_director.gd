class_name AudioDirector
extends AudioStreamPlayer
## 全局音效入口（main.tscn 常驻节点，跨屏存活）。
##
## 音频资源尚未落地，本类只提供接线点：路径无效或资源缺失时静默跳过，绝不打断游戏流程。
## 并发限制：AudioStreamPlayer 单声道，新音效会打断上一条。需要叠音时再加播放池。

var _cache: Dictionary = {}


## 播放一条音效。path 为空/不存在/非 AudioStream 时静默返回。
func play_sfx(path: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = _cache.get(path)
	if stream == null:
		stream = load(path) as AudioStream
		if stream == null:
			return
		_cache[path] = stream
	stop()
	set_stream(stream)
	set_volume_db(volume_db)
	set_pitch_scale(pitch)
	play()


func stop_sfx() -> void:
	stop()


## 释放加载过的流缓存（切项目/退出时调用，避免常驻内存）。
func clear_cache() -> void:
	_cache.clear()
