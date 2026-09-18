# Q8-G Batch 1-A —— Gate 1–7 验收报告

> **日期**：2026-09-12
> **状态**：🟢 **Approved / Close —— 已收口，可提交**
> **最终裁定（外部审阅者）**：**"Q8-G Batch 1-A：🟢 Approved / Close。可以提交。"**
> **规范来源**：`Q8G_BATCH0_RULING.md`（唯一 normative source）+ `Q8G_BATCH1A_RULING.md`（M1–M4 + D7）
> **审阅者成功标准**（原话）：
> **"不是做出一条 1→5，而是证明 `promotion` 作为独立 recipe 语义，能在现有
> refinement / preview / save / replay 架构里成立，同时不会把 `advance` 混回去。"**

---

## 0. 收口结论与边界

| 项 | 结论 |
|---|---|
| **Gate 1–7** | 全部 ✅ 通过（7 个 Gate 均有对应测试） |
| **审阅者对 #5 / #6 的裁定** | ✅ **认可在 1-A 内修掉**（"性质非常特殊"，非无边界扩 scope） |
| **审阅者对 Gate 6 的裁定** | ✅ **接受**（无商店 offer 即跳过、不伪造基准，"完全符合 M3"） |
| **审阅者对跨 role 链的裁定** | ✅ **接受**（"作为垂直切片完全合法"；谱系设计留到 1-B） |
| **文档状态统一** | ✅ 已完成：施工单 `[ ]` 模板已标注，新增 §7.2 最终状态表 |
| **缺陷 #3（实例 rank）** | 🔒 **保持开启**（审阅者明确要求，见 §7 与施工单 §7.1） |

> ### 🎯 归档边界（审阅者要求强守）
>
> > **"1-A = promotion 架构验证完成；不是 light 最终晋升谱系完成，也不是经济系统完成。"**
>
> **未进入**：1-B（19 流派谱系）· 1-C（战斗产石）· 1-D（掉落→UI）· 商店调整。
> 本报告 §5 已记录这些均未提前进入。

---

## 1. 裁定到实现的对应表

| 裁定 | 要求 | 落地 |
|---|---|---|
| **M1** | 每步必须是**另一个** definition；实例 Rank 连升属 advance | 静态锁 `output_gu_id != input_gu_ids[0]` + 4 条链全部换名 |
| **M2** | 新增 **Gate 7 语义隔离**，须证明 advance ≠ promotion | `test_gate_seven_advance_keeps_definition_promotion_swaps_it` |
| **M3** | 成本红线 = **同目标蛊直取成本**；无商店 offer 则**跳过、不伪造基准** | `_cheapest_shop_price_by_gu()` + 两条件测试 |
| **M4** | `Q8G_BATCH0_RULING.md` 为唯一 normative source | 实现仅依据它；旧审计文档不回读 |
| **D1** | 流派取 `light` | 链全部 light（跨 role，符合"垂直切片"定位） |
| **D3** | light 免费 `fixed` **不在 1-A 修**，仅登记 | 登记表 #1，本次未触碰 `data/` 中任何既有配方 |
| **D4** | 复用 `refinement_recipes.json`，新增 `kind:"promotion"` | 未新建文件；`Counter` = advance 377 / fixed 14 / **promotion 4** / free_mix 1 = 396 |
| **D5** | 不机械抬 `SAVE_VERSION` | 实测无新存档键 ⇒ **保持 4**；往返测试守住 |
| **D6** | 保留实例 rank 诊断，措辞改写 | §4.3 措辞已改；诊断项登记为缺陷 #3 |
| **D7** | 批准方案 C 冻结链 | 5 只全部实存、每步 +1、0 新定义 |

---

## 2. D7 冻结链（方案 C）

```text
light_atk_1_01_gu (1)
   └─ promote_light_atk_1_01_to_moon_glow ── 10 石 + 兽骨×1 ──▶ moon_glow_gu (2)
        └─ promote_moon_glow_to_moon_shadow ── 18 石 + 兽骨×2 ──▶ moon_shadow_gu (3)
             └─ promote_moon_shadow_to_light_atk_4_21 ── 30 石 + 兽血×2 ──▶ light_atk_4_21_gu (4)
                  └─ promote_light_atk_4_21_to_light_atk_5_03 ── 45 石 + 兽骨×2 + 毒囊×1 ──▶ light_atk_5_03_gu (5)
```

**为什么不是 A / B**（审阅者裁定原文要点）：

- **方案 A 被拒**：新造 Rank 4/5 moon 蛊 → 会**扩大内容库**，而 1-A 的目标不是扩内容。
- **方案 B 被拒**：1→3→5 跳级 → 违反已冻结的 `promotion = Rank N → Rank N+1`，
  等于**偷改架构**。
