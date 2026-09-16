# Agent3 自办清单（本轮）

> 日期：2026-09-15  
> 基线：`master` @ `d15fa567`（已与 origin 对齐）  
> 角色：执行 worker；**不改** domain / data / RunState / 主式规则；**不改** Shared 文件（`run_controller` / `project.godot` / `save_repository` 等）除非 Owner 走完协议

---

## 范围说明

| 我自己做 | Owner 文档交回后我验收 |
|----------|------------------------|
| 交互门 / Rest / 卡带预算 / B2 / W10 在 `d15fa567` 复跑 | Debug 阶段 B 实现证据 |
| Windows Release 导出 + PCK 阴性断言 | `project.godot` POT 清理 |
| Shared 所有权声明 **草案**（不施工） | `.gutconfig` engine 回归（若裁定） |
| 本清单与验收标准文档 | AI 美术批次入库后的资产回归 |
| | ObjectDB/RID 调查结论（若 Owner 接单） |

---

## A1 — UI 交互门复跑（`d15fa567`）

**目的**：美术素材合入后确认 15 屏三键仍绿。

| 命令 | 期望 |
|------|------|
| `tools/godot.ps1 -Console --headless --path . -s tools/verify_interaction_loop.gd` | 15/15 `dead=[] no_ui_click=[] occluded=[] occluded_known=0`，退出码 0 |
| `… -s tools/verify_rest_headless.gd` | `REST HEADLESS OK`，退出码 0 |
| `… -s tools/verify_card_shape_budget.gd` | `FAILED=0`，退出码 0 |

**失败处理**：不改 domain；只修明确 UI/验证缺陷；否则写入 Owner 清单阻塞项。

---

## A2 — 真窗关键项（B2 / W10）

| 命令 | 期望 |
|------|------|
| 真窗 `verify_b2_four_screens_render.gd` | `B2_FOUR_SCREENS FAILED=0` |
| 真窗 `verify_w10_continue_run.gd` | `W10_CONTINUE_RUN FAILED=0`（首跑失败则串行重试一次并记录） |

---

## A3 — Windows Release + PCK 阴性

| 步 | 动作 | 期望 |
|----|------|------|
| 3.1 | 设 `APPDATA` 后 `--export-release "Windows Desktop"` | rc=0，exe 产出 |
| 3.2 | `--export-pack` | pck 产出 |
| 3.3 | `tools/agent3_pck_audit.gd --pck=…` | `AUDIT_PASS`；tests/tools/docs/lore/Godot 计数 0 |
| 3.4 | Release exe `--headless --quit-after 3` | EXIT=0 |
| 3.5 | OBS：debug_panel / facade 仍进包 → **EXPECTED** 阶段 B 前 |

---

## A4 — Debug 阶段 B：Shared 声明草案（不施工）

产出：`docs/q8g/Q8G_DEBUG_PRUNE_SHARED_DECLARATION_DRAFT.md`（草案，待 Owner 确认后按协议施工）

必含五段：文件 → 原因 → 影响面 → 指定测试 → 单独 commit。

**验收标准（Owner 交回时我按此收）**：

1. `run_controller` 不再编译期引用 `RunDebugFacade` / `DebugPanelView`
2. Release PCK 阴性含：`run_debug_facade`、`debug_panel`、`debug_actions`、`debug_panel_view` = 0
3. Debug 构建：F12 面板仍可用；`is_debug_build` 门控保持
4. `verify_interaction_loop` 仍 15/15 三键
5. unit/integration 不红于合入前基线

---

## A5 — 交付与边界

- 提交：仅在 Owner 点名时 push；本批若需 commit 保持小而聚焦
- 不动：`scripts/domain/**`、`data/**`、`main.tscn`、`project.godot`、`.gutconfig.json`、`addons/dialogue_manager/**`
- 不把 occluded 写入 `KNOWN_OCCLUDED` 白名单
- 不为过门加假按钮 / 去掉 disabled 置灰

---

## 完成定义

```text
[A1] 交互门/Rest/卡带 @ d15fa567
[A2] B2 + W10
[A3] Release 导出 + PCK 阴性 + exe smoke
[A4] Shared 草案落盘
[x] Owner 执行清单已交叉链接（Q8G_OWNER_EXECUTION_CHECKLIST.md）
```

---

## 执行结果（2026-09-15 / `d15fa567`）

| 项 | 结果 |
|----|------|
| A1 交互门 | **PASS** 15/15 三键，退出码 0 |
| A1 Rest | **PASS** `REST HEADLESS OK` |
| A1 卡带预算 | **PASS** `FAILED=0` |
| A2 B2 四屏真窗 | **PASS** `FAILED=0` |
| A2 W10 真窗 | **PASS** `FAILED=0`（`has_save=true`，seed 一致） |
| A3 export-release / pack | **PASS** rc=0；`build/agent3-self-d15fa567/` exe 222MB / pck 113MB |
| A3 PCK 阴性 | **AUDIT_PASS**；OBS：debug_panel=9 facade=5 actions=5；claude_pot=1（Shared） |
| A4 Shared 草案 | **已落盘** `docs/q8g/Q8G_DEBUG_PRUNE_SHARED_DECLARATION_DRAFT.md` |

**A3 注记**：产物随 `d15fa567` 美术批次增大；阴性扫描仍为 0。  
**未做**：Debug 阶段 B 施工、`project.godot` POT、Android、push（待 Owner）。

