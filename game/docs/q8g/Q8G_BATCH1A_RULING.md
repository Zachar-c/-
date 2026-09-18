# Q8-G Batch 1-A 裁定记录（外部架构审阅者第四次裁定）

> - **日期**：2026-09-12
> - **裁定对象**：`docs/q8g/Q8G_BATCH1A_WORKSHEET.md`
> - **裁定结论**：🟢 **批准开工，但做 4 个强制修正**
> - **性质**：**不是返工**，是把几处"容易让 Agent 跑偏"的地方锁死
> - **上游**：`Q8G_BATCH0_RULING.md`（语义冻结）／`EXTERNAL_REVIEW_RULING.md`（第三次裁定）

---

## 0. 一句话总结

> **1-A 的成功标准不是"做出一条 1→5"，而是证明 `promotion` 作为一种独立 recipe 语义，
> 能够在现有 refinement / preview / save / replay 架构里成立，同时不会把 `advance` 混回去。**

---

## 1. 四项强制修正（开工前必须回写）

| # | 修正 | 落点 |
|---|---|---|
| **M1** | **1→5 完整链的定义必须严谨** | §5（本文件）→ 改正 FAQ |
| **M2** | **新增 Gate 7：语义隔离**（`advance` ≠ `promotion`） | 验收清单从 6 → **7** 个闸门 |
| **M3** | **成本红线改为"同目标蛊直取成本"**，无商店 offer 则**不做比较、不得伪造基准** | 闸门 6 |
| **M4** | **`Batch0 Ruling` 是唯一 normative source** —— Agent 只读它，**不得再读旧审计结论作为实现依据** | §0.3 执行纪律 |

> 其余裁定见 §2 批准表。

---

## 2. 逐项裁定

### 2.1 D1：选 `light` 🟢 批准

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

- 现有 `advance` 已证明 `small_light_gu` **实例**可从 Rank 1 → Rank 2；
- light 存在现成的 **1→2→3** 关系 → 最大限度利用**真实数据**验证新 promotion 语义；
- 附带价值：light 的免费 `fixed` 恰好可作为**异常对照样本**。

> ⚠️ **但 1-A 不修 light 免费 `fixed`** —— 见 §2.7。

### 2.2 D2：✅ 确认"更正回写"是开工前硬闸门

`§0.3` 三条实测更正已全部处理，**同意**。但执行纪律需增加一个**极机械**的判断：

```text
Batch 1-A 开工前：
Q8G_BATCH0_RULING.md 必须已包含更正后的正文事实
        ↓
Agent 只读 Batch0 Ruling
        ↓
不得再读取旧审计结论作为实现依据
```

> **审阅者原话风险**："当前已经出现『老文档保留旧事实作审计记录，新文档才是真相』。
> 这之后最危险的不是代码错，而是 **Agent 搜到旧内容后又把『advance 不升转』当成事实**。"
>
> → **`Batch0 Ruling` 必须明确是唯一 normative source**（它已声明权威冻结文档，方向正确）。

### 2.3 D4：🟢 冻结为 **A —— 复用 `refinement_recipes.json`**

> **新增 `kind: "promotion"`，不新建文件。**

理由：`advance` / `fixed` / `free_mix` 都已在这套领域里；本次要修的是
**"recipe kind 的语义边界"**，**不是建立另一套 Recipe Repository**。

```text
refinement_recipes.json
  advance
  promotion   ← 新增
  fixed
  free_mix
```

> 且这正好验证 `refine_command_rules.gd` / `action_preview_service.gd` / catalog validation
> **能否同时接受新 kind** —— 这正是 1-A 要验证的 schema 问题。

### 2.4 "蛊系"绝对不要新增字段 🔴 维持禁止

> **不增加 `gu_family_id`。**

1-A 用 `input_gu_ids` / `output_gu_id` / `school` 表达明确 lineage。

> **理由**：现在验证的是 **promotion schema**，而不是建立新的内容分类系统。
> 若现在加 `gu_family_id`，一条新 recipe 会变成：
> `new recipe kind` + `new gu field` + `new validator` + `new catalog whitelist` + `新内容迁移`
> —— **完全没有必要**。

### 2.5 ⭐ M1：1→5 完整链的定义（**1-A 最需要改的地方**）

原表述"一条完整 1→2→3→4→5 promotion 链"**有歧义**：

| 歧义读法 | 是否认可 |
|---|---|
| **(a)** 实例 Rank 连续可升 | ❌ 这**会重新变成 `advance` 的语义** |
| **(b)** **每一步 output 都必须是下一 Rank 的另一个定义蛊** | ✅ **正确** |

