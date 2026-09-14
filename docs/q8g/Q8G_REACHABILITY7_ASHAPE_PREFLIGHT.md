# Q8-G Reachability-7 / A-Shape Design Preflight（实验记录）

> **范围**：inbox §18 允许的 `Reachability-7 / A-Shape Design Preflight`。
> **性质**：**measurement-only**。只读 R5 审计日志 + `data/*.json`，**不写入游戏**，不修改
> `scripts/domain/**`、`data/**`、`scripts/presentation/**`、`tests/**`、`RunState`、
> 正式 pity / E6 / pacing / battle 规则。
> **工具**：`tools/q8g_reachability7_ashape_preflight.mjs`（本次新增，纯读）
> **重跑**：`node tools/q8g_reachability7_ashape_preflight.mjs`
> **本文件不构成产品裁定。** A 仍为 `CONDITIONAL`。

---

## 0. 执行摘要

| # | 结论 | 强度 |
|---|---|---|
| 1 | **L4/L5 是"份额悬崖"而非"覆盖缺口"** —— 五层**全部**已有非零 Common 通道，但 L4=15.4%、L5=12.5%，而 L1–L3=37.9–51.6% | 强（直接统计） |
| 2 | **`A1 L5-only coverage` 在机制上不是独立变量** —— L5 已有 12.5% 通道，所谓"恢复覆盖"只能是**提高 L5 份额**，即与 `A2` **同机制、仅范围不同** | 强（定义 + 数据） |
| 3 | **3 个 f1=0 局各有且仅有 1 个 Common 胜场**；而 pity 需 `≥4` 个 Common 才能触发一次 ⇒ **pity 单独在数学上无法修复任何一局** | 强（机制推导 + 逐局计数） |
| 4 | **四个候选形状全部零固定产量增加** —— 材料件数**恒为 214**，逐形状 delta 全为 `+0.00` | 强（不变量） |
| 5 | **A2 是唯一高副作用选项**：elite 暴露 −54.3%（0.60）/ −71.6%（0.75）；A1 温和（−8.6% ~ −12.3%）；A3b / A4 / A3a-K=1 **完全不变量** | 强（逐形状计数） |
| 6 | **没有任何单变量能把短局遗留降到 0**（最低 A2@0.75 = 0.22/局）⇒ 单变量包不足，但 **A5 未获批准，本次不运行** | 中（16 局样本） |
| 7 | **f1=0 修复率对 natural f1 率假设高度敏感**：pooled 0.556 → 1.55/3；per-run 观测率 → **0/3**（因失败局自身观测率=0，存在选择效应） | 强（敏感性对照） |

> ⚠️ **与 inbox §18 的一处数字差异（需记录）**：§18 记 `actual：2/3 f1_zero 局修复`。
> 本次以 64 个种子复现流重算，"actual coverage" 基线均值为 **1.55/3**（R6 的 2/3 是**单次抽样点估计**）。
> 这是 R6 自己声明的「单一路径 / 点估计」限制的直接体现，**不是矛盾**，而是本次方法升级的动机。

---

## 1. 方法升级（相对 R6）

| 维度 | R6 | R7（本次） |
|---|---|---|
| 抽样 | 单次 RNG 路径，点估计 | **64 个种子复现流**，报 `均值 [min..max]`（`--replicates=N` 可调） |
| 基线语义 | 只有 "actual" 一档 | 拆成 **OBSERVED（事实，0/3）** 与 **MODEL ACTUAL（对照，1.55/3）** |
| 副作用核算 | 未量化 | 从 `data/loot_tables.json` / `data/pacing.json` **读取真实字段**逐形状核算材料件数 / gu 期望 / elite 暴露 |
| 层级诊断 | 无 | **逐层 Common 份额**表（本报告最关键的定位工具） |
| 时序漂移 | 无 | **逐局 Common 计数矩阵**（对 f1=0 局） |
| 单变量纪律 | A1–A4 单变量 | 同；另拆 `A3a`（计数下限）/ `A3b`（前置窗口）为**两种读法**，且**不合并** |

### 1.1 副作用核算依据（全部取自数据，非硬编码猜测）

| tier | `material_count` | `gu_chance_pct` | `cost_pool` |
|---|---|---|---|
| common | 1 | 6 | 无 |
| elite | 1 | 30 | **有**（`gu_erosion` 诅咒 ×1 层 **或** notoriety +2） |
| boss | 2 | 0 | — |

pity 目标带段：`common=[crude]`、`elite=[plain,refined]`、`boss=[prized]`；`threshold=3`。

