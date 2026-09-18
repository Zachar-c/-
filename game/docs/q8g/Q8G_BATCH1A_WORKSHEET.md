# Q8-G Batch 1-A：promotion 单流派技术垂直切片（施工单）

> ---
>
> # ✅ **1-A 已收口（2026-09-12）—— 🟢 Approved / Close**
>
> > **最终裁定（外部审阅者）**：**"Q8-G Batch 1-A：🟢 Approved / Close。可以提交。"**
>
> **本文件的阅读方式（重要）**：
>
> | 阅读目的 | 去哪里 |
> |---|---|
> | **要看 1-A 到底完成没有 / 验收结果** | 👉 **`docs/q8g/Q8G_BATCH1A_ACCEPTANCE_REPORT.md`（权威结论）** |
> | 要看**施工前**的原始验收意图与门禁设计 | 本文件（§1–§6 的 `[ ]` 清单是**施工前模板**，见下注） |
> | 要看裁定与修正来源 | `docs/q8g/Q8G_BATCH1A_RULING.md` |
>
> ⚠️ **本文件 §1–§6 中的 `[ ]` 复选框是「施工前模板」，不代表当前完成状态。**
> 它们是开工时设计的**验收意图清单**（"应该验证什么"），不是进度追踪。
> **真实完成状态以 `Q8G_BATCH1A_ACCEPTANCE_REPORT.md` §3 的 Gate 表为准**
> （Gate 1–7 **全部 ✅**，对应 23 tests / 107 asserts 全绿；全量 unit 1365/1365；
> 交互闭环 17/17 屏 `dead=[] no_ui_click=[] occluded=[]`）。
> 本文件 §7 末尾已附**最终状态表**。
>
> ### 🎯 收口边界（审阅者要求强守）
>
> > **"1-A = promotion 架构验证完成；不是 light 最终晋升谱系完成，也不是经济系统完成。"**
>
> **已完成**：`promotion` 作为独立 recipe kind 接入 refinement / preview / 执行 /
> save / 载入 / replay；Gate 7 证明其**未退化成 `advance` 别名**。
> **未进入**：1-B（19 流派谱系）· 1-C（战斗产石）· 1-D（掉落→UI）· 商店调整。
>
> ### 🔒 **保留 defect（不得因 1-A 成功而关闭）**
>
> > **"不要因为 1-A 已通过，就把'实例 rank 是否进入战斗/构筑能力计算'关掉。"**
>
> 已证：实例 rank **确实进入 `gu_value`**（⇒ 影响**经济层**，卖价随 rank 变化）。
> **未证**：实例 rank 是否进入**战斗 / 构筑能力层**。
> ⇒ 继续作为**独立 defect**（见 §7.1 登记表 #3）。
> 这个答案决定 `advance` 在《蛊路求真》里究竟是
> **"真正的蛊成长机制"** 还是 **"一种影响资产价值的培炼机制"**。
>
> ---
>
> ## 🟢 **已获开工批准（2026-09-12）—— D1–D7 全部闭合，可开工**
>
> **裁定记录**：`docs/q8g/Q8G_BATCH1A_RULING.md`
>
> | 修正 | 内容 | 落点 |
> |---|---|---|
> | **M1** | **1→5 链定义收紧**：每步 output 必须是**另一个 definition 蛊**（实例 Rank 连升 = advance 语义） | §1.0 / §2.4 |
> | **M2** | **新增闸门 7：语义隔离**（证明 `advance` ≠ `promotion`） | §3 闸门 7 |
> | **M3** | **成本红线改为"同目标蛊直取成本"**；无商店 offer 则**不做比较、不得伪造基准** | §3 闸门 6 |
> | **M4** | **`Q8G_BATCH0_RULING.md` 是唯一 normative source** —— 只读它，**不得再读旧审计结论作实现依据** | §0.3 |
>
> **D7 冻结链**（§6.3）：`light_atk_1_01_gu`(1) → `moon_glow_gu`(2) → `moon_shadow_gu`(3)
> → `light_atk_4_21_gu`(4) → `light_atk_5_03_gu`(5)
>
> ### 🔴 开工红线（审阅者原话）
>
> > **"现在可以改代码，但不要顺手修 light 免费 fixed、不要铺其他流派、
> > 不要碰战斗产石，也不要开始调商店。"**
>
> ### 🔒 成功标准（审阅者原话）
>
> > **1-A 的成功标准不是"做出一条 1→5"，而是证明 `promotion` 作为一种独立 recipe 语义，
> > 能够在现有 refinement / preview / save / replay 架构里成立，同时不会把 `advance` 混回去。**

> - **裁定**：外部审阅者判 Batch 1 为 **🟡 Approved with mandatory staging adjustment**；
>   Batch 1-A 本身 **🟢 批准开工**（含上述 4 项修正）→ 收口时升为 **🟢 Approved / Close**
> - **依据**：`docs/q8g/Q8G_BATCH0_RULING.md`（语义冻结，**唯一权威**）
> - **状态**：✅ **已完成并收口**（见文件头横幅 + §7 最终状态表）
> - **范围**：**只做一条 1→2→3→4→5 垂直链**，验证 schema 不返工
> - **前置**：✅ **§0.3 更正回写已完成**（见 §0.3 清单，13 处全 ✅）

---

## 0. 前置：开工前必须处理的实测冲突

> ## 🔒 **M4：读取纪律（强制）**
>
> ```text
> Q8G_BATCH0_RULING.md    ← ✅ 唯一 normative source，实现只能依据它
> docs/q8f/**             ← ⚠️ 审计记录，含已被推翻的旧事实，禁止作为实现依据
> ```
>
> **具体禁令**：**不得**从 `docs/q8f/` 任何文件引用"advance 不升转"或"sword 零成本"。
> 需要这两条事实时，**只读 `Q8G_BATCH0_RULING.md` §13**。
>
> **理由（审阅者原话）**：老文档保留旧事实作审计记录，新文档才是真相 ——
> **最危险的不是代码错，而是 Agent 搜到旧内容后又把"advance 不升转"当成事实。**

