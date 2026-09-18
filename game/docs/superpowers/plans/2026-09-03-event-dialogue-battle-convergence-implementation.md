# Event Dialogue and Battle Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成事件叙事层迁移、战斗职责收敛和路线/初始蛊可玩性修复。

**Architecture:** Dialogue Manager 脚本只提供叙事分支，适配器把分支 ID 转换为现有命令；`BattleCommandFacade` 是唯一战斗命令入口，V1 resolver 是唯一战斗规则执行者，Battle2 只提供台账纯函数。

**Tech Stack:** Godot 4.7.2, GDScript, JSON, GUT 9.6.1, Dialogue Manager MIT fixed commit `8a49e8001a9021e1982b6e31a10066b41eac2fd2`.

## Global Constraints

- 保持 `RunState` 单一状态所有权和不可变事件日志。
- 不重复实现 `EffectResolver`、`ContentCatalog`、`RunState` 或日志体系。
- UI 只读快照并提交命令；所有成本和拒绝原因可见。
- 第三方来源：[nathanhoad/godot_dialogue_manager](https://github.com/nathanhoad/godot_dialogue_manager), MIT。

### Task 1: Route Closure Regression

**Files:**
- Modify: `scripts/domain/map_generator.gd`
- Test: `tests/unit/test_first_run_route.gd`

- [ ] 写测试：断言 first-run 每个非终点节点的 `next_ids` 非空且全部属于 route。
- [ ] 运行 `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_first_run_route.gd`，确认当前模板外分支失败。
- [ ] 修改 `_route_from_ids()` 重建 `next_ids` 为路线内下一节点，终点设为空。
- [ ] 重新运行同一测试并保留现有分支选择语义。

### Task 2: Data-backed Starter Gu Effects

**Files:**
- Modify: `data/gu.json`
- Modify: `scripts/domain/v1_battle_resolver.gd`
- Test: `tests/unit/test_gu_roles_and_starter_attack.gd`

- [ ] 写测试：六类初始蛊启动战斗后均可 `use_gu`，至少产生伤害、护盾、治疗、控制、位移或标记之一。
- [ ] 运行测试确认缺失效果失败。
- [ ] 为无 `v1_effect` 的战斗蛊补最小 JSON 效果，resolver 仅按现有 `kind` 分派并提供 `heal`/`status`/`shift` 处理。
- [ ] 运行聚焦 GUT，确认真元、念头、事件日志和死亡预检不回归。

### Task 3: Dialogue Branch Adapter and Feedback

**Files:**
- Create: `scripts/domain/dialogue_manager_adapter.gd`
- Create: `data/dialogues/events.dialogue`
- Modify: `scripts/domain/events.gd`
- Modify: `scripts/presentation/run_controller.gd`
- Test: `tests/unit/test_dialogue_gateway.gd`

- [ ] 写测试：分支 ID 映射到现有命令；未知分支返回中文拒绝且不变更状态。
- [ ] 运行测试确认适配器不存在时失败。
- [ ] 实现最小适配器，使用 Dialogue Manager 可用 API；未安装插件时走模板网关降级。
- [ ] 将事件结果接入 `ResultFeed`/`last_feedback`，禁止空反馈直接离开。
- [ ] 运行事件及遭遇集成测试。

### Task 4: Battle Mouse Command Contract

**Files:**
- Modify: `scripts/presentation/run_command_builder.gd`
- Modify: `scripts/presentation/widgets/gu_battle_hand_view.gd`
- Modify: `scripts/presentation/screens/battle_screen_view.gd`
- Test: `tests/unit/test_battle_command_facade.gd`

- [ ] 写测试：`gu.<instance_id>` 点击生成 `use_gu`；单目标命令保留 `target_id`；过期版本拒绝。
- [ ] 运行测试确认目标和点击契约失败。
- [ ] 修复按钮鼠标过滤、重复提交键和目标选择刷新，不改变领域规则。
- [ ] 运行战斗 UI 与 facade 测试。

### Task 5: Full Verification

- [ ] 运行 `tools/check.ps1`。
- [ ] 运行 `git diff --check`。
- [ ] 运行 `tools/smoke_render.ps1` 或仓库等价 Godot headless smoke。
- [ ] 检查工作树只包含任务相关改动并报告未验证风险。
