---
title: 地图生成器
description: MapGenerator 的 5 层拓扑、按层伪随机节奏体系（E1-E7）与种子化规则
date: 2026-09-12
tags: [map, generation, pacing, seeded-random]
---

`map_generator.gd`（470 行）：一局固定 5 大层（LAYER_ORDER one→five），每层 8-11 行 × 每行 2-6 节点；首行 1-2 入口、末行 1 个关底 Boss；行进边每节点连下一行 1-2 个节点（50% 概率 2 条）；大层接缝 = 关底 Boss → 下层入口行[^1]。

## 按层伪随机体系（E1-E7，全部已落地）

| 批次 | 内容 | 落点 |
|---|---|---|
| E1 | 分类概率表：层1 战 82/休 5/未知 9/交易 4 → 层5 战 76/未知 13/交易 8 | pacing.json category_weights |
| E2 | 分类抽取 + 行内去重 + 层保底（累计 ≥5 槽强制补足）；unknown 类迷雾 | `_pick_category_template` |
| E3 | 休息三选一 mode_groups（休整/修炼/炼蛊分组，一次探访只取一份收益） | rest_snapshot.gd |
| E4 | 表现层：「?」迷雾 + 休息三选一 UI + refinement/cultivation → Rest 屏统一路由 | presentation |
| E5 | 回归门：verify_pacing_density.gd 四分类战斗占比门 + verify_route_diversity.gd 全模板可达冒烟 | tools/ |
| E6 | 敌人按层 roll：主题锚定池 + 层 rank 区间 + tier 权重（common 75/elite 25/boss 0）；Boss 永不入选普通节点 | enemy_roll |
| E7 | 商店按层货架：洗牌取前 4+⌊层/2⌋ 件 + 保底 1 件本层最高档；(局种子, 节点模板) 派生 | shop_stock |

全部出自执行卡与 AGENTS.md 当前待办[^1][^2]。

## 锚点与节奏约束

每层 anchors 来自 pacing.json：遗葬 pre_boss、炼蛊 mid、黑市 mid/pre_boss/quarter；每两行强制休整（REST_ROW_STRIDE=2，2026-09-08 由 3 收紧——此前战斗占比一度 82%）[^1]。层主位映射：L1 蟒母 / L2 蛊师 / L3 雷冠君王 / L4 血络主教 / L5 瘴脉君[^3]。

**审计红旗**：终点 final_boss_stand 敌人 miasma_vein_lord（rank3/HP14）弱于 L3/L4 层主；两个 rank5 boss（蓝毛僵/族长）未编入层主位[^4]。

## 首局教学

first_run.json：seed 101，固定 13 节点单入口线性链（beast_swarm_pass → layer_boss_stand_1 → … → final_boss_stand → ascension_window）[^1]。

## 随机数纪律

SeededRng（Lehmer LCG）+ seeded_roll 盐值混合（2026-09-10 修正等差阶梯缺陷，tick 从"种子偏移"改为"流位置"，tick=0 与旧实现字节兼容）[^2]；表现层纯装饰随机豁免（W14）[^5]。注意 PoolManager 只是规划名词，无代码实现——池逻辑分散在 EnemyCatalog / shop_stock / loot pity[^2]。

## 关联页面

- 节点类型与循环位置 → [核心玩法循环](../concepts/gameplay-loop.md)
- pacing/shops/nodes 数据 → [数据表全集](data-tables.md)
- 验证工具 → [验证工具链](verification-toolchain.md)

[^1]: PROJECT_WORLD_MODEL_AUDIT.md, §18
[^2]: PROJECT_WORLD_MODEL_AUDIT.md, §21
[^3]: data/nodes.json
[^4]: PROJECT_WORLD_MODEL_AUDIT.md, §14
[^5]: AGENTS.md, 技术约定 W14
