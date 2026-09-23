# RESEARCH REQUEST · Phase 8 · Rank ×3 真元曲线是否越界承载轴

```yaml
TO: L1（ChatGPT Research）
FROM: L2
DATE: 2026-09-23
STATUS: PENDING_L1
BLOCKS: 构筑分叉 Phase 8 批B（docs/superpowers/plans/2026-09-25-build-fork-rebuild.md 归属表「Rank ×3 真元吞掉成长 → Phase 8」）
CONTEXT: 批A 结构验收已绿（tests/phase8_gate8.test.mjs 11/11；全量 227/227），本件只裁数值与边界，不含实现。
```

## CURRENT PHASE

构筑分叉验证 · Phase 8「Rank 从主成长降回承载轴」。Gate 8 结构批（同 Rank 分叉 / 升阶不换身份 / 伤害无 Rank 倍率 / 承载轴正向锁 / 突破只动承载面）已全部通过；数值批挂起等待本裁决。

## QUESTION

1. **判定**：`cultivation_factor = 1/3/9/27/81` 使真元上限每转 ×3、战斗回气（上限 × regenPct/回合）同步放大——在 L0 Gate 8 口径下，这是否已让 Rank 从「承载轴」越界为「资源循环自动突变」（L0 Build Mutation 定义第 3 条「资源循环发生变化」）？是 / 否 / 有条件。
2. **若越界**：给出 1–5 转的目标曲线（显式数值表），并裁定：
   - 回气继续按「上限百分比」还是改为固定值/混合；
   - 与仓内另一条 `stage_base_battle = 10/30/60/100/150`（`game/data/v1_battle.json`）的归一关系——两条真元曲线谁是战斗权威；
   - lab（web）与 Godot 是否同批改（RUL-2026-09-19-010：Godot = Canonical）。
3. **可复用边界规则**：给出「Rank 承载面 vs 构筑身份面」的判定式，供 Phase 9–11 复用（避免每阶段重开哲学讨论）。
4. **归属冲突裁定**：`game/data/balance.json` `rank_axis_annotations.cultivation_factor` 注记写「P4 处理，本阶段只标注不改值」，而总计划归属表把该问题指给 Phase 8——谁有权改值、在哪个阶段改？

## WHY CODEX CANNOT DECIDE

- V3：数值判定与架构判定一律上抛 L1；曲线新值、回气口径、双曲线归一均属此类。
- L0 裁决 §五只说 Rank 承载「真元质量/规模」，未给量级上限；Gate 8 说升阶不得自动换构筑，未定义「资源循环变多少算换」——两者的边界是模型问题，不是仓库事实问题。
- 仓内已有互相冲突的两份归属（P4 注记 vs Phase 8 归属表），L2 不得替 L0/L1 挑一个。

## KNOWN FACTS（全部内嵌，无需读仓）

**应用点（代码，非键名概括）**

- 公式：`essenceMax(rank, aptitude, data) = essence_base × aptitudeFactor[aptitude] × cultivationFactor[rank]`（`game/wenzhen-web-lab/js/run_rules.js:97-103`）。
- 调用点：开局 `js/main.js:192`（fresh）、突破/资质后 `js/main.js:380`（recomputeQiMax）；战斗回气 `js/main.js:644`：`state.qi + ceil(qiMax × regenPct[aptitude] / 100)`。
- 伤害路径不消费 Rank：`killMoveEffectPlan / resolveProblemHit / actionValues / resolveDirectStrike / resolveEnemyAction` 均无 playerRank（Gate 8c 源+行为双锁，11 测试绿）。
- 突破返回仅 {ok, kind, reason, targetStageIndex/TargetRank, targetLabel, stoneCost, sariId, canStone, canSari, missing, requiredApt, aptitudeOk, stoneOk}，不触 owned/equipped（Gate 8e 绿）。

**实测数值（本机 node 复算，2026-09-23）**

