# AGENT1 / Q8G Post-Fix Baseline and G1 Reassessment

> **角色**：执行 worker（非设计裁定者）。
> **基线提交**：`29286071`（start 泄漏修复，已推送）+ `34b23e69`（Q8-G 归档与 pity state 保留）。
> **性质**：measurement-only。生产代码、数据、RunState、正式 pity / E6 / pacing / battle / promotion 规则**零修改**。
> **本报告不作 A/B/C/D 产品裁定，只交付数据、因果证据、作废范围与未决问题。**

---

## 0. 实际修改文件

| 文件 | 变更 |
|---|---|
| `tools/q8g_agent1_post_fix_baseline.mjs` | **新增**。POST 基线扩展统计工具（起手层 / 访问节点数 / 战斗数与分层 / refinement 探访 / f1–f4 带段 / 五段漏斗 / Gate B/C）；含 `--layers`（按层 settled 份额）与 `<school>/<seed>`（逐场追踪）两个模式。无依赖，只读。 |
| `tools/q8g_agent1_f1_zero_risk.mjs` | **新增**。残余 f1=0 的结构性/方差判定工具（pity 模型 + Wilson 区间）。无依赖，只读。 |
| `tools/q8g_agent1_s1alpha_counterfactual.mjs` | **新增**。S1-α 的**模型无关**逐局反事实（L4/L5 elite→common 换算 + pity 阈值判定）。无依赖，只读。 |
| `docs/q8g/AGENT1_Q8G_POST_FIX_REPORT.md` | 本报告（新增） |
| `docs/q8g/Q8G_WORKER_REPORT_CURRENT.md` | 追加 Agent-1 章节 |
| `docs/q8g/Q8G_HANDOFF_CURRENT.md` | 追加 §29（回写） |

**未修改任何既有工具**：本轮使用的 `q8g_reachability7b_design_preflight.mjs`、
`q8g_reachability7_ashape_preflight.mjs`、`q8g_reachability8_corpus_compare.mjs`、
`q8g_reachability8_b1_map_audit.gd` 全部按原样运行（`--natural=observed` 是该工具**已有**参数，非本轮新增）。

## 0.1 未修改但审阅过的文件

`AGENTS.md`、`docs/q8g/Q8G_HANDOFF_CURRENT.md`（§1–§28）、`Q8G_REACHABILITY3_F1_PITY.md`、
`Q8G_REACHABILITY5_E6_LOOT_TIER_AUDIT.md`、`Q8G_REACHABILITY6_PREFLIGHT.md`、`Q8G_REACHABILITY7B/7C/7D/7E_*.md`、
`Q8G_REACHABILITY8_B1_MAP_AUDIT.md`、`GIT_CORRUPTION_INCIDENT_6.md`、
`scripts/acceptance_driver.gd`（R-5 埋点与五段漏斗定义）、`scripts/domain/map_generator.gd`、
`data/loot_tables.json`（pity / 材料池 / 带段）、`data/pacing.json`。
`git status` 确认本轮零触碰上述文件。

---

## 1. 32 局 POST 基线

### 1.1 语料与确定性

```text
语料目录      %TEMP%/gu-zhenrens-r5-logs/（32 局，<school>_<seed>.log）
重建命令      bash %TEMP%/q8g_rebuild_corpus.sh（等价 tools/q8g_reachability5_tier_audit.ps1 四批合并）
重建退出码    0（32/32 局退出码 0，R-5 summary 全部生成）
协议          PLAYTHROUGH_FULL=1 PLAYTHROUGH_COMBAT_FIRST=1 PLAYTHROUGH_E6_TIER_AUDIT=1
              PLAYTHROUGH_SCHOOL=<school> PLAYTHROUGH_SEED=<seed>
              godot --headless --path . -s scripts/acceptance_driver.gd -- --mode=play
```

**确定性交叉验证**：本轮重建（HEAD = `3f09e040`）与 2026-09-13 首次重建（同一 HEAD 之前的工作树）
逐行对比 `R-5 summary` / `R-5 battle` / `R-4 漏斗` / `行至` 四类关键行：

```text
identical = 32 / 32, differing = 0
```

⇒ 语料可复现，且 `34b23e69` 的 pity state 变更未改变本组种子的输出。

### 1.2 起手层与路线规模

```text
entry layer histogram              {"1": 32}          （全部 L1R0N0）
非 L1 起手                          0 / 32
访问节点数 total / 每局             1279 / 40.0
路线上 refinement 节点 total         98
路线上 combat 节点（实测访问）total   664
战斗数 total / 每局                 619 / 19.3
短局 (<15 战斗)                      5
```

地图产物审计（当前 HEAD 复跑，`tools/q8g_reachability8_b1_map_audit.gd`）：

```text
非 L1 起手的种子数: 0 / 16
起手层直方图: { 1: 22 }（16 个 seed 的 L1R0N0 + 6 个 seed 的 L1R0N1）
契约违规起点数: 0        determinism = OK
```

### 1.3 战斗分层与 tier 分布

```text
battles by layer   L1 145 | L2 165 | L3 148 | L4 98 | L5 63
battles by tier    common 155 | elite 151 | boss 88 | unsettled 225
```

按层 settled 胜场构成（**分母为非 Boss settled**，与 R7 工具口径一致）：

| 层 | common | elite | 非 Boss settled | common 份额 |
|---|---|---|---|---|
| L1 | 71 | 42 | 113 | 62.8% |
| L2 | 51 | 31 | 82 | 62.2% |
| L3 | 28 | 49 | 77 | 36.4% |
| L4 | 4 | 21 | 25 | 16.0% |
| L5 | 1 | 8 | 9 | 11.1% |
| 合计 | 155 | 151 | 306 | 50.7% |

