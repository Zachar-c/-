# 五流派收口冒烟矩阵（2026-08-25）

> 日期：2026-08-25
> 状态：已归档
> 范围：五流派收口冒烟矩阵；保留用于批次追踪。
> 基线：`branch=master @ c597dba`；该计划最终变更以此提交为准。
> 替代关系：矩阵结论已吸收进当前测试基线。


- 分支/工作树：`task1-vendor-open-rpg` 就地执行；基线 `bb0b46f` → 本批 HEAD（见下）
- 执行：控制器实现（T1a/b/c、T2、T3、T5），子代理通道不稳降级（用户裁定）
- 总验证：**unit 424 测试 / 423 过 / 0 败 / 1 pre-existing risky；integration 8 / 8 过（1008 断言）**

## 矩阵：五派 × 最小闭环

| 环节 | 血 | 气 | 力 | 魂 | 炼 | 证据 |
|---|---|---|---|---|---|---|
| 流派初始卡组（5×5+新人注入） | ✅ | ✅ | ✅ | ✅ | ✅ | `tests/integration/test_five_schools_smoke.gd` 全系 50 种子循环（985 断言）；`test_school_starter_data.gd`（注：气系 starter 含新人蛊 `small_light_gu`，去重后注入 5 只，属设计事实） |
| 专属池数据表+隔离校验 | ✅ | ✅ | ✅ | ✅ | ✅ | `school_pools.json`；`test_school_starter_data.gd::test_school_pools_are_isolated_and_school_matched`；catalog 6 条 hint 校验 |
| 战利品学院加权（同系优先+回退） | ✅ | ✅ | ✅ | ✅ | ✅ | `test_loot_tables.gd`（12 种子 force→stone_shell / blood→gen_blood_attack_001 / qi 回退全桶） |
| 战斗行动（basic/卡牌） | ✅ | ✅ | ✅ | ✅ | ✅ | 冒烟 Leg2 全系 50 种子 |
| 材料保底（气道材料） | ✅ | ✅ | ✅ | ✅ | ✅ | `test_loot_pity.gd` 材料保底 4 测试（强制补给/自然命中重置/前进/无池禁止凭空） |
| 炼道战斗内炼蛊（fixed/盲盒/炸炉） | — | — | — | — | ✅ | `test_battle_synthesis.gd` 8 测试（成功/失败/补偿封顶 90 永不到 100/盲盒反噬 gu_erosion/三重拒绝） |
| 死亡结算→新局重建 | ✅ | ✅ | ✅ | ✅ | ✅ | 冒烟 Leg5 全系 50 种子（`force_death_for_test` → terminal → 重开局注入一致） |
| 魂道既有机制 | — | — | — | ✅ | — | `test_soul_school.gd`、`test_v3_soul_and_backlash.gd` 回归全绿（用户既有） |
| S4 三死线/精准死因 | (用户 `1c9d3ec` 交付，非本批) | | | | | `1c9d3ec` 含死亡线常驻+死因面板；回归全绿 |

## 本批提交链（HEAD=`c9c1339` 之后）

- `0366178` RED 规格（3 测试文件）
- `60e467b` T1a refine 系加入、soul `name_zh`→`name`、五系/display-name 校验
- `5cd76bd` T1b `school_pools.json` + 池校验（4 hint）
- `e69d9f7` T1c loot 学院过滤（`_roll_gu` 按专属池交集，回退全桶）
- `4b29bcf` style: 池表末尾换行（review Minor#1）
- `3f45697` T2 材料保底（`material_pity` 计数器，嵌入 `pity` 配置；`RunState.material_pity` 入 STATE_FIELDS）
- `c9c1339` T3 炼道战斗内炼蛊（`synthesis.json`、`refine` 命令、补偿计数、盲盒炸炉反噬）
- `(T5)` 冒烟测试 + 本矩阵文档

## 遗留 Minor（终审台账，均不阻塞）

1. `school_pools.json` 未知池键加固（现行校验只遍历 `SCHOOL_IDS`，拼写错误的池键会被静默忽略）— 低风险，数据目录自查
2. 盲盒炸炉在 `battle_blind` 上的材料无兜底示例测试（仅 4 种子循环覆盖失败路径）
3. 材料展示聚合 `smoke_render`/`resource_icon` 有遗留 `"material"` 单值资源位（用户 UI 会话领域，未动）

## 说明

- `.import` 编辑器噪音与 4 个用户 WIP 文件（3 `.guitkx` + `map_generator.gd`）全程未触碰、未提交。
- S4（T4）由用户 `1c9d3ec` 交付，本批摘除。