- 🔴 **边界**：**"这次不是在'设计一条合理的最终游戏配方'"**——不许拿这条垂直切片的
  实验链**反向定义**最终内容设计；跨 role 不构成问题。

---

## 3. Gate 逐项结论

测试文件：`tests/unit/test_v3_promotion.gd` —— **23 tests / 107 asserts 全绿**

| Gate | 内容 | 测试 | 结果 |
|---|---|---|---|
| **1** | schema / 静态校验 | `test_all_four_promotion_recipes_load_and_validate_clean`<br>`test_promotion_recipes_declare_the_frozen_chain`<br>**反例** `..._output_equals_its_input`<br>**反例** `..._with_multiple_inputs` | ✅ |
| **2** | 执行正确 | 首步换名升转 / 扣石扣料 / 1→5 端到端 / 4 类拒绝（缺石·缺料·缺输入·rank 不足）/ rank5 封顶 / 显式选中实例 | ✅ |
| **3** | preview ≈ execution | 可执行↔真做成功 / 缺石↔真做被拒 / 成本摊开 / **rank 门禁一致** | ✅ |
| **4** | determinism | `test_promotion_is_deterministic_for_the_same_state`<br>`test_promotion_introduces_no_randomness` | ✅ |
| **5** | save / load / replay | `test_promoted_instance_rank_survives_a_save_load_round_trip` | ✅ |
| **6** | 成本红线 | `test_cost_redline_holds_wherever_a_shop_offer_exists`<br>`..._skips_targets_without_a_shop_offer` | ✅ |
| **7** | 语义隔离 advance ≠ promotion | `test_gate_seven_advance_keeps_definition_promotion_swaps_it` | ✅ |

### Gate 1 反例（审阅者特别强调不得删）

```text
promotion: input = A, output = A  →  validation reject
```

实测：合成一条 `output == input` 的 promotion 后跑 `ContentCatalog.validate`，
确实产出 `promotion recipe ... must change gu definition (use advance for same-name rank up)`。
⇒ 以后任何人误把 `advance` 配方复制成 `promotion`，**在 catalog 层直接失败**。

### Gate 6 实测数据

| 步骤 | 目标蛊 | 累计成本* | 商店直取 | 判定 |
|---|---|---|---|---|
| 1 | `moon_glow_gu` | **11** | 12 | ✅ 11 < 12 |
| 2 | `moon_shadow_gu` | **31** | 40 | ✅ 31 < 40 |
| 3 | `light_atk_4_21_gu` | 65 | — | ⏭ **无商店 offer，按 M3 跳过** |
| 4 | `light_atk_5_03_gu` | 115 | — | ⏭ **无商店 offer，按 M3 跳过** |

\* 累计 = 从 1 转一路晋升到该目标的总成本（元石 + 材料按 `loot_tables.materials.value` 折价）。
**两个可比步骤红线均成立**（约 92% / 78% 商店价），无 offer 处**未伪造基准**。

---

## 4. ⚠️ 过程中由测试反向暴露的 2 个既有缺陷（已在 1-A 内修掉）

> 两项都**不是 promotion 独有**，是既有路径（`fixed` / `advance` / 任何带
> `input_min_rank` 的配方）就存在的问题。两者都落在**"看得见做不到 / 校验 A 消耗 B"**
> 透明度红线上，因此一并修复。

### 缺陷 #5 —— `transaction_ledger` 只认 definition，忽略调用方选中的**实例 id**

- **症状**：命令里指定 `input_instance_ids: ["gu_002"]`，实际被消耗的是 `gu_001`。
  根因是 `_add_gu_transaction(...)` 只把 **definition**（`[input_gu_id]`）传给 ledger，
  而 `consume_definition_instances` 按"首个同名 refined 实例"消耗。
- **危害**：promotion 的转数门禁是**按选中实例**算的 ⇒ **"校验 A、消耗 B"**。
- **修法**（保持行为兼容）：
  - 新增 `GuInstance.consume_instance_id_list(instances, stored, instance_ids)`
  - `transaction_ledger(..., consume_instance_ids: Array = [])` —— **缺省空 ⇒ 退回原语义**
  - `_apply_promotion_recipe` 传 `[input_instance_id]`

### 缺陷 #6 —— 预览**从不读 `input_min_rank`**

- **症状**：rank 不足的配方在预览里 `executable: true`，玩家**点了才**被拒
  （`refinement_input_rank_insufficient`）。
- **危害**：正是 AGENTS.md 交互闭环契约禁止的 **"看得见做不到"**。
- **修法**：`_append_recipe_card` 增加转数门禁判定，新增
  `_lowest_selected_rank(state, required)`（按 definition 多集配对，与执行侧同形），
  并把 `block_reason` 写成"输入蛊转数不足（需 N 转，现有 M 转）"。
  **对所有带 rank 门禁的配方生效，不只 promotion。**

