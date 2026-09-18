---
title: v1 战斗引擎
description: scripts/domain/v1_battle_resolver.gd 纯函数式战斗引擎的实现细节与引擎事实
date: 2026-09-12
tags: [battle, resolver, pure-function, implementation]
---

`v1_battle_resolver.gd` 是纯函数式引擎：battle 是普通 Dictionary，每次动作 `duplicate(true)` 后写回（`_dup()`）；2026-08-30 用户裁定全量替换卡牌战斗[^1]。规则层总览见 [战斗系统](../concepts/combat-system.md)。

## 战斗 Dictionary 结构

`{turn, phase, cfg, player{hp, max_hp, true_qi, true_qi_max, regen, buffs{force, yi_zhang}, thoughts...}, enemies[], gu_slots, active_permanents, kill_moves, revealed_to, log, flags, result}`[^1]。

## 核心实现锚点

| 机制 | 实现位置 | 要点 |
|---|---|---|
| 行动门禁 | `can_play_gu` (L236) | 七重拒绝码：gu_consumed/gu_sealed/gu_used_this_turn/insufficient_qi_quality/action_limit_reached/insufficient_thought/insufficient_true_qi |
| 成本扣除 | `_spend_costs` (L331) | true_qi_cost + thought_cost + life_cost |
| 敌人意图 | `_resolve_enemy_intent` (L702) | attack/seal/soul_drain/life_cost/counter；seal 用 `turn % candidates.size()` 确定性"随机" |
| 刻痕结算 | `_settle_marks` (L674) | `min(layers, 10) × 1`，不吃护盾不吃增益只伤敌 |
| 胜负 | `_check_victory` / `_check_player_death` | 全敌倒 / hp+life_time+soul 三轴 |
| Boss 倍率 | facade (L92) | boss_layer_mult 作用于 hp/damage |

行号会漂移，以函数名为锚[^1]。

## 引擎事实（2026-09-11 锁定，改前必读）

- **F1**：显式 v1_effect 无转数放大——只有 role 兜底表生成的 effect 执行 `amount = base + (rank-1)`（RANK_SCALED_KINDS = strike/shield/heal）[^2]。
- **F2**：status 仅 marked/bound，且不参与伤害计算[^2]。
- **F3**：buff 只喂 basic_attack（strike 通道只吃 turn_supports 与 sword_intent）[^2]。
- **F4**：support_school 只惠及本回合后续同流派蛊，end_turn 清零[^2]。
- 杀招不经 `can_activate`——高转杀招的门槛是间接的（须先拥有高转配方蛊）[^1]。
- hp 同步：每条命令后 `sync_battle_hp_to_state` 写回 RunState，防双源漂移[^1]。

## 测试锚点

tests/unit/test_v1_battle_resolver.gd、test_v1_basic_actions.gd、test_v1_gu_effect_guards.gd、test_v1_battle_settlement_guards.gd、test_battle_synthesis.gd（杀招）[^1]。

## 关联页面

- 行动规则与数值 → [战斗系统](../concepts/combat-system.md)
- true_qi 公式 → [资源模型](../concepts/resource-model.md)
- 路由入口 → [领域路由核](domain-router.md)

[^1]: PROJECT_WORLD_MODEL_AUDIT.md, §15/§21
[^2]: docs/superpowers/plans/2026-09-11-sword-school-landing-plan.md, §0
