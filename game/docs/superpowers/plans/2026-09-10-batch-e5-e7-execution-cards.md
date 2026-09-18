# 本轮施工批次 · E5/E6/E7 收尾（4 个可独立验收的任务）

> 日期：2026-09-10
> 上游：`docs/superpowers/specs/2026-09-09-event-classification-design.md` §7 工单表 + §8 待拍板；
> `docs/superpowers/plans/2026-09-09-visual-route-batch-plan.md` §1.5 原子队列。
> 现状：**E1–E4 已落地**（实测：`pacing.json` 5 层 `category_weights` 齐备、`map_generator` 已按分类抽取、
> `test_category_route.gd` 6 用例、`mode_groups` 已进契约、`rest/refinement/cultivation` 已统一走 Rest 屏）。
> 本批只收 **E5 / E6 / E7**。

---

## 0. 批次约定

- **粒度**：4 个任务，每个 **1 个提交**、**可独立验收**、**可独立回滚**。
- **顺序**：`T1 → T2 → T3 → T4`。其中 T1/T2 都会改动 `data/pacing.json` 与层/种子相关常量，**必须串行**；
  T3/T4 只碰 `tools/`，彼此独立，也可提前先做（想先拿基线证据就调前）。
- **共享技术底座**：`scripts/domain/seeded_roll.gd` 已有 `index(bound, seed, salt, tick)` /
  `mixed_seed(seed, salt, tick)`。**本批所有随机一律经它派生**，且**不新增存档字段**——
  `shop_roll` / `enemy_roll` 都从 `(run_seed, node_id)` **确定性重算**，因此不动 `SAVE_VERSION`、
  不需要存档迁移。
- **全局验收门**（每项任务收尾都要过一遍）：`tools\check.ps1` rc=0（内含 guitkx + unit + integration +
  启动探针 + 契约漂移 + `git diff --check`），以及 `verify_interaction_loop.gd` 全屏
  `dead=[] no_ui_click=[] occluded=[]`。

---

## 开工前需要你一句话（**不回复即按默认走**）

| 编号 | 决策点 | 我的默认取值 | 影响 |
|---|---|---|---|
| **D-E** | 敌人随机粒度 | **「节点主题锚定池 + 层品质随机」**：保留节点现有 `enemy_kind` / `enemy_kinds` 作为**池**，层 `rank` 过滤候选，按 `tier` 品质权重抽；**不做**脱离模板的全局抽 | T1 的实现形态 |
| **D-F** | 商店上架数与保底 | **N = 4 + ⌊layer/2⌋**（层1→4、层2→5、层4→6）件；**保底 ≥1 件** `tier == 本层 shop_max_tier`（本层可出的最高档）；**同层同一节点多次进店货架固定**（同一 roll） | T2 的实现形态 |

---

## T1 —— E6：敌人按层品质随机

### 1.1 具体实施内容

| 文件 | 改动 |
|---|---|
| `data/enemies.json` | 12 条每条补 `weight`（正整数）；按现有 `tier`（`common`/`elite`/`boss`）给档位权重（如 common 70 / elite 25 / boss 5 量级），具体值随 `pacing.enemy_weights` 对齐 |
| `scripts/domain/enemy_catalog.gd` | `validate()` 增校验：`weight` 必须存在且为正整数（缺失/非正/非整数 → 记入错误数组，沿用现有 `errors.append` 风格） |
| `data/pacing.json` | `layers["1".."5"]` 各补 `enemy_weights`（按 `tier` 的权重表，层越深 elite/boss 占比越高） |
| `scripts/domain/map_generator.gd` | 战斗节点生成时加 **`enemy_roll`** 抽取：候选池 = 节点 `enemy_kind(s)` → 按当前层 `rank` 上限过滤 → 按 `tier` 权重加权抽 N 个；随机经 `SeededRoll.index(bound, seed, salt="map:<layer>:<node_id>:enemy", tick)`；结果写入节点字段 **`enemy_roll`**（具体 id 数组） |
| `scripts/domain/battle_command_facade.gd` | `_v1_enemies()`（当前在 :98）改为**优先读 `enemy_roll`**；`enemy_roll` 缺失时**回退现有 `enemy_kind` / `enemy_kinds` 行为**（保锚点与旧存档兼容） |
| `tests/unit/test_enemy_roll.gd` | 新建，见验收标准 |

