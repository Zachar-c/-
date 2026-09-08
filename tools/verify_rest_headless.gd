extends SceneTree

## 休息屏 headless 功能验证：加载 tscn、喂快照、跑 _ready/_refresh/_build_choice_card，
## 无渲染条件下验证脚本编译与逻辑无错。用法：
## Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/verify_rest_headless.gd

const RestScene := "res://scenes/ui/screens/rest_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"resources": {"shouyuan": 94, "hunpo": 7, "yuanstone": 12},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
		"layer": 3,
		"title": "闭关 · 休整",
		"note": "强制二选一，不可全拿",
		"choices": [
			{"id": "heal", "label": "调息回血", "detail": "闭目调息，恢复气血至八成", "cost": ""},
			{"id": "upgrade_card", "label": "强化蛊卡", "detail": "温养一张本命蛊，强化其效果", "cost": ""},
			{"id": "remove_card", "label": "温养一蛊", "detail": "择一蛊温养，抹除负面印记", "cost": ""},
			{"id": "remove_imprint", "label": "抹除印记", "detail": "剔除体内残留的异变印记", "cost": ""},
			{"id": "remove_curse", "label": "拔除反噬", "detail": "拔除缠身的诅咒与反噬", "cost": ""},
			{"id": "wash", "label": "洗髓换骨", "detail": "重塑根骨，重选流派",
				"cost": "寿元 12 年", "reason": "一生一次 · 不可逆"},
		],
	}
	var cmds := {
		"close": Callable(self, "_noop"),
		"choose": Callable(self, "_noop"),
	}
	var screen: Control = (load(RestScene) as PackedScene).instantiate()
	root.add_child(screen)
	screen.mount_snapshot(snapshot, cmds)
	await process_frame
	await process_frame
	var sub := screen.get_node_or_null("Backdrop/SubLabel")
	print("SUBLABEL=" + str(sub.text))
	var grid := screen.get_node_or_null("Root/RestStage/StageContent/primary_decision_surface")
	print("PANEL_OK=" + str(grid != null))
	print("REST HEADLESS OK")
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
