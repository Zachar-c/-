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
| tools/check.ps1 | 全局验收门 | test all + 启动探针 + 契约漂移守门 + git diff --check |
| scripts/acceptance_driver.gd | 冒烟/截图/试玩/渲染/崩溃验收 | `--mode=smoke/capture/play/render/crash` |
| tools/check_contract_drift.gd | 契约-实现漂移守门 | 扫描 `scripts/ tests/ data/` 声明标识符 |

## 交互门判定细节

交互回归以真实按下/松开断言守门；透明容器必须 `IGNORE`，`PASS` 同样会遮挡身后兄弟节点。现役样例：`tests/unit/test_wenzhen_battle_screen.gd`。原全屏 `verify_interaction_loop.gd` 已随一次性探针清理，新增交互应按同一原则补 GUT 覆盖[^1][^2]。

## 测试规模与运行纪律

tests/ 分为 unit/integration/helpers。unit 全量约 3-4 分钟，必须后台运行；单文件测试必须用 `-s addons/gut/gut_cmdln.gd -gtest=res://... -gexit` 形式（直接 `-gtest` 会挂死）；GUT 9.6.1 无 assert_ge/assert_le，用 assert_true(x >= n)[^3]。新 worktree 需 cp .godot；类缓存过期跑 `--headless --import`，别删 .godot[^3]。

## 遗留技术债

ObjectDB/RID 泄漏（2026-09-06 复测 20601 实例仍复现）。Dialogue Manager 已移除，不再属于遗留项。

[^1]: AGENTS.md, 工具规则与 AI 契约
[^2]: PROJECT_WORLD_MODEL_AUDIT.md, §21/§22
[^3]: MEMORY.md（项目工作记忆，Godot 坑节）
