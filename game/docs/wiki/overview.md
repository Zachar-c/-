---
title: 問眞项目知识库
description: 以《蛊真人》原著蒸馏为世界真源的《問眞》生产知识入口：原著锚点、转译裁定与工程实现索引
date: 2026-09-25
tags: [overview, hub, wiki, canon]
---

本知识库以 [`lore/wiki`](../../../lore/wiki/index.md) 的原著蒸馏为**世界规则唯一真源**（L0–L5）；本目录只承载两件仍然成立的事：① 原著 → 《问真》的**转译裁定**（L6，游戏数值与改编，不得冒充原著）；② 当前工程的**实现事实**（引擎、数据表、验收）。凡回答“原著里是什么样”，一律先读 `lore/wiki`，不要在本目录重新发明世界观[^1]。

## Key Findings

- **世界真源**：修炼/资质/真元/养蛊炼蛊/杀招/流派/人物与事件，以 `lore/wiki` 为准（含 `canon-index:CAN-*` 与 E-ID 证据链）[^2]。
- **转译纪律**：本目录概念页只写“《问真》如何落地”，与原著不一致处必须显式标为**游戏裁定**，禁止把 `2^(gu-cultivator)` 之类旧倍率写成原著规则（见 `RUL-2026-09-19-008`：转数是层级轴，不是万能倍率）[^3]。
- **工程事实仍归本目录**：战斗引擎、RunState、数据表、验证工具链描述的是代码与配置，不是世界观[^4]。
- **已废止内容**：Agent 所有权 5 步协议等流程约束已随 `RUL-2026-09-17-003` 作废，仅作历史参考[^5]。

## 知识分层

| 要回答什么 | 去哪里 |
|---|---|
| 原著世界规则 / 人物 / 蛊 / 事件 | [`lore/wiki`](../../../lore/wiki/index.md)（World OS、修炼、真元、养蛊炼蛊、流派总表…） |
| 《问真》怎么改、怎么算 | 本目录 `concepts/`（显式游戏裁定） |
| 代码/数据怎么实现 | 本目录 `entities/` |

## 知识库导航

### 转译与设计（concepts/）

| 页面 | 内容 |
|---|---|
| [世界模型转译](concepts/world-model-translation.md) | 原著事实 → 游戏机制的映射与差异声明 |
| [蛊虫与炼蛊](concepts/gu-and-synthesis.md) | 实例/蛊方落地；原著养炼以 lore 为准 |
| [资源模型](concepts/resource-model.md) | 真元/寿元/魂魄的游戏结算；原著资源观以 lore 为准 |
| [杀招系统](concepts/kill-move-system.md) | 配方/化解/泄密落地；原著杀招代价以 lore 为准 |
| [核心玩法循环](concepts/gameplay-loop.md) | 一局 Run 流程（纯游戏） |
| [战斗系统](concepts/combat-system.md) | v1 纯函数引擎规则（纯实现） |
| [经济系统](concepts/economy.md) | 元石与商店数值（纯游戏） |
| [Meta 图鉴](concepts/meta-progression.md) | 跨局保留（纯游戏） |
| [Agent 协作](concepts/agent-ownership.md) | **历史**：已废止的协作契约 |

### 工程实现（entities/）

| 页面 | 内容 |
|---|---|
| [领域路由核](entities/domain-router.md) | resolver 拆分、命令族 |
| [v1 战斗引擎](entities/v1-battle-resolver.md) | 纯函数战斗实现 |
| [RunState 与存档](entities/run-state-and-saves.md) | 状态字段、存档校验 |
| [地图生成器](entities/map-generator.md) | 五层拓扑与节奏 |
| [数据表全集](entities/data-tables.md) | JSON 表主题地图 |
| [验证工具链](entities/verification-toolchain.md) | 测试与验收门 |

### 时间与维护

- [开发时间线](timeline.md)
- [知识库维护](maintenance.md)
- [维护计划](plan.md)

## 原著入口（直接可达）

- [世界操作系统](../../../lore/wiki/world/world-operating-system.md)
- [修炼体系](../../../lore/wiki/world/cultivation-system.md)
- [资质与空窍](../../../lore/wiki/world/aptitude-and-aperture.md)
- [真元](../../../lore/wiki/world/primeval-essence.md)
- [养蛊、用蛊与炼蛊](../../../lore/wiki/world/gu-care-and-refinement.md)
- [流派总表](../../../lore/wiki/world/path-roster.md)
- [全书蛊虫总表](../../../lore/wiki/gu/roster.md)

[^1]: lore/wiki/AGENTS.md（L0–L5 / L6 分层：原著事实与游戏推导严格分离）
[^2]: lore/wiki/index.md；game/docs/lore/canon-index.md
[^3]: game/world-model/rulings/RUL-2026-09-19-008.json
[^4]: game/AGENTS.md（数据以 game/data/ 为真源；验收以 tools/check.ps1 为准）
[^5]: game/world-model/rulings/RUL-2026-09-17-003.json；game/docs/contracts/2026-09-12-agent-ownership-contract.md
