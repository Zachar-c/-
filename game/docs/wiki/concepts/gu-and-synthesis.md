---
title: 蛊虫与炼蛊
description: 《問真》蛊实例/蛊方落地；养炼用原著规则以 lore 蒸馏为真源
date: 2026-09-25
tags: [gu, synthesis, refinement, schools]
---

**原著真源**：[养蛊、用蛊与炼蛊](../../../../lore/wiki/world/gu-care-and-refinement.md)、[全书蛊虫总表](../../../../lore/wiki/gu/roster.md)、[世界操作系统](../../../../lore/wiki/world/world-operating-system.md)。本页只写《问真》如何落地，不重复原著事实、不把游戏公式写成原著[^1]。

## 原著锚点（摘要，细节回 lore）

| 原著规则 | 要点 | 真源 |
|---|---|---|
| 饲养是持续负担 | 一般蛊师只养四五只同转蛊（养不起+用不起） | lore 养蛊页 / `CAN-GU-CARE-001` |
| 炼化是意志对抗 | 抹意志必遭反抗；中断可能前功尽弃；极强者反噬空窍 | lore 养蛊页 |
| 合炼须秘方 | 有些蛊不能合炼；秘方=无数实践与失败总结 | lore 养蛊页 |
| 杀招=组合沉淀 | 单蛊功效单一；组合必有弊端与后遗症 | lore 养蛊页 |
| 协同有边界 | 相似蛊可共用喂养/组合，不等于无条件叠加 | `CAN-GU-SYNERGY-001/002` |

## 《问真》落地（游戏裁定）

- **实例模型**：同名蛊不同实体；交易/喂养/炼化/催动都针对实例。持有无硬上限，由成本形成软上限——与原著“四五只”惯例同构，但**上限数值是游戏压缩**[^2]。
- **目录与流派**：`gu.json` 内容池（含多道标签开放集合）是**游戏内容设计**，不是原著蛊虫全集；查“这只蛊在原著里是谁的/几转/什么用”用 [全书蛊虫总表](../../../../lore/wiki/gu/roster.md)，不要反查游戏表[^3]。
- **蛊方四类**（469 条）：advance 晋升 / promotion 定向晋升（每步 +1 转且换蛊名）/ fixed 古方（附小说出处）/ free_mix 自由混合——**成功率与三结局权重是游戏裁定**，不得写成原著合成公式[^4]。原著已有明确合炼个案（如月光+双小光→月芒）应进 fixed 并保留出处。
- **核心蛊**：一局一只、可推迟可更换——纯游戏构筑节奏，原著无此制度[^2]。

## 已知风险

- 目录多样性尚未兑换成战斗多样性：显式 `v1_effect` 覆盖不足时走角色兜底，标签丰富但手感收敛[^5]。
- 晋升材料单一化（兽骨占比过高）是已登记缺口[^5]。

## 关联页面

- 杀招组合 → [杀招系统](kill-move-system.md)
- 资源消耗 → [资源模型](resource-model.md)
- 数值表 → [数据表全集](../entities/data-tables.md)
- 转译差异表 → [世界模型转译](world-model-translation.md)

[^1]: lore/wiki/AGENTS.md；lore/wiki/world/gu-care-and-refinement.md
[^2]: docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md, §1/§2/§4.1
[^3]: lore/wiki/gu/roster.md；lore/wiki/gu/index.md
[^4]: docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md, §5.3
[^5]: PROJECT_WORLD_MODEL_AUDIT.md, §25
