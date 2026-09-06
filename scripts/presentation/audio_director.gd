class_name AudioDirector
extends AudioStreamPlayer
## 全局音频入口（main.tscn 常驻节点，跨屏存活）。
##
## SFX 由自身播放；BGM 由懒创建的子节点 BgmPlayer 播放，两者互不打断。
## 音频资源缺失时静默跳过，绝不打断游戏流程。
## BGM 资源确定性合成（24kHz mono，无缝循环），无第三方版权；
## 曲目 key 与 run_controller 的视图 → BGM 映射一致。
## 2026-09-06 资产更替：music/ 目录由 .wav 换为 .mp3/.ogg（视曲目而定），
## 循环在播放路径按流类型强制开启（见 _force_loop），import 默认关闭不依赖。

## 曲目表：key → 资源路径。新增曲目需同时更新本表与 tools/generate_music.py。
const BGM_PATHS := {
	"hall": "res://assets/audio/music/hall.mp3",
	"map": "res://assets/audio/music/map.ogg",
	"battle": "res://assets/audio/music/battle.mp3",
	"ending": "res://assets/audio/music/ending.ogg",
}
## BGM 相对主音量衰减，避免盖过音效提示。
const BGM_VOLUME_DB := -9.0

var _cache: Dictionary = {}
var _bgm_player: AudioStreamPlayer = null
## 当前请求的曲目 key（幂等判断 / current_bgm 对外语义，登记意图即更新）。
var _current_bgm := ""
## 播放器实际装载的曲目 key（重建判断：与待播意图不一致时切歌）。
var _player_bgm := ""
var _pending_bgm_key := ""
var _pending_stream: AudioStream = null


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


## 循环由代码强制开启：import 侧默认关闭（WAV 用 loop_mode 枚举，
## MP3/OggVorbis 用 loop 布尔），不依赖具体导入配置。
static func _force_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


## 播放 BGM 曲目（key 见 BGM_PATHS）。未知 key / 资源缺失 / 未入树时静默跳过；
## 同曲目已请求/播放时不重启（同屏命令重渲染幂等）。循环由代码强制开启。
## 播放器只在 _process（树稳定上下文）创建与启动：Godot 4.7 真实音频驱动下，
## _ready 链中创建的 AudioStreamPlayer play() 会静默失败（playing=false）；
## 稳定上下文新建节点 + play 可稳定复现（tools/diag_bgm5.gd 采样 5/5 成功）。
func play_bgm(key: String) -> void:
	var path := str(BGM_PATHS.get(key, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	if key == _current_bgm and _bgm_player != null and is_instance_valid(_bgm_player):
		return
	var stream: AudioStream = _cache.get(path)
	if stream == null:
		stream = load(path) as AudioStream
		if stream == null:
			return
		_force_loop(stream)
		_cache[path] = stream
	if not is_inside_tree():
		return
	# _current_bgm 立即更新，保证同屏重渲染的幂等判断与 current_bgm() 语义。
	_current_bgm = key
	if is_node_ready():
		# 稳定上下文：直接创建并启动播放器（GUT 树/运行中切歌走此路径）。
		_start_player(stream, key)
	else:
		# _ready 链中创建的播放器在真实音频驱动下 play 会静默失败：
		# 只登记意图，由 _process 在稳定上下文落地。
		_pending_bgm_key = key
		_pending_stream = stream


## 创建（或重建）BgmPlayer 并立即尝试播放；若未进入播放态则挂起待播意图，
## 由 _process 逐帧重试（真实驱动下首帧 play 可能静默失败，多帧重试可恢复）。
func _start_player(stream: AudioStream, key: String) -> void:
	if _bgm_player != null and is_instance_valid(_bgm_player):
		_bgm_player.stop()
		# 立即释放而非 queue_free：旧节点帧末才释放会占住 "BgmPlayer" 名字，
		# 新节点被迫改名，get_node("BgmPlayer") 将取到已释放对象。
		_bgm_player.free()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.volume_db = BGM_VOLUME_DB
	add_child(_bgm_player)
	_player_bgm = key
	_bgm_player.set_stream(stream)
	_bgm_player.play()
	if not _bgm_player.playing:
		_pending_bgm_key = key
		_pending_stream = stream


## 稳定上下文兜底：处理 _ready 链中登记的待播意图，及播放未确认时的逐帧重试。
func _process(_delta: float) -> void:
	if _pending_bgm_key.is_empty() or _pending_stream == null:
		return
	if not is_inside_tree():
		return
	if _bgm_player == null or not is_instance_valid(_bgm_player) or _player_bgm != _pending_bgm_key:
		_start_player(_pending_stream, _pending_bgm_key)
		return
	if _bgm_player.playing:
		# 上一帧 play 已确认真实生效（持续输出中），落地本次意图
		_pending_bgm_key = ""
		_pending_stream = null
		return
	_bgm_player.play()
	# 不立即清空 pending：play() 的 playing 标志可能瞬时置位而驱动未真正输出；
	# 保留意图，由下一帧的 playing 确认（false 则继续重试）


## 停止 BGM（保留流缓存，供再次播放复用）。
func stop_bgm() -> void:
	_current_bgm = ""
	_pending_bgm_key = ""
	_pending_stream = null
	_player_bgm = ""
	if _bgm_player != null and is_instance_valid(_bgm_player):
		_bgm_player.stop()


## 当前 BGM 曲目 key；未播放或已停止时为 ""。
func current_bgm() -> String:
	return _current_bgm


## 释放加载过的流缓存（切项目/退出时调用，避免常驻内存）。
func clear_cache() -> void:
	_cache.clear()
