# Owner 执行清单（详细；交回 Agent3 验收用）

> 日期：2026-09-15  
> 性质：**Owner / 其他 Agent 施工清单**。Agent3 只验收，不在此清单上改生产 Shared 文件。  
> 验收人：Agent3（按每项「验收标准」收口）  
> 基线：`master` @ `d15fa567`（或更新后的 origin/master，验收时以 `git rev-parse HEAD` 为准）

---

## 使用方式

1. Owner 按 P0→P2 顺序施工；每项完成写入实际 commit / 产物路径 / 退出码。
2. 交回时附：`git log`、`git status`、关键命令输出（或日志路径）。
3. Agent3 对照「验收标准」逐项 PASS/FAIL；FAIL 写明阻塞，不自行扩大范围修 domain。

---

## P0-1 Debug 编译期裁剪（阶段 B）

### 允许 / 禁止

- 允许改：`scripts/presentation/run_controller.gd`（**Shared**）、新增 `scripts/presentation/debug_bridge.gd`（或等价桥）、`export_presets.cfg`、相关测试。
- 禁止：改 `scripts/domain/**` 规则语义；改 `data/**`；把未接入入口做成可点假按钮；只 exclude 却保留硬引用。

### 施工步骤

| # | 步骤 | 产出 |
|---|------|------|
| B1 | 读 `docs/q8g/Q8G_DEBUG_COMPILE_PRUNE_PLAN.md` + `docs/q8g/Q8G_DEBUG_PRUNE_SHARED_DECLARATION_DRAFT.md`（若已存在） | 方案一致 |
| B2 | 新增惰性桥（Release 不 load facade；Debug `is_debug_build` / feature 时 load） | `debug_bridge.gd` |
| B3 | `run_controller` 全部 `RunDebugFacade.xxx` 改为桥；删除编译期硬引用 | diff 仅 debug 方法族 |
| B4 | `export_presets` Windows：exclude `run_debug_facade.gd`、`debug_panel_view.gd`、`debug_panel.tscn`、`domain/debug_actions.gd` | presets 更新 |
| B5 | 单独 commit：`refactor(debug): optional DebugBridge for release prune` | commit 号 |

### 指定测试（Owner 必跑）

```text
tools/godot.ps1 -Console --headless --path . -s tools/verify_interaction_loop.gd
  期望：15/15 dead=[] no_ui_click=[] occluded=[] occluded_known=0
tools/test.ps1 -Suite unit
tools/test.ps1 -Suite integration
Debug 真窗：F12 面板可挂载（手工或截图）
```

### Agent3 验收标准

1. [ ] Release `--export-pack` + `tools/agent3_pck_audit.gd`：`debug_panel` / `run_debug_facade` / `debug_actions` / `debug_panel_view` 字节计数 = **0**
2. [ ] Release exe `--headless --quit-after 3` EXIT=0，无 SCRIPT ERROR
3. [ ] Debug 构建：面板仍挂载；正式 save/travel/battle 不受影响
4. [ ] 交互门 15/15 三键
5. [ ] 未改 `data/**` 与 domain 规则；commit 不混 UI 无关文件

---

## P0-2 `project.godot` POT 跨 worktree 路径

### 现状

```text
locale/translations_pot_files 包含
res://.claude/worktrees/battle-visual-implementation/data/dialogues/events.dialogue
```

### 施工步骤

| # | 步骤 |
|---|------|
| P1 | 确认正式 POT 只需：`res://data/dialogues/events.dialogue` |
| P2 | 删除跨 worktree 第二路径 |
| P3 | 单独 commit：`fix(project): drop cross-worktree POT path` |

### 指定测试

```text
godot --headless --path . --export-release "Windows Desktop" build/pot-clean/gu-zhenren.exe
tools/agent3_pck_audit.gd --pck=…
  OBS_claude_pot = 0
Release smoke EXIT=0
```

### Agent3 验收标准

1. [ ] `project.godot` 无 `.claude/worktrees` 字符串
2. [ ] PCK 扫描 `res://.claude/worktrees/` = 0
3. [ ] 未夹带其他 project 配置改动

---

## P0-3 最终 Windows Release Gate（在 P0-1、P0-2 之后）

