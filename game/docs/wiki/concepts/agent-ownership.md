---
title: Agent 协作
description: 四角色写区、Shared 单写者区、5 步硬协议与三层验收门的多 Agent 施工纪律
date: 2026-09-12
tags: [agent-ownership, collaboration, contracts]
---

项目由多 AI Agent 并行开发。2026-09-12 落档的 Agent Ownership 契约是硬门槛：**契约落档前禁止开始新功能开发**；背景是历史并行会话曾 4 次物理删除文件[^1]。

## 四角色写区

| 角色 | 写区 | 禁区 |
|---|---|---|
| Logic | scripts/domain/**、data/*.json、领域单测 | presentation、scenes |
| Visual | scenes/**、ui/widgets/*.guitkx、presentation/screens|widgets | domain、禁写 state |
| Test | tests/**、tools/** | 生产代码只读 |
| Astra | 架构级/跨界/终审 | — |

按系统边界划分（battle_screen.tscn 与其 view.gd 同归 Visual）[^1]。

## Shared 单写者区与 5 步协议

7 项共享文件：run_controller.gd、run_snapshot_builder.gd + snapshots/*、resolver.gd、run_state.gd、save_repository.gd、docs/contracts/*、project.godot + main.tscn[^1]。

修改走 5 步硬协议：①声明文件路径 → ②说明对应已批准任务 → ③说明影响面 → ④提交前跑指定测试 → ⑤单独 commit。违反 1-3 一律回退；并发命中后到者等待[^1]。

## 验收门体系

```mermaid
graph LR
    A["GUT 单测 202 文件"] --> B["check.ps1 全局门"]
    B --> C["交互门 17 审计标签"]
    C --> D["渲染级像素验证"]
```

- `tools/test.ps1 -Suite unit|integration`：GUT 全套（unit 全量约 2 分钟，必须后台跑）[^1][^2]。
- `tools/check.ps1`：构建 + 全测 + 启动探针 + 契约漂移守门（契约声明的标识符必须在 scripts/tests/data 存在）[^3]。
- `verify_interaction_loop.gd`：headless 遍历 13 屏 + 大厅 4 子视图，dead / no_ui_click / occluded 三键全空才可交付；occluded 查"接线齐全但点不到"（判定按引擎 `_gui_find_control_at_pos`）[^1]。
- 约 30 个 `verify_*.gd` 逐特性渲染验证，含像素/色彩分布级白屏检测（UNIQUE=1 即白屏）[^2]。

## 领域-表现契约

UI 只读快照只提交命令；`state_version`（=event_log.size()）过期拒绝；拒绝走 39 条中文映射；逐屏快照键表；新增键/命令/组件须同步回写契约文档[^4]。模块接口约定每系统 1 页（module-interfaces/ 01-08），依赖方向只允许 表现层→领域层→数据层[^5]。

## Git 纪律

禁 `git stash` / `git reset --hard` / `git checkout -- .`（.git 五次损坏史）；对照只读用 `git show HEAD:file`；推送/拉取挂起一律显式 wincred 凭证链；构建产物不入库；分支名不带斜杠[^2]。

## 关联页面

- 被协作保护的核心实体 → [领域路由核](../entities/domain-router.md)、[RunState 与存档](../entities/run-state-and-saves.md)
- 工具链细节 → [验证工具链](../entities/verification-toolchain.md)

[^1]: docs/contracts/2026-09-12-agent-ownership-contract.md
[^2]: MEMORY.md（项目工作记忆，Git 纪律与 Godot 坑）
[^3]: AGENTS.md, 工具规则
[^4]: docs/contracts/2026-09-02-domain-ui-contract.md
[^5]: docs/contracts/module-interfaces/README.md
