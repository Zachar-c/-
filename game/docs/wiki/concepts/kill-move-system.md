---
title: 杀招系统
description: 命名杀招的配方组装与化解/泄密落地；原著杀招代价以 lore 蒸馏为真源
date: 2026-09-25
tags: [kill-moves, sword-school, combat]
---

**原著真源**：[养蛊、用蛊与炼蛊](../../../../lore/wiki/world/gu-care-and-refinement.md)（杀招=多蛊组合、必有弊端与后遗症、威力大则真元消耗巨大）。本页写《问真》知识资产化与战斗编码，不把游戏标签写成原著规则[^1]。

## 原著锚点（摘要）

| 原著规则 | 要点 | 真源 |
|---|---|---|
| 组合本质 | 单蛊功效单一；杀招=多蛊组合叠加 | lore 养蛊页 |
| 代价 | 必有弊端与后遗症；威力大则真元消耗巨大 | lore 养蛊页 |
| 术语边界 | 连招/并招是个案技巧，非通用合成公式 | lore 养蛊页 |

## 《问真》落地（游戏裁定）

### 知识资产层

命名杀招需传承/购买/线索/验证掌握；保存后一键提交，成本照常累加——节省或增幅必须来自明确杀招规则[^2]。

### 当前实现（v1_battle.json）

结构 `{id, label, tag, recipe[], true_qi_cost, thought_cost, life_cost, damage, effect}`；释放校验链：配方蛊持有且未封印 → 念头 → 真元 → 寿元（≤0 则不执行直接陨落）[^3]。配方蛊仅 `used_this_turn`，实例不消耗[^3]。

### 化解与泄密

- **化解**：tag 匹配敌人 `counter_hidden/counter_revealed` → 效果无效但资源照扣——机制语义贴近“被看穿则失效”，**标签枚举是游戏编码**[^3]。
- **泄密**：用过即对在场敌人公开——对应原著“杀招一旦被借用，秘密会被洞悉”的直译方向[^3]。

### 剑道落地备忘

“剑意”弱证据被推翻后，侵蚀代价改为“残锋”（永久耗道痕降转）；身份=用法非层数；`steps` 承载多段，不新造 effect kind[^4]。相关流派源流见 [流派总表](../../../../lore/wiki/world/path-roster.md)。

## 已知差距

威力逐条手写 amount，违背“中央参数导出”纪律，内容增长时平衡成本上升[^5]。

## 关联页面

- 组合来源 → [蛊虫与炼蛊](gu-and-synthesis.md)
- 战斗释放 → [战斗系统](combat-system.md)
- 转译表 → [世界模型转译](world-model-translation.md)

[^1]: lore/wiki/world/gu-care-and-refinement.md
[^2]: docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md, §4.2
[^3]: PROJECT_WORLD_MODEL_AUDIT.md, §6/§14/§15（化解语义 §14；counter_revealed 代码字段见 scripts/domain/action_preview_service.gd）
[^4]: docs/superpowers/specs/2026-09-11-sword-cosmology-integration.md
[^5]: PROJECT_WORLD_MODEL_AUDIT.md, §26
