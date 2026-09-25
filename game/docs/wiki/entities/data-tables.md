---
title: 数据表全集
description: data/ 目录 29 张 JSON 表的主题地图、关键数值与已知数据问题
date: 2026-09-25
tags: [data, json, balance, tables]
---

data/ 共 29 张 JSON（约 45 万字节），全部经 ContentCatalog.validate 校验；调参数值必须落 JSON 并过 Schema 校验，禁止散落代码[^1]。

## 表地图

| 表 | 内容 | 关键数值 |
|---|---|---|
| gu.json | 802 只蛊（220/157/180/97/147 按转） | value 锚 3/5/8/12/20；v1_effect 62 只 |
| refinement_recipes.json | 469 配方 + 4 商队报价（**无 recipes.json，别找错**） | advance 377（6/10 石）/ fixed 15 / promotion 76 / free_mix 1 |
| enemies.json | 32 敌（common 13/elite 12/boss 7） | HP 3-20；意图五类；boss 50% 血转阶段 |
| shops.json | 38 offers | 石皮蛊 6 … 月华露 80；剑道系列 8→70 |
| balance.json | 全局经济常数 | 回购 0.5、删卡 120、自由配对 20→300 |
| pacing.json | 5 层节奏 | stone_budget 12→35；加价 0→50%；敌权重 75/25/0 |
| aptitude.json | 资质 | 上限系数 1/2/3/4；**regen_pct 与 v1_battle.json 冲突** |
| v1_battle.json | 战斗/杀招 | 26 杀招；stage_base 10/30/60/100/150 |
| loot_tables.json | 掉落 | elite 30% 强制 epic；pity 3；7 材料定价 |
| schools.json / school_pools.json | 20 流派 × 4 初始蛊 / 20 池 × 40 id | 补一流派改 6 处之一 |
| nodes.json | 37 节点模板 + 登仙节点 | 层主位映射 L1-L5 |
| reputation.json | 恶名 | 价格 +10%/点（封顶 60%）、敌意 +15%、先手 -10% |
| contracts.json | 5 契约（contract_cap 6） | 血契打击 +30%；调试契约开局 1000 石 |
| curse.json | 3 诅咒 | 蛊蚀拔除底价 6 石；滞胀免费额度 2 |
| deck.json | 卡面容量 | 容量 12/手牌 2；删卡等各限 2 次/局 |
| synthesis.json | 战斗合成 | 基础 60% 每败 +10% ≤+30%；盲合 -20% |
| dda.json | 动态难度 | 权重 3/3/2/2/1；≥5 险象、≥9 衰运 |
| npcs.json / events.json / relics.json / inheritances.json | 5 NPC / 24 事件 / 2 遗物 / 3 传承 | 事件池为 D4 扩容产物 |
| gu_names.json / names.json | 中文映射 | 802 蛊名 + 16 类实体名 |
| first_run.json / journal.json / buffs.json / debug.json | 教学/手记/调试 | 首局 13 节点；6 结局文案 |

## 数据问题登记

1. regen_pct 同名双源冲突（aptitude 40/30/20/10 vs v1_battle 35/30/25/18）[^2]。
2. final_boss_stand 敌人 rank3/HP14 弱于 L3/L4 层主；2 个 rank5 boss 游离[^3]。
3. 兽骨 378/385 独大——晋升经济单点依赖[^2]。
4. 敌人无防御字段、无直接元石掉落字段[^3]。

## 纪律

原 SQL 数据排除令已解除（2026-09-10）：enemies.json 32 条由 validate 全量 + 池契约测试守卫[^1]。补一流派需改 6 处（schools/school_pools/gu.json 40 只/SCHOOL_IDS/测试硬编码/选择屏）[^4]。

[^1]: AGENTS.md, 技术约定与当前待办
[^2]: PROJECT_WORLD_MODEL_AUDIT.md, §11/§26
[^3]: PROJECT_WORLD_MODEL_AUDIT.md, §14
[^4]: [失源] MEMORY.md（项目工作记忆，流派节；源未入库已失传，主张待重锚，见 plan.md 已知缺口）
