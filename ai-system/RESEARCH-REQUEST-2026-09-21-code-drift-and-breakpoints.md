# RESEARCH REQUEST

```text
STATUS: ANSWERED
FROM: L2 Codex (local monorepo audit)
TO: L1 ChatGPT Research
DATE: 2026-09-21
ANSWERED_BY: L1 2026-09-21
ANSWER_DOC: game/world-model/rulings/RUL-2026-09-21-010.json
EXECUTION_ORDER: Projection → Rank → Economy → KillMoveChecker → CounterBoundary
```

## 裁决摘要（L1）

| 项 | 结论 |
| --- | --- |
| Q1 杀招 | **B 渐进**：保留 declared damage，加组件一致性 ±15%（coordination 0.85–1.15）；禁方案 A 全量重写 |
| Q2 经济 | **四轴分写**（Income/Price/RefineLoss/Breakthrough）；门禁单位=「几场 I_r」；TOO_CHEAP/TOO_EXPENSIVE 只报警不改价 |
| Q3 投影 | schema 补 `id/parents[]/scope/rationale/authority/validation`；**禁投影炼方组成/实体ID/转数/道/事实/冻结 Ruling** |
| Q4 Counter | 只负责可预告意图的战术应对；**禁升格唯一骨架**；新 primitive 五门+SOURCE |
| Q5 Rank | 8 字段纵轴；**均不许直接用 rank_multiplier**；低转有成本折算则不再价值折损；复杂度用 complexity_points |
| Q6 顺序 | **调序** 1 Projection 2 Rank 3 经济 4 杀招 5 Counter |
| C3 | 月光+小光×2 = 唯一 WORLD 炼方；×1 仅 `experimental_scenario_recipe` |
| C6 | 测试须 R1→R5 连续；正式一局结构 **UNRESOLVED**（倾向：知识跨局/力量不跨局） |

留白四条（黄金紫晶×10 / 高转经济倍数 / 跨转×2 / 五转出现率）保持 UNRESOLVED，禁止 L2 代填。

---

# 原问题（存档）

## CURRENT PHASE

《问真》Web Lab 十分钟 MVP 之后 → 纵向力量体系（一转～五转）。工程原则 Integration First。
产品定论：力量体系即玩法——蛊=元件、杀招=组件运行结构、道=语法、转数=承载、经济=力量环。

## QUESTION（Q1–Q6）

### Q1 杀招组件化
本地证据：`v1_battle.json` km_force_avalanche.recipe=[force_gu,bear_strength_gu] 但 damage=8、true_qi_cost=4 在杀招本体（26 条同构）。
选项：A 立刻组件推导 / B 渐进校验 / C 暂缓。要最小 schema。
→ **已裁 B**（见上表与 RUL-010）。

### Q2 购买力门禁
收入/店价/market_rules/炼耗分写。Lab 投影 20×、念头 2、HP 24、石1:2。
要 1→5 门禁表与 RUL-008 对齐方式。
→ **已裁四轴 + 场次制区间**（RUL-010.q2）。

### Q3 父子投影 schema
WORLD thought=3 → LAB 2。禁投影清单。
→ **已裁补 5 字段 + 禁投影炼方组成**（RUL-010.q3）。

### Q4 Counter 权限上限
Intent/Observe/counter 族。要职责边界与新机制准入。
→ **已裁 primitive_only + 五门准入**（RUL-010.q4）。

### Q5 Rank 纵轴字段 ≤8
低转保值、杀招复杂度。
→ **已裁 8 字段，均禁 rank_multiplier**（RUL-010.q5）。

### Q6 五断点顺序 + 重大变更
→ **已调序**；L2 可做/须呈 L0 清单见 RUL-010。

## KNOWN FACTS / CONFLICTS / CONSTRAINTS

（与送审时相同，可复核）

1. Rank 真源 `balance.json` 40/80/160/320/640；`rank_step_ratio=2`；访问点 `gu_balance.gd`。
2. HP 双轴 RUL-009：human_base_health=100；禁止丙等→HP×0.8。
3. 念头 WORLD 3 → LAB 2；石→真元 WORLD 1:5 → LAB 1:2。
4. `gu.json` 802；moonlight `v1_effect={strike,amount:3}` value=4。
5. 炼方 468；`moon_glow_fixed`=月光+小光×2（原文 17024-17155）；`moonlight_glow`=×1。
6. kill_moves 26 预制 damage。
7. `market_rules.gd`：gu_public_price=rank_standard_price×4。
8. `v1_battle_resolver` Owner；battle2 ORPHAN 并行。
9. 验收：check_balance 38/38 · tests 116/116 · autoplay 30/41。
10. 禁止第四套 Rank/定价/战斗；30/24/50=Golden。

C1 杀招预制技能 · C2 经济无锚 · C3 双炼方 · C4 Counter 膨胀 · C5 双战斗 · C6 单局长度。

约束：Integration First；RUL-008/009；禁第四套系统；L1 留白勿代填。
