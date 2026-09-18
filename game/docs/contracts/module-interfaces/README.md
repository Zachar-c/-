# 模块接口约定（Module Interfaces）

> 给每个核心系统 1 页接口约定：输入输出、信号、依赖、强制规则。
> **Agent 生成代码时强制参考本目录**，避免跨模块乱调用。

## 索引

| # | 模块 | 文件 | 一句话 |
|---|---|---|---|
| 01 | 战斗结算 | `v1_battle_resolver.gd` + `battle_command_facade.gd` | 蛊行动制战斗状态机，唯一入口 `Facade.apply_turn` |
| 02 | 蛊实体与合成 | `gu_instance.gd` + `synthesis_rules.gd` + `recipe_rules.gd` | 蛊实例生命周期 + 配对映射合成 |
| 03 | 地图节点生成 | `map_generator.gd` | 五层拓扑 + 锚点保底 + 可见性/可达性 |
| 04 | 内容目录 | `content_catalog.gd` | 数据唯一加载入口 + Schema 校验 |
| 05 | 运行状态 | `run_state.gd` + `save_repository.gd` | 单局状态权威载体 + 存档 |
| 06 | 行动预览 | `action_preview_service.gd` | UI 命令卡片的唯一来源 |
| 07 | 领域动作路由 | `resolver.gd` + `loot_resolver.gd` + `economy_rules.gd` | 非战斗动作唯一路由 + 战利品/经济 |
| 08 | 表现层命令面 | `run_controller.gd` + `run_command_builder.gd` | UI↔领域唯一桥梁 |

## 数据流总览（单向依赖）

```
data/ JSON ──> content_catalog ──> domain 规则（resolver/facade/map/loot/economy）
                                      ▲              │
                      action_preview  │              ▼
                                      └──── run_state ◄── battle（临时态）
                                                    │
run_controller ──> run_command_builder ──> Resolver/Facade ──> run_state ──> run_snapshot_builder ──> UI
```

依赖方向：表现层 → 领域层 → 数据层，**禁止反向依赖**（domain 不 import presentation；脚本不直接读 JSON）。

## 变更流程（改接口必做）

1. 改接口（函数签名/数据键/命令面）→ 先更新本目录对应页。
2. 改数据键/命令面 → 同时更新 `docs/contracts/2026-09-02-domain-ui-contract.md`。
3. 新增模块 → 本目录加一页 + 索引 + 数据流更新。
4. 全量回归（unit + integration）保持全绿后交付。
