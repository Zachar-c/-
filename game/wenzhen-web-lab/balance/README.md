# Balance 四层体系（2026-09-21 L0 架构纠正）

```text
canonical/   原著事实 + 道 Profile     ← 只记事实与语义，禁止战斗数值
rulings/     裁定层                   ← Fact → 游戏身份的解释与禁令
models/      能力空间与曲线           ← Rank/Quality/Effect/Enemy/Economy/…
projections/ 推导器                   ← 由模型生成数值
generated/   投影产物（禁止手改）      ← gu_stats / enemy_stats / shop / drops
simulation/  验证                     ← 战斗/经济/成长/autoplay
```

**Golden Dataset**：`../vertical/data/` 与 `../golden/` 中的手填 30 蛊 / 24 杀招 / 50 敌人
→ 身份为 **校准集**，用来验证 projection 是否推得出合理结果，**不是**真源。

**依赖规则**

1. 任何数值不得直接写在 `canonical/`。
2. `generated/` 只能由 `projections/` 写出；人改 generated 一律无效。
3. 每个 derived 字段必须能沿依赖图回溯到 Fact / Ruling / Model。
4. `origin: canonical | adaptation | experimental | derived` 标在定义处。
5. 改上游（Fact/Ruling/Model）→ 全量重生成 → 重跑 simulation；禁止只改某只蛊的伤害。

**价值向量**（禁止单一 value）：
`combat_direct, defense, control, information, mobility, resource, refinement, killer_move, economy`
