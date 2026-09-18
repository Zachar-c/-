---
title: 战斗系统
description: v1 纯函数战斗引擎的回合结构、四类玩家行动、伤害公式与状态体系的规则层总览
date: 2026-09-12
tags: [combat, battle, turn-based]
---

2026-08-30 用户裁定全量替换卡牌战斗为 v1 引擎[^1]：battle 是普通 Dictionary，每次动作 `duplicate(true)` 后写回，无抽牌/牌库/弃牌堆[^2]。蛊虫实例的卡片化 UI 只是操作界面，不是技能许可证[^3]。

## 回合结构

战斗开始时按恶名/敌对度掷先手，敌先手立即执行一轮[^2]。玩家回合（可多次行动）→ end_turn：念头清零、支援清空、蛊 used 复位 → 逐个存活敌人执行意图 → 刻痕结算 → 剑意减半 → 回合+1 → 玩家回合开始回真元[^2]。

## 玩家四类行动

| 行动 | 消耗 | 说明 |
|---|---|---|
| play_gu | 真元+念头(+寿元) | 七重门禁：蛊死/封印/本回合已用/真元质量/行动上限/念头/真元[^2] |
| basic_attack | 1 念头，不耗真元 | 伤害 = 1 + buffs；buff 只喂此通道[^2] |
| play_kill_move | 配方校验+真元+念头(+寿元) | 寿元扣到 ≤0 则效果不执行直接陨落[^2] |
| end_turn | — | 进入敌方回合 |

行动次数受魂魄底蕴分档（2/3/4/5/6 次）[^2]。

## 伤害与状态

全确定性，无命中/暴击/闪避随机。蛊 strike = amount + 同流派支援 + 剑道剑意；先吃 shield 剩余穿透；heal 钳制上限；shift 已裁定转译为等量护盾（2026-09-12）[^2]。战斗回合膨胀：敌 HP +2/回合（上限+6）、伤 +1（上限+2）；Boss 层倍率 HP×1.5/伤×1.25[^4]。

状态体系刻意做薄（引擎事实 F1-F4）：显式 v1_effect 无转数自动放大；status 仅 marked/bound 且不参与伤害；buff 只进 basic_attack；support_school 只惠及本回合后续同流派蛊[^5]。复杂度被推向蛊组合与杀招——这是设计取向而非缺陷[^6]。

敌人意图五种：attack / seal（确定性封蛊 ≤3 回合）/ soul_drain / life_cost / essence_burn；Boss 50% 血量转二阶段[^2]。反制 `reactions` 把 counter_tag 塞入 counter_hidden，与杀招化解联动（见 [杀招系统](kill-move-system.md)）。

## 关联页面

- 引擎实现细节 → [v1 战斗引擎](../entities/v1-battle-resolver.md)
- 真元/念头/魂魄的来源与去向 → [资源模型](resource-model.md)
- 战斗中的经济行为 → [经济系统](economy.md)

[^1]: docs/superpowers/plans/ 系列与 scripts/domain/v1_battle_resolver.gd 头注释
[^2]: PROJECT_WORLD_MODEL_AUDIT.md, §15
[^3]: docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md, §0/§4.1
[^4]: data/pacing.json
[^5]: docs/superpowers/plans/2026-09-11-sword-school-landing-plan.md, §0 引擎事实
[^6]: PROJECT_WORLD_MODEL_AUDIT.md, §16