### 0.1 已核实的新事实（本文件新增证据）

用只读探针（真实 `Resolver` 调用，固定种子，跑完即删）实测，得到三条**与本项目既有文档冲突**的事实。

#### ⚠️ 更正一：`advance` **确实会升转**，且这是**有意的**

**探针证据**：

```
[PROBE1] small_light_gu 定义 rank = 1
[PROBE1] 构造后实例 rank = <无 rank 键>
[PROBE1] ok = true
[PROBE1] 输出实例 gu_002 def=small_light_gu rank=2      ← 升转了
[PROBE2] new_run 后实例 keys=[..., "rank", ...] rank=1    ← 正常途径带 rank=1
```

**代码证据**（`refine_command_rules.gd:229-232`）：

```gdscript
if is_advance:
    # 同名升阶：本体进阶不换名，阶数 +1（封顶五转）
    output_instance["rank"] = mini(int(instances[str(preselected[0])].get("rank", 1)) + 1, 5)
```

**数据证据**：

| advance 子集 | 条数 | 输入蛊定义转数 | `input_min_rank` |
|---|---|---|---|
| A | 220 | 1 | 无 |
| B | 157 | 2 | 2 |

**真相**：`advance` 的**输入与输出是同一只蛊的"实例"**，转数 +1（封顶 5）。
「输入输出转数相同」是**用定义（JSON）转数对比得出的假象** ——
220 条对比的是 `gu.json` 里 `small_light_gu.rank=1` 与其自身；
而**实例**转数在 refine 后变成了 2。157 条的 `input_min_rank=2` 正是"必须已升到 2 转才可再升"的守卫。

> **结论**：`advance` **不是坏数据**，它是**唯一在运行的升转机制**，而且**成本可见**（6/10 石 + 材料）。

#### ⚠️ 更正二：13 条 `fixed` **并非零元石**（之前记录有误）

实测全部 13 条可升转 `fixed` 的成本：

| recipe | 输入 | 输出 | 目标转 | 元石 | 材料 |
|---|---|---|---|---|---|
| `moon_ray_forged` | moonlight_gu + small_light_gu | moon_ray_gu | 2 | **(无)** | (无) |
| `moon_glow_fixed` | moonlight_gu + small_light_gu ×2 | moon_glow_gu | 2 | **(无)** | (无) |
| `moonlight_glow` | moonlight_gu + small_light_gu | moon_glow_gu | 2 | **(无)** | (无) |
| `white_jade_advance` | jade_skin_gu + white_boar_strength_gu | white_jade_gu | 2 | **50** | boar_king_tusk ×1 |
| `white_jade_basic` | jade_skin_gu + white_boar_strength_gu | white_jade_gu | 2 | **50** | (无) |
| `blood_moon_forged` | moon_ray_gu + blood_atk_1_08_gu | blood_atk_3_11_gu | 3 | **(无)** | (无) |
| `moon_shadow_locked` | moon_glow_gu + qi_mov_1_07_gu | moon_shadow_gu | 3 | **(无)** | (无) |
| `stone_shell_bone_forge` | (无蛊，直造) | stone_shell_gu | 1 | (无) | beast_bone ×2 |
| `ascend_sword_atk_1_05_gu` | sword_atk_1_05_gu | sword_atk_2_12_gu | 2 | **12** | beast_bone ×1 |
| `ascend_sword_atk_1_06_gu` | sword_atk_1_06_gu | sword_atk_2_13_gu | 2 | **12** | beast_bone ×1 |
| `ascend_sword_def_1_07_gu` | sword_def_1_07_gu | sword_def_3_14_gu | 3 | **24** | beast_blood ×1 |
| `ascend_sword_mov_1_08_gu` | sword_mov_1_08_gu | sword_mov_3_15_gu | 3 | **24** | beast_blood ×1 |
| `ascend_sword_heal_1_09_gu` | sword_heal_1_09_gu | sword_heal_4_16_gu | 4 | **40** | venom_sac ×1 |
| `ascend_sword_rec_1_10_gu` | sword_rec_1_10_gu | sword_rec_5_17_gu | 5 | **60** | boar_king_tusk ×1 |

**更正**：
- ❌ 旧记录「13 条全部 `stone_cost` 缺失 → 不花元石」→ **只有 5 条真正无成本，9 条有成本**。
- ❌ 旧记录「`ascend_sword_rec` 零元石零材料一步 1→5」→ **实为 60 石 + 1 獠牙**。

> **影响**：`EXTERNAL_REVIEW_RULING.md` §6.6「sword 1→5 零成本异常」的**前提不成立**。
> 加成本这件事**已经是现状**（60 石 + 獠牙）。真正的问题只剩**对称性**（16 流派没有对应链）。

#### ⚠️ 更正三：真实的不对称在 **light 系 5 条免费 `fixed`** 上

| 组 | 条数 | 元石成本 |
|---|---|---|
| **sword** | 6 | 12/12/24/24/40/60 + 材料 ✅ 有成本（全库最完整梯度） |
| **light 免费组** | **5** | **0 石 0 材料** ❌ ← **真正的漏洞** |
| light/earth 有成本组 | 3 | `white_jade_advance`/`basic` 50 石、`stone_shell_bone_forge` 2 骨 |
| 其余 16 流派 | 0 | — |

> **免费组明细**（`moon_glow_fixed` / `moon_ray_forged` / `moonlight_glow` → 2 转；
> `blood_moon_forged` / `moon_shadow_locked` → **3 转**）：
> 后者两条 **0 成本直达三转**，是本批最需要处理的条目。
>
> **结论**：审查红线（"低转蛊成本效率"）面临的风险**不是 sword 太便宜**，
> 而是 **light 系 5 条 `fixed` 完全免费**。

### 0.2 这些更正对已有文档的影响