> **关键推论**：`common` 与 `elite` 的 `material_count` **都是 1** ⇒ `elite→common` 转换**件数中性**；
> 真正改变的是**品质带段**（crude ← plain/refined）、**gu 掉落率**（6% ← 30%）与**精英成本暴露**。
> 因此"不得增加固定产量"这一红线，四个形状**全部天然满足**（见 §5）。

---

## 2. 语料与基线复现

```text
16 局（batch1 8 + batch2 8）
f1_zero = 3
short (<15 战斗) = 6
natural timing（Common 早于首次 refinement 的局）= 4/16
pooled observed 自然 f1 率（common 胜场中）= 25/45 = 0.556
```

R6 基线**完整复现**（`actual coverage` 2/3 单次抽样、`+L5` 3/3、`+L4` 1/3、`share=0.60` 3/3 等）。

---

## 3. 🔴 定位发现一：L4/L5 是"份额悬崖"，不是"覆盖缺口"

```text
逐层 Common 覆盖（settled non-boss）
  L1: settled= 24  common=12  rate=50.0%
  L2: settled= 31  common=16  rate=51.6%
  L3: settled= 29  common=11  rate=37.9%
  L4: settled= 26  common= 4  rate=15.4%   ← 悬崖起点
  L5: settled= 16  common= 2  rate=12.5%   ← 最低
```

**结论**：`layerHasCommon` 显示 `[1,2,3,4,5]` —— **五层全部已有非零 Common 通道**。
所谓 "L4/L5 Common 候选覆盖" 问题，本质是**份额被压低到 L1–L3 的 1/3 ~ 1/4**，
**不是**"某一层完全没有 Common 通道"。

> 这直接推翻了一种常见误读：不存在"把 L5 打开/关闭"这个开关。
> (`force/11` 的 `common_layers=[4,5]` 早已在 R6 短局分析中露过面。)

### 3.1 由此产生的 A1 定性修正

inbox §18 把 `A1` 命名为 "L5-only coverage"。**在本语料上这个命名无法按字面实现**：

```text
若 L5 已是非零通道 ⇒ "恢复 L5 覆盖" 只能是提高 L5 的份额
                 ⇒ A1 的机制 = 幅度（magnitude）
                 ⇒ 与 A2 机制相同，差别仅在 SCOPE（仅 L5 vs 全层）
```

因此 **A1 与 A2 不是两个独立机制**。真正与"幅度轴"正交的只有：

```text
A3（population guard：只改"哪些局"被照顾）
A4（order：只改"顺序"）
```

本次仍按 inbox 要求单变量运行 A1，但**新增 `A1 @own 0.13`**（把 L5 恢复到它自己的观测份额）
作为"覆盖式"读法的忠实实现，用于与 `A1 @0.60/0.75`（幅度式读法）对照。

---

## 4. 🔴 定位发现二：pity 在数学上无法修复任何一个 f1=0 局

### 4.1 机制推导

pity 计数**只在 Common 胜场推进**，`counter >= 3` 时强制交付一次并清零：

```text
common#1 → counter=1
common#2 → counter=2
common#3 → counter=3
common#4 → counter>=3 ⇒ 交付 1 次，counter=0
```

⇒ **无自然命中时，pity 每 4 个 Common 胜场才交付 1 次** ⇒ **修复阈值 = 4 个 Common 胜场**。

### 4.2 逐局核对

```text
Pity feasibility on the f1=0 runs (pity alone fires on common #4, #8, ...):
  force/20260927 battles=19 common_victories=1  short=no   pity_alone_can_repair=NO  (needs >= 4)
  sword/11       battles= 9 common_victories=1  short=yes  pity_alone_can_repair=NO  (needs >= 4)
  sword/33       battles= 8 common_victories=1  short=yes  pity_alone_can_repair=NO  (needs >= 4)
```

**三个失败局各有且仅有 1 个 Common 胜场** ⇒ **pity 全部无法触发**。

> 这解释了 R6 的重要现象：「`+L5` 已修复 3/3」**并不是 pity 起作用**，
> 而是把 Common 数量推高到让**自然命中**（或以 A2@0.75 让计数跨过 4）发生。
> **pity 从来不是这个问题的解**——它要求的前置条件（≥4 Common）正是失败局缺的东西。

### 4.3 逐局 Common 计数矩阵（决策相关）

```text
run            actual A1@ref 0.36 A1@own 0.13  A1@0.60  A1@0.75  A2@0.60  A2@0.75  A3a K=1  A3a K=2   A3b   A4
force/20260927       1           1           1         2        2        3       5*        1        1      1     1
sword/11             1           2           1         2        2        2       4*        1        2      1     1
sword/33             1           2           1         2        2        2        2        1        2      1     1
  (* = at/above the pity-only repair threshold of 4)
```

