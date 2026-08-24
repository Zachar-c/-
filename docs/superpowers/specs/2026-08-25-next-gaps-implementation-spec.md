# 下一批工程缺口实施规格（地图收敛网络 / 精英BOSS / 牌组容量 / 盲盒凶兆）

> 日期：2026-08-25
> 依据：`2026-08-25-nanjiang-card-roguelike-vision-review.md` §3 衔接总表与 §5 顺序；AGENTS.md"下一批工程缺口"。
> 基线：工作树 @ `130b7e1`；201 unit + 6 integration 全绿；`check.ps1` exit 0。
> 实施方式：T5→T6→T7→T8 依序、每 Task 独立小提交、失败测试先行、全量验证。
> 前置声明：T6 的**终局门禁**（升仙需先胜 BOSS）依赖评审 P5 未裁定口径，本批**只做数据与校验**，不接门禁；P5 裁定后单独落地。

## T5 地图收敛网络生成（M1/M2/M5 最小可行版）

### 目标

非首局（`first_run == false`）的生成路径从"分段链式"升级为**网状两端收敛**：每阶段 2–3 个节点、节点多入少出、跨阶段支路、终点收敛到 `ascension_window`；每局保证锚点类型（shop / refinement / inheritance）至少各 1；固定种子可复现；首局（seed 101, first_run.json）路径保持不变。

### 设计（代码事实为基础）

`MapGenerator._generated_route_ids(seed, nodes)` 改造为网络生成（保持 `build(seed, first_run)` 对外契约）：

1. **阶段选取**：沿用每阶段候选池（one/three/four/five），每阶段选 2–3 个节点（种子随机）；
2. **硬性锚点**：仍强制 `earth_vein_contest`（一次）、`poison_fog_vein`、`ascension_window` 收尾（现有测试依赖）；
3. **类型锚点保底**：若某阶段已选节点不含类型 shop / refinement / inheritance，从同阶段该类型候选补入（替换一个随机已选项），保证每局三种功能都出现；
4. **连线（多入少出/收敛）**：`_route_from_ids` 之后做网络化 pass——阶段 i 的每个节点 `next_ids` 指向阶段 i+1 的已选节点（按种子确定性取 1–2 个）；最后阶段全指向 `ascension_window`；追加少量"跨支路跳转"（种子决定，跳到后续 1–2 阶段的节点）；起点阶段节点保留 `start: true`；
5. **防刷（M5 精神）**：不新增黑市数量规则（下批），仅依赖节点预算与类型保底。

### 改动点

| 文件 | 改动 |
| --- | --- |
| `scripts/domain/map_generator.gd` | 新增 `_networkize(route_ids, nodes, seed)`（阶段分组→锚点保底→连线）；`_generated_route_ids` 调用它；`_route_from_ids` 保持（first_run 不变）；可见性/可达性/树列 API 不改 |
| 数据 | `nodes.json` 不动（网络化全靠现有 next_ids 数据与生成逻辑） |

### 测试（tests/unit/test_map_network.gd）

1. 可复现：同种子两次 build 结果一致（含 next_ids）。
2. 收敛：任意可达节点沿 `next_ids` 存在路径到达 `ascension_window`（1–20 种子）。
3. 锚点保底：1–20 种子每局至少 1 个 shop、1 个 refinement、1 个 inheritance 类型节点。
4. 硬锚点不变：`earth_vein_contest` 每局至多一次；`poison_fog_vein`/`ascension_window` 在列。
5. 首局回归：`build(101, true)` 路由与 `first_run.json` 完全一致。
6. 无死路：可达节点集合在终局前非空（无提前断链）。

## T6 精英/BOSS 敌人数据与终局合并（数据层；终局门禁留待 P5）

### 目标

新增精英与 BOSS 敌人数据并通过目录校验；战斗系统零改动即支持（意图/反应机制通用）；终局合并（BOSS 战↔升仙窗口）等待 P5 裁定。

### 改动点

| 文件 | 改动 |
| --- | --- |
| `data/enemies.json` | 新增 `ridge_elite_scout`（tier `elite`，hp 6，essence 4，意图伤害 3，含一个反应）与 `miasma_vein_lord`（tier `boss`，hp 9，essence 6，意图伤害 4，含反应）——技能数值走现有 intents/clues/reactions 字段 |
| `scripts/domain/enemy_catalog.gd` | 校验扩展：`tier` ∈ [common, elite, boss]（沿用 `_is_integral` 思路）；标签/目录表加 elite/boss 中文名（display_text 或 enemy_catalog 内） |
| `scripts/integration/open_rpg_adapter.gd` | 仅确认战斗 context 不变（无需改） |

### 测试（tests/unit/test_enemy_catalog.gd 扩展）

1. 新敌人通过 `ContentCatalog.validate()`（无错误）。
2. 坏数据：`tier: "mythic"` → 校验报错。
3. 战斗可用：`BattleResolver.start({"enemy_kind": "miasma_vein_lord"}, ...)` 开局正常（意图/HP/先手字段齐全）。
4. 标签：敌人目录包含精英/BOSS 中文标签。