因为 Batch 0 冻结的 promotion 是 **`Rank N 某类蛊 → 指定 Rank N+1 候选`**，故 1-A 必须明确：

```text
Rank 1 instance
 ↓ promotion
Rank 2 target Gu（另一 definition）
 ↓ promotion
Rank 3 target Gu（另一 definition）
 ↓ promotion
Rank 4 target Gu（另一 definition）
 ↓ promotion
Rank 5 target Gu（另一 definition）
```

**而不是**：

```text
某只蛊 instance rank 1
 ↓
同一个 definition rank 2      ← ❌ 这是 advance
 ↓
同一个 definition rank 3
```

### 2.6 M2：`advance` 的措辞改写 + 保留验证

最新证据已证明 `advance → instance.rank +1`，且 **`GuBalance.gu_value()` 会读取实例 rank**。
因此旧的疑虑"advance 也许只是经济符号"**已被部分消解**。

> ### ⚠️ 但**仍要保留**施工单的验证：**战斗 / 构筑到底有没有读取实例 rank。**
> **这是一个非常好的独立诊断，不要因为 `gu_value` 已经读取就把它删掉。**

**结论措辞应改为**（替代原"可能没有真实成长"）：

> **`advance` 已确认是"实例升转机制"；尚待确认实例 rank 是否参与战斗构筑能力计算。**

### 2.7 D3：light 免费 `fixed` —— 🟡 **登记 defect，不在 1-A 修**

新证据已把问题讲清楚：

| 组 | 条数 | 成本 |
|---|---|---|
| sword | 6 | 12/12/24/24/40/60 石，有成本 |
| **light 免费组** | **5** | **0 石 0 材料**（含 2→3 的 0 成本直达） |

**它当然是缺陷，但不是 1-A 的阻塞条件。** 正式处置：

```text
light 免费 fixed
→ defect registered
→ 不在 1-A 修
→ 后续 promotion/content cleanup 处理
```

> **理由**：这样 1-A 才能回答一个**非常纯粹**的问题 ——
> **"新 promotion kind 能不能跑通？"**
> 而不是 **"promotion 能不能跑通，同时顺便重新设计 light 的历史 recipe。"**
>
> ⚠️ 否则 1-A 会悄悄变成
> **`promotion schema` + `免费 fixed 重构`** —— **这就开始膨胀了。**

### 2.8 D5：🟡 **不机械升 `SAVE_VERSION`**

`SAVE_VERSION` 是否升级取决于：**存档格式是否发生不向后兼容的变化**。

- 若 `promotion` 只增加了一个现有 recipe 对象支持的 `kind`，
  而存档实际保存的是 `recipe_id` / `instance state` / `rank` → **未必需要升版**。
- 但若**存档直接持久化 recipe kind**，且旧版本加载器无法识别 `promotion` → **必须升**。

> **D5 改写为**：
> **先检查 save payload 是否持久化 recipe kind；只有兼容性被实际破坏时才升 `SAVE_VERSION`。**
> **不要为了一个新 JSON 枚举值机械升存档版本。**

### 2.9 ⭐ M3：成本红线改为"同目标蛊直取成本"

**原表述**："低转蛊 + 材料 + 元石 → 高转蛊，总成本 < 直接购买同级高转蛊。" —— 方向对。

**但**：1-A 选 light 后，**不能拿 sword 的 `purchase_sword_atk_2_12 = 18` 当主要验证对象**
（那是另一个蛊系）。应定义为：

```text
同目标蛊 / 同 Rank / 同可用渠道的最低直接取得成本
即：promotion_total_cost(target_gu)  <  direct_acquisition_cost(target_gu)
```

`direct_acquisition_cost` 可来自**现有商店直接 offer**。

> ### 🔴 **如果某个 target Gu 根本没有商店 offer**：
> **该条 promotion 暂不执行红线比较，不得伪造基准。**

审阅者原话："否则 **Agent 很容易为了满足红线，随便找一个同 Rank 商品来比较**。"

### 2.10 ⭐ M4→Gate 7：新增第七个闸门 **语义隔离**

原六闸门（schema / execution / preview / deterministic / save-load / cost redline）已很好，**增加**：

#### 闸门 7：语义隔离

**必须证明 `advance` ≠ `promotion`**。具体至少验证：

```text
advance
→ 同 definition，instance.rank +1

promotion
→ 消耗输入 Gu instance
→ 产出指定 target definition
→ target rank = input rank + 1
```

> 这样才能真正证明 Batch 1-A **不是"给旧 `advance` 换一个名字"**。
> **这是整个 Q8-G 的核心。**

