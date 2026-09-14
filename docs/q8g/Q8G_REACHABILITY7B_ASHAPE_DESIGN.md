# Q8-G Reachability-7B / A-Shape Design Preflight（设计预审记录）

> **范围**：inbox §19 的 5 项后续（作用域裁定 / 副作用接受度 / 短局 guard / 时序候选 / 32+ 局验证）。
> **性质**：**measurement-only**。只读 R5 审计日志 + `data/*.json`，**不写入游戏**，不修改
> `scripts/domain/**`、`data/**`、`scripts/presentation/**`、`tests/**`、`RunState`、
> 正式 pity / E6 / pacing / battle 规则。
> **工具**：`tools/q8g_reachability7b_design_preflight.mjs`（新增，纯读）
> **重跑**：`node tools/q8g_reachability7b_design_preflight.mjs`
> **本文件不构成产品裁定。** A 仍为 `CONDITIONAL`，B/C/D 维持不批准，**A5 combined 未实现**。

---

## 0. 执行摘要

| # | 结论 | 强度 |
|---|---|---|
| 1 | **8 个 f1=0 局全部"机会饥饿"** —— Common 计数为 `3,0,1,0,1,0,1,0`，**0/8 达到 pity 修复阈值 4** | 强 |
| 2 | 🔴 **同产量下作用域几乎不影响结果** —— 目标 96 个 Common 时，L5-only / L4+L5 / 全层给出 `f1zero 3.80–3.86/8`、`elite 134–136`，**三者等价** | 强（配对对比） |
| 3 | 🔴 **L5-only 有硬上限**：81 + 23 可转换 = **104 个 Common 封顶**（share=1.0 也只有 104）⇒ 无法支撑大幅提升 | 强 |
| 4 | **四个方案材料件数恒为 389.0** —— 全部件数中性，"不增加固定产量"红线机械成立 | 强（不变量） |
| 5 | **Guards 才是有效杠杆**：`G2 floor K=4` 把 `f1zero` 从 2.72 提到 **7.13/8**、`shortZero` 4.92→**0.52**，代价 elite −27（150→123） | 强 |
| 6 | **时序-only 无法修复 f1=0**（2.72→2.72），只买到 `inWindow +1.65` ⇒ 顺序改不了计数 | 强 |
| 7 | 32 局语料**复现并加固**了 R7 的"份额悬崖"：L1 50.0% / L2 52.4% / L3 35.2% / **L4 17.0% / L5 11.5%** | 强 |

---

## 1. 语料扩展（16 → 32 局）

按 inbox §19 item 5，实际**执行**了验证批次（不只是写计划）：

| 批次 | 种子 | 局数 | 状态 |
|---|---|---|---|
| batch1（R5 原批） | 20260927 / 11 / 33 / 55 | 8 | 既有 |
| batch2（R6） | 101 / 202 / 303 / 404 | 8 | 既有 |
| **batch3（本次）** | 505 / 606 / 707 / 808 | 8 | ✅ 新增 |
| **batch4（本次）** | 909 / 1111 / 1212 / 1313 | 8 | ✅ 新增 |

- 每批 force ×4 + sword ×4；单局约 **8.5 秒**，16 局共约 **2 分钟**。
- 工具侧新增 `-Batch3` / `-Batch4` 开关（`tools/q8g_reachability5_tier_audit.ps1`）。
- **32 局汇总**：`f1_zero = 8` · `short (<15 战斗) = 14` · pooled 自然 f1 率 = **0.531**（28/32 局有 Common 胜场）。

### 1.1 逐层覆盖在 32 局上复现（R7 结论加固）

```text
L1: settled= 56  common=28  rate=50.0%
L2: settled= 42  common=22  rate=52.4%
L3: settled= 54  common=19  rate=35.2%
L4: settled= 53  common= 9  rate=17.0%   ← 悬崖
L5: settled= 26  common= 3  rate=11.5%   ← 最低
```

⇒ 样本翻倍后**形状不变**。"L4/L5 是份额悬崖、非零覆盖"从 16 局观察升级为 32 局稳健结论。

---

## 2. 🔴 核心事实：f1=0 局是"机会饥饿"

```text
f1=0 breakdown: short(<15) = 6, long = 2
  their Common counts: 3, 0, 1, 0, 1, 0, 1, 0   (repair needs >= 4 without a natural hit)
  => 0/8 can be repaired by pity alone.
```

**8 个失败局中，2 个连 1 个 Common 胜场都没有**，其余 6 个只有 0–3 个。**没有一个达到 pity 修复阈值 4**。