**读法**：

- `A1`（含 0.60/0.75）**从未把任何一局推过 4** ⇒ 即便份额拉到 75%，单靠 L5 也不够。
- 只有 **`A2@0.75` 让 `force/20260927`(5) 与 `sword/11`(4) 跨过阈值** —— 但 `sword/33` 仍只有 2。
- `A3b` / `A4` **完全不改变任何一局的 Common 计数**（纯顺序/换位）⇒ 结构上不可能跨阈值。

---

## 5. A1–A4 结果（64 复现流，`均值 [min..max]`）

```text
variant                     f1zero_fix        inWindow       shortZero           deliv       matPieces           guExp           elite          common
------------------------------------------------------------------------------------------------------------------------------------------------------
OBSERVED(事实)                    0/3          12/16               2            25          214.00           27.00           81.00           45.00
ACTUAL (对照)                1.55/3        10.89/16            0.94  22.94 [14..29]          214.00           27.00           81.00           45.00
A1 L5 cov @ref 0.36          2.05/3        11.70/16            0.45  29.19 [22..32]          214.00           25.32           74.00           52.00
A1 L5 cov @own 0.13          1.84/3        11.48/16            0.66  27.05 [21..32]          214.00           26.76           80.00           46.00
A1 L5 cov @0.60              2.28/3        11.80/16            0.61  31.55 [27..39]          214.00           24.60           71.00           55.00
A1 L5 cov @0.75              2.28/3        11.78/16            0.42  31.81 [25..39]          214.00           24.60           71.00           55.00
A2 share floor 0.60          2.50/3        14.56/16            0.23  50.23 [46..59]          214.00           16.44           37.00           89.00
A2 share floor 0.75          2.78/3        14.58/16            0.22  58.67 [53..68]          214.00           13.08           23.00          103.00
A3a short floor K=1          1.48/3        11.11/16            0.97  26.02 [22..30]          214.00           27.00           81.00           45.00
A3a short floor K=2          2.06/3        12.05/16            0.41  27.16 [24..32]          214.00           26.28           78.00           48.00
A3b short front-window       1.86/3        12.14/16            0.59  24.77 [22..32]          214.00           27.00           81.00           45.00
A4 timing-only (all)         1.92/3        12.20/16            0.86  23.22 [18..30]          214.00           27.00           81.00           45.00
```

### 5.1 强制报告项逐条交付（inbox §18 清单）

| 报告项 | 结果 |
|---|---|
| **f1=0 修复率** | 见上表 `f1zero_fix`；OBSERVED 恒为 **0/3**（事实），MODEL 对照 1.55/3 |
| **首次交付是否在 refinement 窗口内** | 见 `inWindow`；最佳为 A2@0.75 = **14.58/16**，最低副作用组（A3b/A4）为 **12.14 ~ 12.20/16** |
| **短局遗留数** | 见 `shortZero`；**无任何单变量达 0**，最低 A2@0.75 = **0.22** |
| **总材料件数变化** | **全部为 214.00，delta = +0.00**（见 §5.2 不变量证明） |
| **元石 / Elite cost 潜在影响标记** | 见 §5.3 |

### 5.2 材料件数不变量（"不得增加固定产量"红线的机械证明）

```text
所有形状 matPieces = 214.00，逐形状 delta = +0.00
```

原因：`common.material_count = elite.material_count = 1`，且所有形状**只做 elite↔common 互换**
（settled 局总数守恒：`81+45 = 37+89 = 23+103 = 126`，boss 段不受影响）。
⇒ **四个候选形状均未增加固定产量**，红线天然满足。
**变化的是构成（品质带段 / gu 概率），不是数量。**

### 5.3 元石 / Elite-cost 暴露标记

```text
elite 基线 = 81
  A1 @own 0.13   → 80   EXPOSURE DROPS  −1.00 (−1.2%)
  A1 @ref  0.36  → 74   EXPOSURE DROPS  −7.00 (−8.6%)
  A1 @0.60       → 71   EXPOSURE DROPS −10.00 (−12.3%)
  A1 @0.75       → 71   EXPOSURE DROPS −10.00 (−12.3%)
  A2 @0.60       → 37   EXPOSURE DROPS −44.00 (−54.3%)   ← 高副作用
  A2 @0.75       → 23   EXPOSURE DROPS −58.00 (−71.6%)   ← 高副作用
  A3a K=1        → 81   NO COST IMPACT（不变量）
  A3a K=2        → 78   EXPOSURE DROPS  −3.00 (−3.7%)
  A3b            → 81   NO COST IMPACT（不变量，已证多集守恒）
  A4             → 81   NO COST IMPACT（不变量，纯排列）
```