---

## 3. 最终批准状态表

| 项目 | 裁定 |
|---|---|
| Batch 1-A 开工 | 🟢 **批准** |
| 选 `light` | 🟢 **批准** |
| 单条完整 1→5 | 🟢 **批准**（**须按 §2.5 定义：每步换 definition**） |
| 使用 `refinement_recipes.json` | 🟢 **批准** |
| 新增 `kind=promotion` | 🟢 **批准** |
| 新增 `gu_family_id` | 🔴 **禁止** |
| 免费 light fixed | 🟡 **登记、不在 1-A 修** |
| sword 异常链 | ✅ 已从"异常成本"更正为**正常成本梯度** |
| `advance` | ✅ 确认为**实例 rank +1** |
| `promotion` | ✅ **必须与 advance 保持语义隔离** |
| SAVE_VERSION | 🟡 **按实际兼容性决定，不机械升级** |
| promotion 数值 | 🟡 **provisional，仅验证接口/红线** |
| 商店改价 | 🔴 **禁止** |
| 战斗产石 | 🔴 **禁止，留到 1-C** |
| Boss / Elite | 🔴 **禁止，留到 1-D** |

---

## 4. 最终施工顺序（批准，含 Gate 7）

```text
D2：确认所有事实更正已回写
 ↓
Gate 1：promotion schema
 ↓
单条 light 1→2
 ↓
Gate 2：execution
 ↓
Gate 3：preview
 ↓
Gate 7：advance ≠ promotion          ← 新增
 ↓
扩展 2→3
 ↓
扩展 3→4→5
 ↓
Gate 4：determinism
 ↓
Gate 5：save / load / replay
 ↓
Gate 6：成本红线
 ↓
Batch 1-A 收口
```

---

## 5. 审阅者结语

> **这一步一旦跑通，后面的 19 流派扩展就会从"架构探索"降级成"内容铺设"，
> 那时候 Batch 1-B 才真正值得一次性铺开。**

---

## 6. 对本仓的落地状态

| 项 | 状态 |
|---|---|
| 本裁定落档 | ✅ 本文件 |
| 4 项强制修正（M1–M4）回写施工单 | ✅ 已完成（见 `Q8G_BATCH1A_WORKSHEET.md` 头部修正横幅 + 各节） |
| D1/D3/D4/D5 决策点 | ✅ 已裁定（见 §2.1/2.7/2.3/2.8） |
| D6 决策点 | 🟡 **转为 Gate 7 的验证项**（不再作为"待裁定"，因审阅者保留了该诊断） |
| **D7 决策点** | ✅ **已裁定 = 方案 C**（见 §7） |
| 生产代码 | 🟢 **已开工（2026-09-12）** —— D7 定档，四项修正已回写 |

---

## 7. D7 最终裁定（第五次裁定）：**批准方案 C** ✅

> **裁定日期**：2026-09-12
> **结论**：**🟢 正式批准方案 C**，并**冻结**为 1-A 的 promotion 垂直链。

### 7.1 冻结链（IMMUTABLE for 1-A）

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

**五只 definition 全部已存在**；**每步严格 `+1 Rank`**；**每步更换 definition** →
同时满足 **M1** 与 **Gate 7**。

### 7.2 为何否决 A / B（审阅者原话要点）

| 方案 | 否决理由 |
|---|---|
| **A** 继续创造 Rank 4/5 moon 蛊 | **1-A 的目标是验证 promotion schema，不是顺便扩大内容库。** 方案 A 会新增两个 `gu` definition，随之扩大 catalog、内容验证与后续维护面，**当前没有必要** |
| **B** 接受 1→3→5 跳级 | 会**直接违反本批已冻结的 `promotion = Rank N → Rank N+1`**，并把"promotion 可以跨转"的**新语义偷偷塞进 Batch 1-A** —— **这属于架构变更，不是垂直切片** |

### 7.3 方案 C 满足的实验需求（逐条）

- ✅ 不新增 `gu.json` **字段**
- ✅ 不新增新的 **Gu definition**
- ✅ 每步严格 **+1**
- ✅ 每步**换 definition**
- ✅ 全部属于 `light`
- ✅ lineage 由 **recipe 自己明确表达**

> **审阅者结论**：**"最低风险、最高信息量的 schema 实验。"**

### 7.4 🔒 静态校验要求（审阅者特别强调，**不得删**）

`promotion` 的静态校验应直接锁死：

```text
output_gu_id != input_gu_ids[0]
```

**且不仅测试正确案例，还要有反例**：

