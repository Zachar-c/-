# 模块接口：表现层命令面（run_controller + run_command_builder）

> 契约层级：表现层。UI 与领域的唯一桥梁：UI 调用 controller 提交命令 → 领域执行 → 快照回写 UI。
> 仓库路径：`scripts/presentation/run_controller.gd`、`scripts/presentation/run_command_builder.gd`、`scripts/presentation/run_snapshot_builder.gd`

## 职责

承载运行期全局状态（当前 RunState + route + battle）、命令提交（路由到 resolver/facade）、视图切换与存档加载；把领域结果翻译为 UI 可渲染的快照。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `start_new_run(seed, school, contract_ids, buff_ids)` | 种子+开局选项 | void | 开局（含 buff 结算、初始蛊） |
| `start_m0_run(seed)` | 种子 | void | 独立四战 M0 入口；写入 `node_flags.m0_mode`，复用现有路线/战斗管线 |
| `submit_command(command)` | 命令字典 | `{ok, ...}` | **UI 唯一提交入口**（路由 battle→facade / 其余→resolver） |
| `submit_dialogue_selection(title)` | 对话选项标题 | Dictionary | 对话分支选择 |
| `save_current_run() / load_saved_run()` | — | Error/bool | 存档（无感自动保存） |
| `save_and_leave_map() / leave_map_without_save()` | — | void | 地图离场（保存/放弃） |
| `visible_route_nodes(forward_layers=2)` | 层数 | Array | 地图可见节点（经 map_generator） |
| `current_view_name()` | — | String | 当前屏名（路由键） |
| `rejection_text(reason)` | 领域拒绝原因 | String | 用户可读文案（UI 弹错用） |

## 关键数据契约

- 命令构建：`RunCommandBuilder.for_screen(screen, controller)` 按屏注册命令集；`_battle_card_command/_rest_choose_command/_shop_buy_command` 等按卡片 ID 组装命令
- 战斗屏命令面（第三阶段 Task 3，2026-09-17）：新增 `submit_command(command)`——UI **新路径只转呈卡片自带的结构化命令**（`card.command` + 本屏交互态补入的 `target_id`）；`play_card(action_id, target_id, confirmed)` 降级为按 ID 组装的兼容包装（存量夹具/旧信封卡），不得再作为新 UI 的入口
- M0 命令：大厅 `new_m0_run` 进入切片；Reward `m0_reward_take` 由控制器校验当前三选一会话后，携带内部 `option` 经 `Resolver.apply` 结算；UI 不直调 `M0RewardResolver`。
- 战斗杀招命令：`play_kill_move` 携带可选 `confirmed`（T16，2026-09-15）。残锋会触发质变且未确认时，领域侧硬拦 `sword_mark_confirm_required`；表现层确认框复用 `GuConfirmDialog`，不得静默出招
- 战斗终局收口（第三阶段 Task 4，2026-09-17）：victory / retreat / death **只有一条收口路径** `RunBattleFlow.finish_battle_in_session`——它调 `finalize_session` 交出账本快照、由生命周期层落**唯一**一条 `battle_finished`（`info._battle2_ledger` 携带快照），再分派 Reward / Encounter / Ending。victory / retreat 收口后清空 `controller.current_battle`；**战死保留战斗现场**（死因归因与死亡复盘通路读它，run 已终结不会再续战），并由 `DeathReportBuilder` 在收口前生成报告。门面自身不写 `battle_finished`
- 快照：`RunSnapshotBuilder` 输出 UI 消费字典（资源条/立绘/意图/卡片），键全集见 `docs/contracts/2026-09-02-domain-ui-contract.md`
- 视图路由：`RunScreenRouter.MASTER_SCENE_PATHS` 唯一路由表（.tscn，无 guitkx 生成层；W12 split 自 `run_controller.gd` 迁至 `run_screen_router.gd`）

## 信号

无（controller 非信号驱动；UI 经快照轮询/回调）。若未来需要事件推送，新增信号必须同步本页。

## 依赖

- 全部 domain 模块（resolver/facade/map_generator/loot/economy）+ `content_catalog.gd` + `run_state.gd`
- `action_preview_service.gd`（卡片来源）；`run_snapshot_builder.gd`（快照）；`audio_director.gd`（BGM 随屏切换）

## 强制规则（Agent 生成代码必读）

1. UI 只调 `submit_command` 且命令必须来自预览卡片；禁止 UI 直接 import domain resolver/facade。
2. 新增屏幕：`MASTER_SCENE_PATHS` 注册 + `for_screen` 命令集 + 快照键契约，三处同步。
3. controller 不得缓存领域规则结果：每个命令重新经领域校验，防止状态漂移。
4. 存档键/结构变更必须同步 `save_repository` 序列化与 `to_save_data`，保证旧档可加载。
5. 表现层只读快照，不写状态键；发现「数据拿不到」先查快照构建，不要绕道改状态。
