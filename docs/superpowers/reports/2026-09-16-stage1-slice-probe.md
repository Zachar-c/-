# Stage 1 纵向切片：场景探针与验收结果（2026-09-16）

> 规格：`docs/superpowers/specs/2026-09-16-stage1-gu-entity-vertical-slice-design.md`
> 前置：Stage 0 Gate = GO（`docs/lore/generated/world-model-stage0-gate.md`）
> 本轮补的是设计 §8.3 要求的「代表性场景探针」与 AGENTS 待办里的三个未做项：
> **身份夹具注入 / 固定 seed 路线探针 / 货郎·炼成场景验收脚本**。

---

## 1. 交付物

| 物 | 路径 | 结果 |
|---|---|---|
| 场景探针 | `tools/verify_stage1_slice.gd` | **RESULT: PASS**，165 项断言，0 条 SCRIPT ERROR |
| 回归单测 | `tests/unit/test_stage1_slice_scene_gates.gd` | 5/5（455 asserts） |

复现：

```bash
godot --headless --path . -s tools/verify_stage1_slice.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gtest res://tests/unit/test_stage1_slice_scene_gates.gd -gexit
```

探针的固定 seed 取**预登记列表**（`101, 202, 303 … 2121`）内第一个「L1 含炼蛊台」的 seed，
本轮命中 **seed=101**；`STAGE1_SEED=<int>` 可覆盖。不是事后挑选。

---

## 2. 各 Gate 结论

### Gate A 目录完备度

- `ContentCatalog.load_and_validate_all()`：**0 条校验错误**。
- 12 只切片蛊全部具备**显式 `v1_effect`** + `feeding_need` + `feeding_cost`，无一只走 `role` 兜底。
- 月光固定方 `moon_glow_fixed`：`default_unlocked=true`，输入契约仍为
  `moonlight_gu + small_light_gu ×2 → moon_glow_gu`。
- `moon_shadow_gu` 仍未显式化（切片剧本可不出现，探针只校验「若显式化必须是 shift」）。

### Gate B 固定 seed 路线（seed=101）

- 五大层齐全，每层行数 `11 / 10 / 9 / 8 / 11`（契约区间 8–11），**每层末行单节点（关底台）**。
- **无后向边**（DAG，地图不可回溯）；**非首行每节点 ≥1 入边**（无孤岛）。
- L1 从起点到关底 **10 步**；L1 内节点类型分布：
  `combat×11, pursuit×6, rest×5, shop×3, inheritance×3, cultivation×2, hazard×1, market×1, refinement×1, seclusion×1`。
- **L1 存在 1 个炼蛊台** ⇒ 剧本第 5 步可达。
- L1 的 `enemy_roll` 抽到了 `ridge_hound×2`、`mountain_boar×7`（切片三敌之二）。

### Gate C 身份夹具（南疆边地散修）+ 未炼化门禁

- 夹具开局：**月光蛊 ×1 已炼化**（本命），**小光蛊 ×2 未炼化**；不给任何流派 starter 四件套
  （断言 `force_gu` / `blood_droplet_gu` 均不在手）。
- 注入**写进不可变事件日志**（`reason = stage1_background_injected`），不是静改写状态。
- 未炼化门禁：战斗槽只收 `RunState.refined_instances()`，**两只未炼化小光蛊一张都进不去**，
  月光蛊正常入槽。
- Gate C-0 真实开局：`controller.start_new_run(101, "force")` → Map 屏、0 条内容校验错误、
  持有 5 只蛊实例（证明清理 `role` 兜底后开局通路未损）。

### Gate D 炼成场景

- **容量门禁自证**：魂魄 1 ⇒ `craft_cap=2` < 3 只输入，`refine_gu` 被拒
  （`refinement_capacity_exceeded`）**且三只输入仍在蛊仓**（拒绝不烧料）。
- **成功路径**：夹具补到魂魄 3 后，月光固定方执行成功 —— 3 只输入 `state=consumed` 且移出蛊仓，
  产出 `moon_glow_gu` 已炼化入库，事件 `refinement_succeeded` 且 `targets` 含
  `recipe:moon_glow_fixed`（可归因）。