### 1.2 交付物 / 预期结果

- 数据表带 `weight`、`pacing` 带 `enemy_weights`、战斗节点带 `enemy_roll`；
- 战斗屏快照的 `enemies[]` 来自 `enemy_roll`，与地图节点一致（同一节点多次进入同一批敌人）；
- 新建 `tests/unit/test_enemy_roll.gd`。

### 1.3 验收标准（可量化）

1. **同种子同敌**：同一种子、同一层、同一节点，生成两次 `enemy_roll` **逐元素相等**；
2. **层品质单调**：跑 ≥100 个种子的完整路线，统计各层 `elite+boss` 占比——**层 1 < 层 3 < 层 5**（允许相等但不得逆序）；
3. **层门禁**：任何 `enemy_roll` 中的敌人 `rank` **不得高于**该层 `rank` 上限；
4. **旧路径不破**：显式给 `enemy_kind`、不给 `enemy_roll` 时，`_v1_enemies` 结果与改动前**完全一致**（回归断言）；
5. **校验生效**：构造 `weight: 0` / 缺失 `weight` 的敌人条目，`enemy_catalog.validate` 必须报错；
6. 全量门：`unit` + `integration` 全绿。

### 1.4 验收方式（逐条对应）

```powershell
# ① ③ ④ ⑤ ⑥ —— 新单测 + 相邻回归
tools\test.ps1 -Test tests/unit/test_enemy_roll.gd
tools\test.ps1 -Test tests/unit/test_enemy_catalog.gd
tools\test.ps1 -Test tests/unit/test_category_route.gd
tools\test.ps1 -Suite integration
```

期望：`Passing Tests == Tests`（0 失败）；`test_enemy_catalog` 仍绿（新增校验不误伤现有 12 条）。

```powershell
# ② —— 层品质分布（T1 落地后 T3 会把它自动化；这里先看手工输出）
tools\godot.ps1 --headless --path . -s tools\verify_route_diversity.gd
```

期望：输出逐层敌人品质计数表，`elite+boss` 占比随层递增。

> 举证：把上面命令的输出贴给我或自行比对即可；每个提交都会附实测输出要点（≤3 行）。

---

## T2 —— E7：商店按层随机

### 2.1 具体实施内容

| 文件 | 改动 |
|---|---|
| `data/shops.json` | `offers[]` 每条补 `weight`（正整数）；`content_catalog` 的 schema 校验同步要求该字段 |
| `scripts/domain/shop_command_rules.gd` | 新增 `shop_roll(state, catalog, node_id)`：按层 `max_tier` 过滤 → 按 `tier` 权重加权抽 **N = 4 + ⌊layer/2⌋** 件 → **保底 ≥1 件 `tier == 本层 shop_max_tier`（本层可出的最高档）**（不足则从候选中强制补）；随机经 `SeededRoll.index(..., salt="shop:<node_id>:roll", tick)` |
> 口径修正（2026-09-10 实测）：规格原写 `tier ≥ max(2, layer)`，但 `pacing.layers["1"].shop_max_tier = 1`——层 1 根本没有 tier≥2 的货，该保底**永远不可能满足**。改为"本层可出的最高档"后任何层都可满足，且语义更准：保证"每架至少有一件本层新档次的货"。
| `scripts/presentation/snapshots/shop_snapshot.gd` | 货架（当前 **:23** `for offer_key in offer_by_id:` 全量列）改为**只列 `shop_roll` 内的 N 件**；价格/品质/应急支付推导逻辑保持不变 |
| `scripts/domain/shop_command_rules.gd` | 购买校验增：**offer 不在本次 `shop_roll` 内 → 拒绝**，错误码 `shop_offer_not_in_stock`（放在现有 `shop_tier_locked` 之后、`insufficient_stone` 之前） |
| `tests/unit/test_shop_roll.gd` | 新建，见验收标准 |
| 契约回写 | `docs/contracts/2026-09-02-domain-ui-contract.md` 的 Shop 行补 `shop_roll` 语义与越权拒绝码；`2026-09-02-page-inventory-requirements.md` 黑市屏同步 |

