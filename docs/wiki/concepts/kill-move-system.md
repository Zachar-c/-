---
title: 杀招系统
description: 命名杀招的配方组装、威力配置、化解标签与泄密机制
date: 2026-09-12
tags: [kill-moves, sword-school, combat]
---

命名杀招是玩家自由组合之上的"知识资产"层：需要通过传承、购买、线索或验证掌握；保存为杀招后一键提交，但成本照常累加，任何节省或增幅必须来自明确杀招规则[^1]。

## 当前实现（v1_battle.json 26 条）

构成：剑道 22 + 光 2 + 血 1 + 力 1[^2]。结构 `{id, label, tag, recipe[definition_id...], true_qi_cost, thought_cost, life_cost, damage, effect}`[^2]。威力手工配置，最高"五指拳心剑·五转"= 5 剑组成、7 真元、2 念头、伤害 24[^2]。

释放校验链：配方蛊全部持有且未封印 → 念头 → 真元 → 寿元（扣到 ≤0 效果不执行直接陨落）[^2]。配方蛊仅标记 used_this_turn，实例不消耗[^2]。

## 化解与泄密（世界模型直译）

- **化解**：杀招 tag（light/blood/force/sword）匹配敌人 `counter_hidden/counter_revealed` → 效果无效但资源照扣；隐藏化解受击后移入 revealed[^2]。
- **泄密**：杀招用一次即 `reveals=true`，在场全部敌人 id 追加进 `battle.revealed_to`——直译原文"仙道杀招一旦被借用，当中的秘密就会被其他蛊仙洞悉"[^2]。

## 剑道落地的教训（2026-09-11 考据修正）

旧版押"剑意"被推翻：原文「剑意」仅 4 次而「飞剑」200 次；侵蚀代价改写为"残锋"（永久耗道痕降转），非自伤[^3]。剑道身份 = "用法"非"层数"，八机制中刻痕（印在目标身上、道痕自寻弱点）与代价（永久耗剑道仙蛊道痕）是两颗星[^3]。杀招 `steps` 就是"多段"的合法宿主，不加新 effect kind[^3]。杀招可跨转数：层级由配方蛊决定，凡道杀招 190 次，改良是生命周期常态[^3]。

## 已知差距

杀招威力违背纪律 7（中央参数导出），逐条手写 amount，内容增长时平衡成本平方级上升[^4]。规格 §4.2 的"验证过的自由编排可保存为杀招"尚未实现[^1]。

## 关联页面

- 战斗内释放流程 → [战斗系统](combat-system.md)
- 剑道流派内容 → [蛊虫与炼蛊](gu-and-synthesis.md)
- 化解反制的敌人侧 → [数据表全集](../entities/data-tables.md)

[^1]: docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md, §4.2
[^2]: PROJECT_WORLD_MODEL_AUDIT.md, §6/§15
[^3]: docs/superpowers/specs/2026-09-11-sword-cosmology-integration.md 与 MEMORY.md 剑道条目
[^4]: PROJECT_WORLD_MODEL_AUDIT.md, §26
