---
title: 問眞项目知识库
description: 《問眞》（前称蛊路求生）项目全部设计决策、系统实现与工程纪律的综合知识库入口
date: 2026-09-12
tags: [overview, hub, wiki]
---

本知识库按 [LLM Wiki 规范](maintenance.md) 编译，覆盖《問眞》项目散落在 130+ 份文档中的设计资产：权威规格、契约、计划、审计与工程纪律。源文档一律只读；本目录的页面是综合层，每个事实主张都带脚注指回源文件。

## Key Findings

- **项目身份**：《問眞》0.9.0，以《蛊真人》小说为世界模型（World Model）的单机修行肉鸽，不做剧情复刻，从世界规则推导游戏机制[^1]。
- **世界模型已进入引擎的六处硬证据**：转数质量门禁、资质四档贯穿、念头行动制、杀招化解+泄密、三轴死亡（hp/寿元/魂魄）、节点内真元预算[^2]。
- **最大设计风险**：802 只蛊中仅 48 只有显式战斗效果，其余 754 只走角色兜底数值——目录多样性尚未兑换成战斗多样性[^3]。
- **工程纪律强于常规**：TDD red-green、纯函数战斗引擎、事件日志不可变、Agent 所有权 5 步协议、交互闭环回归门[^4]。

## 知识库导航

### 核心概念（concepts/）

| 页面 | 内容 |
|---|---|
| [世界模型转译](concepts/world-model-translation.md) | 小说规则 → 游戏机制的映射表与判定 |
| [核心玩法循环](concepts/gameplay-loop.md) | 一局 Run 的完整流程与 Roguelike 结构 |
| [战斗系统](concepts/combat-system.md) | v1 纯函数引擎、行动类型、伤害公式 |
| [资源模型](concepts/resource-model.md) | 真元双轨、三轴死亡、元石经济角色 |
| [蛊虫与炼蛊](concepts/gu-and-synthesis.md) | 蛊实例体系、20 流派、蛊方三类 |
| [杀招系统](concepts/kill-move-system.md) | 配方组合、化解标签、泄密机制 |
| [经济系统](concepts/economy.md) | 价值锚、层预算、黑市兑换、通胀 |
| [Meta 图鉴](concepts/meta-progression.md) | 跨局保留什么、归因机制 |
| [Agent 协作](concepts/agent-ownership.md) | 四角色写区、5 步协议、验收门 |

### 关键实体（entities/）

| 页面 | 内容 |
|---|---|
| [领域路由核](entities/domain-router.md) | resolver 拆分、四命令族、55 种命令 |
| [v1 战斗引擎](entities/v1-battle-resolver.md) | 纯函数战斗实现细节 |
| [RunState 与存档](entities/run-state-and-saves.md) | 状态字段、双 JSON、校验位 |
| [地图生成器](entities/map-generator.md) | 5 层拓扑、E1-E7 节奏体系 |
| [数据表全集](entities/data-tables.md) | 29 张 JSON 表的主题地图与关键数值 |
| [验证工具链](entities/verification-toolchain.md) | 测试、检查、交互门、渲染验证 |

### 时间与维护

- [开发时间线](timeline.md) — 2026-08-21 至 09-12 的里程碑脉络
- [知识库维护](maintenance.md) — 更新机制、lint 清单、routine 提示词
- [维护计划](plan.md) — 当前知识库建设进度追踪

[^1]: README.md
[^2]: PROJECT_WORLD_MODEL_AUDIT.md, §5
[^3]: PROJECT_WORLD_MODEL_AUDIT.md, §25
[^4]: AGENTS.md