若分母改为「全部 settled（含 Boss）」：L1 62.8% / L2 45.1% / L3 26.2% / L4 10.3% / L5 4.5% / 合计 39.3%。

PRE（污染语料）同口径非 Boss 份额：L1 50.0% / L2 52.4% / L3 35.2% / L4 17.0% / L5 11.5% / 合计 35.1%。

**关键读法**：修复**没有**改变各层的 Common 比例结构；改变的是**层的权重**——32 局全部从 L1 起手后，
战斗集中在 L1–L3（145/165/148），而 L4/L5 只有 98/63。池化份额从 35.1% 升到 50.7% 是层权重迁移的结果，
不是深层 Common 通道被修好。**L4/L5 的 Common 悬崖依然存在（16.0% / 11.1%）。**

### 1.4 refinement 探访与 Common 时序

```text
refinement 探访 total                     98（= 路线上 refinement 节点总数 98，机会 100% 被消费）
common before first refinement            73
common after last refinement               8
```

### 1.5 材料带段（f1–f4）

带段口径（`data/loot_tables.json` → `pity.material_pity.target_bands_by_tier`，带段→f 段映射为 provisional）：

```text
f1 = common 池 ∩ 本流派 promotion 链 ∩ quality_band == crude   （例 mat_force_1）
f2 = elite 池 ∩ 链 ∩ plain
f3 = elite 池 ∩ 链 ∩ refined
f4 = boss 池 ∩ 链 ∩ prized
```

```text
掉落  f1 66 | f2 57 | f3 54 | f4 48        （合计 225 件本流派材料）
剩余  f1 38 | f2 36 | f3 39 | f4 40
材料掉落合计（含非本流派）1066 件
```

每场 Common 胜利的落料件数为 **2–4 件**（118 场 2 件 / 36 场 3 件 / 1 场 4 件 = 348 抽）。
f1 命中率 = 66 / 348 = **19.0% 每抽**，与 `school_material_resonance=5` 的权重估算
（5 / (21×1 + 5) ≈ 19.2%）一致；换算为「每场 Common 胜利至少掉 1 件 f1」≈ 37.6%，实测 63/155 = 40.6%。

### 1.6 五段漏斗与 Gate

```text
漏斗  visits 98 | gu_ready 98 | mat_ready 88 | full_ready 70 | attempts 72 | successes 72
promotion 完成 72 次 | 最高 rank 达到 5
gate_b PASS 15 / 32      gate_c PASS 8 / 32
```

`mat_ready → full_ready` 的 18 次损耗、`full_ready → attempts` 的 2 次损耗是本轮唯一可见的漏斗断点，
量级远小于 Common 机会问题（见 §3）。

### 1.7 f1=0 人口

```text
f1_zero = 2 / 32   （PRE 为 8 / 32）
短局中的 f1=0 = 1，长局中的 f1=0 = 1
两局的 Common 胜场数均为 2
```

Common 胜场数分布（32 局）：

```text
1 场: 1 局 | 2 场: 2 局 | 3 场: 8 局 | 4 场: 3 局 | 5 场: 6 局 | 6 场: 6 局 | 7 场: 2 局 | 8 场: 2 局 | 9 场: 2 局
⇒ Common 胜场 ≤ 3 的局共 11 局（34%），其中 2 局失败
```

---

## 2. force/303 逐场分析

**结论：force/303 不是 start 泄漏残留，也不是时序问题；它是「Common 胜场数低于 pity 阈值」的供给不足局。**

```text
entry=L1R0N0  访问节点=45  战斗=20  路线 refinement 节点=2  探访=2
visit_marks=[11, 18]      common_indices=[1, 4]      common_layers=[1, 1]
f1_count=0   bands: f1×0  f2×2  f3×4  f4×4
funnel: visits 2 | gu_ready 2 | mat_ready 2 | full_ready 0 | attempts 0 | successes 0
gate_b=FAIL  gate_c=FAIL   持有蛊最高 rank=4
```

逐场（节选关键场次）：

| idx | 结果 | 层 | tier | 实际敌人 | 材料 |
|---|---|---|---|---|---|
| 1 | victory | L1 | common | (多敌 `mountain_boar`+`ridge_hound`) | `moon_blue_petal`, `mat_fire_1` |
| 2 | victory | L1 | elite | `thunder_crown_wolf` | `mat_fire_2` |
| 3 | retreat | L1 | unsettled | `beast_swarm` | — |
| 4 | victory | L1 | common | `ridge_hound` | `mat_qi_1`, `mat_earth_1` |
| 9 | victory | L2 | boss | `marrow_gu_adept` | `mat_force_3` |
| 11 | **retreat** | L3 | unsettled | `ridge_hound` | — ← 第 1 次 refinement 探访 |
| 13 | victory | L3 | boss | `thunder_crown_sovereign` | `mat_qi_3` |
| 17 | victory | L4 | boss | `blood_vein_bishop` | `mat_force_3` |
| 18 | **retreat** | L5 | unsettled | `clan_elder` | — ← 第 2 次 refinement 探访 |
| 20 | victory | L5 | boss | `miasma_vein_lord` | `mat_earth_4` |

因果链：

1. 全部 20 场里只有 **2 场 Common 胜利**（idx 1、4），**都在 L1**；
2. 这 2 场共 **4 抽**材料，命中 `moon_blue_petal` / `mat_fire_1` / `mat_qi_1` / `mat_earth_1`，
   **没有一次命中 force 学派的 crude 材料 `mat_force_1`**（4 抽全空的概率约 0.81⁴ ≈ 43%，属正常方差）；
3. 正式 pity 阈值 = 3，且按 `material_pity_by_tier` **按 tier 独立计数**——需要第 4 场 Common 胜利才强制兑现；
   本局只有 2 场，**pity 从未触发**；