```text
promotion:
input  = A
output = A
→ validation reject
```

> **目的（审阅者原话）**：**"这样以后任何人误把 `advance` 配方复制成 `promotion`，
> 会在 catalog / schema 层直接失败，而不是运行时才发现语义混乱。"**
>
> 该要求已落在 `Q8G_BATCH1A_WORKSHEET.md` **Gate 1** 与 **Gate 7**，**不得删改**。

### 7.5 ⚠️ 边界提醒（审阅者原话）

> **"这次不是在'设计一条合理的最终游戏配方'。"**
>
> D7 选这五只蛊的目的，是
> **"制造一条最小、真实、可运行的 promotion 垂直链。"**
>
> 所以这条链存在一些**"跨 role"并不构成问题**。
>
> 等 1-A 跑通以后，**Batch 1-B 才真正讨论**：
> "每个流派应该怎样建立**有世界语义的晋升谱系**。"
>
> 🔴 **不能拿垂直切片的实验链反向定义最终内容设计。**

### 7.6 决策点总表（全部闭合）

| 项目 | 状态 |
|---|---|
| D1 `light` | ✅ |
| D2 更正回写 | ✅ |
| D3 免费 `fixed` | 🟡 **登记、不修** |
| D4 recipe schema | ✅ |
| D5 `SAVE_VERSION` | ✅ **按实际兼容性检查** |
| D6 实例 rank 消费 | 🟡 **Gate 7 / 独立诊断** |
| **D7 promotion 五蛊链** | ✅ **批准方案 C** |
| **Batch 1-A** | 🟢 **正式可开工** |

### 7.7 🔴 开工期间的红线（审阅者原话）

> **"现在可以改代码，但不要顺手修 light 免费 fixed、不要铺其他流派、
> 不要碰战斗产石，也不要开始调商店。"**
>
> 这些边界在最终施工单里已经明确列出。

> **里程碑意义**：**"这一步跑通后，Q8-G 的风险会从'架构设计风险'
> 正式降到'内容铺设风险'，届时再进入 1-B 会非常稳。"**

---

## 7. ⚠️ 落档时新发现的阻塞项（D7，需用户裁定）

> **本项不来自审阅者裁定，而是本仓在回写 M1 时做数据核实发现的事实。**
> **它不推翻 D1（选 light），但影响 1-A 能否立即开工。**

### 7.1 发现

M1 要求"每步 output 必须是**另一个 definition** 且 **+1 转**"。为落实它，本仓扫描了 `light` 全部 40 只蛊：

| role | 最长 rank 递增链 |
|---|---|
| `light_atk` | 3 步（seq1:r1 → seq2:r3 → seq3:r5，**跳级**） |
| `light_rec` / `light_mov` / `light_log` / `light_heal` / `light_def` | 3 步且**非单调**（多为同 rank） |
| **moon 系** | **止步 rank 3**（`moon_shadow_gu`） |

**全库对照**（802 只蛊同法扫描）：

- 能达 **5 步 +1 链**的 role 仅 **2 个**：`human_atk`、`force_atk`（**均非 light**）
- **全库没有任何 4/5 步链被现有 recipe 覆盖**（= Q8-F 原始结论）

### 7.2 含义

> **1-A 的 4 条 promotion recipe 必然是"新造内容"**，不能靠"发现既有 1→5 关系"。
> 审阅者原判断"light 存在现成 1→2→3 关系"**只到 3 步**，且不是连续转数。

### 7.3 三个策略（施工单 §6.3 有详表）

| 策略 | 说明 | 风险 |
|---|---|---|
| (a) 延展 moon 系 | 新造 r4/r5 gu 定义 | **新增 2 个定义**，体量大 |
| (b) 用 `light_atk` 跳级链 | `1→3→5` 只 2 条 recipe | **违反"每步 +1"**，需先裁定可跨转 |
| **(c) 既有蛊组合，每步 +1** ✅ | 0 新定义 | lineage 跨 role（可接受，promotion 本就是定向的） |

**推荐 (c)**，已验证可行：

```text
light_atk_1_01_gu   rank 1   ✅ 存在
   ↓ promotion
moon_glow_gu        rank 2   ✅ 存在
   ↓ promotion
moon_shadow_gu      rank 3   ✅ 存在
   ↓ promotion
light_atk_4_21_gu   rank 4   ✅ 存在
   ↓ promotion
light_atk_5_03_gu   rank 5   ✅ 存在
```

> **5 只蛊全部实存、转数全部匹配、每步换 definition** —— 满足 M1 与 Gate 7。
> 🔴 **需用户确认后方可写入数据。**
