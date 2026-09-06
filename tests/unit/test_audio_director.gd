extends GutTest


## BGM 系统测试：资源存在性、播放器行为、视图 -> 曲目映射。
## 曲目由 tools/generate_music.py 确定性合成（music/ 现为 .mp3/.ogg 资产）；
## AudioDirector 懒创建 BgmPlayer，未知 key / 资源缺失 / 未入树均静默跳过，
## 绝不打断游戏流程。
##
## 播放断言策略：节点已就绪时 play_bgm 同步创建并播放（direct start），测试先
## 做同步断言；仅当实际走了 pending/_process 兜底路径时才等待帧推进（GUT
## headless 下 _process 的帧推进与 await 并非严格同步，直接同步断言最稳定）。


const AudioDirectorScript = preload("res://scripts/presentation/audio_director.gd")
const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")

const BGM_KEYS := ["hall", "map", "battle", "ending"]
const BGM_PATHS := {
	"hall": "res://assets/audio/music/hall.mp3",
	"map": "res://assets/audio/music/map.ogg",
	"battle": "res://assets/audio/music/battle.mp3",
	"ending": "res://assets/audio/music/ending.ogg",
}

var _hosts: Array = []


func after_each() -> void:
	for host in _hosts:
		if is_instance_valid(host):
			host.queue_free()
	_hosts.clear()


## 建一棵含 AudioDirector 的宿主树（必须入树，BgmPlayer 懒创建依赖 in-tree）。
func _spawn_director() -> AudioDirector:
	var host := Node.new()
	host.name = "Host"
	add_child(host)
	var director: AudioDirector = AudioDirectorScript.new()
	host.add_child(director)
	_hosts.append(host)
	return director


## 取 BgmPlayer；direct start 路径同步创建，必要时（pending 兜底）等帧推进。
func _wait_player(director: AudioDirector) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = director.get_node_or_null("BgmPlayer")
	for i in range(5):
		if player != null:
			break
		await get_tree().process_frame
		player = director.get_node_or_null("BgmPlayer")
	return player


## 等待播放确认（跨帧确认机制：上一帧 play 后本帧确认 playing）。
func _wait_playing(player: AudioStreamPlayer) -> void:
	for i in range(60):
		if player.playing:
			break
		await get_tree().process_frame


func test_bgm_assets_exist_and_load() -> void:
	for key in BGM_KEYS:
		var path: String = BGM_PATHS[key]
		assert_true(ResourceLoader.exists(path), "BGM asset must exist: %s" % path)
		var stream: Resource = load(path)
		assert_not_null(stream, "BGM must load: %s" % path)
		assert_true(stream is AudioStream, "BGM must be an AudioStream: %s" % path)


## 按流类型读循环开关（与 AudioDirector._force_loop 对称）。
func _loop_enabled(stream: AudioStream) -> bool:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
	if stream is AudioStreamMP3:
		return (stream as AudioStreamMP3).loop
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	return false


func test_play_bgm_unknown_key_is_silent() -> void:
	var director := _spawn_director()
	director.play_bgm("no_such_track")
	assert_eq(director.current_bgm(), "")
	director.play_bgm("")
	assert_eq(director.current_bgm(), "")


func test_play_bgm_sets_track_and_loop() -> void:
	var director := _spawn_director()
	director.play_bgm("hall")
	assert_eq(director.current_bgm(), "hall")
	var player: AudioStreamPlayer = await _wait_player(director)
	assert_not_null(player, "BgmPlayer must be created")
	await _wait_playing(player)
	assert_true(player.playing, "BGM must be playing after play_bgm (deferred start)")
	assert_true(player.stream is AudioStream, "BgmPlayer stream must be an AudioStream")
	assert_true(_loop_enabled(player.stream),
			"BGM loop must be forced on in code (import default is disabled)")


func test_play_bgm_same_track_is_idempotent() -> void:
	var director := _spawn_director()
	director.play_bgm("battle")
	var player: AudioStreamPlayer = await _wait_player(director)
	assert_not_null(player, "BgmPlayer must be created before idempotent replay")
	var stream_before: AudioStream = player.stream
	director.play_bgm("battle")
	assert_eq(director.current_bgm(), "battle")
	assert_eq(player.stream, stream_before, "same track must not swap stream")
	assert_true(is_instance_valid(player), "same track must not rebuild the player")


func test_play_bgm_switch_track_changes_stream() -> void:
	var director := _spawn_director()
	director.play_bgm("hall")
	var player: AudioStreamPlayer = await _wait_player(director)
	assert_not_null(player, "first player must be created before switching")
	var hall_stream: AudioStream = player.stream
	director.play_bgm("battle")
	var player2: AudioStreamPlayer = await _wait_player(director)
	assert_eq(director.current_bgm(), "battle")
	assert_not_null(player2, "switched player must be recreated under the same name")
	assert_ne(player2.stream, hall_stream, "track switch must swap stream")
	await _wait_playing(player2)
	assert_true(player2.playing, "switched track must be playing")


func test_stop_bgm_clears_track() -> void:
	var director := _spawn_director()
	director.play_bgm("map")
	director.stop_bgm()
	assert_eq(director.current_bgm(), "")


func test_sfx_api_keeps_working() -> void:
	var director := _spawn_director()
	director.play_sfx("res://no/such/sfx.wav")
	assert_false(director.playing, "missing sfx must stay silent")
	director.stop_sfx()
	director.clear_cache()


func test_play_bgm_without_tree_is_silent() -> void:
	var director: AudioDirector = AudioDirectorScript.new()
	director.play_bgm("hall")
	assert_eq(director.current_bgm(), "", "untreed director must not create BgmPlayer")
	director.free()


func test_run_controller_syncs_bgm_on_view_change() -> void:
	var main := Node.new()
	main.name = "Main"
	add_child(main)
	_hosts.append(main)
	var controller := RunControllerScript.new()
	var director: AudioDirector = AudioDirectorScript.new()
	# main.tscn 中 AudioDirector 节点名固定；RunController 经 "../AudioDirector" 寻址
	director.name = "AudioDirector"
	main.add_child(controller)
	main.add_child(director)

	controller._view_name = "Title"
	controller._sync_bgm()
	assert_eq(director.current_bgm(), "hall")
	controller._view_name = "Map"
	controller._sync_bgm()
	assert_eq(director.current_bgm(), "map")
	controller._view_name = "Battle"
	controller._sync_bgm()
	assert_eq(director.current_bgm(), "battle")
	controller._view_name = "Ending"
	controller._sync_bgm()
	assert_eq(director.current_bgm(), "ending")
	controller._view_name = "Shop"
	controller._sync_bgm()
	assert_eq(director.current_bgm(), "map", "exploration screens must fall back to map")


func test_run_controller_without_director_is_silent() -> void:
	var controller := RunControllerScript.new()
	add_child(controller)
	_hosts.append(controller)
	controller._view_name = "Battle"
	controller._sync_bgm()
	pass_test("no crash when AudioDirector sibling is missing (unit-drive trees)")