这解释了此前所有"为什么某些干预看起来有效"的现象：
`+L5` / `A2` 之所以能"修复"这些局，**不是**因为 pity 被触发，
而是因为干预**把 Common 数量推到了自然命中会发生的水平**。
⇒ **问题的度量单位是"每局 Common 胜场数"，不是"份额百分比"。**

---

## 3. 【inbox item 1】作用域裁定：L5-only / L4+L5 / 全层

### 3.1 方法：**同产量配对对比**

若不做配对，"改 L5"和"改全层"无法与"改得更多"区分开。因此对每个作用域，
**搜索使总 Common 数落到同一目标的份额**，再比较结果。

> 实现要点（踩过的坑）：每局的转换判定必须用**与 share 无关的稳定均匀数**。
> 若把 share 混进哈希种子，每个 step 都会重排全部战斗 ⇒ 实现数对 share **非单调** ⇒ 配对搜索失效。
> 已在 `stableUniform()` 中修正并注释。

### 3.2 结果

```text
--- target total Commons ≈ 96 ---
scope         share  commons  f1zero_fix  inWindow  shortZero   elite  curseLyr   notor
L5 only       0.758       96      3.81/8     20.14       4.00     135      67.5   135.0
L4+L5         0.172       97      3.86/8     21.09       3.78     134      67.0   134.0
all layers    0.144       95      3.80/8     21.22       3.84     136      68.0   136.0

--- target total Commons ≈ 111 ---
scope         share  commons  f1zero_fix  inWindow  shortZero   elite  curseLyr   notor
L5 only       0.990      104      4.02/8     20.14       3.84     127      63.5   127.0   ← 饱和
L4+L5         0.232      110      4.34/8     21.09       3.52     121      60.5   121.0
all layers    0.182      111      5.20/8     23.42       2.66     120      60.0   120.0
```

### 3.3 裁定建议

1. **同产量下三个作用域基本等价**（96 目标：`f1zero` 3.80–3.86、`elite` 134–136 全部落在噪声内）。
   ⇒ **作用域不是主要杠杆；总量才是。**
2. **L5-only 触顶**：`81 + 23 = 104` 个 Common 是硬上限（share=1.0 也只到 104）。
   ⇒ 若目标需要 >104 个 Common，**L5-only 在结构上做不到**，必须扩到 L4+L5 或全层。
3. **高目标的边际差异**（111 目标）指向：**全层的"分散"比 L5-only 的"集中"更能覆盖到饥饿局**
   （`f1zero` 5.20 vs 4.02；`shortZero` 2.66 vs 3.84）。但该差异处于抽样噪声边缘，**不足以单独定案**。
4. **同时满足"能做大事"与"不浪费"的形态是 `L4+L5` 或全层**；L5-only 只适合小幅补丁。

> ⚠️ **本节不批准任何数值**。`0.758` / `0.172` / `0.144` 等只是"达到某总产量所需的份额"，
> **不是平衡目标**，禁止写入生产配置。

---

## 4. 【inbox item 2】副作用接受度

### 4.1 精英成本暴露（从 `data/loot_tables.json` 真实读取）

```text
elite cost pool: backlash | notoriety
  -> per elite battle expect 0.50 curse layer(s) + 1.00 notoriety
```

即每场精英战斗期望带来 **0.5 层 `gu_erosion` 诅咒** 或等价地 **1.0 点 notoriety**（池权重 1:1）。

| 作用域（96 目标） | elite | curseLyr | notoriety |
|---|---|---|---|
| BASELINE | 150 | 75.0 | 150.0 |
| L5 only | 135 | 67.5 | 135.0 |
| L4+L5 | 134 | 67.0 | 134.0 |
| all layers | 136 | 68.0 | 136.0 |

⇒ **同等产量下三者副作用一致**（elite −10%）。这与 R7 中 `A2@0.75` 的 −71.6% 形成鲜明对比：
**R7 的巨幅副作用来自"加得太多"，不是来自"改错了地方"。**

### 4.2 Gu 期望

```text
gu_chance_pct: common 6  vs  elite 30
BASELINE guExp = 49.9   →   各作用域 46.0–46.5
```

⇒ 约 **−7%**，远小于 R7 中 `A2@0.75` 的 27→13（−52%）。**仍属"精英密度下降"的同一后果。**

### 4.3 材料品质带段（副作用中最容易被忽略的一项）

池权重实测：