> 终局门禁（升仙窗口前必经 BOSS 战、attempt_ascension 前置检查）列为 P5 裁定后的独立小任务，不进本批。

## T7 牌组数量模型（C2/P11 最小可行版）

### 目标

牌组总量受限（容量），产出蛊虫类操作（购买/炼蛊/易物）不静默超限；移除/升级/复制机制已有命令，补齐容量校验与预览反馈。

### 设计

- 容量常量：新领域助手 `DeckCapacityScript`（或并入现有 helper）：`static func card_count(state, catalog) -> int`（= `DeckBuilder.build_card_cache` 数量）与 `static func capacity() -> int`（默认 12，数据表 `deck.json` 可配，v1 常量即可）。
- 校验点：`_add_gu_transaction`（购买/换蛊/炼蛊 combine→fixed 产出）与 `_apply_fixed_recipe` 产出路径、`_shop_barter` 产出、盲盒 `mutate_to` 产出：产出后数量 > capacity → 拒绝（对应 feed `deck_capacity_exceeded`），事件不写入。
- 移除路径：`destroy_gu`（弃蛊）与 `sell_gu`、炼蛊消耗已是移除手段；不新增命令。
- 预览：蛊虫相关卡片（购买/炼蛊/换蛊）在"将导致牌组超限"时 `executable=false` + 文案"牌组已满（%d/%d），请先弃蛊或出售"。

### 改动点

| 文件 | 改动 |
| --- | --- |
| `scripts/domain/deck_capacity.gd`（新建，`class_name DeckCapacity`） | `card_count(state, catalog)`、`capacity()`、`would_exceed(state, catalog, extra_cards: int)` |
| `scripts/domain/resolver.gd` | 各产出路径加容量拒检；`_add_gu_transaction` 签名扩展（optional `extra_cards` 或按产出蛊查重） |
| `scripts/domain/action_preview_service.gd` | 产出类卡片容量投影与文案 |
| `data/deck.json`（新建） | `{"capacity": 12}`，ContentCatalog 加载 + 整数校验 |

### 测试（tests/unit/test_deck_capacity.gd）

1. 默认容量 12；`card_count` 与 deck_cache 一致。
2. 购买使牌组 12→13 → 拒绝 `deck_capacity_exceeded`，状态不变。
3. 等于容量时购买 → 拒绝；低于容量 → 接受。
4. 炼蛊 fixed 产出超限 → 拒绝（输入不消耗）。
5. `destroy_gu` 后容量释放，可再购买。
6. 预览卡片超限时 executable=false + 文案含"牌组已满"。

## T8 盲盒负面梯度与凶兆提示（G1/P10）

### 现状核实

`free_mix` 三结果权重 5:4:1（destroyed / mutation_venom / explosion，爆炸含气血 2+魂魄 1+寿元 1 代价，事件 reason 齐备）——**梯度已达标，不重做数值**。缺口在凶兆提示：未知档只有统一模糊文案，未按投入组合分化。

### 改动点

| 文件 | 改动 |
| --- | --- |
| `data/refinement_recipes.json` | `free_mix` 增加 `risk_hints`：按输入蛊 `tags` 匹配的模糊凶兆文案（如含 `poison` 标签 → "炉中隐约腥气，恐催生毒物"；含 `fire`/高转 → "炉火躁动" 等），v1 至少 2 条规则 |
| `scripts/domain/action_preview_service.gd` | `_append_free_mix_card` 未知档：有命中规则显示命中文案，无规则保持原模糊文案；已知档（meta 记录）优先级不变 |
| `scripts/domain/content_catalog.gd` | `risk_hints` 校验（tags 必须存在于 gu tags 表；text 非空） |

### 测试（tests/unit/test_free_mix_ominous.gd）

1. 含毒标签输入的盲盒预览出现规则凶兆文案。
2. 无标签组合回退原模糊文案。
3. 已知档（meta.unlocked_random_outcomes）优先于凶兆规则。
4. 校验：`risk_hints` 引用不存在标签 → 报错。

## 验收与风险

- 每 Task：失败测试先行 → 最小实现 → 全量 `tools/test.ps1`（当前 201+6）→ `tools/check.ps1` → 独立小提交（ASCII）。
- 回归风险清单：
  - T5：`test_generated_route_does_not_repeat_required_contest`、`test_same_seed_builds_same_non_first_route` 是主要触点；`test_v2_first_slice_flow`/`test_v3_ui_exposure`（first_run）不受影响。
  - T6：`enemy_catalog` 标签测试扩展；战斗无行为改动。
  - T7：产出路径拒检可能触碰 `test_v2_economy_resolver`（购买/炼蛊）——默认容量 12 下现有用例不超限（现牌组 ≤5），预期零回归。
  - T8：预览文案断言仅新增，不动已有"结果未明"/"畸变"断言。
- 边界约定：新增 JSON 数值 `_is_integral` 校验；状态变化入事件日志；UI 只展示投影。

> 本规格待批准后进入 TDD；T6 终局门禁与 P5–P12 未裁定项另行立项。