4. 两次 refinement 探访发生在战斗 #11 / #18，**晚于**唯一的 Common 窗口（#1、#4）；
   `common_before_first_refinement=2`、`common_after_last_refinement=0`；
5. `mat_ready=2`（两次探访时 f2/f3/f4 已够），但 `full_ready=0`（缺 f1），
   故 `attempts=0`——**不是玩家没去炼，是 f1 断供**。

即：**该局失败的唯一原因是「Common 胜场数 < pity 阈值」，与起手层、路线长度、Elite 暴露、
refinement 时序均无关。** 20 场的「长局」并不提供更多 Common 机会——L4/L5 的 Common 份额只有 16.0% / 11.1%。

`force/20260927`（另一失败局）结构完全相同：entry L1R0N0、13 场、Common 仅 2 场且都在 L1
（`common_layers=[1,1]`，材料为 `mat_sword_1`）、`f1×0`、`mat_ready=2`、`full_ready=0`、`attempts=0`。

---

## 3. G1 K=2 是否仍有必要

### 3.1 旧结论赖以成立的前提已消失

G1 的语义是**短局 guard**：对短局保底 Common 机会。它成立的前提是「短局 ↔ Common 机会稀缺」相关。
POST 基线实测该相关性**已断裂**：

```text
短局（<15 战斗）5 局及其 Common 胜场数：
  force/20260927  13 场  Common 2  f1=0
  force/11        12 场  Common 6  f1=2
  force/707       13 场  Common 1  f1=1
  sword/202       12 场  Common 3  f1=1
  sword/55         5 场  Common 3  f1=1
⇒ 5 个短局里 4 个的 Common 胜场 ≥ 3；只有 1 个失败

而另一个失败局 force/303 是 20 场的长局
⇒ 短局只覆盖 2 个失败局中的 1 个；长局失败局结构上不受短局 guard 影响
```

### 3.2 报告层 hypothetical：G1 K=2 的收益为 **0**

在 POST 语料上按**观测 natural f1 率**（0.406）重跑 A-shape preflight
（`tools/q8g_reachability7_ashape_preflight.mjs --natural=observed`）：

```text
OBSERVED（事实，无模型）：f1zero_fix 0/2 | inWindow 30/32 | shortZero 1 | matPieces 482 | elite 151 | common 155

variant                f1zero_fix   shortZero   elite      common
ACTUAL                     0/2          1        151.00     155.00
A3a short floor K=1        0/2          1        151.00     155.00   ← 无成本
A3a short floor K=2        0/2          1        150.00     156.00   ← 等价 G1 K=2：收益 0，Elite −1
A3b short front-window     0/2          1        151.00     155.00
A4 timing-only (all)       0/2          1        151.00     155.00
```

f1=0 两局在各变体下的 Common 胜场数（修复需 ≥4）：

```text
run            actual  A3a K=1  A3a K=2  A3b  A4
force/20260927    2        2        2      2   2
force/303         2        2        2      2   2
```

另一口径（`tools/q8g_reachability7b_design_preflight.mjs`，natural 率固定 0.556，偏乐观）：

```text
BASELINE        f1zero_fix 1.55/2   elite 151
G1 floor K=2    f1zero_fix 1.55/2   elite 150      ← 差值 0
G2 floor K=4    f1zero_fix 1.72/2   elite 145
G3/G4           f1zero_fix 1.55/2   elite 151/152
```

两种 natural 率假设下，**G1 K=2 相对基线的 f1zero 修复增量都是 0**，同时仍付出 Elite 暴露代价。
机制上可解释：G1 是「机会数量保底」，而两局的 Common 数为 2，pity 兑现需要第 4 场；
把 2 抬到 2（或略高）不跨过阈值，自然 f1 命中又没发生，因此无法修复。

### 3.3 结论（供裁定）

```text
G1 K=2 在 POST 基线上：收益 0 / 2 局，成本 Elite −1（报告层模型）。
其目标人口（短局）只覆盖 2 个失败局中的 1 个，且该局不受保底影响。
⇒ 不建议按原裁定继续实施 G1 K=2；是否彻底取消、或改为针对「Common 胜场数」而非「局长度」的变量，
  需要 Luna 新裁定（worker 不自行改设计）。
```

### 3.4 裁定结果（2026-09-14，inbox §31）

```text
G1 K=2：正式撤回（依据：POST 语料下 f1zero 修复 0/2，Elite 151 → 150 —— 无收益仍有代价）
Common-victory guard：不批准（即使需要 K ≥ 4 才能覆盖剩余两局，也属新机制设计，不属 G1 小修）
剩余 2/32 f1=0：接受为正常随机尾部，不开新机制修复
```

本节结论与裁定一致，无需 worker 进一步动作。

---

## 4. S1-α 是否仍有必要

### 4.1 S1-α 的观测对象确实还存在

L4/L5 的 Common 通道**非零但极薄**（16.0% / 11.1%），且绝对量很小（L4 4 场、L5 1 场）：

```text
L5 实际 Common 上限（R7B 模型）：155 实际 + 8 可转换 = 163（硬上限）
```

所以 S1-α 描述的「深层 Common 稀缺」是**真实存在**的。

### 4.2 但它修不动当前的 f1 缺口

报告层 S1-α hypothetical（L5-only / L4+L5 / 全层 coverage，匹配总量与提高总量两种口径）：

```text
--- 匹配总量（target ≈ 155 Common）---
scope        commons  f1zero_fix   inWindow  shortZero  elite
L5 only        155      1.55/2       29.69     0.17     151
L4+L5          155      1.55/2       29.69     0.17     151
all layers     155      1.55/2       29.69     0.17     151

--- 提高总量（target ≈ 185 Common）---
L5 only        163      1.67/2       29.81     0.17     143
L4+L5          184      1.83/2       30.09     0.17     122
all layers     187      1.83/2       30.33     0.17     119
```

