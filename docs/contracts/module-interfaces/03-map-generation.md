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
| `instance_id_for(layer, row, index)` | 三层坐标 | String | 节点 ID 规范（`node_L_R_I`） |
| `layer_index(stage)` | `"one".."five"` | int 1..5 | 层名↔层号 |

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
