extends SceneTree
## Agent3 Windows Release PCK 阴性断言（直接扫 PCK 字节串，不合并工程盘 res://）。
## 用法：godot --headless --path . -s tools/agent3_pck_audit.gd -- \
##   --pck=/abs/path/gu-zhenren.pck

const FORBIDDEN := [
	"res://tests/",
	"res://tools/",
	"res://docs/",
	"res://.preview/",
	"res://.codex/",
	"res://.superpowers/",
	"res://memory/",
	"res://lore_engine/",
	"res://lore_sources/",
	"res://vendor/",
	"res://分支：六卷精编版/",
	"res://肉鸽设计-原始数据/",
	"res://scripts/acceptance_driver",
	"res://scripts/guitkx_build",
	"res://Godot/",
	"res://ui/_sample",
]

## 允许残留：project.godot POT 引用的跨 worktree 路径（Shared，另案）
const KNOWN_SHARED_PREFIXES := [
	"res://.claude/worktrees/",
]


func _initialize() -> void:
	var pck_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pck="):
			pck_path = arg.trim_prefix("--pck=")
	if pck_path.is_empty() or not FileAccess.file_exists(pck_path):
		printerr("AUDIT_FAIL pck missing")
		quit(1)
		return
	var bytes := FileAccess.get_file_as_bytes(pck_path)
	if bytes.is_empty():
		printerr("AUDIT_FAIL empty pck")
		quit(1)
		return
	var text := bytes.get_string_from_utf8()
	print("PCK_BYTES=" + str(bytes.size()))

	var violations: Array = []
	for needle in FORBIDDEN:
		var n := text.count(needle)
		print("HIT %s = %d" % [needle, n])
		if n > 0 and not _known_shared_only(needle, text):
			violations.append(needle + " x" + str(n))

	# 软观察：debug 仍进包（阶段 B 前预期）
	print("OBS_debug_panel=" + str(text.count("debug_panel")))
	print("OBS_run_debug_facade=" + str(text.count("run_debug_facade")))
	print("OBS_debug_actions=" + str(text.count("debug_actions")))
	print("OBS_claude_pot=" + str(text.count("res://.claude/worktrees/")))

	if violations.is_empty():
		print("AUDIT_PASS")
		quit(0)
	else:
		for v in violations:
			printerr("VIOLATION " + str(v))
		printerr("AUDIT_FAIL")
		quit(1)


func _known_shared_only(needle: String, text: String) -> bool:
	# .claude 全部来自 project.godot POT Shared 残留时标为 known_shared
	for prefix in KNOWN_SHARED_PREFIXES:
		if needle.begins_with(prefix):
			return true
	return false