按观测率口径（A1 = L5 coverage，各 magnitude）：

```text
A1 L5 cov @own 0.11    f1zero_fix 0/2   elite 150
A1 L5 cov @ref 0.51    f1zero_fix 0/2   elite 150
A1 L5 cov @0.60        f1zero_fix 0/2   elite 150
A1 L5 cov @0.75        f1zero_fix 0/2   elite 149
A2 share floor 0.60    f1zero_fix 2/2   elite 61
```

f1=0 两局的 Common 数在 **A1（L5-only）全系变体**下**恒为 2**，不跨过 pity 兑现阈值 4。

⚠️ **但 R7 的逐局表只覆盖了 L5-only 作用域**；L4+L5 与全层只有聚合值，无法逐局核对。
§4.5 用**模型无关的逐局反事实**补上了这一格，结论与本节不同，以 §4.5 为准。

### 4.3 唯一能闭合缺口的是全层份额下限，代价不可接受

```text
A2 share floor 0.60（全层）  f1zero_fix 2/2   elite 151 → 61   （−59.6%）
A2 share floor 0.75（全层）  f1zero_fix 2/2   elite 151 → 49   （−67.5%）
材料件数在全部变体下恒为 482（+0.00），变化的是品质带段与 Gu 期望
```

### 4.4 结论（供裁定）

```text
S1-α（按层绑定 L4/L5 opportunity 保护）在 POST 基线上：L5-only 修复 0/2，L4+L5 修复 1/2。
它描述的稀缺是真的，但修复量与代价严重不成比例，且两局中有一局结构上无法被覆盖恢复触及。
⇒ 不建议为 F1 缺口实施 S1-α；若实施，应作为「深层内容多样性」议题单独立项并单独验收，
  不应挂在 f1 / Gate B/C 目标下。
```

### 4.5 模型无关逐局反事实（更正 §4.2 的作用域结论）

工具：`tools/q8g_agent1_s1alpha_counterfactual.mjs`（新增，只读）。

方法：把 L4/L5 的 **elite 胜场直接换算成 Common 胜场**，再看该局的 Common 数是否达到
pity 兑现阈值（threshold + 1 = 4）。因为「N ≥ 4 时 pity 在**最坏情况**（自然命中全不发生）下也保证命中」，
**该修复判定不依赖任何 natural f1 率假设**，是确定性的。

```text
force/20260927  末次 refinement 探访 = 战斗 #10
   actual        commons=2  -> 未修复
   S1a L5-only   commons=2  -> 未修复
   S1a L4+L5     commons=2  -> 未修复     （该局 13 场从未进入 L4/L5）

force/303       末次 refinement 探访 = 战斗 #18
   actual        commons=2  -> 未修复
   S1a L5-only   commons=3  -> 未修复     （L5 只有 1 场 elite 可转换）
   S1a L4+L5     commons=5  -> 修复        （第 4 场 Common 落在战斗 #16，早于末次探访 #18，可兑现）
```

全语料汇总：

```text
variant          f1zero 修复  修复且在窗口内  elite 被转换 受影响局数
actual                0            0               0           0
S1a L5-only           0            0               8           6
S1a L4+L5             1            1              29          14
```

⇒ 更正后的结论：

```text
L5-only  ：0/2 修复（与 §4.2 的 R7 结果一致）
L4+L5    ：1/2 修复，代价是 14 局共 29 场 elite 胜场被转换为 Common
force/20260927 结构上无法被救：它 13 场就结束、从未进入 L4/L5，
               因此任何「按层恢复深层 Common 覆盖」的方案对它都是空集。
```

**未建模部分（只有 elite→common 的计数是精确的）**：品质带段变化（elite plain/refined → common crude）、
Gu 概率（0.30 → 0.06）、战斗元石、以及玩家在改变后的地图上是否仍走同一路线。

---

## 5. 旧 G1 数值作废清单

以下数值全部建立在**受 start 泄漏污染的短局人口**（f1=0 8/32、短局 14/32）之上，在新基线上**不得继续引用**：

```text
[作废] G K=2 条件接受边界（inbox §25）
        f1zero 修复区间 4.92–6.00 / 8
        Elite 4.69 → 4.31 / 局；Gu 1.56 → 1.47 / 局
        诅咒 2.34 → 2.16 / 局；恶名 4.69 → 4.31 / 局
        受影响局数 9 / 32；单局最多损失 2 场 Elite；短局 Elite 3.14 → 2.29 / 局
[作废] G K=1/K=2/K=3/K=4 比较（inbox §23）
        4.94 / 6.00 / 7.02 / 7.02 次修复；elite 146 / 138 / 128 / 123
[作废] G1 vs G2 成本效率（inbox §22）
        0.2773 vs 0.1609 次修复 / 每减少 1 场 Elite
[作废] 区间化报告（inbox §23）
        BASELINE 1.61–2.67/8；G K=2 4.92–6.00/8；G K=4 6.05–7.02/8；M@101 3.95–4.92/8；M@141 6.23–6.61/8
[作废] M 前沿（inbox §22）
        实际 Commons 81；有效收益峰值 ≈101；收益停滞 131；收益死区 149–202；天花板 231
[作废] M 代价预算（inbox §24）
        M@101 Elite −0.63/局 / Gu −0.15/局；M@120 −1.22 / −0.29；M@141 −1.88 / −0.45
[作废] R7B 报告层总量（inbox §20）
        baseline f1zero_fix ≈2.72/8、shortZero ≈4.92；G1 K=2 ≈6.20/8、shortZero ≈1.44、elite 150→138
[作废] 「短局 = 战斗数 < 15」的人口定义（14/32）
        新基线为 5/32，且短局已不再是失败的主要载体
[作废] 材料件数基线 389.0（inbox §20/§21）
        新基线为 482.0（口径：R7 工具的 matPieces 统计，32 局）
```