```text
common pool: crude 98.3% / plain 1.7%
elite  pool: plain 73.3% / refined 25.3% / crude 1.3%
boss   pool: prized 57.4% / refined 40.4% / plain 1.1% / crude 1.1%
```

在 +15 目标下的件数分布：

```text
scope         pieces   guExp   crude   plain  refined  prized
BASELINE       389.0    49.9    83.3   113.0   101.9    90.8
L5 only        389.0    46.3    97.9   102.3    98.1    90.8
L4+L5          389.0    46.0    98.9   101.6    97.8    90.8
all layers     389.0    46.5    96.9   103.0    98.3    90.8
```

**读法**：
- **件数恒为 389.0** ⇒ 不增加固定产量（红线机械成立）。
- **`crude` 件数 83.3 → 97.9/98.9/96.9**，`plain` 与 `refined` 同步下降
  ⇒ 这是 **elite→common 转换把 `plain/refined` 段换成了 `crude` 段**。
- `prized`（boss）不变 ⇒ Boss 未受影响。

> **这是本次最需要在产品层面拍板的副作用**：材料**总数不变**，
> 但**高段材料占比下降**。若 1-B/1-C 的 promotion 链依赖 `plain/refined` 段材料，
> 本方案会**降低这些链的材料供给质量**。inbox 中的硬限"不得增加固定产量"满足，
> 但**"带段结构变化"是独立风险**，需与 1-B 的材料可达性结论对照后裁定。

### 4.4 接受度裁定建议

| 副作用 | 量级（96 目标） | 建议 |
|---|---|---|
| 材料件数 | **0%**（389.0 恒定） | 🟢 可接受（红线下） |
| Elite 成本暴露 | −10%（150→134–136） | 🟡 需产品确认：精英玩法密度下降 |
| Gu 期望 | −7%（49.9→46.0–46.5） | 🟡 同上，同源 |
| 材料带段 | `crude` +15pp，`plain/refined` 下降 | 🟠 **须与 1-B/1-C 材料可达性对照** |

---

## 5. 【inbox item 3】短局 opportunity guard 候选

### 5.1 设计约束

**不增加固定产量**。由于 `common.material_count == elite.material_count == 1`，
短局内的 `elite→common` 转换**件数中性** ⇒ 该转换合法，属**构成改变**而非产量增加。

### 5.2 候选与数据

```text
guard                 f1zero_fix  inWindow  shortZero   pieces   elite
BASELINE                  2.72/8     20.02       4.92    389.0     150
G1 floor K=2              6.20/8     23.72       1.44    389.0     138
G2 floor K=4 (pity)       7.13/8     25.19       0.52    389.0     123
G3 window >=1             2.72/8     20.77       4.92    389.0     150
G4 window >=2             2.72/8     20.77       4.92    389.0     150
```

- **G1（短局至少 2 个 Common）**：`f1zero` 2.72 → **6.20**，`shortZero` 4.92 → **1.44**，elite −12。
- **G2（短局至少 4 个 Common = pity 阈值）**：`f1zero` → **7.13**，`shortZero` → **0.52**，elite −27。
- **G3/G4（仅在 refinement 窗口内保证 K 个 Common，纯换位）**：
  **对 `f1zero` 零效果**，只买到 `inWindow +0.75`；**elite 完全不变量**。

### 5.3 裁定建议

1. **G2 是本轮最强杠杆**：几乎清零短局遗留（4.92 → 0.52），代价是 elite −18%（150→123）。
2. **纯"窗口换位"（G3/G4）无效** —— 与 §2 的机制一致：**顺序改不了计数**，饥饿局需要**更多 Common**。
3. **G1 是性价比点**：拿到 G2 约 87% 的 `f1zero` 收益，只付 elite −8%。
4. 建议把 **G1/G2 作为候选形态进入下一轮**，但**必须与 §4.3 的带段副作用一起评估**。

---

## 6. 【inbox item 4】refinement 时序候选

### 6.1 设计约束

**不增加节点、不修改正式地图** ⇒ 唯一合法操作是** redistribution（重排）**，且必须**多集守恒**（保持 Common 总数不变）。

> 实现要点（踩过的坑）：早期版本把所有 eligible 战斗重写为 `i < target ? common : elite`，
> 当 `target < 原 Common 数` 时**会丢 Common**（elite 反涨到 198）。已改为
> **先在窗口内放 `min(total, 窗口槽位)` 个，剩余 Common 放到窗口后最早的位置**，保证总数守恒。

### 6.2 候选与数据