- 常量：`essence_base=10`；`aptitude_factor` 丁1/丙2/乙3/甲4；`cultivation_factor` 1/3/9/27/81；`regenPct` 丁18/丙25/乙30/甲35（`js/data.js` ← `game/data/aptitude.json`）。
- 丙等上限：**20 / 60 / 180 / 540 / 1620**（转 1→5）。
- 丙等每回合回气：**5 / 15 / 45 / 135 / 405**。
- 消耗端：live 杀招 `true_qi_cost` = 2–3（km_light_bulwark 2，其余 3）；开局蛊 `trueQiCost` 0–2；炼化 `attuneCost = 4+2×(rank-1)`。
- 约束强度：转1 一发杀招 ≈ 60% 一回合回气；转3 一发杀招 ≈ **6.7%** 一回合回气——转3 起真元不再是行动选择的约束。

**权威文本**

- L0 §五（批准）：Rank 承载「力量承载、使用门槛」，列出含「真元质量/规模」；明确 Rank 不作为构筑身份、不得退化为万能数值倍率（`docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md`）。
- L0 Build Mutation 定义（同件 §一）：**「资源循环发生变化」计为构筑变化**；「伤害 4→6 / HP+10 / Rank+1 / 稀有度」不算。
- Gate 8（总计划）：「Rank 提升后若不改蛊/杀招，不能自动变成完全不同的 Build」。
- 归属表：「Rank ×3 真元吞掉成长 → Phase 8」。
- `balance.json` 注记：`cultivation_factor` 「relocated → essence_budget 轴，**P4 处理，本阶段只标注不改值**，上游 aptitude.json」；`stage_base_battle` 同型注记（上游 v1_battle.json）。
- HOLD-1（战后真元回满）**NOT APPROVED**——本问题不得用「改战后回满」当解法。

## CONFLICTS

1. **L0 内部张力**：§五允许 Rank 承载真元规模 ↔ §一 + Gate 8 把「资源循环跳变」算作/接近构筑自动突变。缺边界定义。
2. **归属冲突**：归属表指 Phase 8 ↔ balance.json 注记指 P4 且禁改值。
3. **双曲线**：aptitude 转数曲线（1/3/9/27/81）与 stage_base_battle（10/30/60/100/150）并存；lab 战斗真元实际走 aptitude 曲线（main.js 调用点如上），stage_base_battle 在 lab 链未作为战斗上限应用点出现——哪条是权威需裁定。
4. **与 HOLD-1 耦合风险**：若压平转数曲线，战后回满的「免费大池」效应会变化，但 HOLD-1 冻结中，任何方案不得依赖改 HOLD-1。

## CONSTRAINTS

- 不得改 HOLD-1 / HOLD-2；不得扩容 vertical 动词；不得新建第二套战斗核。
- 批A 零数值漂移已落地，不得回退。
- 若判「越界」，新曲线必须给出 **1–5 转完整数值表**（L2 不允许自行插值）。
- Godot = Canonical（RUL-010）：方案须说明 web/lab 与 Godot 的落地顺序或同批关系。
- 证据纪律：`game/wenzhen-web-lab/docs/BALANCE_EVIDENCE_DISCIPLINE.md`——复写引擎模拟不得作为依据（本件未使用）。

## DESIRED OUTPUT

1. 三态判定：**越界 / 不越界 / 有条件越界**（有条件则写出触发条件）。
2. 若需改值：1–5 转 `cultivation_factor` 显式表 + 回气口径 + 双曲线归一说明 + 是否同改 Godot。
3. 一行式边界规则（例：「Rank 只允许改变 X 类字段；凡改变行动成本/回气斜率/Y 类者视为构筑面」——由 L1 定稿）。
4. 归属裁定：P4 注记 vs Phase 8 归属表，谁在何时改 `game/data/aptitude.json`。
5. 若判定「暂不越界」：给出 Phase 8 批B 的替代验收口径（Gate 8 结构绿即可关闭 Phase 8？还是追加何种植入探针）。