仍然有效、未作废的：

```text
[保留] R5 审计的 tier 结构结论：L4/L5 rank 区间过滤后 Common 候选稀缺（新基线仍成立：16.0% / 11.1%）
[保留] R5 的 fallback 通道结论：多敌战斗按 common 兜底
[保留] R6 的「数量与时序是两个独立变量」方法论
[保留] 正式 pity 语义：按 tier 独立计数、阈值 3、第 4 场 Common 兑现
```

---

## 6. 新的未决问题

> **本节已按裁定与 §4.5 更正对齐（2026-09-14 22:10）**：Q1/Q3/Q6 的初稿口径已过期，
> 括号内为更正后的表述。

```text
Q1  剩余 2/32 的 f1=0 是否可接受？
    两局均为「Common 胜场 = 2、低于 pity 阈值、自然命中未发生」。
    [已更正] 闭合路径有三种，代价依次递增：
      ① L4+L5 覆盖恢复 -> 修复 1/2，转换 29 场 elite（另一局从未进入 L4/L5，不可达）
      ② 全层 Common 份额下限 ≥0.60 -> 修复 2/2，Elite −59.6%
      ③ 改 pity 阈值语义
    三种都超出本轮范围。
    [裁定] 已判定为正常随机尾部，接受，不开新机制。

Q2  是否需要把「保护变量」从「局长度」改为「Common 胜场数」？
    POST 数据显示局长度已不是失败载体（短局 4/5 的 Common ≥3），而 Common 胜场 ≤3 的 11 局承载了全部失败。
    这是新机制设计。
    [裁定] 不批准（K ≥ 4 亦属新系统，无足够证据开启）。

Q3  L4/L5 Common 悬崖是否要作为独立议题处理？
    它真实存在（16.0% / 11.1%），也不受 start 修复影响。
    [已更正] 初稿称它「不构成当前 f1 缺口」——**不准确**：L4+L5 覆盖恢复可修复 2 局中的 1 局。
    准确表述是：它是当前缺口的**部分**成因，但修复量与代价严重不成比例，且无法触及另一局。
    若要处理，应定义为「深层内容多样性」，与 f1 / Gate B/C 解耦。
    [裁定] S1-α 不作为 F1 修复、暂不实施；若保留须改名「深层内容多样性 / 层级体验设计」。

Q4  f1 每抽命中率 19.0%（共 348 抽）是否需要重新校准？
    该值由 common 池 22 条 + `school_material_resonance=5` 决定；
    它直接决定「几场 Common 才够」——是比 pity 阈值更上游的变量。
    [未裁定，经济线冻结]

Q5  force/303 是否需要在更大样本上重演？
    本轮为单局观测（4 抽全空，概率约 43%）；若要判断它是方差还是结构性问题，
    需要同 seed 的重复流或扩大样本。
    [裁定] 残余 2/32 已判定为正常尾部，无需为此扩大样本。

Q6  包装层 `tools/check.ps1` 在 unit 段曾为 FAIL。
    [已更正] 该 SCRIPT ERROR 已由 Agent2/VDA 于 2748ef82 修复并提交；
    §12.1.1 的回归门结果现可归给 HEAD 2748ef82。
```

---

## 7. 未修改生产文件声明

```text
未修改（逐项确认）：
  scripts/domain/**        （含 run_state.gd、loot_resolver.gd、map_generator.gd、content_catalog.gd）
  data/**                  （含 nodes.json、loot_tables.json、pacing.json、enemies.json、balance.json）
  scripts/presentation/**
  tests/**
  RunState / 事件日志 / 存档
  正式 pity（material_pity / material_pity_by_tier）
  正式 E6 抽取语义 / pacing rank 区间 / enemy weights
  battle 规则 / promotion 规则 / 商店 / Soul / 地图拓扑

未运行：M+G、M+T、M+G+T 任何组合；未把任何报告层 hypothetical 数值写回生产配置。
未实施：G1、S1-α、A2 份额下限。
未使用：git reset --hard、强制检出、递归删除。
```

本轮唯一新增的可执行文件是 `tools/q8g_agent1_post_fix_baseline.mjs`（只读分析工具，不进入正式运行路径）。

### 7.1 工作树中的无关未提交改动（非本任务，未触碰）

```text
scripts/presentation/widgets/gu_card_view.gd   （3 insertions / 4 deletions）
    内容：_load_gu_texture() 由 Image.new()+img.load() 改为 FileAccess.file_exists()+load()，
          与 3f09e040 对 gu_tall_fan_hand_view.gd 的卡牌插画修复同源。
    归属：本任务开始前不存在、任务执行中出现，非 Agent 1 产生；已按 AGENTS.md「保护用户未提交改动」
          保留原样，未读取以外未做任何写操作。
```

`git status` 其余条目：`docs/q8g/Q8G_HANDOFF_CURRENT.md`、`docs/q8g/Q8G_WORKER_REPORT_CURRENT.md`（本任务回写）、
`docs/q8g/AGENT1_Q8G_POST_FIX_REPORT.md`、`tools/q8g_agent1_post_fix_baseline.mjs`（本任务新增）、
以及既有的未跟踪项 `.codex/` 与 4 个 `assets/wenzhen/enemies/*.png(.import)`。

---

## 8. 验证命令与退出码