### 2.2 交付物 / 预期结果

- 黑市每次进店只显示 N 件（不再全量列出），且**同一节点反复进出货架一致**；
- 购买不在货架上的货被领域层拒绝（不是 UI 藏起来）；
- 新建 `tests/unit/test_shop_roll.gd`；契约两页已回写。

### 2.3 验收标准（可量化）

1. **确定性**：同 run 种子 + 同节点，两次计算 `shop_roll` **逐元素相等**；
2. **节点相关性**：同层不同节点，`shop_roll` **不完全相同**（至少有一个不同种子的样本）；
3. **数量与保底**：层1/2/3/4/5 的货架长度分别为 **4/5/5/6/6**；每份货架**至少 1 件** `tier == 本层 shop_max_tier`（本层可出的最高档）；
4. **快照=购买**：快照列出的 id 集合 == `shop_roll` 集合；对**不在**该集合内的 offer 调用购买 → 返回 `ok=false` 且 `reason == "shop_offer_not_in_stock"`；
5. **不越层**：货架内不存在 `tier > max_tier` 的货（沿用现有 `shop_tier_locked` 语义，不得回退）；
6. 全量门：`unit` + `integration` 全绿；契约漂移工具 `ok`。

### 2.4 验收方式

```powershell
tools\test.ps1 -Test tests/unit/test_shop_roll.gd
tools\test.ps1 -Suite integration
tools\check.ps1          # 含契约漂移 check_contract_drift
```

期望：单测 0 失败；`check.ps1` rc=0 且漂移工具输出 `contract drift: ok (N identifiers resolved)`。

手工复核（可选）：

```powershell
tools\godot.ps1 --headless --path . -s tools\verify_interaction_loop.gd
```

期望：`AUDIT[Shop] ... dead=[] no_ui_click=[] occluded=[]`（黑市按钮仍可达）。

---

## T3 —— E5a：`verify_pacing_density` 扩 4 分类统计

### 3.1 具体实施内容

- 扩 `tools/verify_pacing_density.gd`：现有逐层节点构成统计之上，补
  **4 分类（`battle` / `rest` / `unknown` / `trade`）计数 + 占比**；
- 加**断言**：战斗占比必须落在 **50–60%**（与 `tests/unit/test_category_route.gd:97`
  的 `test_combat_share_within_50_60_percent` **同一口径**，避免两处标准打架）；
- 断言失败时 **`quit(1)`**（现在无论对错都 `quit(0)`，无法当门用）。

### 3.2 交付物 / 预期结果

- 工具输出每层一张分类表（计数 + 百分比）；
- 失败即非零退出码，可直接挂进 CI/门链。

### 3.3 验收标准

1. 3 个种子（现有 `[101, 4242, 777]`，可加）**× 5 层**全部打印分类表，四类计数之和 == 该层节点数；
2. 全部种子的战斗占比 **∈ [50%, 60%]**；
3. 故意把断言阈值调成不可能满足（临时）时，工具**返回非零退出码**——用完即还原，不提交。

### 3.4 验收方式

```powershell
tools\godot.ps1 --headless --path . -s tools\verify_pacing_density.gd
echo "exit=$LASTEXITCODE"
```

期望：打印 15 张分类表；`exit=0`。

---

## T4 —— E5b：`route_diversity` 全模板可达冒烟

### 4.1 具体实施内容

