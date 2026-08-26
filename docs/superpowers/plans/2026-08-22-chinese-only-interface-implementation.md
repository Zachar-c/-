# 首版中文单语界面 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让南疆冒烟版的全部玩家可见界面和离线对话只显示中文，同时保持规则、存档和内部标识符的 ASCII 稳定性。

**Architecture:** 在展示层新增一个无状态的 `DisplayText` 映射类。四个 Godot 视图用它把内部 ID 翻译为中文，并用面向玩家的摘要替代原始结果字典；领域层与保存格式不变。

**Tech Stack:** Godot 4.6.2 目标、GDScript、JSON 数据表、GUT 9.x。

## Global Constraints

- 玩家可见文本只使用中文；调试窗口标题 `Nanjiang Smoke (DEBUG)` 不改动。
- 源代码标识符、JSON 键、节点 ID、事件日志、存档和测试名称使用 ASCII。
- 不修改 `vendor/godot-open-rpg/`，不增加语言选择或网络依赖。
- 规则、随机种子、存档、事件日志和结局归因继续完全本地且可复现。

---

### Task 1: 建立中文显示词典和离线对话

**Files:**
- Create: `scripts/presentation/display_text.gd`
- Create: `tests/unit/test_display_text.gd`
- Modify: `data/dialogue_templates.json`

**Interfaces:**
- Produces `DisplayText.node(id) -> String`、`type(id) -> String`、`action(id) -> String`、`gu(id) -> String`、`inheritance(id) -> String`、`enemy(id) -> String`、`fact(id) -> String`、`outcome(id) -> String` 和 `result(result: Dictionary) -> String`。

- [x] **Step 1: Write failing mapping tests**

```gdscript
func test_display_text_translates_known_ids_without_leaking_internal_ids() -> void:
    assert_eq(DisplayText.node("village_short_work"), "山村短工")
    assert_eq(DisplayText.type("market"), "市集")
    assert_eq(DisplayText.gu("small_light_gu"), "小光蛊")
    assert_eq(DisplayText.outcome("risky_success"), "险中功成")
```

- [x] **Step 2: Run the test to verify failure**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_display_text.gd -gexit`

Expected: FAIL because `DisplayText` does not exist.

- [x] **Step 3: Implement pure display mapping and Chinese templates**

```gdscript
class_name DisplayText
extends RefCounted

static func node(id: String) -> String:
    return NODES.get(id, "未知地点")
```

Define all authored IDs used by the data tables and map unknown input to a Chinese fallback. Translate only `text` values in `dialogue_templates.json`; preserve every JSON key and enum.

- [x] **Step 4: Run focused unit test**

Expected: PASS with every asserted display value in Chinese.

### Task 2: 让所有运行时视图使用显示词典

**Files:**
- Modify: `scripts/presentation/map_view.gd`
- Modify: `scripts/presentation/encounter_view.gd`
- Modify: `scripts/presentation/battle_view.gd`
- Modify: `scripts/presentation/ending_view.gd`
- Modify: `tests/unit/test_display_text.gd`

**Interfaces:**
- Consumes `DisplayText` static display methods.
- Produces UI text with no raw node, type, action, Gu, inheritance, enemy, fact, result, journal heading or journal body IDs.

- [x] **Step 1: Add a failing render-text test**

```gdscript
func test_result_summary_is_chinese_and_does_not_serialize_dictionary() -> void:
    var summary := DisplayText.result({"ok": true, "npc_reaction": "caution"})
    assert_eq(summary, "对方保持谨慎。")
    assert_false(summary.contains("{"))
```

- [x] **Step 2: Run the test to verify failure**

Expected: FAIL because result summary mapping is missing.

- [x] **Step 3: Replace direct ID rendering**

Call `DisplayText` in each presentation script. Retain ASCII values in signal payloads and commands. Translate journal headings, `JournalBuilder.text_for(entry)` output and `visible_facts` only when rendering; do not modify immutable journal entries.

- [x] **Step 4: Run focused unit tests and full suite**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

Expected: all unit and integration tests pass.

### Task 3: 验证并提供手工验收运行

**Files:**
- Modify: `README.md`

**Interfaces:**
- Documents the Chinese-only player interface and unchanged debug title.

- [x] **Step 1: Add one concise Chinese-only UI note to README**

State that player-facing text is Chinese-only in the first release and that internal data IDs remain ASCII.

- [x] **Step 2: Run verification commands**

```powershell
& '<Godot exe>' --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit -glog=2
& '<Godot exe>' --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit -glog=2
& '<Godot exe>' --headless --path . --quit-after 3
git diff --check
```

Expected: all tests pass, headless boot exits with code `0`, and project-authored changes have no whitespace errors.

## Implementation Record

- Completed in isolated worktree `task1-vendor-open-rpg`; no files under `vendor/godot-open-rpg/` were changed.
- Added `DisplayText` as the presentation-only translation boundary and converted the offline dialogue templates and their built-in fallback to Chinese.
- Verification on 2026-08-22: focused display tests `5/5`, dialogue/save regression tests `3/3`, full unit suite `43/43` with 149 assertions, integration suite `2/2` with 9 assertions, headless boot exit code `0`, and `git diff --check` passed with no whitespace errors.
- Started the graphical Godot build with `gl_compatibility` for manual acceptance; debug window title remains `Nanjiang Smoke (DEBUG)`.
