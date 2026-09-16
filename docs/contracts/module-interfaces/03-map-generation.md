# 模块接口：地图节点生成（map_generator）

> 契约层级：领域层。地图拓扑唯一来源；表现层只读 `route` 渲染，禁止改写节点字段。
> 仓库路径：`scripts/domain/map_generator.gd`；裁定表：`data/pacing.json`、`data/nodes.json`

## 职责

按种子生成五大层扇形收敛拓扑（每大层 8–11 行 × 每行 2–6 节点，Boss 行 1 节点），按 pacing 裁定表保底投放锚点，并提供可见性/可达性查询。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `build(seed_value, first_run, catalog)` | 种子 + 是否教学链 | `Array[Dictionary]`（route） | **唯一生成入口**；教学链=13 节点线性骨架，实例局=五层拓扑 |
| `reachable_nodes(route, state)` | route + RunState | `Array[Dictionary]` | 当前可达节点（沿用已访问集合） |
| `visible_nodes(route, state, forward_layers=1)` | route + state | `Array[Dictionary]` | 迷雾揭示：当前选择层 + 前瞻 N 层 |
| `visible_node_ids(route, state, forward_layers)` | 同上 | `Array[String]` | 便捷变体 |
| `tree_columns(route)` | route | `Array[Array]` | 列宽分组（UI 画树用） |
| `instance_id_for(layer, row, index)` | 三层坐标 | String | 节点 ID 规范（`L{layer}R{row}N{index}`） |
| `layer_index(stage)` | `"one".."five"` | int 1..5 | 层名↔层号 |
| `node_threat(node, catalog)` | node 字典 + catalog | `""` \| `"elite"` | **D7（2026-09-16）遭遇威胁只读投影**：遭遇里有 `tier=="elite"` 敌人即 `"elite"`。读键顺序 `enemy_roll` → `enemy_kinds` → `enemy_kind`（与战斗侧同源）；仅 `type=="combat"`；`revealed==false` 一律 `""`（迷雾纪律）。**判据读 catalog 的 `tier`，不得退回 id 子串判**（12 个精英里只有 1 个 id 含 "elite"）。表达的是**遭遇风险**，不承诺结算 tier |
| `encounter_enemy_ids(node)` | node 字典 | `Array` | 上面的读键顺序抽出为可复用静态函数（威胁投影与测试共用，避免两处各写一套） |

## 关键数据契约（node 字典）

- `{id, template_id, layer, row, visible, start, next_ids[], type ∈ {combat/rest/shop/inheritance/refinement}, ...}`
- **`enemy_roll: Array[String]`（E6，2026-09-10）**：仅写在 **`type=="combat"` 且非锚点**的实例上，
  是"本节点要打的敌人"。锚点、各大层关底台（`layer_boss_stand_N` / `final_boss_stand`）**不带该键**——
  它们是刻意摆放的，Boss 不会随机出现。
  - 抽取口径：候选池 = 模板 `enemy_theme` 的主题池 ∩ 本层 `enemy_rank_min..enemy_rank_max`
    ∩ `tier != boss`；按 `pacing.enemy_weights` 的 tier 权重加权、**同节点内不重复**；
    数量 = 模板声明的敌人个数（`enemy_kinds` 长度，缺省 1），因此多敌遭遇（如 `beast_swarm_pass`）
    的**形状**被保留。
  - **确定性**：种子流 = `mixed_seed(seed, "enemy_roll:<实例 id>", 0)`，与拓扑生成共享的 rng **相互独立**
    ——所以该字段可用 `stripped`（去掉敌人目录）对照断言地图结构逐字段不变，
    引入 E6 **不改动既有地图布局与既有种子产出**。
  - 该键随 `route` 一起进存档；旧存档无此键时战斗侧自动回退（见 01 页）。
- **`threat` 不在 route 节点上**（D7，2026-09-16）：它是**表现层快照键**，由 `map_snapshot` 调用
  `MapGenerator.node_threat` 现算——**不进 route、不进存档、无迁移成本**，动作方式是纯读投影。
- 锚点行语义：`"mid"=row/2`、`"pre_boss"=row_count-2`；`pacing.json.layers["1"].anchors` = `yizang_ridge(pre_boss)` + `refinement_hollow(mid)`
- 黑市 `ridge_black_market` 每大层恰 1 处（mid 行）；休整 `rest_hollow/rest_shrine` 每三行交错
- 路由含 `final_boss_stand`（末层关底）与 `ascension_window`（仅从 Boss 台可达）

## 信号

无（纯函数式 domain 模块）。

## 依赖

- `data/pacing.json`（layers 裁定表：行数/锚点/模板池）、`data/nodes.json`（节点模板）、`data/first_run.json`（教学链）
- `seeded_roll.gd`（SeededRng，种子确定性）；`run_state.gd`（可达性判定）

## 强制规则（Agent 生成代码必读）

1. 拓扑生成只经 `build`；禁止在 UI/控制器手写节点数组。
2. 新增节点类型须三处同步：`nodes.json` 模板、`pacing.json` 池/锚点、`docs/contracts/2026-09-02-page-inventory-requirements.md` 页面需求。
3. 可见性/可达性只经 `visible_nodes/reachable_nodes` 查询，表现层不得自行遍历 `next_ids` 推导。
4. 行/列布局改动须保持 `_anchor_rows` 保底语义（黑市/休整/传承/炼蛊锚点不得静默丢失），相关守卫测试 `test_map_anchor_guards.gd` 必须保持全绿。