- **失败路径（盲炼）**：`free_mix` 抽到 `free_mix_explosion`，输入蛊全部消亡、蛊仓清空，
  世界内代价真实结算（本局未终局，可继续观察）。

### Gate E 货郎 / 商队场景

- 货郎 `wandering_peddler` 的 L1 可买档 `purchase_stone_shell`：
  **展示价 = 结算价 = 6 元石**（`shop_layer_price` 与实扣一致，**无隐藏元石**），产出已炼化入库。
- 三道门禁全部在线：元石不足 → `insufficient_stone`（**且不产出蛊**）；
  非本 NPC 货架 → `npc_stock_missing`；不在货郎节点 → `npc_not_present`。
- 设计 §6 的「元石买血滴蛊」：现役数据挂在**商队报价 `buy_droplet`**（6 元石），
  走 `buy_gu` 验证通过 —— 扣费与报价一致、血滴蛊已炼化入库。
- 「卖山货」：`sell_material` 所得 = 单价 × 数量（本轮 2 × 2 = 4），材料清零。

### Gate F 确定性

同 seed 复跑，六门判定序列逐字符一致（191/191）。

---

## 3. 暴露的缺口（**均未擅自修改生产数据/代码**，需裁定）

| # | 缺口 | 证据 | 影响 |
|---|---|---|---|
| 1 | **L1 不出现货郎节点** | seed=101 的 L1 无 `contact` 类型、无 `npc_id=wandering_peddler`；该模板在 `nodes.json` 里 `stage=two` | 剧本第 6 步（货郎）在 L1 单局内走不到；Gate E 改用节点模板 id 直接钉场景 |
| 2 | **现役领域没有「未炼化 → 已炼化」的炼化命令** | resolver 命令表只有 `refine_gu`（合炼）/`feed_instance`（喂养）/`release_gu`（放生）；`refined_instances()` 的状态白名单是 `refined/contracted/weakened`，**没有未炼化态** | 剧本第 5 步「用未炼化小光蛊做原料」在现役规则下不可执行；夹具用已炼化实例代跑 |
| 3 | **盲炼失败没有世界内原因文案** | 事件 reason 为 `free_mix_destroyed / free_mix_mutation / free_mix_explosion`，`DisplayText` 无对应映射（`scripts/presentation/**` 无 `free_mix` 引用） | 违反设计 §5「失败必须有火候/相性/心神之类的原因文案」；玩家只能看到原始 code |
| 4 | **货郎货架不含血滴蛊** | `npcs.json:wandering_peddler.stock = [purchase_stone_shell, purchase_moonlight, barter_unknown_gu]`；血滴蛊只在商队 `buy_droplet` | 设计 §6 的「货郎买 `blood_droplet_gu`」需改数据（或改剧本） |
| 5 | **货郎 `purchase_moonlight` 是 tier 3，L1 买不到** | `npc_trade` 复用 `_shop_purchase`，因此**连黑市分层门禁一起复用**：L1 时 `shop_tier_locked`。`shop_command_rules.gd` 只把「货架」判定豁免给了 npc_trade，**tier 门禁没豁免** | 若切片剧本要求 L1 内货郎卖月光蛊，需裁定：豁免 `npc_trade` 的分层门禁，或下调该报价 tier |

---

## 4. 边界声明

- 本轮**零生产 diff**：只新增 `tools/` 探针与 `tests/unit/` 单测，未改 `data/`、`scripts/`、
  `scenes/`，未扩大蛊目录与流派数（设计 §出口条款）。
- 「身份夹具」是**探针级夹具**，不是生产开局流程；`select_school` 命令面与 20 流派未动
  （设计 §11.3 的「先夹具剧本、后拆流派择道」批次口径）。
- 探针里的 `unrefined` 状态字是**夹具专用**；生产侧若要落地「未炼化」语义，需先裁定状态模型。
