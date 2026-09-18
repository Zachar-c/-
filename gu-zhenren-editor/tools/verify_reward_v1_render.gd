extends SceneTree

## 结算屏线框稿 v2 实施渲染验收（2026-09-08）：真实窗口挂载 reward_screen.tscn，
## 喂 mock snapshot（战利 3 卡 + 保底/DDA 行），force_draw 后保存整窗截图
## 到 .preview/reward_v1_render.png 供与线框稿 v2 对比。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_reward_v1_render.gd

const RewardScene := "res://scenes/ui/screens/reward_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"resources": {"shouyuan": 41, "hunpo": 7, "yuanstone": 12},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
		"layer": 3,
		"title": "结算",
		"subtitle": "得胜 · 战利三选一",
		"rewards": [
			{"name": "毒瘴蛛", "quality": "毒道 · 一阶", "desc": "瘴气缠身，攻其不备"},
			{"name": "元石 × 8", "quality": "横财", "desc": "入囊"},
			{"name": "生机草", "quality": "木道 · 一阶", "desc": "净化一层负面"},
		],
		"pool_fallback_note": "池排除列表：(无) · 当前种子 101 · 事件数 2 · DDA 分位 0/10 平稳",
		"pity_note": "保底计数 · 蛊 0 / 材料 0 · 合成连败 0",
	}
	var cmds := {
		"close": Callable(self, "_noop"),
	}
	var screen: Control = (load(RewardScene) as PackedScene).instantiate()
	root.add_child(screen)
	screen.mount_snapshot(snapshot, cmds)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var window := root as Window
	var tex := window.get_texture()
	if tex == null:
		push_error("no render target; run without --headless")
		quit(1)
		return
	var img := tex.get_image()
	var dir := "res://.preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out := ProjectSettings.globalize_path(dir) + "/reward_v1_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