PowerShell 工具沙箱会拦截 Godot 子进程（`tools/*.ps1` 在沙箱内 1 秒返回假 rc），
Bash 禁止调用 `powershell.exe`；因此 Godot 相关命令在 Bash 中直接调用 console exe，退出码为原生值。

| # | 命令 | 退出码 | 结果 |
|---|---|---|---|
| 1 | `git status --short --branch` / `git log --oneline -20` | 0 | `master` 干净；`29286071` 在历史中；`34b23e69` 归档 Q8-G |
| 2 | `git merge-base --is-ancestor 29286071 HEAD` | 0 | YES |
| 3 | `godot --headless --path . -s tools/q8g_reachability8_b1_map_audit.gd` | 0 | 非 L1 起手 0/16；契约违规 0；determinism OK |
| 4 | `bash %TEMP%/q8g_rebuild_corpus.sh` | 0 | 32/32 局 rc=0，R-5 summary 全部生成 |
| 5 | 新旧语料关键行 `diff`（32 文件） | 0 | identical=32 / differing=0 |
| 6 | `node tools/q8g_agent1_post_fix_baseline.mjs` | 0 | §1 全部聚合指标 |
| 7 | `node tools/q8g_agent1_post_fix_baseline.mjs --layers` | 0 | §1.3 按层份额 |
| 8 | `node tools/q8g_agent1_post_fix_baseline.mjs force/303` | 0 | §2 逐场追踪 |
| 9 | `node tools/q8g_agent1_post_fix_baseline.mjs force/20260927` | 0 | 另一失败局逐场 |
| 10 | `node tools/q8g_reachability7b_design_preflight.mjs` | 0 | scope / G / T 报告层对比 |
| 11 | `node tools/q8g_reachability7_ashape_preflight.mjs --natural=observed` | 0 | A1–A4 变体 + 每局 Common 数表 |

---

## 9. 未验证风险

```text
R1  报告层模型的 natural f1 率假设。R7 用观测率 0.406，R7B 固定 0.556（偏乐观）；
    两者结论一致（G1 增量 0），但绝对修复数仍属模型依赖值，不得当作承诺。
R2  单 RNG 路径、32 局样本。f1=0 由 8 降到 2 后，剩余人口的统计分辨率很低（n=2）；
    「G1 收益为 0」在小样本下是强方向性结论，但不是精确的 0。
    → 已补 §12.2：残余 2 局与 pity 模型的预期 2.97 局（区间 2.14–3.94）一致，属方差尾部。
R3  A2（全层份额下限）的 Elite 代价（−60%）是模型层估算，未逐场重演 enemy roll / stone reward。
R4  f1 每抽命中率 19.0% 由 348 抽估计，未做置信区间；它影响「几场 Common 才够」的判断。
    → 已补 §12.2：每场 Common 胜利命中率 q = 0.4065，Wilson 95% CI [0.3323, 0.4851]。
R5  force/303 的「4 抽全空」为单局观测，未做重复流验证（见 Q5）。
R6  「短局」定义仍沿用 <15 战斗；本轮显示该定义与失败人口脱钩，但未测试其他阈值。
R7  ~~本轮未重跑 unit / integration / check~~ → **已补 §12.1：在含其他 Agent 在途修复的工作树上
    六段全部 exit 0，`run_gut_checked` 严格判定 PASS。**
    ⚠️ 但该结果**不等于 HEAD 全绿**：HEAD 上 `test_slay_gu_final_chapter.gd:149` 的
    loot_tables SCRIPT ERROR 仍存在，正由 VDA 工作流在途修复（见 §12.1 更正）。
```

---

## 10. 设计冲突与是否需要 Luna 新裁定

```text
冲突 1  G1 K=2 的既有条件接受（inbox §25）与 POST 实测（收益 0 / 成本 Elite −1）直接矛盾。
        §25 的验收边界本身写明「实现前必须重新确认」，本轮完成了该重新确认，结论为不建议实施。
        → 需要 Luna 裁定：正式撤回 §25 的条件接受，或改换保护变量。

冲突 2  S1-α 的授权范围（inbox §26/§27 定为「设计方向，未批准实现」）与 POST 实测
        （修不动 f1 缺口）不一致。若仍要保留该方向，需重新定义其产品目标。
        → 需要 Luna 裁定。

冲突 3  剩余 2/32 的 f1=0 与「消灭全部 f1=0」的目标口径（inbox §25 裁定二已明确
        目标是「改善短板」而非「消灭全部」）之间需要重新对齐：新基线的短板已不是短局。
        → 需要 Luna 裁定新的目标口径。

本轮 worker 未越过以下边界：未实施任何生产改动，未运行任何 M/G/T 组合，
未把 hypothetical 数值写入配置，未自行选择 A/B/C/D。

### 10.1 裁定项 ⑤ 仍然有效（更正）

§6 Q6 / 裁定项 ⑤ 为「包装层 `tools/check.ps1` 在 unit 段的既有 SCRIPT ERROR 修法」。

> **更正**：本节初稿曾据 §12.1 的首次结果判定该项「已自动失效」。经时间戳核对，
> 该结果是在**已包含其他 Agent 在途修复**的工作树上取得的，**不能**据此认为 HEAD 已修好。

事实：

```text
HEAD（3f09e040）的 tests/unit/test_slay_gu_final_chapter.gd:149 仍是有 bug 的写法
  -> tools/check.ps1 在 pristine HEAD 上仍会在 unit 段 exit 1
该问题正由 VDA 工作流（另一 Agent，2026-09-14）在途修复，配套 tools/test.ps1 增加 --import 前置；
修复尚未提交，本轮未触碰、未代其提交。
```

⇒ **裁定项 ⑤ 保留**，但其归属应从「Agent 1 待裁定」转为「VDA 工作流在办事项」。

### 10.2 待裁定清单 → 已裁定（2026-09-14，inbox §31）

```text
① G1 K=2 条件接受是否撤回            → 已正式撤回
② S1-α 是否重新定义产品目标          → 不作为 F1 修复，暂不实施；若保留需改名为
                                       「深层内容多样性 / 层级体验设计」