```text
timing                f1zero_fix  inWindow  shortZero   pieces   elite
BASELINE                  2.72/8     20.02       4.92    389.0     150
T1 front-load all         2.72/8     21.67       4.92    389.0     150
T2 cluster pre-visit      2.72/8     21.67       4.92    389.0     150
```

### 6.3 裁定建议

1. **时序-only 对 `f1zero` 零效果**（2.72 → 2.72），两个候选都只买到 **`inWindow +1.65`**。
2. **T1 与 T2 在本语料上退化为同一结果** —— 说明在"不加节点"约束下，
   时序的自由度实质上只有**"前移"一个方向**，两个候选不构成真正的两个变量。
3. ⇒ **时序候选应作为"改善交付窗口"的辅助手段，不能作为修复 `f1=0` 的主手段。**
4. 红线复核：**未新增 refining 节点、未改地图拓扑、未改 pacing**；
   `elite` 与 `pieces` 均**严格不变量**（150 / 389.0），符合"多集守恒"证明。

---

## 7. 【inbox item 5】32+ 局验证

### 7.1 已执行

语料已从 16 局扩展到 **32 局**（batch3/batch4，见 §1），并在此语料上重跑了 R7 与 R7B 全部分析。
**§1.1 证实 R7 的逐层份额结论在 32 局上形状不变。**

### 7.2 后续验证计划（建议）

| 项 | 内容 |
|---|---|
| 语料 | **≥ 32 局**（已达）；建议再扩到 **48 局**（batch5/6）以压窄均值噪声 |
| 每批构成 | force ×N + sword ×N 对称，避免流派偏置 |
| 复现流 | 每候选 **≥ 64** 个确定性复现流；报告均值与 `min..max` |
| 必报指标 | `f1zero_fix` · `inWindow` · `shortZero` · `material pieces` · **带段分布** · elite / curse / notoriety |
| 接受门 | 件数必须恒等；带段变化必须显式列出；elite 成本变化必须标注 |
| 禁止 | 不写生产配置；不实现 A5 combined；不改 enemies tier / pacing / E6 / 地图 |

### 7.3 扩展命令（已可用）

```bash
# 生成新批次（每批 8 局，约 70 秒）
pwsh -File tools/q8g_reachability5_tier_audit.ps1 -Batch3
pwsh -File tools/q8g_reachability5_tier_audit.ps1 -Batch4
# 分析（自动适配语料规模）
node tools/q8g_reachability7_ashape_preflight.mjs
node tools/q8g_reachability7b_design_preflight.mjs
```

> ⚠️ **已知工具缺陷（未修，登记）**：`tools/q8g_reachability5_tier_audit.ps1` 通过
> `godot.ps1 -Console` 解析路径时 `$LASTEXITCODE` 为空，导致 `throw "sweep failed ... exit="` 误报。
> 本次改用**直接调用 Godot 二进制**的方式生成 batch3/batch4（已验证可行）。
> 修复前请按上表用直调方式，或修复该 wrapper 的退出码处理。

---

## 8. 未获批准 / 维持冻结

- ❌ `A5 combined`：**未实现**（需 A1–A4 单变量结论齐备并另行批准）
- ❌ `0.60` / `0.75` / `0.758` / `0.172` / `0.144` 等**任何份额数值**写入生产配置
- ❌ L4/L5 rank 放宽、enemy tier 重分类、pacing 修改、E6 weights 修改
- ❌ 新增 refinement 节点或地图拓扑改动
- ❌ `scripts/domain/**`、`data/**`、`scripts/presentation/**`、`tests/**` 任何改动

---

## 9. 交付物

| 文件 | 性质 |
|---|---|
| `tools/q8g_reachability7b_design_preflight.mjs` | **新增**，纯读，measurement-only |
| `tools/q8g_reachability5_tier_audit.ps1` | 追加 `-Batch3` / `-Batch4` 开关（行为向后兼容） |
| `tools/q8g_reachability7_ashape_preflight.mjs` | 修一个硬编码 `/16` 的显示 bug（语料已 32） |
| 32 局 R5 审计日志 | `<TEMP>/gu-zhenrens-r5-logs/`（16 局新增） |
| `docs/q8g/Q8G_REACHABILITY7B_ASHAPE_DESIGN.md` | 本文件 |

**冻结区在工作树中存在既有未提交改动**（ZCode 的 R5/R6 审计仪器），**非本次产物，亦未被本次触碰**。

---

**记录时间**：2026-09-13
**裁定状态**：**A 仍为 CONDITIONAL；B / C / D 维持不批准；生产规则冻结；A5 未批准**