| 文档 | 受影响表述 | 处置 |
|---|---|---|
| `docs/q8f/ECONOMY_CURRENT_AUDIT.md` | §4「稀有度…」无影响 | — |
| `docs/q8f/PROMOTION_ECONOMY_AUDIT.md` | **§0.1 事实 A（377 不升转）**、**§2.2（sword 零元石）** | ✅ **已更正**（头部横幅 + §0.2 内联） |
| `docs/q8f/EXTERNAL_REVIEW_RULING.md` | **§2.4（advance 不升转）**、**§6.6（sword 1→5 零成本）** | ✅ **已更正** |
| `docs/q8f/Q8F_RETROSPECTIVE.md` | **§2 #7 晋升链闭合**（判据依据部分失效） | ✅ **已复核**（判定不变） |
| `docs/q8f/review/01 / 03 / 04 / MAIN` | 头部事实 4、判据 #7、附录 D.3 | ✅ **已更正** |
| `docs/q8g/Q8G_BATCH0_SEMANTICS_WORKSHEET.md` | Q4 表、Q4.2、Q5.5、Q5.6 | ✅ **已更正** |
| `docs/q8g/Q8G_BATCH0_RULING.md` | **§5（advance=同名培炼）**、**§6.6** | ✅ **已更正**（横幅 + §13） |

> **注意**：这不否定 Batch 0 的**方向**（advance 与 promotion 语义分离），
> 但**改写了理由**：拆分的依据不是"advance 是坏数据"，而是
> **"advance 承担的是**实例培炼**，而 play 需要的是**跨蛊系的定向晋升**"**。
>
> 且**升转覆盖已经比想象的好**（377 条 advance 全覆盖转 1/2 蛊的实例升转），
> 这**降低了** Batch 1-B 的紧迫性。

### 0.3 开工前清单（硬门槛）—— ✅ **已全部完成（2026-09-12）**

- [x] **把 §0.1 三条更正回写** `Q8G_BATCH0_RULING.md`（§5 / §6.6 横幅 + **§13 正文**）
- [x] 同步更正 `EXTERNAL_REVIEW_RULING.md` §1.1 / §2.4 / §6
- [x] 在 `PROMOTION_ECONOMY_AUDIT.md` 顶部加「已更正」标注（保留原文作记录）
- [x] 重新评估 `Q8F_RETROSPECTIVE.md` §2 #7「晋升链闭合」的判定（判定不变，理由已改）
- [x] 复核 `AGENTS.md` 的"当前待办"（不含 Q8-F 事实，无需改动）
- [x] **附加**：`review/01_HEADLINE_FACTS.md`、`review/03`、`review/04`、
      `Q8G_BATCH0_SEMANTICS_WORKSHEET.md`、`Q8F_REVIEW_PACK_MAIN.md` 一并标记

> **回写清单共 13 处，已全部处理**（明细见 `Q8G_BATCH0_RULING.md` §13.4）。
> **D2 问题已消解**：更正先于施工，事实基础现已一致。
>
> ⚠️ **但 D1 / D3 / D4 / D5 / D6 仍未裁定**，见本文件 §6 —— **定档前不写生产代码**。

---

## 1. Batch 1-A 的唯一目标

> ## 验证：**一条完整的 1→2→3→4→5 promotion 链，能让现有 recipe/resolver/snapshot/save 系统跑通，且不需要返工 schema。**

**不是**：
- ❌ 铺满 20 流派（那是 1-B）
- ❌ 战斗产石（那是 1-C）
- ❌ Boss/Elite 获取（那是 1-D）
- ❌ 调平衡

### 1.0 ⭐ **M1 修正：1→5 链的严谨定义（不得歧义）**

原表述"一条完整 1→2→3→4→5 promotion 链"**存在两种读法**，**其中一种是错的**：

| 读法 | 内容 | 裁定 |
|---|---|---|
| **(a)** | 某只蛊的**实例 Rank 连续可升**（同一 definition，rank 1→2→3→4→5） | 🔴 **错误** —— 这**正是 `advance` 的语义**，会立刻混淆两者 |
| **(b)** | **每一步 output 都必须是下一 Rank 的另一个定义蛊** | 🟢 **正确**（本 1-A 采用） |

**依据**：Batch 0 冻结的 promotion 语义是 **`Rank N 某类蛊 → 指定 Rank N+1 候选`**（跨定义）。

**1-A 必须构造的链（读法 b）**：

```text
Rank 1 instance（definition A）
   ↓ promotion recipe #1
Rank 2 target Gu（definition B ≠ A）      ← 换 definition
   ↓ promotion recipe #2
Rank 3 target Gu（definition C ≠ B）      ← 换 definition
   ↓ promotion recipe #3
Rank 4 target Gu（definition D ≠ C）      ← 换 definition
   ↓ promotion recipe #4
Rank 5 target Gu（definition E ≠ D）      ← 换 definition
```

**必须避免的链（读法 a = advance）**：

```text
某只蛊 instance rank 1
   ↓
同一个 definition rank 2      ← ❌ 这是 advance，不是 promotion
   ↓
同一个 definition rank 3
```

> ### 门禁
> 链上**每一条** promotion recipe 必须满足：`output_gu_id != input_gu_ids[0]`。
> 若某一步 `output_gu_id == input_gu_ids[0]`，**该步必须改用 `advance` kind，不得写 `promotion`**。

### 1.1 为什么必须先切这一刀（审阅者理由）

> 当前最大未知量**不是"80 条数据能不能写出来"**，
> 而是 **"promotion 的数据表达是否真的适合现有 recipe 系统"**。
>
> 第一条 promotion 链实际上是一个**架构原型**。

> **好处**：任何一个 schema 错误都只会影响一个小切片，
> **而不会炸掉 80 条配方 + Loot + UI**。

### 1.2 审阅者给出的推进方式（据此定 A / B）

审阅者观察到：`gu.json` 里有大量蛊**本质上已经是**某只 1 转蛊的实例升阶产物
（`small_light_gu` → `moon_glow_gu` 等）。

