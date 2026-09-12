---
title: 验证工具链
description: 测试套件、全局检查门、交互闭环回归与渲染级验证工具的完整清单
date: 2026-09-12
tags: [testing, verification, tools, gut]
---

验收纪律：AI 契约裁定交互改动默认以 headless 回归门验收，仅用户主动要求才开真窗模拟键鼠；headless 通过不代表真窗可用[^1]。

## 工具清单

| 工具 | 用途 | 关键参数 |
|---|---|---|
| tools/test.ps1 | GUT 测试 | -Suite unit/integration/all；-Test 单文件 |
| tools/check.ps1 | 全局验收门 | guitkx 构建 + test all + 启动探针 + 契约漂移守门 + git diff --check |
| tools/verify_interaction_loop.gd | 交互闭环门 | 13 屏 + 大厅 4 子视图 = 17 个 AUDIT 标签；dead/no_ui_click/occluded 三键全空才可交付；约 4.5 分钟 |
| ~30 个 verify_*.gd | 逐特性渲染验证 | 含像素/色彩分布（UNIQUE=1 即白屏） |
| tools/verify_pacing_density.gd | E5 地图节奏门 | 四分类 + 聚合战斗占比 |
| tools/verify_route_diversity.gd | E5 路线多样性门 | 全池模板冒烟 |

## 交互门判定细节

dead = 无 pressed/toggled 连接（接线判定同时计入 CheckButton 的 toggled，否则误报死按钮）；no_ui_click = 未过 MasterTheme 音频接线（每次交互须视觉+听觉双重反应）；occluded = 点击中心被遮挡（**PASS 同样遮挡，只有 IGNORE 让路**，判定按引擎 `_gui_find_control_at_pos` 子节点逆序）。既有未修项登记 KNOWN_OCCLUDED 留档表，以 occluded_known 计数呈现[^1][^2]。

## 测试规模与运行纪律

tests/ 202 个 .gd（unit/integration/helpers）[^2]。unit 全量约 2 分钟，必须 run_in_background；单文件测试必须用 `-s addons/gut/gut_cmdln.gd -gtest=res://... -gexit` 形式（直接 `-gtest` 会挂死）；GUT 9.6.1 无 assert_ge/assert_le，用 assert_true(x >= n)[^3]。新 worktree 需 cp .godot；类缓存过期跑 `--headless --import`，别删 .godot[^3]。

## 遗留技术债

ObjectDB/RID 泄漏（2026-09-06 复测 20601 实例仍复现）；Dialogue Manager invalid UID[^1]。

[^1]: AGENTS.md, 工具规则与 AI 契约
[^2]: PROJECT_WORLD_MODEL_AUDIT.md, §21/§22
[^3]: MEMORY.md（项目工作记忆，Godot 坑节）