**含义**：elite 每场携带 `cost_pool`（`gu_erosion` 诅咒一层 **或** notoriety +2）。
elite 暴露下降 = **成本暴露下降**，但同时 **gu 期望从 27.00 降到 13.08–16.44**、**材料品质带段下移**。
⇒ **A2 的高疗效是用"精英玩法密度"换来的**，这是本次最重要的副作用结论。

---

## 6. 敏感性对照（方法学要点）

### 6.1 natural f1 率的选择会翻转结论

| natural 率模型 | `ACTUAL` f1zero_fix | `A1@0.75` | `A2@0.75` |
|---|---|---|---|
| pooled 常数 0.556（默认，R6 口径） | 1.55/3 | 2.28/3 | 2.78/3 |
| per-run 观测率（`--natural=observed`） | **0/3** | **0/3** | 2/3 |

**原因（重要）**：per-run 观测率对**恰好失败的那 3 局等于 0**（它们 1 个 Common、0 次命中）。
用一局自身的 0 命中率去预测它未来的自然命中，是**小样本循环 + 选择效应**。
⇒ `--natural=observed` 是**有偏对照**，默认 pooled 模型更可信。

**但它揭示了一个有价值的机制事实**：在"自然命中率≈0"的悲观视角下，**只有 pity 能救**，
而 pity 需要 **≥4 Common** —— 与 §4 的推导完全一致。
两个模型从不同方向指向同一个约束：**Common 机会数量，而非份额措辞**。

### 6.2 复现性

```text
--replicates=64  与  --replicates=256  的方向排序一致
A2@0.75 三次连跑逐字节相同（完全确定性）
```

样本从 64 → 256 时，`ACTUAL` 1.55 → 1.61/3，`A2@0.60` 2.50 → 2.35/3：
说明**均值本身仍有 ±0.15/3 量级的抽样噪声**，不宜按小数位做排序。

---

## 7. 置信度限制（必须随结论一起引用）

```text
16 局样本
单一 RNG 路径（R5 审计日志）
报告层模型（非引擎内实测）
point estimate → 已升级为 64/256 复现流的均值区间，但均值仍有 ±0.15/3 噪声
```

⇒ 结果**可用于方向排序与副作用排序**，**不足以证明最终平衡数值或生产规则**。

---

## 8. 对 A5（combined）的隐含结论（**未运行**）

- 四个单变量**都无法把 `shortZero` 压到 0**（最低 0.22）。
- `A3b` / `A4` 被证明**在结构上不可能**跨过 pity 阈值（不改 Common 计数）。
- `A1`（L5 单层）**从未把任何一局推过 4**，即便份额 75%。
- 唯一能跨阈值的是 `A2@0.75`，但代价是 elite 暴露 −71.6%。

⇒ 从机制上看，**"把失败局推到 ≥4 Common"需要跨层份额 + 短局前置的组合**，
这正是 `A5` 的形态。**但 inbox §18 明确要求 A5 需 A1–A4 完成并另行批准**，
故本次**不运行 A5**，仅登记该缺口。

---

## 9. 未获批准事项（维持冻结）

- ❌ 修改 `data/enemies.json` 的 tier / `data/pacing.json` 的 rank 区间或 weights
- ❌ 修改 E6 正式抽取语义、正式 pity、战斗元石、Elite cost、promotion 规则
- ❌ 把 `0.60` / `0.75` 写成正式平衡数值
- ❌ 直接增删 refinement 节点或调整地图拓扑
- ❌ 运行 `A5 combined`
- ❌ 任何 `scripts/domain/**`、`data/**`、`scripts/presentation/**`、`tests/**` 改动

---

## 10. 交付物

| 文件 | 性质 |
|---|---|
| `tools/q8g_reachability7_ashape_preflight.mjs` | **新增**，纯读，measurement-only |
| `docs/q8g/Q8G_REACHABILITY7_ASHAPE_PREFLIGHT.md` | 本文件 |
| R6 工具 / 日志 | **未改动**，继续作为实验工具保留 |

冻结区状态：`scripts/domain`、`data`、`scripts/presentation`、`tests` 在工作树中**存在既有未提交改动**，
经核对为 **ZCode 的 R5/R6 审计仪器**（含 `AUDIT`/`R-5`/`tier_audit`/`material_pity` 等 24 处标记），
**非本次产物，亦未被本次触碰**。

---

**记录时间**：2026-09-13
**裁定状态**：**A 仍为 CONDITIONAL；B / C / D 维持不批准；生产规则冻结**
