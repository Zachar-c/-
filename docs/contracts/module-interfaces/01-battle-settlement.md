# 模块接口：战斗结算（v1_battle_resolver + battle_command_facade）

> 契约层级：领域层。本页是 Agent 接入战斗的唯一入口约定，禁止绕过 facade 直接操作 battle 字典。
> 仓库路径：`scripts/domain/v1_battle_resolver.gd`、`scripts/domain/battle_command_facade.gd`

## 职责

推进蛊行动制战斗的状态机：`player_action`（出蛊/拳脚/杀招/结束回合/撤退）→ 结算 → `victory|defeat|player_action`，不持有任何表现层引用。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `Facade.start(encounter, state, catalog)` | encounter: `{enemy_kind}`；state: RunState | `{battle, enemies, result}` | 构建战斗字典；Boss 战写 `flags.boss_battle=true` |
| `Facade.apply_turn(battle, state, command, catalog)` | command: `{type, instance_id, target_id, ...}` | `{battle, state, result, accepted, feeds, finished}` | **唯一合法行动入口**；`finished=true` 即战斗结束（victory/defeat/retreat） |
| `Facade.apply_enemy_pre_turn(battle, state, catalog)` | battle | `{battle}` | 回合前敌方结算（未接入主流程则保持空实现） |
| `V1.player_action(battle, action)` | action: `{type: play_gu/basic_attack/play_kill_move/end_turn}` | `{battle, result:{ok, reason, changes}}` | 底层原语；**表现层不得直呼**，仅守卫测试使用 |
| `V1.end_turn(battle)` | battle | `{battle, result}` | 敌方意图结算 + 新回合；内部检查 `_is_over` |
| `Facade.boss_blocks_retreat(battle)` | battle | bool | Boss 战禁止撤退 |

## 关键数据契约（battle 字典）

- 玩家区：`player.{hp, max_hp, shield, life_time, soul, true_qi, thoughts, used_this_turn, buffs{force/yi_zhang}, position, cultivation}`
- 敌区：`enemies[] = {id, label, hp, max_hp, shield, alive, intent{kind, damage, seal_turns, soul_drain, life_cost}, statuses{}, counter_revealed, counter_hidden}`
- 蛊槽：`gu_slots[] = {instance_id, definition_id, rank, used_this_turn, is_sealed, consumed, true_qi_cost, thought_cost, durability_mode, v1_effect, effect}`
- 阶段：`phase ∈ {player_action, victory, defeat}`；`result = {outcome, cause}`（cause ∈ hp/life_cost/soul）
- 旗标：`flags = {}`（Dictionary，非 Array；Boss 战含 `boss_battle`）

## 信号

无（纯函数式 domain 模块；表现层经 `run_controller` 轮询 `finished/result`）。

## 依赖

- `content_catalog.gd`（load_all 提供蛊定义/敌人/数值）；`run_state.gd`（RunState 投影）
- `data/balance.json`（撤退/转阶成本）；`data/enemies.json`（敌人基础值）
- `action_points.gd`（每回合行动数）；`cultivator_rules.gd`（转阶门禁）；`seeded_roll.gd`

## 强制规则（Agent 生成代码必读）

1. 战斗任何状态变更必须经 `Facade.apply_turn`；表现层不得改写 battle 字典键。
2. 新增行动类型必须三处同步：`Facade.apply_turn` 的 command 路由、`V1.player_action` 的 action 路由、`docs/contracts/2026-09-02-domain-ui-contract.md` 命令面。
3. 战斗结束（victory/defeat/retreat）后任何 action 必须返回 `battle_over` 拒绝（`player_action` 入口已强制）。
4. 效果数值只经 `v1_effect`/`effect` 字典表达，禁止在 resolver 内硬编码成本/伤害。