> **这可以先把"1 转蛊 → 2 转蛊"的 promotion 先落在这些已有关系上**，
> 不必等 20 流派全铺。

---

## 2. 选型：用哪个流派做垂直切片

### 2.1 候选评估

| 流派 | rank 分布 | 现有 fixed 链 | 现成 1→N 关系 | 评估 |
|---|---|---|---|---|
| **sword** | 1:11 / 2:9 / 3:8 / 4:5 / 5:7 | **6 条**（12/24/40/60 石） | ✅ 完整 1→2→3→4→5 | ⚠️ **已被 fixed 占用**；且成本已正常 |
| **light** ✅**选定** | 有 1–5 | 3 条（**免费**） | ✅ moonlight→moon_glow→moon_shadow | ✅ **advance 关系现成**；免费 fixed 可作**异常对照样本** |
| **earth** | 有 1–5 | 2 条（免费） | ✅ jade_skin+white_boar→white_jade | ✅ 关系现成（次选） |
| **blood** | 有 1–5 | 1 条（免费） | blood_atk_1_08→blood_atk_3_11 | 🟡 仅 2→3 |

### 2.2 ✅ **D1 已裁定：选 `light`**（审阅者第四次裁定）

**理由不是"light 更简单"**，而是它适合做真正的**垂直 schema 验证**：

```text
small_light_gu
   ↓
moon_glow_gu
   ↓
moon_shadow_gu
   ↓
Rank 4 light
   ↓
Rank 5 light
```

1. **advance 关系现成**：`small_light_gu`(1) → `moon_glow_gu`(2) → `moon_shadow_gu`(3) 已是既有现实；
   探针 PROBE1 已实测 `small_light_gu` advance 到 rank 2 → 与 `moon_glow_gu` 的 tag 一致。
2. **最大限度利用真实数据**验证新 promotion 语义（light 有现成 1→2→3 关系）。
3. **附带价值**：light 的免费 `fixed` 恰好可作为**异常对照样本**。
4. **非 sword**：避开已被 6 条 fixed 占用的流派，验证的是**新增能力**而非既有能力。

> ### 🔒 **但 1-A 不修 light 免费 `fixed`** —— 正式冻结为 **"不属于 1-A；仅登记 defect"**（见 §6 D3 / §5 / §7.1）

**次选 `earth`**：同样有现成关系，且只有 2 条 fixed，切面更小（本批不采用）。

### 2.3 ⚠️ **开工前必读：`light` 没有现成的 4/5 步链（2026-09-12 二次核实）**

> 这是对 §2.2 理由 2"light 有现成 1→2→3 关系"的**边界澄清**。
> **结论：light 的"现成关系"只到 3 步，且不是连续转数。**
> 这不推翻 D1 裁定（1-A 本来就要**新建** promotion recipe），但**必须先知道要建多少**。

**实测 `light` 全部 40 只蛊的转数分布 + 最长递增链**：

| role 前缀 | 最长链 | 明细 |
|---|---|---|
| `light_atk` | **3 步** | seq1:r1 → seq2:r3 → seq3:**r5**（**跳过 r2/r4**） |
| `light_rec` | 3 步 | seq7:r3 / seq8:r5 / seq9:r3（**非单调**） |
| `light_mov` | 3 步 | 全部 rank 1（seq16/23/30）**无递增** |
| `light_log` | 3 步 | 全部 rank 3（seq19/26/33）**无递增** |
| `light_heal` | 3 步 | 全部 rank 2（seq17/24/31）**无递增** |
| `light_def` | 3 步 | seq15:r1 / seq22:r5 / seq29:r5 |
| **moon 系**（非编号） | **3 步** | `small_light_gu`(1) → `moonlight_gu`(1) / `moon_glow_gu`(2) / `moon_ray_gu`(2) / `moon_shadow_gu`(3) —— **止步 rank 3** |

> **即：`light` 内不存在 `r1→r2→r3→r4→r5` 的自然链。最长的 `light_atk` 是 1→3→5（跳级）。**

**全库横向对照**（同法扫描 802 只蛊）：

| 结果 | 数量 |
|---|---|
| 能达到 **5 步** rank 递增链的 role | **仅 2 个**：`human_atk`（1→2→3→4→5）、`force_atk`（1→2→3→4→5） |
| 能达到 4 步的 role | 5 个（`wisdom_atk` / `slave_atk` / `gold_atk` / `human_atk` / `force_atk`） |

> ⚠️ **重要背景**：**全库没有任何 4/5 步链是被现有 recipe 覆盖的**——
> 这正是 Q8-F 审计的原始结论（升转链只 4 流派、424 只高转蛊无配方）。
> **所以 1-A 的 4 条 promotion recipe 必然是"新造内容"，不是"发现既有关系"。**

**对 1-A 的实际影响**：

- [ ] 1-A 的 1→5 链**由我们新写 4 条 promotion recipe 构成**（不是复用既有 fixed）；
- [ ] **每一条的 `input` / `output` 都要选定具体蛊** → 这是**内容决策**，需在开工前定档；
- [ ] 可选策略（**待用户裁定，见 D7**）：
  - **(a) 用 `moon` 系延展**：`moon_shadow_gu`(3) 之上**新造** r4/r5 —— 但会**新增 gu 定义**（体量大）
  - **(b) 用 `light_atk` 跳级链**：`light_atk_1_01`(1) → `light_atk_3_02`(3) → `light_atk_5_03`(5) ——
        只 **2 条** promotion，但**违反"每步 +1 转"**（除非承认 promotion 可跨转）
  - **(c) 用 `light` 内既有的 r1/r2/r3/r4/r5 蛊自由组合**：不需要新定义，但 lineage 靠 recipe 声明

> **推荐 (c)**：不新增 gu 定义（守住 M4/审阅者"不扩内容分类系统"的精神），
> 用 light 现有的 `light_atk_1_01`(1) → `light_atk_3_02`(3) 不满足 +1，
> 故改取 `light_atk_1_01`(1) → `moon_glow_gu`(2) → `moon_shadow_gu`(3) → `light_atk_4_21`(4) → `light_atk_5_03`(5)，
> **每步 +1 且全部是 light 既有蛊**。**此链需你确认。**