- 新建 `tools/verify_route_diversity.gd`：
  - 从 `data/nodes.json` 取**模板全集**（按 `stage` 分组）；
  - 对多种子（建议 ≥5）× 全 5 层跑 `MapGeneratorScript.build(seed, false)`，累计每个模板的出现次数；
  - 输出**覆盖表**：每层哪些模板出现过、哪些 `never_seen`；
  - 断言：**每个非锚点、非层专属的模板至少可达一次**；存在不可达即 `quit(1)` 并列出名单。
- **实现约束（重要）**：`layer_boss_*` 与锚点节点是**层专属**的，不能当"不可达"判红——
  按 `stage` 归层做断言，层内专属节点只在本层检查。
- **复用现有白名单，别另造一套**：`tools/verify_pacing_density.gd` 末尾已有
  `_is_special(template_id)`，列出 `ridge_black_market` / `refinement_hollow` / `rest_hollow` /
  `rest_shrine` / `yizang_ridge` / `final_boss_stand` / `layer_boss_stand_*`。
  T4 应**复用同一判据**（把该函数提取为两工具共享，或原样复制并加注释指向来源），
  否则两个工具会对"哪些模板算特殊"产生两套口径。

### 4.2 交付物 / 预期结果

- 新工具 + 一份"全模板可达性"报告（stdout）；
- 若确实存在不可达模板 → 工具报红并给名单（这本身就是有价值的结论，届时按 `on_skip`/`next_ids` 排查）。

### 4.3 验收标准

1. 工具对 ≥5 个种子跑完不报错，输出覆盖表；
2. `never_seen` 为空（按层归属判定后）；
3. 若断言失败，输出必须**点名**是哪个模板、属于哪层、`visible` 取值；
4. 工具退出码语义正确（全可达 0 / 有不可达 非 0）。

### 4.4 验收方式

```powershell
tools\godot.ps1 --headless --path . -s tools\verify_route_diversity.gd
echo "exit=$LASTEXITCODE"
```

期望：`exit=0`，覆盖表里每个模板至少出现 1 次。

---

## 批次收尾（4 项全过后）

```powershell
tools\check.ps1
```

期望：`rc=0`；并且：

- `data/enemies.json` 的**提交排除令解除**（`AGENTS.md` 待办第 4 条：E6 补 weight 验证后解除）；
- 回写 `AGENTS.md` 当前待办：把"E1–E7 整批"收敛为 **E 线已闭环**（见 `2026-09-10-open-items-and-decisions.md` §D1）；
- 更新 `docs/superpowers/plans/2026-09-09-visual-route-batch-plan.md` §1.5 队列状态。

---

## 汇总核对表（施工完成后逐项打勾）

| 任务 | 交付物 | 关键验收命令 | 通过判据 |
|---|---|---|---|
| **T1** 敌人按层随机 | `enemies.json weight` + `pacing.enemy_weights` + `enemy_roll` + `test_enemy_roll.gd` | `tools\test.ps1 -Test tests/unit/test_enemy_roll.gd` | 0 失败；同种子同敌；层品质递增；rank 门禁生效；旧路径逐字节一致 |
| **T2** 商店按层随机 | `shops.json weight` + `shop_roll` + 越权拒绝 + 契约回写 + `test_shop_roll.gd` | `tools\test.ps1 -Test tests/unit/test_shop_roll.gd` | 0 失败；N=4/5/5/6/6；保底 ≥1；快照=购买；越权返回 `shop_offer_not_in_stock` |
| **T3** pacing 分类统计 | `verify_pacing_density.gd` 扩展 | `tools\godot.ps1 --headless --path . -s tools\verify_pacing_density.gd` | 15 张分类表；战斗占比 50–60%；`exit=0` |
| **T4** route diversity | `verify_route_diversity.gd`（新建） | `tools\godot.ps1 --headless --path . -s tools\verify_route_diversity.gd` | `never_seen` 为空；`exit=0` |

---

## 9. 施工状态（2026-09-10 用户裁定后实施）

用户指令：**先修随机数 → 商店固定货架 → 敌人和点位加主题标签**。已按下述落地。

