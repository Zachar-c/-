extends SceneTree

## 战斗屏 v2 线框稿实施渲染验证（2026-09-07）：真实窗口挂载 battle_screen.tscn，
## 喂合成快照（玩家左下立绘 + 3 敌人意图/状态 + 杀招 + 手牌 4 + 右列按钮），
## force_draw 后保存整窗截图到 .preview/battle_v1_render.png 供与线框稿 v2 比对。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_battle_v1_render.gd

const BattleScene := "res://scenes/ui/screens/battle_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"resources": {"shouyuan": 41, "hunpo": 7, "yuanstone": 12},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
		"layer": 3,
		"player": {
			"name": "问真",
			"hp": 94,
			"max_hp": 120,
			"shield": 12,
			"thoughts": 8,
			"primordial": 4,
		},
		"actions": {"left": 8, "max": 12},
		"enemies": [
			{"id": "e0", "name": "毒瘴蛛", "hp": 23, "max_hp": 50, "shield": 0, "alive": true,
				"intent": {"type": "charge", "value": 3, "speed": 0, "detail": "蓄势待发"},
				"statuses": [{"name": "中毒", "stacks": 2}, {"name": "蓄力", "stacks": 1}]},
			{"id": "e1", "name": "石皮蝎", "hp": 66, "max_hp": 75, "shield": 0, "alive": true,
				"intent": {"type": "attack", "value": 8, "speed": 1, "detail": "猛击"},
				"statuses": [{"name": "石皮", "stacks": 3}, {"name": "猛击", "stacks": 1}]},
			{"id": "e2", "name": "血苔蛇", "hp": 9, "max_hp": 78, "shield": 0, "alive": true,
				"intent": {"type": "attack", "value": 4, "speed": 2, "detail": "腐毒"},
				"statuses": [{"name": "虚弱", "stacks": 1}, {"name": "腐毒", "stacks": 1}]},
		],
		"hand": [
			{"id": "c0", "name": "月光蛊", "school_label": "光道", "quality": "一阶", "effect": "对敌造成 6 点伤害",
				"synergy": "", "cost": "2", "cost_ex": "念头 2", "executable": true, "target_type": "single_enemy",
				"dangerous": false, "known_risk": [], "block_reason": ""},
			{"id": "c1", "name": "石皮蛊", "school_label": "土道", "quality": "一阶", "effect": "获得 10 点护盾",
				"synergy": "", "cost": "1", "cost_ex": "念头 1", "executable": true, "target_type": "none",
				"dangerous": false, "known_risk": [], "block_reason": ""},
			{"id": "c2", "name": "小光蛊", "school_label": "光道", "quality": "一阶", "effect": "恢复 4 点气血",
				"synergy": "", "cost": "1", "cost_ex": "念头 1", "executable": true, "target_type": "none",
				"dangerous": false, "known_risk": [], "block_reason": ""},
			{"id": "c3", "name": "生机草", "school_label": "木道", "quality": "一阶", "effect": "净化 1 层负面",
				"synergy": "", "cost": "2", "cost_ex": "念头 2", "executable": true, "target_type": "none",
				"dangerous": false, "known_risk": [], "block_reason": ""},
		],
		"kill_moves": [
			{"name": "月噬", "sequence_display": "光·月 Ⅱ", "cost": "6", "executable": true, "block_reason": ""},
		],
		"inventory": {},
		"flee_available": true,
		"first_battle": true,
		"feedback": "",
		"dda_boss_hint": "",
	}
	var cmds := {
		"play_card": Callable(self, "_noop"),
		"end_turn": Callable(self, "_noop"),
		"refine": Callable(self, "_noop"),
		"flee": Callable(self, "_noop"),
	}
	var battle: Control = (load(BattleScene) as PackedScene).instantiate()
	root.add_child(battle)
	battle.mount_snapshot(snapshot, cmds)
	await process_frame
	await process_frame
	# 布局自检：打印关键容器实际位置（配合像素级比对）
	var _dbg := func():
		for n in ["Root/battle_hud", "Root/BattleStage", "Root/BattleStage/battle_field",
				"Root/BattleStage/battle_field/PlayerPanel", "Root/BattleStage/battle_field/EnemyPanel",
				"Root/BattleStage/battle_field/BattleInfo", "Root/BattleStage/battle_field/BattleInfo/KillRow",
				"Root/BattleStage/battle_field/OpsDock", "Root/BattleStage/battle_field/HintHost",
				"Root/HandStage", "Root/HandStage/HandMargin/battle_hand/HandArea/Hand",
				"Root/HandStage/BuildVer"]:
			var node := battle.get_node_or_null(n)
			if node:
				print("DBG ", n, " pos=", node.position, " size=", node.size)
		var hand := battle.get_node_or_null("Root/HandStage/HandMargin/battle_hand/HandArea/Hand")
		if hand:
			print("DBG hand childs: card=", hand.get_node("CardRow").size,
					" cancel=", hand.get_node("CancelRow").size,
					" cancel_childs=", hand.get_node("CancelRow").get_child_count())
	_dbg.call()
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
	var out := ProjectSettings.globalize_path(dir) + "/battle_v1_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
