extends Node

## 音效管理器（第18批基础架构）
##
## 管理游戏中所有音效的播放、音量控制和资源加载。
## NOTE (A-1 landing 2026-09-06): no `class_name AudioManager` here - the
## script is registered as an autoload singleton of the same name in
## project.godot, and declaring the class_name made Godot fail every boot
## with "Class AudioManager hides an autoload singleton".
## 音效文件统一放在 `assets/audio/` 目录下，按类别分子目录。
## 开源音效来源：Freesound（CC0/CC BY）、OpenGameArt（CC0/CC BY）等。
##
## 使用方式：
##   AudioManager.play_sfx("ui_click")
##   AudioManager.play_sfx("battle_hit", 0.8)
##   AudioManager.set_master_volume(0.5)

## 音效注册表：音效ID → 文件路径（相对于res://）
## 第二批A-F-01：从Kenney.nl引入开源音效（CC0），替换程序生成测试音效。
## 音效文件统一使用OGG格式，放在 `assets/audio/` 目录下，按类别分子目录。
const SFX_REGISTRY := {
	# UI 音效（Kenney UI Audio）
	"ui_click": "assets/audio/ui/ui_click.ogg",
	"ui_hover": "assets/audio/ui/ui_hover.ogg",
	"ui_confirm": "assets/audio/ui/ui_confirm.ogg",
	"ui_cancel": "assets/audio/ui/ui_cancel.ogg",
	"ui_error": "assets/audio/ui/ui_error.ogg",
	# 战斗音效（Kenney Impact Sounds）
	"battle_hit": "assets/audio/battle/battle_hit.ogg",
	"battle_critical": "assets/audio/battle/battle_critical.ogg",
	"battle_miss": "assets/audio/battle/battle_miss.ogg",
	"battle_death": "assets/audio/battle/battle_death.ogg",
	"battle_card_play": "assets/audio/battle/battle_card_play.ogg",
	"battle_status_apply": "assets/audio/battle/battle_status_apply.ogg",
	# 炼蛊音效（Kenney Impact Sounds）
	"refine_success": "assets/audio/refine/refine_success.ogg",
	"refine_fail": "assets/audio/refine/refine_fail.ogg",
	"refine_curse": "assets/audio/refine/refine_curse.ogg",
	# 环境音效（OpenGameArt CC0）
	"env_cave_ambient": "assets/audio/env/cave_ambient.ogg",
	"env_wind": "assets/audio/env/wind.wav",
	"env_fog": "assets/audio/env/fog.ogg",
	# 概念层音效（Kenney Impact Sounds）
	"concept_seal_stamp": "assets/audio/concept/concept_seal_stamp.ogg",
	"concept_ink_spread": "assets/audio/concept/concept_ink_spread.ogg",
	"concept_text_strike": "assets/audio/concept/concept_text_strike.ogg",
}


## 音效多变体表：音效ID → 变体数量（不含基础版）。
## 第三批A-F-10：同类音效引入多变体，随机选择避免重复感。
## 变体文件命名规则：{基础文件名}_{1..N}.ogg，与基础版同目录。
const SFX_VARIANTS := {
	"ui_click": 5,
	"battle_hit": 5,
	"battle_card_play": 5,
}

## 音量配置
var _master_volume := 1.0
var _sfx_volume := 1.0
var _music_volume := 0.6

## 音效玩家池（避免频繁创建AudioStreamPlayer）
var _sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 8

## 单例引用
static var _instance: AudioManager = null


func _ready() -> void:
	_instance = self
	# 预创建音效玩家池
	for i in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)


static func get_instance() -> AudioManager:
	return _instance


## 播放音效
## sfx_id: 音效注册表中的ID
## volume_scale: 音量缩放（0.0-1.0），默认1.0
## pitch_scale: 音调缩放（0.5-2.0），默认1.0
static func play_sfx(sfx_id: String, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> void:
	if _instance == null:
		return
	if not SFX_REGISTRY.has(sfx_id):
		push_warning("AudioManager: 未知音效ID: %s" % sfx_id)
		return
	var path: String = SFX_REGISTRY[sfx_id]
	# 第三批A-F-10：如果该音效有多变体，随机选择一个变体播放，避免重复感
	# 表现层音效变体，非玩法随机，豁免种子化约束（见 AGENTS.md 技术约定豁免条款）。
	if SFX_VARIANTS.has(sfx_id):
		var variant_count: int = SFX_VARIANTS[sfx_id]
		var variant_idx: int = randi() % (variant_count + 1)
		if variant_idx > 0:
			var base_path: String = path.get_basename()
			var ext: String = path.get_extension()
			path = base_path + "_" + str(variant_idx) + "." + ext
	var stream := load(path) as AudioStream
	if stream == null:
		# 音效文件尚未引入，静默失败（不打断游戏流程）
		return
	var player := _instance._get_free_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = linear_to_db(_instance._sfx_volume * volume_scale)
	player.pitch_scale = pitch_scale
	player.play()


## 获取空闲的音效玩家
func _get_free_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	# 所有玩家都在播放，返回第一个（覆盖最旧的音效）
	return _sfx_players[0] if _sfx_players.size() > 0 else null


## 设置主音量（0.0-1.0）
static func set_master_volume(volume: float) -> void:
	if _instance == null:
		return
	_instance._master_volume = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
			linear_to_db(_instance._master_volume))


## 设置音效音量（0.0-1.0）
static func set_sfx_volume(volume: float) -> void:
	if _instance == null:
		return
	_instance._sfx_volume = clampf(volume, 0.0, 1.0)


## 设置音乐音量（0.0-1.0）
static func set_music_volume(volume: float) -> void:
	if _instance == null:
		return
	_instance._music_volume = clampf(volume, 0.0, 1.0)


## 获取主音量
static func get_master_volume() -> float:
	return _instance._master_volume if _instance else 1.0


## 获取音效音量
static func get_sfx_volume() -> float:
	return _instance._sfx_volume if _instance else 1.0


## 获取音乐音量
static func get_music_volume() -> float:
	return _instance._music_volume if _instance else 0.6


## 停止所有音效
static func stop_all_sfx() -> void:
	if _instance == null:
		return
	for player in _instance._sfx_players:
		player.stop()


## 检查音效文件是否存在
static func has_sfx(sfx_id: String) -> bool:
	if not SFX_REGISTRY.has(sfx_id):
		return false
	var path: String = SFX_REGISTRY[sfx_id]
	return ResourceLoader.exists(path)
