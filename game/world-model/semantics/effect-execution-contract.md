# Effect Execution Contract V1

> 地位：Web 正式 Runtime 的效果执行契约（RUL-2026-09-25-001 Q1-A'，2026-09-25）。
> 来源：`game/docs/q8/GU_EFFECT_GRAMMAR_V2_FINAL.md` 的**执行语义与事务纪律**（该文件的「唯一权威/全局操作集冻结」地位已被裁定撤销，本契约承接其执行语义；5 操作降为 V1 最小 verb 集）。
> 实现：`game/wenzhen-web-lab/js/gu_rules.js` `effectPlan`/`applyPart`。变更本契约须走 L1 评审。

## 1. 执行管线

```text
can_activate → trigger → condition ─(false)→ 结束（零成本）
                          ↓ (true)
                     cost commit（第一笔不可逆状态变化）
                          ↓
                       selector → modifier → operation
```

## 2. 事务纪律（全部为契约条款）

1. **condition miss 不扣成本**——条件不满足时，任何成本都不得结算。
2. **cost commit 是第一笔不可逆变化**——效果结算前先落账成本；后续失败不回滚成本。
3. **consume_status 原子结算**——线性公式 `final_amount = base + stacks × per_stack`，消耗层数与加成同笔落账、不可拆分。
4. **delay 先付成本后登记**——拖延不免费；延迟效果在打出时已完成成本结算。
5. **selector 稳定语义**——`self / enemy_first / enemy_all`，语义不得随调用方漂移。
6. **effect 执行确定性**——同 state + 同 effect 必须得到同 result（确定性 RNG 之外的随机禁止进入 Executor）。
7. **禁止 resolver 散落特殊蛊 id 判断**——蛊的特殊性必须表达为数据（effect 字段/binding），不得在执行器里写 `if (id === '...')`。

## 3. V1 verb 集（现行实现全集）

| verb | 语义 | 实现落点 |
|---|---|---|
| strike | 造伤；同流派 support 加成、sword_intent 增幅、consume_status 叠层结算 | gu_rules.js applyPart |
| shield / grant_block | 护体（等价落账 block） | 同上 |
| heal | 治疗 | 同上 |
| heal_and_strike | 复合：heal + strike 一次落账 | 同上 |
| status | 施加状态层（marked 等） | 同上 |
| shift | 位置转换＝等量 block（2026-09-12 裁定） | 同上 |
| sword_intent | 剑意层数（strike 时结算） | 同上 |
| weaken_intent | 降低目标下一次 damage intent | 同上 |
| inspect | 侦察/看破标记 | 同上 |

杀招（kill moves）不走预制 effect 主结算：组件 battleEffect 按 recipe 顺序合成（L0 2026-09-22/2026-09-25 裁定），合成结果为战斗语义权威。

## 4. 新增 verb 的唯一路径

```text
Wiki / Canon rule（取证+证据链）
    ↓
Game Semantic binding（本层登记语义与边界）
    ↓
Effect verb（applyPart case + 本表登记 + Golden Case）
```

禁止反向：「肉鸽需要一个新技能 → 直接加 verb → 事后找 Lore 解释」。

## 5. No Silent Fallback（冻结不变量）

- 未知 verb → **fail-fast**（applyPart default 抛错，2026-09-25 起生效；此前静默 no-op 已清除）。
- Canon-driven 内容缺 binding、projection 缺 parent、生成丢字段 → 一律 fail-fast。
- 断言锚点：`tests/semantics.test.mjs`（Q2-⑤）、`tools/check_projection.mjs`。

## 6. Rank 边界

- Executor 内**禁止任何隐藏 rank 倍率**（无 `amount += rank-1`）——Executor 只执行已解析完成的 effect。
- amount 只来自：①Canon-driven explicit projection；②legacy 内容的 role default curve（经 `projections.json` 显式投影表）。
- Rank 只负责能力预算、使用门槛、真元质量、可承载复杂度、稀缺度/社会层级等上游约束（RUL-2026-09-19-008/011）。

## 7. 与 CombatCore 的关系

```text
CombatCore（回合/行动/敌我生命周期/Command 编排）
    ↓
Effect Semantic Executor（本契约，gu_rules.applyPart）
    ↓
State transition
```

不替换 CombatCore；Executor 只回答「一个合法 effect 对当前 battle state 做什么」。

## 8. 敌方杀招管线（P5-B1 敌人持蛊化，2026-09-26）

敌人攻击与玩家蛊虫走同一条 Effect Grammar——敌方 intent 不再是自由手填的裸数值：

```text
enemies.json（世界 Owner）
  enemy.attackSource = 'gu' | 'innate'
  enemy.guRefs            ── 装载（身份，含辅蛊）
  intent.guRefs           ── 杀招组件（strike 类蛊参与合成）
        ↓  构建期（build_data.mjs）
  Σ enemyAttackAmount[gu.rank]  ==  intent.damage   （fail-fast 校验）
        ↓  运行时（mvp_logic.enemyIntentDamage，CombatCore 同源）
  同一条压缩投影公式合成伤害 → resolveEnemyAction / previewEnemyDamage
```

- **attackSource=gu**（蛊修/异动）：伤害杀招必须声明 `guRefs`，伤害=装载主战蛊（effect.kind=strike）按 `PROJ-LAB-ENEMY-ATTACK-001`（压缩投影，parent=balance.effect_budget）求和；缺 guRefs、缺投影、合成漂移一律 fail-fast。
- **attackSource=innate**（兽/凡人/尸魔/凡兵符箓，intent 级可覆盖）：沿用 authored damage——这是显式声明，不是 fallback；原著依据=凶兽以天生手段攻击、蛊修亦可持凡兵。
- **压缩不变量**（check_projection + C6-2 常驻断言）：表值 ≤ lab attack 曲线（PROJ-LAB-ROLE-CURVE-001）且单调不减；敌方 DPR≈玩家 1/4 是遭遇窗口设计（check_balance H1），非第三规则源。
- **运行期一致性**：换皮测试「换皮-5」证明合成只吃 id 绑定 + kind + rank——改名不变、换组件即变、预制 damage 不驱动。