③ 剩余 2/32 f1=0 的接受度            → 接受为正常随机尾部
④ 保护变量是否改为 Common 胜场数      → 不批准（K ≥ 4 亦属新机制，不开新系统）
⑤ 包装层 SCRIPT ERROR 修法            → 不在 Agent 1 范围；由 Agent2 验证任务独立收口
⑥ 多 Agent 共用工作树的测量纠缠        → 已采纳：裁定明确「验证结果必须绑定工作树」，
                                       HEAD 与工作树须分开表述；分支隔离后分别提交
```

裁定原文：`docs/q8g/Q8G_HANDOFF_CURRENT.md` §31。

**Agent 1 无剩余待裁定项；无新增生产施工授权。**

### 10.3 本报告自身的更正记录（供复核追溯）

```text
更正 1（§12.1）验证归因：初稿把「工作树 unit 全绿」归因为 34b23e69 修掉了 SCRIPT ERROR。
                 经文件 mtime 核对（他人 21:21:50 / 21:22:05 先改，本轮 21:25:47 才运行），
                 该归因错误，已改为「共享工作树快照，不等于 HEAD」。
更正 2（§4.5）S1-α 作用域：初稿称 S1-α 修复 0/2（只对 L5-only 成立）。
                 模型无关逐局反事实显示 L4+L5 修复 1/2，已按作用域分别陈述。
更正 3（§12.2）统计估计量：初稿误用「局是否命中」估计 q；
                 已改为「每场 Common 胜利是否命中」，q = 0.4065。
```
```

---

## 11. 一句话摘要

```text
start 泄漏修复后，f1=0 从 8/32 降到 2/32；剩余两局的唯一共同原因是
「Common 胜场只有 2 场、低于 pity 兑现阈值（4）、自然命中未发生」，且两局的 Common 窗口都在 L1。
该残余与 pity 模型的预期 2.97 局（区间 2.14–3.94）一致 ⇒ 属正常方差尾部，非结构性缺陷。
G1 K=2（短局 guard）对这两局的修复增量为 0，成本仍为 Elite −1；
S1-α 按作用域分：L5-only 修复 0/2，L4+L5 修复 1/2（代价 14 局共 29 场 elite 转换），
且 force/20260927 从未进入 L4/L5，结构上无法被覆盖恢复触及。
唯一能闭合缺口的是全层 Common 份额下限 ≥0.60，代价 Elite −60%。
⇒ 裁定（inbox §31）：G1 K=2 撤回；S1-α 不作为 F1 修复、暂不实施；
   Common-victory guard 不批准；剩余 2/32 接受为正常尾部。经济线保持冻结。
```

---

## 12. 附录：两项收尾验证（2026-09-14 补）

本节回应 §9 中标记为「未验证」的 R7，以及 §6 的 Q5/Q6 与裁定项 ⑤。

### 12.1 回归门在工作树上全绿（⚠️ 与在途改动纠缠，非 HEAD 结论）

> **先读 §12.1.1**：该归因歧义已由其他 Agent 的提交落地解决，
> 本节结果现在**可以合法归属 HEAD `2748ef82`**。以下保留原始记录以供追溯。

> **重要更正（2026-09-14 21:45）**：本节初稿曾把结果归因为「两条 SCRIPT ERROR 已被 `34b23e69` 修掉」。
> 经时间戳核对，**该归因错误**，已按下列事实改写。

时间线（文件 mtime vs 本轮测试运行时间）：

```text
21:13:12  scripts/presentation/widgets/gu_card_view.gd        被改（其他 Agent）
21:19:37  export_presets.cfg                                  被改（其他 Agent）
21:20:47  docs/q8g/AGENT3_UI_RELEASE_REPORT.md                新增（其他 Agent）
21:21:50  tests/unit/test_slay_gu_final_chapter.gd            被改（其他 Agent，VDA）
21:22:05  tools/test.ps1                                      被改（其他 Agent，VDA）
21:25:47  本轮 unit 运行开始
21:31:50  docs/q8g/Q8G_VERIFICATION_DEBT_AUDIT.md             新增（其他 Agent）
21:32:35  本轮 unit 运行结束
```

⇒ 本轮的 unit / integration 运行**发生在其他 Agent 的修复之后**，因此：

```text
[不是] 34b23e69 修掉了该 SCRIPT ERROR
[是]   HEAD（3f09e040）的 tests/unit/test_slay_gu_final_chapter.gd:149 仍是有 bug 的写法
       （diff 的 `-` 行即 HEAD 版本：把 loot_tables 每个顶层 value 赋给 Dictionary）；
       它由**在途的 VDA 工作**（2026-09-14，另一 Agent）于 21:21:50 修复，
       并配套在 tools/test.ps1 增加 `--import` 前置步骤（21:22:05），
       以解决 b82950e1 引入 MaShanZheng-Regular.ttf 后 `.godot` 导入缓存过期
       导致的编译期级联 SCRIPT ERROR。
```

因此本节结果只能表述为「**在当前工作树（含在途修复）上**全绿」，**不能**表述为「HEAD 上全绿」：

| 阶段 | 退出码 | 结果（当前工作树） |
|---|---|---|
| `scripts/guitkx_build.gd` | 0 | `compiled=0 errors=0 held=0 total=16` |
| unit（GUT） | 0 | **Tests 1445 / Passing 1445 / Failing 0**（Asserts 47771，375.8s） |
| integration（GUT） | 0 | **Tests 32 / Passing 32 / Failing 0**（Asserts 1476，70.6s） |
| 启动探针 `--quit-after 3` | 0 | OK |
| `tools/check_contract_drift.gd` | 0 | `contract drift: ok (168 identifiers resolved)` |
| `git diff --check` | 0 | 无空白错误 |