> **决策点 D7**：1-A 的 1→5 链取哪 5 只蛊？（见 §6.3）

---

## 3. 1-A 验收清单（**七个闸门** —— Gate 7 为第四次裁定新增）

> > ### ⚠️ **以下 §3 的 `[ ]` 是「施工前模板」，不是进度追踪**
> >
> > 它们是开工时设计的**验收意图清单**（"应该验证什么"），刻意保留以便回溯设计意图。
> > **不要拿它们判断"完成没"** —— 真实状态见 **§7 末尾的最终状态表**，
> > 权威验收结论见 **`Q8G_BATCH1A_ACCEPTANCE_REPORT.md`**。
> >
> > **一句话结论**：**Gate 1 / 2 / 3 / 4 / 5 / 6 / 7 全部 ✅ 通过。**

### 闸门 1：Schema 不返工 【核心】

```
新增 kind: "promotion" 的一条链，落在现有 refinement_recipes.json
  ↓
不改现有 recipe 字段语义
  ↓
content_catalog.validate 通过
```

**必须回答**：
- [ ] 新增 `"promotion"` kind 是否需要**改动 `content_catalog` 白名单**？（**AGENTS.md 红线**）
  > 现有代码：`refine_command_rules.gd:81` 的 `match` 有 `"fixed", "advance"` / `"free_mix"` / default；
  > `content_catalog.gd:750` 的 curated-source 校验只列了 `["fixed","free_mix"]`。
  > → **新增 kind 需两处同步**（match 分支 + 白名单）。
- [ ] 是否**不新增任何 `gu.json` 字段**？（**审阅者明确 🔴 禁止 `gu_family_id`**）
  > **"蛊系"先作为语义概念**，用 `input_gu_ids` / `output_gu_id` / `school` 表达 lineage。
- [ ] ⭐ **M1 门禁入校验**：`promotion` recipe 必须满足 **`output_gu_id != input_gu_ids[0]`**
  > **若相等 → 校验必须拒绝**（该关系应改用 `advance`）。
  > 理由：这是**闸门 7 语义隔离**在 schema 层的静态保证（见 §1.0）。

### 闸门 2：执行正确

```
Rank 1 蛊（definition A）+ 指定材料 + 元石
  ↓
产出 Rank 2 蛊（definition B ≠ A，正确 definition_id 与 rank）
  ↓
Rank 1 实例被消耗、从 cave_aperture 移除
```

- [ ] 产出蛊的 `definition_id` **≠ 输入 definition**（M1）与 `rank` 正确
- [ ] 输入实例 `state = "consumed"` 且从 `stored_gu_instance_ids` 移除
- [ ] 元石与材料正确扣除
- [ ] **预检顺序正确**（缺料/容量/rank 门禁**先于**烧材料 —— 参考现有 `advance_capped` 教训）

### 闸门 3：Preview ≈ Execution

- [ ] `action_preview_service.gd:413` 的 `match str(recipe.get("kind"))` **新增 promotion 分支**
- [ ] 预览显示的产出/成本与执行结果一致

### 闸门 4：确定性

- [ ] 同 seed → 同 promotion 可见性 → 同结果
- [ ] 两次运行输出逐字一致（沿用 F8 的验证方式）

### 闸门 5：Save / Load / Replay

- [ ] 存盘 → 读盘 → promotion 产出的蛊实例（含 rank）不丢
- [ ] **先检查 save payload 是否持久化 `recipe kind`**
  > **D5 已裁定**：**只有兼容性被实际破坏时才升 `SAVE_VERSION`。**
  > - 若存档只保存 `recipe_id` / instance state / rank → **不升**
  > - 若**直接持久化 recipe kind** 且旧加载器无法识别 `promotion` → **必须升**
  >
  > 🔴 **不要为了一个新 JSON 枚举值机械升存档版本。**

### 闸门 6：成本红线（任务书 §六）—— ⭐ **M3 修正**

> ## ⚠️ 原表述"总成本 < 直接购买**同级**高转蛊"**不够精确**，已修正。
>
> **1-A 选 light 后，不得拿 sword 的 `purchase_sword_atk_2_12 = 18` 当主要验证对象**（那是另一个蛊系）。

**修正后的红线定义**：

```text
同目标蛊 / 同 Rank / 同可用渠道的最低直接取得成本

即：promotion_total_cost(target_gu)  <  direct_acquisition_cost(target_gu)
```

`direct_acquisition_cost` 可来自**现有商店直接 offer**。

- [ ] 对**每个 target Gu** 单独计算 `direct_acquisition_cost`（**同蛊、同 rank、同渠道**）
- [ ] **无商店 offer 的 target Gu → 该条 promote 暂不执行红线比较**
- [ ] 🔴 **不得伪造基准**（不得随便找一个同 Rank 商品来比较以"满足"红线）

---

### ⭐ 闸门 7：**语义隔离**（Gate 7，第四次裁定新增）

> ## **这是整个 Q8-G 的核心。必须证明 `advance` ≠ `promotion`。**

**必须验证的两条不变量**：

```text
advance
→ 同 definition，instance.rank +1
→ output_gu_id == input_gu_ids[0]

promotion
→ 消耗输入 Gu instance
→ 产出指定 target definition（output_gu_id != input_gu_ids[0]）
→ target rank = input rank + 1
```

- [ ] 构造一组**对照测试**：同一输入蛊，分别走 `advance` 与 `promotion`，断言产出**不同**
  （`advance` 保留 definition，`promotion` 换成 target definition）
- [ ] 断言 `promotion` **确实消耗**输入实例（`state == "consumed"` + 从 `cave_aperture` 移除）
- [ ] 断言 `promotion` 产出实例的 `rank == 输入 rank + 1`
- [ ] **反例测试**：若某条 promotion recipe 写成 `output_gu_id == input_gu_ids[0]`，
      必须**被校验拒绝**（或明确要求改用 `advance`）