### Owner 步骤

```text
1. 固定 HEAD = 拟发布 commit
2. APPDATA=… godot --headless --export-release "Windows Desktop" build/release-final/gu-zhenren.exe
3. --export-pack 同预设 → pck
4. tools/agent3_pck_audit.gd --pck=…
5. release exe --headless --quit-after 3
6. 真窗完整体感抽测：Hall→Map→Battle→Reward→Rest/Shop（截图可选）
```

### Agent3 验收标准

1. [ ] 阴性：tests/tools/docs/memory/lore_engine/lore_sources/vendor/Godot/语料/acceptance_driver/guitkx_build = 0
2. [ ] debug 四路径 = 0（依赖 P0-1）
3. [ ] `.claude/worktrees` = 0（依赖 P0-2）
4. [ ] exe smoke EXIT=0
5. [ ] 报告写明 HEAD 与产物路径

---

## P1-1 `.gutconfig` engine error tracking（待 Luna 裁定后）

### 若裁定「恢复」

| # | 步骤 |
|---|------|
| G1 | `.gutconfig.json` 恢复包含 engine 类失败 |
| G2 | 全量 unit，记录真实 SCRIPT ERROR 清单 |
| G3 | 只修**明确包装/加载误报**，不借机改 domain |

### Agent3 验收标准

1. [ ] 裁定文档或 handoff 写明「已批准恢复」
2. [ ] unit 退出码与失败数可复现
3. [ ] 未用「改断言掩盖真错误」过关

---

## P1-2 ObjectDB/RID 泄漏

### Owner 步骤

1. 用 `--verbose` 或缩小用例定位泄漏脚本/场景
2. 产出：`docs/q8g/Q8G_OBJECTDB_LEAK_TRIAGE.md`（根因 + 是否 GUT 语境）
3. **禁止**为清零日志而删测试

### Agent3 验收标准

1. [ ] 有可复现步骤与根因分类
2. [ ] 若修：泄漏计数下降且测试仍绿；若不修：明确「已知遗留、不阻塞 Release」

---

## P1-3 W10 真窗首跑 flake（钉死）

### Owner 步骤

1. 串行、单进程真窗重跑 `verify_w10_continue_run.gd` ≥5 次（无并行 Godot）
2. 若可复现：记时序/路径；**禁止**改 save 语义
3. 若不可复现：在报告写「环境并发因素」，harness 可选加重试

### Agent3 验收标准

1. [ ] 有次数与失败率
2. [ ] 未改 `save_repository` 业务语义

---

## P2-1 美术 BATCH 入库后回归

| # | 步骤 |
|---|------|
| A1 | 按 `docs/art/BATCH-*-PROMPTS.md` 生成并落目录 |
| A2 | `tools/import.ps1` 导入；更新 `assets_manifest.json` |
| A3 | 战斗/休息/商店/结局/敌人立绘真窗或截图抽测 |
| A4 | 交互门 + 卡带预算 |

### Agent3 验收标准

1. [ ] manifest 与磁盘一致、单测绿
2. [ ] 无 `Image.load` 导出 WARNING 回潮
3. [ ] 交互门三键仍绿

---

## P2-2 道徽入框 / 云纹边框（可选）

- 道徽：13/20 → 20/20 或明确放弃  
- 云纹：生成或程序化；失败则文档记录「放弃本批」

---

## 明确不做（本轮）

```text
Android 导出 / SDK
修改 data/** 或 domain 生产规则（G1/M/T/pity/E6/pacing）
LLM 新文本能力
把 KNOWN_OCCLUDED 当放行清单扩项
```

---

## 交回格式（Owner 填写）

```text
提交清单：
  <sha> <subject>

命令与退出码：
  <cmd> → <exit>  <log或摘要路径>

未完成项：
  …

需要 Agent3 验收的项编号：P0-1 / P0-2 / …
```

---

## Agent3 验收总表（我填）

| 项 | 结果 | 证据 |
|----|------|------|
| P0-1 Debug 裁剪 | | |
| P0-2 POT | | |
| P0-3 最终 Gate | | |
| P1-1 gutconfig | | |
| P1-2 ObjectDB | | |
| P1-3 W10 | | |
| P2-1 美术 | | |