### 9.1 前置：随机数缺陷已修（MEMORY.md 同条目）

- 采用**方案 B**：`SeededRoll.index` 改为"以 `mixed_seed(seed, salt, 0)` 派生一条流，推进 tick 步后取一个值"，
  `SeededRng` 新增 `discard(n)`。**`tick = 0` 逐字节兼容** → `map_generator._node_rng` 与地图生成零影响。
- 新增 `tests/unit/test_seeded_roll_distribution.gd`（步长占比 / 2-gram 卡方 / salt 去相关）。
  **红→绿已验证**：旧实现下相邻步长只有 2 种（占比 0.998）、卡方 2901/6203；修复后 0.263/0.185/0.025、卡方 11.3/45.4。
- 因基线变更修正 4 条既有测试；**逐条判定均为断言脆弱性**（把过强前提改成真正的不变量），无产品 bug。

### 9.2 T2 敌人与点位主题标签 —— 已完成

- 主题白名单（`enemy_catalog.THEMES`）：`beast / faction / cultivator / neutral / anomaly`。
- `data/enemies.json` 12 条加 `theme`；`data/nodes.json` **15 个带 `enemy_kind` 的节点**加 `enemy_theme`。
  > 施工发现：带敌人的节点**不止 `type=combat`**——还有 `contact / caravan / pursuit / earth_vein`，
  > 它们都有 `fight` 选项，全部需要标签。
- 新增 `enemy_catalog.enemy_pool(catalog, theme, fallback_ids)`：**池空绝不返回空**（参考 Slay-The-Robot 的 fallback 约定）。
- **池很薄（实测）**：beast 6 / faction 2 / cultivator 2 / neutral 1 / anomaly 1；
  按"层 N 上限 = N"过滤后普通战斗候选：层1=3、层2=6、层3=7、层4=7、层5=7。
  → **层 4/5 不再变化**，随机收益有限。**扩敌人表（12 → 20+）是后续内容工作**，不阻塞机制落地。

### 9.3 T3 商店固定货架（E7）—— 已完成

与原卡的偏离（都是收窄，非扩张）：

| 项 | 原卡 | 实际 | 理由 |
|---|---|---|---|
| 上架范围 | 全部 offer 按层过滤后抽 N | **只抽"货"**（`purchase / material_purchase / gu_fang_unlock / barter / lifespan_deal`），**服务常驻**（`resource_trade / wash_notoriety / recipe_unlock / soul_boost`） | 既有语义里货阶门禁本就只作用于 `purchase`，服务是柜台业务；STS 与 deck_builder_tutorial 也是这个分工 |
| `shops.json` 加 `weight` | 计划加 | **未加** | 采用"洗牌取前 N"后权重用不上，加了就是死数据；将来要加权再补 |
| 越权拒绝范围 | 未限定 | **只约束 `shop_purchase`** | `npc_trade` 走 NPC 自己的 `npc.stock`，混用会误杀散修货郎货架（`test_npc_stock` 抓到，已修） |
| 保底 | `tier == 本层 shop_max_tier` | 同 | 层 1 也成立（原规格 `tier ≥ max(2,层)` 在层 1 不可满足，已修） |

- 新增 `tests/unit/test_shop_roll.gd` 9 例；3 条既有测试改为**从真实货架取货**。
- 契约回写：`domain-ui-contract` Shop 行（含判定顺序 阶 → 架 → 钱）+ `page-inventory` P5 验收项。

### 9.4 未开工：T4 敌人按层抽取（E6）

- 池已就绪（主题标签 + `enemy_pool`），**只差**：`pacing.layers` 各加 `enemy_rank_max`、
  `map_generator` 写 `enemy_roll`、`battle_command_facade._v1_enemies` 优先读 `enemy_roll`（缺失回退现行为）、
  锚点与大层 Boss 免抽、`tests/unit/test_enemy_roll.gd`。
- 等待用户确认「是否扩敌人表」，或先按现有薄池落地（机制正确但层 4/5 变化有限）。
