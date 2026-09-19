# RESEARCH REQUEST · P3 Effect 管线：预算分配公式

```text
CURRENT PHASE: P1（转数语义）/ P2（Rank Power Budget）/ P2.1（runtime HP 接线）已交付。
P3（统一 Effect 管线）已启动，但卡在**数值分配公式**上——本件请求该公式。
TYPE: 设计裁决请求（不是事实核对）
FROM: L2 Orchestrator
TO: L1 Research
BLOCKING: P3 的全部实现批次。Worker 与 L2 均无权自定这些数值。
```

---

## 1. 为什么必须问你

你的 RUL-2026-09-19-008 **D6** 已冻结管线形状：

```
Rank → Effect Budget → Effect Archetype → Gu-specific Modifier → Final Effect
```

**D7** 已冻结判据：不要求高转 raw damage 一律更高；要求「同角色定位、同类型、同代价结构的能力预算随转数上升」，
并列出预算可花的 11 个维度（伤害/范围/目标数/距离/控制/持续时间/穿透/可靠性/资源效率/复合效果/特殊规则）。

**D2** 已冻结预算曲线：`Rank Power Budget ≈ 每转 ×2`，1→5 转 = **40 / 80 / 160 / 320 / 640**（已由 P2 落地为唯一真源）。

**但**：预算曲线（40…640）与蛊效果的实际量纲（`amount` 是 1…8 这种小整数）之间，**没有任何已裁定的换算关系**；
每个原型把预算切给哪些维度、切多少，也没有裁定。
我不能让 Worker 自己编这套系数——那正是你明令禁止的「作者随手写 damage=3」，只是换成 Worker 随手写。

---

## 2. 现状实测：这不是「两套世界」，是「一套退化世界」

数值全部来自 `game/data/gu.json`（802 只）与 `game/data/v1_battle.json`。

**802 只蛊的分工**：

| 类别 | 数量 | 效果从哪来 |
| --- | --- | --- |
| 显式声明 `v1_effect` | **61** | 作者手写字面量 |
| 无声明 → role 兜底 | **741** | `v1_battle.json.default_effect_by_role` 六条 |

**兜底表（741 只的实际曲线）**——公式为 `amount = 基准 + (转数 - 1)`，即**线性 +1/转**：

| role | kind | 是否随转放大 | r1→r5 | r5/r1 |
| --- | --- | --- | --- | --- |
| attack | strike | 是 | 2 / 3 / 4 / 5 / 6 | **3.0×** |
| defense | shield | 是 | 3 / 4 / 5 / 6 / 7 | **2.3×** |
| healing | heal | 是 | 2 / 3 / 4 / 5 / 6 | **3.0×** |
| logistics | heal | 是 | 1 / 2 / 3 / 4 / 5 | 5.0× |
| movement | shift | **否** | 1 / 1 / 1 / 1 / 1 | **1.0×** |
| recon | status(marked) | **否** | 1 / 1 / 1 / 1 / 1 | **1.0×** |

对照你冻结的预算曲线：**r5/r1 = 16.0×**。
→ 741 只蛊（占 92%）的五转能力，实际只做到一转的 **2.3–5 倍**，而预算说 16 倍。

**11 个维度的实际使用情况**：D7 允许预算花在 11 个维度上，
但现行兜底**只用了 1 个**（`amount`）。范围/目标数/控制/持续/穿透/资源效率等维度没有任何表达。

## 3. 61 只手写效果：既稀疏，又倒挂

按 role × kind 分布：

| role | 总蛊数 | 有手写效果的转数 | 备注 |
| --- | --- | --- | --- |
| attack | 379 | 1,2,3,4,5 | 28 只，唯一覆盖全转的 role |
| defense | 100 | **仅 1,3** | 7 只；四只 r3 shield **amount 全是 5** |
| movement | 92 | **仅 1,3** | 6 只；**amount 全是 1**（切给 `shift`，量纲不随转放大） |
| healing | 80 | **仅 1,4** | 11 只（含 logistics 的 5 只） |
| recon | 78 | **仅 1,5** | 5 只 sword_intent：r1 = 1，**r5 = 2** |
| logistics | 73 | **仅 1** | 5 只 |

