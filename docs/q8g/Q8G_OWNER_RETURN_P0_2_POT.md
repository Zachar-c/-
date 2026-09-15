# P0-2 `project.godot` POT 跨 worktree 路径 — Shared 声明 + Owner 交回

> 对应：`docs/q8g/Q8G_OWNER_EXECUTION_CHECKLIST.md` **P0-2**
> 执行者：Owner 侧 Agent；验收者：Agent3
> 基线 HEAD：`d15fa567`（开工时）

---

## 一、Shared 所有权 5 步声明

`project.godot` 属 `docs/contracts/2026-09-12-agent-ownership-contract.md` §2 的 Shared 单写者区，
且 `Q8G_DEBUG_COMPILE_PRUNE_PLAN.md` §4 明确「不得改 `project.godot` 除非走 Shared ownership 5 步协议」。

### 1. 声明文件

```text
project.godot
```

### 2. 原因

**表层**：`internationalization/locale/translations_pot_files` 带一条跨 worktree 的陈旧路径：

```text
res://.claude/worktrees/battle-visual-implementation/data/dialogues/events.dialogue
```

该目录已不是注册 worktree（`git worktree list` 只剩主工作树；`.git/worktrees/` 不存在；
`git worktree prune --dry-run` 无可清元数据），是 66MB / 1747 文件的**悬空孤儿副本**；
正式 POT 源是 `res://data/dialogues/events.dialogue`。

**深层（本项真正的难点）**：只删这一行**不成立**。Dialogue Manager 插件会把它写回来：

```text
addons/dialogue_manager/plugin.gd:325 _update_localization()
  ① if not DMSettings.get_setting(UPDATE_POT_FILES_AUTOMATICALLY, true): return   ← 总开关
  ② 把 dialogue_cache.get_files() 里所有 dialogue 文件补进 translations_pot_files
  ③ ProjectSettings.save()  → 直接写 project.godot

addons/dialogue_manager/utilities/dialogue_cache.gd:155 _get_dialogue_files_in_filesystem()
  从 res:// 递归扫描，只跳过 [".godot", ".tmp"]
  —— 既不跳过 .claude 等点目录，也不读 .gdignore
```

⇒ 只要那个孤儿 `.dialogue` 还在磁盘上，**任何一次编辑器启动或 `--import`**
（`tools/test.ps1` 现已把 `--import` 作为前置步骤）都会把路径写回。
**只删行 = 每次跑测试都会被还原，等于没修。**

**采用的持久解法**（非破坏性、不改 vendor）：

```text
在 project.godot 增加插件自带的开关（DMSettings 从 ProjectSettings 读同名键）：
  [dialogue_manager]
  editor/translations/update_pot_files_automatically=false
→ _update_localization() 在 ① 处 early-return，永不触碰 translations_pot_files。
```

**未采用**的两种解法及原因：

```text
(a) 删除孤儿目录 .claude/worktrees/battle-visual-implementation/
    → 属「删除他人工作目录」，需用户明确指令；本项未授权，不做。
(b) 改 addons/dialogue_manager/** 让它跳过点目录 / 尊重 .gdignore
    → vendor 第三方代码；Agent3 自办清单 A5 列为「不动」；改动需单独审计。
```

### 3. 影响面

```text
受影响：
  - POT 生成源列表：少一条已废弃路径（正确结果）。
  - Dialogue Manager 插件的「自动维护 POT 列表」功能被关闭。
    本项目 POT 源只有 1 个文件（data/dialogues/events.dialogue），且已显式登记，
    因此该自动维护对本项目无收益，只有副作用（反复注入孤儿路径）。

不受影响：
  - 所有运行时行为：存档 / 战斗 / 地图 / UI / 事件日志。
  - dialogue 的编译、运行与 DialogueManager autoload（与 POT 无关）。
  - 其他 ProjectSettings 键。
```

### 4. 指定测试

见 §三「命令与退出码」，全部在**最终内容**上跑过。

### 5. 单独 commit

```text
fix(project): drop cross-worktree POT path and stop DM auto-POT rewrite
```

---

## 二、受控实验证据（证明修复是自持的）

「删行」与「删行 + 关开关」两次对照，判据是 `grep -c worktrees project.godot`：

```text
实验 A（只删行，未关开关）
  删后：0 处
  godot --headless --path . --import
  → 1 处  ❌ 路径被插件写回

实验 B（删行 + [dialogue_manager] editor/translations/update_pot_files_automatically=false）
  删后：0 处
  第 1 次 --import → 0 处  ✅
  第 2 次 --import → 0 处  ✅ 幂等
```

结论：修复**自持**，不再依赖「不要开编辑器」这类口头约束。

---

## 三、Owner 交回

```text
提交清单：
  6ea67c95  fix(project): drop cross-worktree POT path and stop DM auto-POT rewrite
  88e906c9  docs(q8g): record P0-2 POT cleanup declaration and owner return

（P0-1 由另一 Agent 提交：a35e3786 refactor(debug)… / 79b67210 chore(export)…）

命令与退出码：
  grep -c worktrees project.godot                          → 0（import 前后各一次，幂等）
  godot --headless --path . --quit-after 3                 → rc=0，无 SCRIPT ERROR
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/unit -gexit -glog=2        → 0
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit -glog=2 → 0
  godot --headless --path . -s tools/verify_interaction_loop.gd → 0（15/15 三键全空）

未完成项：
  - P0-1 Debug 阶段 B：由另一 Agent 施工中，本轮未触碰其任何文件
  - P0-3 最终 Release Gate：需 P0-1 + P0-2 都落地后执行
  - 孤儿目录 .claude/worktrees/（66MB）本身未删除（未授权）；本修复已使其不再影响 POT

需要 Agent3 验收的项编号：P0-2
```

---

## 四、P0-2 验收标准自评（对照清单）

| # | 标准 | 自评 | 证据 |
|---|---|---|---|
| 1 | `project.godot` 无 `.claude/worktrees` 字符串 | **PASS** | `grep -c worktrees` = 0，且 `--import` ×2 后仍为 0 |
| 2 | PCK 扫描 `res://.claude/worktrees/` = 0 | **待 P0-3 复测** | `.claude/*` 本就在 `exclude_filter` 中；Agent3 A3 观测的 `claude_pot=1` 计的是 **POT 字符串**，本次已消除且不会再回来 |
| 3 | 未夹带其他 project 配置改动 | **PASS** | `git diff -- project.godot` 仅 2 处：删 1 条 POT 路径 + 增 1 个插件开关 |

---

## 五、并发与可归因性说明（重要）

本项执行期间，**另一 Agent 正在同一工作树实时施工 P0-1**（`run_controller.gd` / `export_presets.cfg` /
`debug_bridge.gd` / `debug_panel_view.gd` / `test_t5d_debug_panel.gd`，mtime 21:33–21:40）。

```text
- 本轮**未触碰**上述任何文件；`project.godot` 是唯一被本项修改的生产文件。
- 指定测试运行窗口内（约 5 分钟）相关文件 mtime 前后一致 ⇒ 结果未被并发编辑打断，可归因。
- 期间观测到一次瞬时不可加载：
    SCRIPT ERROR: Identifier "DebugBridge" not declared in the current scope
    at res://scripts/presentation/run_controller.gd:497
  该状态在 `--import`（重建全局类缓存）后消失，属**构建缓存滞后**而非源码错误；
  `tools/test.ps1` 现已内置 `--import` 前置，正常测试路径不会遇到。
```