> **目的**：证明 Batch 1-A **不是"给旧 `advance` 换一个名字"**。

---

## 4. ⚠️ 顺带必须处理：`advance` 的可测成长（审阅者的硬门槛）

### 4.1 审阅者要求（原文要点）

> 「存在一个字段发生变化」≠「玩家真的获得成长」。
> 如果只是数据变化，而 Resolver / 预览 / 战斗 / 构筑**没有读取它**，
> 那实际只是"改了一项没人消费的数据"。
>
> **Batch 1 必须新增一条：`advance` 的增强必须至少有一个已验证的生产消费者。**

### 4.2 ⚠️ 但本文件的实测发现改变了这个问题的形态

**探针 + 代码证据表明**：`advance` 的增强**已经是可测的** —— 它就是 **实例转数 +1**：

| 消费点 | 是否读取实例 rank | 证据 |
|---|---|---|
| `refine_command_rules.gd:210,232` | ✅ | `advance_rank` 门禁 + `rank = min(rank+1,5)` |
| `GuBalance.gu_value` | ✅ | `max(字面 value, gu_value_by_rank[rank])` → **卖价随实例 rank 变化** |
| `_selected_input_instance_ids` | ⚠️ | 待验证 |

> **含义**：§4.1 的担忧（"改了没人消费的数据"）**大概率不适用于 `advance`**，
> 因为实例 rank **确实被 `gu_value` 消费**（升转后卖价翻倍：3 → 5）。
>
> **但仍需验证**：实例 rank 是否被**战斗 / 构筑**消费？
> 若只被 `gu_value`（定价）消费、不被战斗消费，则"培炼"仍只是**经济符号**而非**战力成长**。

### 4.3 ⭐ **M2 修正后的结论措辞**

> ## ✅ **`advance` 已确认是"实例升转机制"；尚待确认实例 rank 是否参与战斗构筑能力计算。**
>
> （**替代**原措辞"可能没有真实成长" —— 该措辞已过时。）

**审阅者明确保留这项验证**：

> "仍然要保留施工单的验证：**战斗 / 构筑到底有没有读取实例 rank。**
> 这是一个非常好的独立诊断，**不要因为 `gu_value` 已经读取就把它删掉**。"

### 4.4 1-A 必须做的验证

> > ### 🔒 **本项在 1-A 收口后仍保持开启 —— 未被 1-A 解决**
> >
> > 状态：**实例 rank → 经济层（`gu_value`）✅ 已证**；
> > **实例 rank → 战斗/构筑能力层 ❓ 未证**。
> > 归属 defect #3（见 §7.1），**不得因 1-A 通过而关闭**。
> > 审阅者收口裁定原话：**"不要因为 1-A 已通过，就把'实例 rank 是否进入
> > 战斗/构筑能力计算'关掉。"**

- [ ] **追踪实例 rank 的全部消费点**（战斗 / 构筑 / 预览 / 快照 / 估价）→ ❓ **未完成，保持开启**
- [ ] 若战斗不消费实例 rank → **这是一个独立的缺陷**，登记但**不在 1-A 修** → ✅ 已登记为 defect #3
- [ ] 明确写入文档：`advance` 的成长**已确认**影响经济层（卖价随 rank 变化）；
      **是否影响战力层待定** → ✅ 已写入（本注 + 验收报告 §7）

---

## 5. 明确不做（1-A 期间）

| ❌ | 归属 |
|---|---|
| 铺 20 流派 × 4 跃迁 | Batch 1-B |
| 战斗产石 | Batch 1-C |
| Boss 配方线索 / Elite 定向候选 | Batch 1-D（**先 domain 后 UI**） |
| 新增 `gu_family_id` | 🔴 **审阅者明确禁止** |
| `stone_budget` / `free_pair` / `SoulRules` | 🔴 不得接 |
| 商店改价 | 🔴 Batch 2（先修 `gu_value`） |
| 数据垃圾清理 | Batch 4 |
| **修 light 免费 `fixed`（5 条）** | 🟡 **登记 defect，不在 1-A 修**（见 §6 D3 / §7.1） |

---

## 6. 决策点裁定结果（第四次裁定，全部已决）

| # | 事项 | **裁定** |
|---|---|---|
| **D1** | 用 `light` 还是 `earth` 做 1-A 垂直切片？ | 🟢 **`light`**（§2.2） |
| **D2** | 是否先完成 §0.3 的更正回写再开工？ | ✅ **已消解**（§0.3 全部完成） |
| **D3** | light 的 **5 条免费 fixed** 是否在 1-A 加成本？ | 🟡 **不加，登记 defect**，后续 promotion/content cleanup 处理 |
| **D4** | `promotion` 落在哪？ | 🟢 **A：复用 `refinement_recipes.json`，新增 `kind: "promotion"`**（**不新建文件**） |
| **D5** | `SAVE_VERSION` 是否升版？ | 🟡 **按实际兼容性决定**（先查 payload 是否持久化 kind；**不机械升级**） |
| **D6** | 实例 rank 是否被**战斗**消费？ | 🟡 **转为 Gate 7 的验证项**（不再作为"待裁定"；结论措辞已按 §4.3 改写） |
| **D7** | 1-A 的 1→5 链取哪 5 只蛊？ | ✅ **批准方案 C**（见 §6.3，冻结链 + 静态校验锁死） |

### 6.1 D4 补充理由（审阅者原话要点）

> `advance` / `fixed` / `free_mix` 都已在这套领域里。本次要修的是
> **"recipe kind 的语义边界"**，**不是建立另一套 Recipe Repository**。
>
> 且这正好验证 `refine_command_rules.gd` / `action_preview_service.gd` / catalog validation
> **能否同时接受新 kind** —— 这正是 1-A 要验证的 schema 问题。

### 6.2 D3 补充理由（审阅者原话要点）

