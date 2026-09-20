extends SceneTree
## Agent3 Windows Release PCK 阴性断言（直接扫 PCK 字节串，不合并工程盘 res://）。
## 用法：godot --headless --path . -s tools/agent3_pck_audit.gd -- \
##   --pck=/abs/path/gu-zhenren.pck

## 🔴 needle 形态（2026-09-15 实测修正）：PCK **文件表不带 `res://` 前缀**。
##     证据：同一份包 `project.binary` 命中 1，而 `res://project.binary` 命中 **0**；
##     带前缀的命中全部来自**文件内容**（`.import` 的 dest_files、`.remap` 的 path=、脚本源码字符串）。
##     因此排除项必须写**去前缀**形态，否则测的是「内容里有没有提过」而不是「文件表里有没有」。
##     对照真值（new vs 旧包）：lore_engine/ 0↔4 · lore_sources/ 0↔1 · tools/ 0↔1
##     · Godot/editor_settings 0↔2
const FORBIDDEN := [
	"tests/unit/",
	"tests/integration/",
	"tools/",
	"docs/",
	".preview/",
	".codex/",
	".superpowers/",
	"memory/",
	"lore_engine/",
	"lore_sources/",
	"vendor/",
	"分支：六卷精编版/",
	"肉鸽设计-原始数据/",
	"acceptance_driver.gd",
	"Godot/editor_settings",
	"Godot/app_userdata/",
]

## 反空转 canary：这些**必然**在包内（2026-09-15 实测计数见注释）。
## 任一为 0 ⇒ 扫描器坏了，必须 FAIL 而不是 PASS。
const CANARIES := [
	"project.binary",          # 1
	"run_screen_router.gd",    # 5
	"gu_card_view.gd",         # 6
	"MaShanZheng-Regular.ttf", # 4
]

## 允许残留：project.godot POT 引用的跨 worktree 路径（Shared，另案）
const KNOWN_SHARED_PREFIXES := [
	"res://.claude/worktrees/",
]

## 字节级子串计数。**两种 String 解码在 PCK 上都不可用**（2026-09-15 实测）：
##   * `bytes.get_string_from_utf8()`  → 在首个非法 UTF-8 续字节处截断（**offset 34**）⇒ 34 字符
##   * `bytes.get_string_from_ascii()` → 在首个 NUL 字节处截断          ⇒ **5 字符**
## 两者都会让 count() 恒为 0 ⇒ **恒 AUDIT_PASS（假 PASS，等于没扫）**。
## 也不能用 `PackedByteArray.find(PackedByteArray)`：4.7 只接受 int 模式。
## 因此：用原生 `find(int)` 定位首字节，再用末字节预筛，最后逐字节校验。
func _count(hay: PackedByteArray, needle: String) -> int:
	var pat := needle.to_utf8_buffer()
	var plen := pat.size()
	var total := hay.size()
	if plen == 0 or plen > total:
		return 0
	var first := pat[0]
	var last := pat[plen - 1]
	var hits := 0
	var i := hay.find(first, 0)
	while i != -1:
		if i + plen <= total and hay[i + plen - 1] == last:
			var ok := true
			var k := 1
			while k < plen:
				if hay[i + k] != pat[k]:
					ok = false
					break
				k += 1
			if ok:
				hits += 1
		i = hay.find(first, i + 1)
	return hits


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
	print("PCK_BYTES=" + str(bytes.size()))

	# 🔴 反空转自检（2026-09-15 修复）：必须证明扫描器真的读到了整份文件。
	# 原实现 `bytes.get_string_from_utf8()` 在 **byte offset 34** 就遇到非法 UTF-8 续字节而截断
	# （PCK 头部本身是二进制）⇒ 得到的字符串只有 34 字符 ⇒ 此后所有 count() 恒为 0
	# ⇒ **恒 AUDIT_PASS（假 PASS，等于没扫）**。现改为字节级检索 + canary 自检。
	# 本文件只做只读断言，不改包、不改工程。
	print("SCAN_BYTES=" + str(bytes.size()))
	var canary_fail: Array = []
	for c in CANARIES:
		var cn := _count(bytes, c)
		print("CANARY %s = %d" % [c, cn])
		if cn == 0:
			canary_fail.append(c)
	if not canary_fail.is_empty():
		printerr("AUDIT_FAIL 扫描器自检失败：必然存在的 canary 未命中 %s（扫描为空转）" % str(canary_fail))
		quit(1)
		return

	var violations: Array = []
	for needle in FORBIDDEN:
		var n := _count(bytes, needle)
		print("HIT %s = %d" % [needle, n])
		if n > 0 and not _known_shared_only(needle, bytes):
			violations.append(needle + " x" + str(n))

	# 软观察：debug 仍进包（阶段 B 前预期非 0）
	print("OBS_debug_panel=" + str(_count(bytes, "debug_panel")))
	print("OBS_run_debug_facade=" + str(_count(bytes, "run_debug_facade")))
	print("OBS_debug_actions=" + str(_count(bytes, "debug_actions")))
	print("OBS_debug_snapshot=" + str(_count(bytes, "debug_snapshot")))
	print("OBS_claude_pot=" + str(_count(bytes, "res://.claude/worktrees/")))

	if violations.is_empty():
		print("AUDIT_PASS")
		quit(0)
	else:
		for v in violations:
			printerr("VIOLATION " + str(v))
		printerr("AUDIT_FAIL")
		quit(1)


func _known_shared_only(needle: String, _bytes: PackedByteArray) -> bool:
	# 注意：KNOWN_SHARED_PREFIXES 不在 FORBIDDEN 里，故本函数目前恒返回 false（死分支，保留原样）。
	for prefix in KNOWN_SHARED_PREFIXES:
		if needle.begins_with(prefix):
			return true
	return false