`run_gut_checked.ps1` 的严格判定（`Parse Error / Ignoring script / Nothing was run / SCRIPT ERROR`）
在 unit 与 integration 上均为 PASS——**同样是在含在途修复的工作树上**。

**对裁定项 ⑤ 的修正结论**：

```text
⑤ 仍然有效（未自动失效）。
   HEAD 上 tools/check.ps1 的 unit 段仍会因 loot_tables 顶层键 float 赋值而 exit 1；
   该问题正由 VDA 工作流（其他 Agent）在途修复，且修复**尚未提交**。
   本轮未触碰该文件，也未代其提交。
```

**并发风险（需知悉）**：本工作树同时被多个 Agent 编辑（`AGENT3_UI_RELEASE_REPORT.md`、VDA 文档、
`gu_card_view.gd`、`export_presets.cfg`、`tools/test.ps1`、`tests/unit/test_slay_gu_final_chapter.gd`）。
本轮的所有测试数字都是在该共享工作树上取得的**快照**，随其他 Agent 的后续编辑可能失效。
Agent 1 未修改、未回退、未提交任何他人改动。

### 12.1.1 归因歧义已由提交落地解决（2026-09-14 21:55 补）

在 §12.1 写就之后，其他 Agent 已把在途修复提交：

```text
73e3e5ee  fix(ui): load card art via ResourceLoader and widen export excludes      （Agent3）
2748ef82  test: fix slay-gu loot pool assertion and pre-import cache in test.ps1   （Agent2 / VDA）
```

当前 HEAD = `2748ef82`。核对工作树：`git status --short` 相对 HEAD 仅多出 **Agent 1 自己的**
文档与只读工具（`docs/q8g/AGENT1_*`、`docs/q8g/Q8G_HANDOFF_CURRENT.md`、
`docs/q8g/Q8G_WORKER_REPORT_CURRENT.md`、`tools/q8g_agent1_*.mjs`），
**不包含任何代码/数据/测试改动**。

⇒ 修正后的归因表述：

```text
本轮 unit 1445/1445、integration 32/32、check.ps1 六段 rc=0
    = 对应提交状态 HEAD 2748ef82
      （测试所依赖的代码/数据/测试文件在工作树与 HEAD 逐字节一致；
        Agent 1 的新增物为文档 + 只读 node 工具，不参与 GUT 用例、不影响契约漂移）
```

即：**§12.1 的绿现在可以合法归给 HEAD `2748ef82`**，而不再是「无法归属的共享工作树快照」。
裁定 §31 要求的「验证结果必须绑定工作树」在此得到满足。

⚠️ 仍需注意：HEAD 已由 `3f09e040` 前移到 `2748ef82`。本报告 §1–§12 的**语料与统计结论**
来自 `3f09e040` 时代重建的 32 局语料（当时工作树已含等价的经济数据），
而 §12.1 的**回归门结果**对应 `2748ef82`。两者不要混引。

### 12.2 残余 f1=0 是方差尾部，不是结构性异常（关闭 R2/R4 的定性部分）

工具：`tools/q8g_agent1_f1_zero_risk.mjs`。模型沿用正式 pity 语义
（按 tier 独立计数、阈值 3 ⇒ 第 4 场 Common 强制兑现），并用语料自身估计命中率。

```text
Common 胜场合计 155 | Common 胜利上的材料抽数 348（每场 2.25 抽）
f1 材料抽数 63      ⇒ 每抽命中率 0.1810
命中 f1 的 Common 胜利 63 / 155 ⇒ 每场 Common 胜利命中率 q = 0.4065
q 的 Wilson 95% 区间 = [0.3323, 0.4851]

Common 胜场数直方图：N=1:1  N=2:2  N=3:8  N=4:3  N=5:6  N=6:6  N=7:2  N=8:2  N=9:2

模型  P(f1=0 | N) = (1-q)^N （N ≤ 3；N ≥ 4 时 pity 保证命中）
      N=1 → 0.5935    N=2 → 0.3523    N=3 → 0.2091    N≥4 → 0

预期 f1=0 局数 = 2.97      （q 取 95% 区间边界时为 2.14 .. 3.94）
观测 f1=0 局数 = 2
```

⇒ **观测值 2 落在预期区间内且略低于点估计（2.97）**，说明残余 f1=0 是
「Common 胜场数分布 × pity 阈值」的正常尾部，**没有隐藏缺陷**，也**不需要**为这 2 局寻找新的结构性修复。

同时得到一条模型无关的结构性结论：

```text
所有风险局（N ≤ 3）的 N 都小于 pity 兑现阈值 4。
⇒ 任何 floor K ≤ 3 的短局 guard 都无法把其中任何一局抬到兑现阈值。
   要真正改变这 2 局，guard 的下限必须 ≥ 4（即每局额外补 ≥2 场 Common），
   这比 G1 K=2 的量级大得多，且 Elite 代价也高得多。
```

局限：32 局来自每 seed/学派的**单一 RNG 路径**，各局不是独立抽样，区间仅供参考，不是形式化检验。

### 12.3 复现命令

```bash
node tools/q8g_agent1_f1_zero_risk.mjs          # 12.2
"$GODOT" --headless --path . -s scripts/guitkx_build.gd
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/unit -gexit -glog=2
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit -glog=2
"$GODOT" --headless --path . --quit-after 3
"$GODOT" --headless --path . -s tools/check_contract_drift.gd
git diff --check
```