> 这样 1-A 才能回答一个**非常纯粹**的问题：**"新 promotion kind 能不能跑通？"**
> 而不是"promotion 能不能跑通，同时顺便重新设计 light 的历史 recipe"。
>
> ⚠️ 否则 1-A 会悄悄变成 **`promotion schema` + `免费 fixed 重构`** —— **这就开始膨胀了。**

### 6.3 ✅ **D7 已裁定：批准方案 C**（第五次裁定，2026-09-12）

依据 §2.3 的扫描：**light 无现成 4/5 步链**，故 4 条 promotion recipe 属**新造**。
三策略中**已正式批准 (c)**：

| 策略 | 裁定 |
|---|---|
| **(a)** 延展 moon 系（新造 r4/r5 定义） | ❌ **否决** —— 1-A 目标是验证 schema，**不是扩大内容库**；会新增 2 个 definition，扩大 catalog/验证/维护面 |
| **(b)** 用 `light_atk` 跳级链 1→3→5 | ❌ **否决** —— 违反已冻结的 `promotion = Rank N → Rank N+1`，会把"可跨转"新语义**偷塞进 1-A**（属架构变更） |
| **(c)** 既有蛊组合，每步 +1 | ✅ **批准并冻结** |

#### 🔒 **D7 冻结链（1-A 期间不可更改）**

```text
light_atk_1_01_gu   Rank 1
   ↓ promotion
moon_glow_gu        Rank 2
   ↓ promotion
moon_shadow_gu      Rank 3
   ↓ promotion
light_atk_4_21_gu   Rank 4
   ↓ promotion
light_atk_5_03_gu   Rank 5
```

**满足**：不新增 `gu.json` 字段 ✓ · 不新增 Gu definition ✓ · 每步严格 +1 ✓ ·
每步换 definition ✓ · 全部 light ✓ · lineage 由 recipe 表达 ✓

> **审阅者结论**：**"最低风险、最高信息量的 schema 实验。"**

#### 🔒 **静态校验锁死（审阅者特别强调，不得删）**

```text
output_gu_id != input_gu_ids[0]
```

**正例 + 反例都要测**：

```text
promotion: input = A, output = A
→ validation reject
```

> **目的**：**"以后任何人误把 `advance` 配方复制成 `promotion`，
> 会在 catalog / schema 层直接失败，而不是运行时才发现语义混乱。"**

#### ⚠️ **边界提醒（审阅者原话）**

> **"这次不是在'设计一条合理的最终游戏配方'。"**
> D7 的目的是**"制造一条最小、真实、可运行的 promotion 垂直链"**，
> 所以**"跨 role"并不构成问题**。
> 等 1-A 跑通后，**Batch 1-B 才讨论**"每个流派应该怎样建立**有世界语义的晋升谱系**"。
>
> 🔴 **不能拿垂直切片的实验链反向定义最终内容设计。**

---

## 7. 施工顺序（已批准，含 Gate 7）

> ### ✅ **执行状态（2026-09-12 收口）—— Gate 1 / 2 / 3 / 4 / 5 / 6 / 7 全部落地**
>
> 单测：`tests/unit/test_v3_promotion.gd` **23 tests / 107 asserts 全绿**。
> 全量 unit：**1365/1365 通过**（196 scripts，158s）。
> 行为保持：`fixed` / `advance` / `shop` / `preview` 既有套件 **43/43** 无回归。
>
> 过程中**由测试反向暴露 2 个既有缺陷**（非 promotion 独有，见 §7.1 第 5、6 项），
> 均属"看得见做不到 / 校验 A 消耗 B"透明度红线，已在 1-A 内一并修掉：
>  · **#5** `transaction_ledger` 只认 definition、忽略调用方选中的实例 id
>    → 新增 `consume_instance_id_list` + `consume_instance_ids` 参数（缺省空 ⇒ 原语义）。
>  · **#6** 预览**从不读 `input_min_rank`** → `_append_recipe_card` 增 `_lowest_selected_rank`
>    判定（对所有带 rank 门禁的配方生效，不只 promotion）。
>
> D5 已核：promotion 不新增存档键，`SAVE_VERSION` **保持 4 不抬**；升后的实例 rank
> 经 `serialize_run` → `load_run_from_data` 往返后仍是 2。

```text
D2：确认所有事实更正已回写        ✅ 已完成
 ↓
Gate 1：promotion schema          ✅ 4 条配方 + 静态锁 + 正/反例测试
 ↓
单条 light 1→2                    ✅
 ↓
Gate 2：execution                 ✅（含缺料/缺石/rank不足/封顶/缺输入，全部"拒绝不烧料"）
 ↓
Gate 3：preview ≈ execution       ✅（含 rank 门禁一致性；此处修掉缺陷 #6）
 ↓
Gate 7：advance ≠ promotion        ✅ 语义隔离对照测试
 ↓
扩展 2→3                          ✅
 ↓
扩展 3→4→5                        ✅ 端到端 1→5 一条链走通
 ↓
Gate 4：determinism               ✅ 同态同果 + 无 roll 注入
 ↓
Gate 5：save / load / replay      ✅ 转数往返保持，SAVE_VERSION 不抬
 ↓
Gate 6：成本红线                  ✅ 有商店 offer 处逐步比较；无 offer 处按 M3 跳过
 ↓
Batch 1-A 收口                     ✅
```

### 7.1 defect 登记表（1-A 期间只登记，不修）

