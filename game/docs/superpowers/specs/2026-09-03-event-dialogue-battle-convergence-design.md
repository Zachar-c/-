# Event Dialogue and Battle Convergence Design

## Goal

将事件叙事迁移到 Dialogue Manager 分支脚本适配层，并把现有 V1 战斗与 Battle2 台账收敛为单一可执行入口；修复旅行断路、初始蛊无效果、事件无反馈和战斗卡牌点击卡关。

## Boundaries

- `RunState`、`EffectResolver`、`ContentCatalog` 和事件日志继续作为唯一领域边界。
- Dialogue Manager 只读取 `.dialogue` 脚本并返回分支 ID/文本，不扣资源、不掷骰、不修改状态、不跳地图。
- 事件分支 ID 由适配器映射到现有 `EncounterSessionResolver`/`Resolver` 命令；拒绝和成功都写入现有反馈流。
- 战斗唯一执行入口为 `BattleCommandFacade` -> `V1BattleResolver`；`Battle2TurnEngine` 仅保留念头台账纯函数，不再执行第二套战斗规则。
- 蛊实例按 `gu.json` 的 `v1_effect` 结算。没有显式效果的初始战斗蛊使用其 `combat` 角色的最小数据驱动兜底，并在测试中覆盖六类效果。
- `first_run.route_ids` 生成路线时只保留路线内后继；末节点后继为空，非末节点至少一条真实后继。

## Dialogue Flow

```text
node event -> DialogueAdapter.start(event_id, context)
  -> branch id -> existing command
  -> Resolver/EncounterSessionResolver
  -> append_event + ResultFeed + Chinese feedback
```

缺少脚本或分支时使用现有模板网关的中文降级文本，并返回可见的 `last_feedback`，禁止静默离开。

## Battle Flow

```text
mouse click -> battle_screen_view -> run_command_builder
  -> BattleCommandFacade.apply_turn
  -> V1BattleResolver.play_gu/basic_attack/end_turn
  -> RunState event log + snapshot refresh
```

单目标蛊先进入目标选择；危险蛊先确认；过期快照被拒绝并刷新。卡牌按钮必须可点击，且不可执行状态必须显示中文原因。

## Third-party

采用 [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager)，MIT License，固定审计提交 `8a49e8001a9021e1982b6e31a10066b41eac2fd2`，目标 Godot 4.6+。本次只引入脚本资源和适配器，不让插件持有 RunState。

## Verification

- GUT：事件脚本/分支映射、事件反馈、战斗六类初始蛊、卡牌点击命令、路线后继闭合。
- `tools/check.ps1`、`git diff --check`。
- Godot headless smoke，必要时使用现有渲染脚本检查战斗与地图挂载。