---

## 5. 回归证据

| 检查 | 结果 |
|---|---|
| `test_v3_promotion.gd` | **23 / 23** ✅ |
| 全量 unit（`-gdir=res://tests/unit`） | **1365 / 1365** ✅（196 scripts，158s） |
| 相邻套件（refinement / recipe / save / preview） | **68 / 68** ✅ |
| 交互闭环门 `verify_interaction_loop.gd` | **17/17 屏 `dead=[] no_ui_click=[] occluded=[] occluded_known=0`** ✅ |
| `AUDIT[Refine]` 可点控件 | 399 → **403**（+4 = 新配方卡全部接线） |

**改动面（5 文件，+225 / −5）**

```text
data/refinement_recipes.json             |  89 +  （4 条 promotion，逐行插入保住 1 空格缩进/LF）
scripts/domain/action_preview_service.gd |  46 +
scripts/domain/content_catalog.gd        |  14 +
scripts/domain/gu_instance.gd            |  28 +
scripts/domain/refine_command_rules.gd   |  53 +
```

**未做（严守边界）**：未修 light 免费 `fixed`（D3）· 未铺其他流派（1-B）· 未碰
战斗产石（1-C）· 未动商店（1-D）· 未新增 `gu_family_id` · 未抬 `SAVE_VERSION`。

---

## 6. 审阅者裁定结果（已全部闭合）

| # | 提交的问题 | 审阅者裁定 |
|---|---|---|
| 1 | 缺陷 #5 / #6 在 1-A 内修掉是否恰当？ | 🟢 **认可**。理由：#5 属**事务正确性**（"检查 A、实际消耗 B"）；#6 属**明确的交互闭环破坏**（"UI 显示可执行、实际点击才拒绝"）。两者都过了全量 1365 unit 与相邻套件回归 ⇒ "作为 1-A 的伴随修复是合理的，而不是无边界扩 scope"。对兼容式扩展（`consume_instance_ids` 默认为空时保持旧语义）表示放心。 |
| 2 | Gate 6 无商店 offer 处跳过是否接受？ | 🟢 **接受**。"无商店 offer 就跳过，不伪造比较基准，这是正确的。" Rank 4/5 无 offer 故不比较 —— "这个处理完全符合 M3，而不是为了'凑一个通过'硬找别的蛊做基准。" |
| 3 | 跨 role 折返链是否接受？ | 🟢 **接受**。"看起来不漂亮，但**作为垂直切片完全合法**。"关键结构条件全部满足：`Rank 1→2→3→4→5`、每步换 definition、不新增 Gu definition、不新增 `gu_family_id`。 |
| 4 | 是否批准提交？ | 🟢 **批准**。"Q8-G Batch 1-A：🟢 Approved / Close。可以提交。" |

---

## 7. 🔒 收口后仍保持开启的 defect（不得关闭）

> **审阅者原话**：**"不要因为 1-A 已通过，就把'实例 rank 是否进入战斗/构筑能力计算'关掉。"**

| 已证 / 未证 | 内容 |
|---|---|
| ✅ **已证** | 实例 rank **确实进入 `gu_value`** ⇒ 影响**经济层**（卖价随实例转数变化） |
| ❓ **未证** | 实例 rank 是否进入**战斗 / 构筑的能力计算** |

**为什么必须留着**：这个答案决定 `advance` 在《蛊路求真》里的性质 ——
是 **"真正的蛊成长机制"**，还是 **"一种影响资产价值的培炼机制"**。
1-A 的成功**不构成**对此问题的回答，**不得顺带宣布解决**。

> 审阅者裁定：**"这个问题留给后续阶段处理是对的。"**

---

## 8. 对下一阶段（Batch 1-B）的建议

> 审阅者原话：
> **"下一阶段可以进入 Batch 1-B，但我建议先把'19 个流派的晋升谱系设计'单独做一次
> 架构/内容规则裁定，再批量铺数据，不要直接复制 1-A 的实验链。"**

**即：1-B 开工前应先有一份「流派晋升谱系设计」裁定文档**，明确：

1. 每个流派的**谱系语义**（是否允许跨 role 折返、是否允许跨流派晋升）；
2. **转数梯度规则**（每步必须 +1？可否跳级？跳级的适用条件）；
3. **成本曲线规则**（相对商店直取价的比例区间）；
4. 与 `advance`（同名培炼）的**分工边界**（何时该用哪个机制）。

⚠️ **不得把 1-A 的实验链（`light_atk_1_01` → `moon_glow` → `moon_shadow` →
`light_atk_4_21` → `light_atk_5_03`）当作 1-B 的模板直接复制** ——
它的目的是 schema 验证，不是内容设计（D7 边界提醒）。