| # | defect | 证据 | 归属 |
|---|---|---|---|
| 1 | **light 系 5 条免费 `fixed`**（0 石 0 材料，含 2 条 0 成本 2→3） | `Q8G_BATCH0_RULING.md` §13.3 | 后续 promotion/content cleanup |
| 2 | `white_jade_advance` / `white_jade_basic` **同输出同价重复配方** | 同上 | Batch 4 cleanup |
| 3 | 实例 rank 是否被**战斗/构筑**消费 | §4.4 | 🔒 **独立 defect，1-A 期间与收口后均保持开启**（见下方注） |
| 4 | 旧审计文档仍含已被推翻的事实 | §0 M4 | 已加横幅，但 1-A 只读 Batch0 Ruling |
| 5 | `transaction_ledger` 按 **definition** 消耗、忽略调用方已选中的**实例 id** | Gate 2 测试 `test_promotion_accepts_an_explicit_input_instance_id` 首轮红 | ✅ **1-A 已修**：新增 `consume_instance_id_list` + `consume_instance_ids` 参数 |
| 6 | 预览 **从不读 `input_min_rank`**，rank 不足的配方显示为「可执行」 | Gate 3 测试 `test_preview_blocks_promotion_when_the_input_rank_is_too_low` 首轮红 | ✅ **1-A 已修**：`_append_recipe_card` 增 `_lowest_selected_rank` 判定（对所有配方生效，非仅 promotion） |

> 第 5、6 项都是**在写测试时才暴露**的：它们不是 promotion 独有，而是既有路径
> （`fixed` / `barrow` / 任何带 `input_min_rank` 的配方）就存在的缺陷。两者都落在
> 「看得见做不到 / 校验 A 消耗 B」这一类透明度红线上，因此在 1-A 内一并修掉；
> 修法保持行为兼容（`consume_instance_ids` 缺省为空 ⇒ 退回原语义）。

> ### 🔒 **缺陷 #3 的收口状态（审阅者明确要求保留）**
>
> > **"不要因为 1-A 已通过，就把'实例 rank 是否进入战斗/构筑能力计算'关掉。"**
>
> | 已证 / 未证 | 内容 |
> |---|---|
> | ✅ **已证** | 实例 rank **确实进入 `gu_value`** ⇒ 影响**经济层**（卖价随实例转数变化） |
> | ❓ **未证** | 实例 rank 是否进入**战斗 / 构筑的能力计算** |
>
> **为什么必须留着**：这个答案决定 `advance` 在《蛊路求真》里的性质 ——
> 是 **"真正的蛊成长机制"**，还是 **"一种影响资产价值的培炼机制"**。
> 1-A 的成功**不构成**对这个问题的任何回答，因此**不得顺带宣布解决**。
> 归属：后续阶段独立处理（审阅者裁定 "留给后续阶段处理是对的"）。

---

### 7.2 ✅ 最终状态表（收口确认，2026-09-12）

> **本表是施工单内判断"完成没"的唯一依据。** 权威验收结论见 `Q8G_BATCH1A_ACCEPTANCE_REPORT.md`。

| Gate | 内容 | 状态 | 对应测试 |
|---|---|---|---|
| **Gate 1** | promotion schema / 静态校验（含 2 反例） | ✅ | `test_all_four_promotion_recipes_load_and_validate_clean`、`..._output_equals_its_input`、`..._with_multiple_inputs` |
| **Gate 2** | 执行正确（换名升转 / 扣料 / 端到端 / 4 类拒绝 / 封顶） | ✅ | `test_first_step_promotes_...`、`test_promotion_chain_runs_end_to_end_1_to_5` 等 8 条 |
| **Gate 3** | preview ≈ execution（含 rank 门禁一致） | ✅ | `test_preview_reports_promotion_as_...` 等 4 条 |
| **Gate 4** | determinism（同态同果 / 无 roll 注入） | ✅ | `test_promotion_is_deterministic_for_the_same_state`、`..._introduces_no_randomness` |
| **Gate 5** | save / load / replay（rank 往返保持，SAVE_VERSION 不抬） | ✅ | `test_promoted_instance_rank_survives_a_save_load_round_trip` |
| **Gate 6** | 成本红线（有 offer 处比较；无 offer 处按 M3 跳过） | ✅ | `test_cost_redline_holds_wherever_a_shop_offer_exists`、`..._skips_targets_without_a_shop_offer` |
| **Gate 7** | 语义隔离 `advance` ≠ `promotion` | ✅ | `test_gate_seven_advance_keeps_definition_promotion_swaps_it` |
| — | **Batch 1-A 收口** | ✅ | **23 tests / 107 asserts 全绿** |

**回归证据**

| 检查 | 结果 |
|---|---|
| `test_v3_promotion.gd` | 23 / 23 ✅ |
| 全量 unit | **1365 / 1365** ✅（196 scripts，158s） |
| 相邻套件（refinement / recipe / save / preview） | 68 / 68 ✅ |
| 交互闭环门 17 屏 | `dead=[] no_ui_click=[] occluded=[] occluded_known=0` ✅ |
| `AUDIT[Refine]` 可点控件 | 399 → 403（+4 = 新配方卡全部接线） |

**§3 模板清单勾选情况**（仅供回溯设计意图，非进度追踪）

| 模板项 | 落地情况 |
|---|---|
| 闸门 1：白名单同步 | ✅ `content_catalog` curated-source 加 `"promotion"`；`refine_command_rules` match 加分支 |
| 闸门 1：不新增 `gu.json` 字段 | ✅ 未新增（`gu_family_id` 依旧 🔴 禁止） |
| 闸门 1：M1 静态门禁 | ✅ `output_gu_id != input_gu_ids[0]` + 反例测试 |
| 闸门 2：definition 更换 / rank 正确 / consumed / 扣料 / 预检顺序 | ✅ 全部覆盖 |
| 闸门 3：preview 分支 + 一致性 | ✅ 分支复用（注释说明）+ 4 条一致性测试 |
| 闸门 4：同 seed 同结果 / 逐字一致 | ✅ |
| 闸门 5：存读档不丢 rank / 检查 payload | ✅ 已查：无新存档键 ⇒ 不抬版本 |
| 闸门 6：逐 target 计算 / 无 offer 跳过 / 不得伪造 | ✅ 两条测试，含"跳过是有意的"断言 |
| 闸门 7：对照测试 / consumed / rank+1 / 反例 | ✅ 全部覆盖 |
| §4 `advance` 成长可测 | ✅ rank → `gu_value`（经济层）已证；战斗/构筑层 **未证，保持开放** |