**三转「空洞」确认**：三转共 180 只蛊，只有 10 只手写，其中 `strike` **只有 1 只**
（`water_atk_3_05_gu`，amount = **2**）。

**按你 D7 口径的首轮倒挂扫描（同 kind 比 amount 上限）**：

```
strike: r1 上限 4 → r2 上限 4 → r3 上限 2 → r4 上限 5 → r5 上限 8
                                  ^^^^^^^^^^
                        三转纯攻击蛊的上限低于一转与二转
```

- `water_atk_3_05_gu`（三转 / attack / strike / amount **2**）对照一转手写 strike 上限 4、二转上限 4。
- 若它与一二转那几只**同定位同代价结构**，这就是你 D7 定义的**真倒挂**（不是「三转侦查蛊伤害 2」那种合法情形）。
  代价结构能否判定为「同」，需要按 `essence_cost / true_qi_cost / value` 分组复核——这笔复核我尚未做，不敢替你定。

## 4. 量纲缺口（这是最需要你拍的一点）

现行三套数字各说各话，互相没有换算关系：

```
Rank Power Budget（你冻结）      r1 = 40     … r5 = 640        （+16×）
兜底 strike amount（在跑）        r1 = 2      … r5 = 6          （+3×）
徒手基准（balance.json）          100 × unarmed_damage_ratio(0.2) = 20
常见敌人气血（enemies.json）      common rank1 = 4
```

即：预算 40 与 amount 2 之间差 **20 倍**；`amount` 2 正好是常见敌人 4 点气血的一半。
**「预算 40」到底等于几点 `amount`？** 这个换算不做出来，P3 的任何一个批次都无法落地。

## 5. 请你给出

1. **Effect Archetype 清单**——直接对齐现有 6 个 role（attack 379 / defense 100 / movement 92 / healing 80 / recon 78 / logistics 73）与现有 8 个 kind（strike / heal / shield / shift / status / sword_intent / weaken_intent / heal_and_strike）即可，
   还是要重划？若重划，请给出「旧→新」映射口径。
2. **每个 archetpye 的预算分配公式**：预算花在 D7 的哪些维度上、各占多少。至少覆盖 6 个 role。
3. **量纲换算**：`Rank Power Budget(rank)` → 该原型主维度数值（如 strike 的 `amount`）的换算关系与取整规则。
4. **不随转放大的维度怎么办**：`shift`（位移）与 `status`（层数）现在完全不随转成长，
   导致 movement / recon 两条 role 的五转蛊与一转蛊等价。这是否符合你的意图？
   若否，它们的成长应该体现在哪个维度（距离？目标数？持续时间？）。
5. **倒挂的落地判定口径**：把 D7 的「同定位同代价结构」翻译成**可执行的脚本判据**
   （我准备把它写成断言，见 `CONSTRAINTS-V2` R5「写不进脚本的规则不许存在」）。
   例如：按 `(role, kind)` 分组、以 `value`/`essence_cost` 分档，然后要求「高转档位的能力预算不低于低转档位」。
   具体分档口径请你定，我不自行发明。

## 6. 约束

- **我不会让 Worker 自定上述任何数字**。本件未回复前，P3 只做不依赖数值的准备工作（普查器、残余数据清理、P2.1 的三个小 follow-up）。
- 你不需要迁就现有 `amount` 量级——若你认为该整体重标定（例如乘 20 倍），请直接说，我按新口径改；
  现有 802 只的数值本来就是未论证的字面量。
- D7 里「一转纯攻击蛊伤害 4、三转侦查/控制蛊伤害 2 不叫倒挂」这条我完全接受，
  我担心的只有同一 `(role, kind)` 内三转不如一转的情形。
