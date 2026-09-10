# E6 敌人按层抽取（enemy_roll）落地报告

> 日期：2026-09-10
> 用户指令：退役死字段（并明确**蛊修最低一转**）→ 处理 `tools/_reg*.log` → 继续实施 E6 按层抽取
> 验收：`tests/unit/test_enemy_roll.gd` 15 例；unit 全量见文末

## 1. 抽取口径

```
候选池 = 模板 enemy_theme 的主题池
         ∩ rank ∈ [enemy_rank_min, enemy_rank_max]     ← 本层区间
         ∩ tier != boss                                ← Boss 只在锚点摆放
→ 按 pacing.enemy_weights 的 tier 权重加权（common 75 / elite 25 / boss 0）
→ 同节点内不重复；数量 = 模板声明的敌人个数（保留多敌遭遇的形状）
```

**四条不变量**（每条都对应一个"错了会静默毁掉节奏"的点）：

| 不变量 | 为什么必须 | 守卫 |
|---|---|---|
| Boss 绝不随机出现 | 关底台是刻意摆放的锚点；随机抽到 Boss 会让层节奏与"Boss 是刻意安排"同时失效 | `test_roll_never_returns_a_boss_across_every_theme_and_layer`（**红→绿已验证**：移除排除后立刻报出 80 例 Boss，含 `clan_patriarch@L5`） |
| 同节点不重复 | 节点上出现两个同名敌人会被 `content_catalog` 当**错误**拒绝 | `test_roll_does_not_repeat_within_one_node` |
| 区间为空先放宽下界 | 否则某个主题会在深层被整层抽空（neutral 主题在层 5 的 [3,5] 里没有成员） | `test_roll_relaxes_the_floor_instead_of_emptying_a_theme` |
| 不扰动地图布局 | 抽取若消费拓扑共享的 rng，会让**所有既有种子的地图变形** | `test_enemy_roll_does_not_perturb_the_map_layout`（去掉敌人目录后逐字段对照） |

最后一条是关键：抽取走**独立派生流** `mixed_seed(seed, "enemy_roll:<实例 id>", 0)`，
与拓扑生成共享的 rng 互不相干——所以 E6 落地**不改动既有地图布局与既有种子产出**。

## 2. 逐层效果（5 个种子实测）

| 层 | rank 区间 | 实测候选 | 说明 |
|---|---|---|---|
| 1 | [0,1] | 3 种（山猪 / 兽群 / 山脊猎犬） | 未入转的杂鱼与一转并见 |
| 2 | [0,2] | 5 种 | 铁皮山猪、铁冠鹰进入 |
| 3 | [1,3] | 11 种 | **首次出现非野兽战斗**（势力/蛊修） |
| 4 | [2,4] | 10 种 | 血森狼、家老进入 |
| 5 | [3,5] | 6 种 | 龙鹰（rank 5）出现；**山猪不再出现** |

改动前层 4/5 的战斗与层 3 完全同质（都是同一批），现在每层都有独立的品质带。

> 施工中发现的缺陷：只设上限时**层 5 仍能抽到 rank-0 的山猪**。补 `enemy_rank_min`
> （层 1/2 = 0、层 3 = 1、层 4 = 2、层 5 = 3）后消除。这正是 E6 原文"**按层品质**随机"的含义。

## 3. 接线位置

| 文件 | 改动 |
|---|---|
| `data/pacing.json` | 每层加 `enemy_rank_min` / `enemy_rank_max`；顶层加 `enemy_weights`（+15 行，纯新增） |
| `scripts/domain/enemy_catalog.gd` | 新增 `roll_enemy_ids` / `_rollable_candidates` / `_weighted_pick`；新增 `GRADES` 常量与阶梯校验 |
| `scripts/domain/map_generator.gd` | `_generate_instance_route` 多收一个 `enemy_catalog`；`build` 透传；非锚点 `type=="combat"` 实例写 `enemy_roll` |
| `scripts/presentation/run_controller.gd` | encounter 优先透传 `enemy_roll` |
| `scripts/domain/battle_command_facade.gd` | `_v1_enemies` 与 `start` 的敌人来源优先级改为 `enemy_roll` > `enemy_kinds` > `enemy_kind` |
| `scripts/domain/content_catalog.gd` | 校验 `enemy_rank_min/max` 与 `enemy_weights`（含 **`boss` 必须为 0**）；删除退役的 `turn` 校验 |

**旧存档兼容**：`enemy_roll` 随 `route` 一起序列化；旧档没有该键时战斗侧自动回退到模板敌人，
回退分支有专门用例（`test_facade_falls_back_to_the_template_enemy_without_a_roll`，含多敌遭遇）。

## 4. 实测统计

- 5 个种子共 289 个非锚点战斗节点，**全部**带 `enemy_roll`；锚点（5 个/局）**全部**不带。
- 不变量扫描（5 种子 × 全节点）：Boss 出现在随机结果 = **0**；主题不符 = **0**；
  同节点重复 = **0**；数量与模板声明不符 = **0**。
- tier 权重实测：400 次抽取的 elite 占比 **25.5%**（配置 25%）。

## 5. 文档回写

- `docs/contracts/module-interfaces/03-map-generation.md`：node 字典新增 `enemy_roll` 契约
  （含"锚点不带""独立派生流""随 route 进存档""旧档回退"）。
- `docs/contracts/module-interfaces/01-battle-settlement.md`：`Facade.start` 的敌人来源优先级。
- `docs/contracts/module-interfaces/04-content-catalog.md`：敌人 schema（`grade`、无 `turn`/`essence`）、
  阶梯口径、`enemy_weights` 与层区间、`roll_enemy_ids` 接口。
- `docs/lore/canon-index.md`：新增 `CAN-RANK-LADDER-001`（用户裁定的阶梯）、
  `CAN-BEAST-BASELINE-001`、`CAN-MORTAL-001`、`CAN-BEAST-HERD-001`。
- `AGENTS.md`：E6 状态更新。
