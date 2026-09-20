# Handoff · 舍利蛊转数修复（lab 侧）与 Godot 数据缺陷登记

```text
TASK sari-rank-fix
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE bugfix (lab-only) + data-defect report

GOAL
修掉「拿到二转舍利蛊却用不了」的实测 bug，并诚实显示突破材料的持有情况。
```

## 一、用户实测现象

玩家在 2 转时持有一只「青铜舍利蛊」，整备页「修炼 突破」面板要求「赤铁舍利蛊」，
按钮灰色不可用；而面板把需求写成 `赤铁舍利蛊 ×1`，读起来像背包条目，
玩家以为已持有却不能点。两件事都有问题：**一张嘴说错话，一只手不认货**。

## 二、原著依据（本次修复的事实来源）

`蛊真人-clean.txt:86506`（一句话列全系列，主依据）：

> 从一转到五转，分别有青铜、赤铁、白银、黄金、紫晶舍利蛊。

同一点另有两条复述：

- `:18066`「一转的是青铜舍利蛊，专门针对一转蛊师。二转的是赤铁舍利蛊，只对二转蛊师有效。三转的就是这白银舍利蛊了。」
- `:18068`「到了四转，还有黄金舍利蛊。」

结论：舍利系列的转数由**名字**唯一决定——青铜 1 / 赤铁 2 / 白银 3 / 黄金 4 / 紫晶 5。

## 三、Godot 数据缺陷（本次**未**修改，仅登记）

`game/data/names.json:266` 把 `gold_atk_2_12_gu` 命名为 **青铜舍利蛊**，而 `game/data/gu.json`
给它的 `rank` 是 **2**。按原著，青铜舍利蛊应是 **1 转**。当前 Godot 侧舍利系列的实际分布：

| 实体 id | rank 字段 | 名字 | 原著应为 |
|---|---:|---|---:|
| `gold_atk_1_21_gu` | 1 | 铜蛊 | —（不是舍利） |
| `gold_atk_2_11_gu` | 2 | 赤铁舍利蛊 | 2 ✓ |
| `gold_atk_2_12_gu` | 2 | **青铜舍利蛊** | **1 ✗** |
| `gold_atk_3_13_gu` | 3 | 白银舍利蛊 | 3 ✓ |
| `gold_atk_4_14_gu` | 4 | 黄金舍利蛊 | 4 ✓ |
| `gold_atk_5_15_gu` | 5 | 紫晶舍利蛊 | 5 ✓ |

即：**青铜这个名字被挂在了一个 2 转实体上，且该实体同时是金色进阶链的第 2 级产物**。

**为什么 Godot 侧没动**：`game/data/refinement_recipes.json:5194` 的
`promote_gold_atk_1_21_to_gold_atk_2_12` 与 `:5216` 的 `promote_gold_atk_2_12_to_gold_atk_3_13`
构成 1→5 的严格阶梯，`game/tests/unit/test_promotion_1b1a.gd:88` 断言
`int(gu_by_id[output_gu]["rank"]) == int(gu_by_id[input_gu]["rank"]) + 1`
（`:91` 另断言 `input_min_rank == i + 1`）。把 `gold_atk_2_12_gu` 的 rank 改成 1 会直接打断这条链与该测试。
**这属于数据语义缺陷，须走 L1/L0 裁决后另行处理，不在本次 lab bugfix 范围内。**

## 四、lab 侧改法

**按名字定转数，不读 `rank` 字段**——`tools/build_data.mjs` 新增显式映射 `SARI_BY_RANK`：

```js
1: 'gold_atk_2_12_gu'   // 青铜
2: 'gold_atk_2_11_gu'   // 赤铁
3: 'gold_atk_3_13_gu'   // 白银
4: 'gold_atk_4_14_gu'   // 黄金
5: 'gold_atk_5_15_gu'   // 紫晶
```

同时改了两处：

1. **舍利货架的 `tier` 取原著转数**（青铜 = tier 1）。此前 tier 取实体 `rank`，
   青铜被算成 tier 2，导致**一转区域买不到一转舍利蛊，一转小突破永远无舍利可用**
   （`shop_rules` 按 `offer.tier <= 该层 shop_max_tier` 上架）。
2. **整备页区分「需求」与「持有」**（`js/journey.js` 的 `renderPrep`）。此前把需求蛊直接渲染成
   `名字 ×1`，读起来就是背包条目；现在改为独立一行「需要 1 只 X · 你持有 N」，
   且当持有其他阶舍利时显式摊开说明「舍利不可越阶替代；你还持有 …（N 转）」。
   按钮文案也改显示真实需求名。

## 五、验证

```text
data:  node tools/build_data.mjs
       -> gu 77 | recipes 6 | killMoves 5 | enemies 14 | nodes 37 | route 12 | shopOffers 34
       -> sariByRank {"1":"gold_atk_2_12_gu","2":"gold_atk_2_11_gu","3":"gold_atk_3_13_gu",
                      "4":"gold_atk_4_14_gu","5":"gold_atk_5_15_gu"}
       -> 货架 tier：青铜 1 / 赤铁 2 / 白银 3 / 黄金 4 / 紫晶 5
tests: node --test tests/*.test.mjs -> PASS 55/55
browser (drive.mjs，三次运行 console 均 0 error):
  1. 1 转 / 0 舍利：「需要 1 只 青铜舍利蛊 · 你持有 0」，按钮 disabled
  2. 1 转 / 持青铜：按钮可用，「你持有 1」，点击后日志「小突破 · 1 转中阶」，
     事件 reason=small_breakthrough_sari, targets=["gold_atk_2_12_gu"]
  3. 用户原场景（2 转 / 持青铜 / 7 元石）：
     「消耗 赤铁舍利蛊 / 需要 1 只 赤铁舍利蛊 · 你持有 0 /
       舍利不可越阶替代；你还持有 青铜舍利蛊 ×1（1 转）」，按钮 disabled
     —— 行为正确（青铜不能顶 2 转），且界面终于把原因说清楚了
```

## 六、风险与后续

1. **Godot 数据缺陷未修**（见第三节）。修它需要先定：金色进阶链与舍利系列是同一套蛊还是两套？
   现在被一个名字强行捏在一起。此事已列入待裁决，**不由 lab 自行处理**。
2. `gold_atk_2_16_gu`（名为「舍利蛊」，rank 2）仍留在支持蛊白名单里但不在 `SARI_BY_RANK`
   任一转数上，因此既不会上架也不会被突破消耗。属于同名兜底实体，来源未澄清。
3. 本修复是**按需硬编码**：若 Godot 侧将来厘清并修正了舍利转数，`SARI_BY_RANK` 应改为读取数据字段。
